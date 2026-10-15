-- Run in an isolated schema with 001,002,003 installed. ALWAYS roll back.
BEGIN;
CREATE OR REPLACE FUNCTION presales.test_assert(ok boolean,label text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERTION FAILED: %',label; END IF;
END $$;

DO $$
DECLARE a jsonb; b jsonb; c jsonb; d jsonb; job jsonb; token uuid; conv uuid; out_id uuid; n integer;
BEGIN
  PERFORM presales.test_assert((SELECT count(*)=2 FROM presales.messages WHERE text_content LIKE 'legacy%'),'legacy rows preserved');
  PERFORM presales.test_assert((SELECT count(*)=2 FROM presales.messages WHERE telegram_chat_id=86000001),'legacy chat backfill');
  PERFORM presales.test_assert((SELECT count(*)=1 FROM presales.chat_message_receipts),'legacy duplicate canonical receipt');
  a := presales.accept_update('{"update_id":86000003,"message_id":1,"chat_id":86000001,"user_id":86000001,"text":"duplicate old","message_type":"text"}');
  PERFORM presales.test_assert(a->>'status'='duplicate','legacy cross-conversation duplicate');
  a := presales.accept_update('{"update_id":86000004,"message_id":2,"chat_id":86000001,"user_id":86000001,"text":"next","message_type":"text"}');
  PERFORM presales.test_assert(a->>'conversation_id'='86000000-0000-0000-0000-000000000003','existing active conversation reused');
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c#>>'{state,requirements,legacy}'='true','legacy state preserved');
  PERFORM presales.commit_decision((c->>'update_id')::bigint,(c->>'lease_token')::uuid,'{"state":{"requirements":{"legacy":true}},"response":"Recorded"}');
  job := presales.claim_outbox();
  PERFORM presales.finish_outbox((job->>'id')::uuid,(job->>'lease_token')::uuid,'{"ok":true,"message_id":500,"status":200}');

  a := presales.accept_update('{"update_id":87000000,"message":{"message_id":1,"chat":{"id":87000000,"type":"group"},"from":{"id":87000000,"is_bot":false},"text":"hello"}}');
  PERFORM presales.test_assert(a->>'status'='ignored','reject group');
  a := presales.accept_update('{"update_id":87000000,"message":{"message_id":1,"chat":{"id":87000000,"type":"private"},"from":{"id":87000000,"is_bot":true},"text":"hello"}}');
  PERFORM presales.test_assert(a->>'status'='ignored','reject bot');
  a := presales.accept_update('{"update_id":9999999999999999999,"message_id":1,"chat_id":87000000,"user_id":87000000,"text":"hello"}');
  PERFORM presales.test_assert(a->>'status'='ignored','reject overflow');

  a := presales.accept_update('{"update_id":87000001,"message_id":1,"chat_id":87000001,"user_id":87000001,"text":"email person@example.com 09171234567","message_type":"text"}');
  conv := (a->>'conversation_id')::uuid;
  b := presales.accept_update('{"update_id":87000001,"message_id":1,"chat_id":87000001,"user_id":87000001,"text":"same"}');
  PERFORM presales.test_assert(b->>'status'='duplicate','update duplicate');
  b := presales.accept_update('{"update_id":87000002,"message_id":1,"chat_id":87000001,"user_id":87000001,"text":"same message new update"}');
  PERFORM presales.test_assert(b->>'status'='duplicate','chat message duplicate');
  PERFORM presales.accept_update('{"update_id":87000003,"message_id":2,"chat_id":87000001,"user_id":87000001,"text":"next"}');
  c := presales.claim_inbox(); token := (c->>'lease_token')::uuid;
  PERFORM presales.test_assert(c->>'update_id'='87000001','claim oldest');
  PERFORM presales.test_assert((c->>'lease_until')::timestamptz>clock_timestamp()+interval '590 seconds','600 second inbox lease');
  PERFORM presales.test_assert(c#>>'{envelope,text}' NOT LIKE '%person@example.com%' AND c#>>'{envelope,text}' NOT LIKE '%09171234567%','contact redacted');
  PERFORM presales.test_assert(c#>>'{state,contact_present}'='false','contact absent');
  PERFORM presales.test_assert(presales.claim_inbox() IS NULL,'one outstanding claim per conversation');
  BEGIN
    PERFORM presales.commit_decision(87000001,gen_random_uuid(),'{"state":{},"response":"wrong"}');
    RAISE EXCEPTION 'stale token accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  BEGIN
    PERFORM presales.commit_decision(87000001,token,'{"state":{"bad":true},"response":"x","handoff":{"reason":"test","priority":"invalid","summary":"test"}}');
    RAISE EXCEPTION 'invalid handoff accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM presales.conversation_state WHERE conversation_id=conv AND state ? 'bad'),'failed commit rolled back state');
  d := presales.commit_decision(87000001,token,jsonb_set('{"state":{"requirements":{"scope":"CRM"}},"consent_status":"granted","consent_evidence":{"command":"/consent yes"},"response":"Recorded","lead":{"score":80,"status":"hot","summary":"lead","reasons":[]},"estimate":{"service_code":"crm_data_entry","total_min":10000,"total_max":18000,"calculation":{},"disclaimer":"placeholder"}}'::jsonb,
    '{estimate,disclaimer}',(SELECT policy_value->'text' FROM presales.business_policies WHERE code='estimate_disclaimer')));
  out_id := (d->>'outbox_id')::uuid;
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM presales.leads WHERE conversation_id=conv),'lead requires stored contact and consent');
  PERFORM presales.test_assert((SELECT count(*)=1 FROM presales.consent_events WHERE update_id=87000001),'consent evidence appended');
  b := presales.commit_decision(87000001,token,'{"state":{},"response":"ignored replay"}');
  PERFORM presales.test_assert(b->>'status'='duplicate' AND b->>'outbox_id'=out_id::text,'commit replay same reply');
  PERFORM presales.test_assert((SELECT count(*)=1 FROM presales.outbox_jobs WHERE update_id=87000001),'one reply');
  BEGIN PERFORM presales.replay_inbox(87000001); RAISE EXCEPTION 'completed replay allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c#>>'{state,requirements,scope}'='CRM','next claim sees committed state');
  PERFORM presales.fail_inbox(87000003,(c->>'lease_token')::uuid,'transient',true);
  PERFORM presales.test_assert((SELECT status='retry_wait' AND available_at>clock_timestamp() FROM presales.inbox_jobs WHERE update_id=87000003),'inbox retry backoff');
  UPDATE presales.inbox_jobs SET available_at=clock_timestamp()-interval '1 second' WHERE update_id=87000003;
  c := presales.claim_inbox(); token := (c->>'lease_token')::uuid;
  UPDATE presales.inbox_jobs SET lease_until=clock_timestamp()-interval '1 second' WHERE update_id=87000003;
  BEGIN PERFORM presales.commit_decision(87000003,token,'{"state":{},"response":"late"}'); RAISE EXCEPTION 'expired commit allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  c := presales.claim_inbox();
  PERFORM presales.test_assert((c->>'lease_token')::uuid<>token,'reclaim rotates token');
  BEGIN PERFORM presales.fail_inbox(87000003,token,'stale',true); RAISE EXCEPTION 'stale failure allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  PERFORM presales.fail_inbox(87000003,(c->>'lease_token')::uuid,'permanent',false);
  PERFORM presales.test_assert(presales.claim_inbox() IS NULL,'dead letter not automatically reclaimed');
  PERFORM presales.replay_inbox(87000003);
  c := presales.claim_inbox();
  PERFORM presales.commit_decision(87000003,(c->>'lease_token')::uuid,'{"state":{},"response":"Recovered"}');

  job := presales.claim_outbox();
  PERFORM presales.test_assert(job->>'id'=out_id::text,'outbox order');
  PERFORM presales.test_assert(presales.claim_outbox() IS NULL,'one outbox lease per destination');
  d := presales.finish_outbox((job->>'id')::uuid,(job->>'lease_token')::uuid,'{"ok":false,"status":429,"retry_after":30,"error":"rate limited"}');
  PERFORM presales.test_assert(d->>'status'='retry_wait' AND (SELECT available_at>clock_timestamp()+interval '29 seconds' FROM presales.outbox_jobs WHERE id=out_id),'429 retry_after');
  UPDATE presales.outbox_jobs SET available_at=clock_timestamp()-interval '1 second' WHERE id=out_id;
  job := presales.claim_outbox(); token := (job->>'lease_token')::uuid;
  d := presales.finish_outbox(out_id,token,'{"ok":true,"message_id":501,"status":200}');
  PERFORM presales.test_assert(d->>'status'='sent','send acknowledgement');
  d := presales.finish_outbox(out_id,token,'{"ok":true,"message_id":501,"status":200}');
  PERFORM presales.test_assert(d->>'status'='duplicate','send ack replay');
  BEGIN PERFORM presales.replay_outbox(out_id); RAISE EXCEPTION 'sent replay allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  job := presales.claim_outbox(); out_id := (job->>'id')::uuid; token := (job->>'lease_token')::uuid;
  UPDATE presales.outbox_jobs SET lease_until=clock_timestamp()-interval '1 second' WHERE id=out_id;
  PERFORM presales.test_assert(presales.claim_outbox() IS NULL,'expired delivery quarantined');
  PERFORM presales.test_assert((SELECT status='dead_letter' AND delivery_uncertain FROM presales.outbox_jobs WHERE id=out_id),'unknown delivery dead letter');
  BEGIN PERFORM presales.finish_outbox(out_id,token,'{"ok":true,"message_id":502}'); RAISE EXCEPTION 'stale sender accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  BEGIN PERFORM presales.replay_outbox(out_id); RAISE EXCEPTION 'ambiguous replay without acknowledgement';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;
  PERFORM presales.replay_outbox(out_id,true);
  job := presales.claim_outbox();
  PERFORM presales.finish_outbox(out_id,(job->>'lease_token')::uuid,'{"ok":true,"message_id":502}');

  PERFORM presales.configure_owner_chat(88000001);
  PERFORM presales.accept_update('{"update_id":87000004,"message_id":3,"chat_id":87000001,"user_id":87000001,"text":"/contact person@example.com"}');
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c#>>'{state,contact_present}'='true' AND c#>>'{envelope,text}'='/contact [EMAIL STORED WITH CONSENT]','consented contact placeholder');
  PERFORM presales.test_assert(NOT(c ? 'runtime_settings') AND NOT(c->'catalog' ? 'runtime_settings'),'private settings excluded');
  d := presales.commit_decision(87000004,(c->>'lease_token')::uuid,'{"state":{},"response":"Handoff recorded","lead":{"score":80,"status":"hot","summary":"lead"},"handoff":{"reason":"requested","priority":"normal","summary":"CRM scope"}}');
  PERFORM presales.test_assert(d->>'owner_outbox_id' IS NOT NULL,'owner job queued');
  PERFORM presales.test_assert((SELECT payload->>'text' LIKE '%person@example.com%' FROM presales.outbox_jobs WHERE id=(d->>'owner_outbox_id')::uuid),'consented contact in owner notification');
  PERFORM presales.test_assert((SELECT NOT score_approved AND status='unqualified' FROM presales.leads WHERE conversation_id=conv),'unapproved scoring unqualified');
  PERFORM presales.accept_update('{"update_id":87000005,"message_id":4,"chat_id":87000001,"user_id":87000001,"text":"follow up"}');
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c->>'conversation_status'='handed_off','handoff visible in claim');
  BEGIN PERFORM presales.commit_decision(87000005,(c->>'lease_token')::uuid,'{"state":{},"response":"Price","estimate":{"service_code":"crm_data_entry","total_min":10000,"total_max":18000,"disclaimer":"Preliminary"}}');
    RAISE EXCEPTION 'estimate after handoff allowed'; EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
  d := presales.commit_decision(87000005,(c->>'lease_token')::uuid,'{"state":{},"response":"Already recorded","lead":{"score":80,"status":"hot","approved":true,"summary":"lead"},"handoff":{"reason":"requested","priority":"normal","summary":"CRM scope"}}');
  PERFORM presales.test_assert(d->>'owner_outbox_id' IS NULL,'repeated handoff does not notify again');
  PERFORM presales.test_assert((SELECT count(*)=1 FROM presales.handoff_tickets WHERE conversation_id=conv),'repeated handoff reuses ticket');
  PERFORM presales.test_assert((SELECT score_approved AND status='hot' FROM presales.leads WHERE conversation_id=conv),'approved scoring applied');
  PERFORM presales.accept_update('{"update_id":87000006,"message_id":5,"chat_id":87000001,"user_id":87000001,"text":"/delete"}');
  c := presales.claim_inbox();
  PERFORM presales.commit_decision(87000006,(c->>'lease_token')::uuid,'{"state":{"old":true},"reset":true,"consent_status":"withdrawn","response":"Recorded","privacy_delete_requested":true}');
  PERFORM presales.test_assert((SELECT contact_email IS NULL FROM presales.customers WHERE telegram_user_id=87000001),'withdrawal clears contact');
  PERFORM presales.test_assert((SELECT state='{"requirements":{},"consent":"withdrawn"}'::jsonb FROM presales.conversation_state WHERE conversation_id=conv),'reset baseline canonical consent');
  PERFORM presales.test_assert((SELECT count(*)=1 AND bool_and(reason='privacy_delete_requested') FROM presales.handoff_tickets WHERE conversation_id=conv),'privacy request updates local ticket');
  PERFORM presales.test_assert((SELECT status='handed_off' FROM presales.conversations WHERE id=conv),'handoff retained');
END $$;

DO $$
DECLARE c jsonb; a jsonb; n integer; k integer;
BEGIN
  -- Exclude catalog rows in all five groups, while retaining the original data.
  UPDATE presales.services SET approved=false WHERE code='crm_data_entry';
  UPDATE presales.service_packages SET active=false WHERE code='starter_automation';
  UPDATE presales.pricing_adjustments SET approved=false WHERE code='custom_api';
  UPDATE presales.business_policies SET active=false WHERE code='estimate_disclaimer';
  UPDATE presales.faqs SET approved=false;
  PERFORM presales.accept_update('{"update_id":89000001,"message_id":1,"chat_id":89000001,"user_id":89000001,"text":"password=this-must-not-be-stored"}');
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c#>>'{envelope,text}'='[REDACTED SENSITIVE TEXT]' AND c#>>'{envelope,message_type}'='sensitive','sensitive message persisted only as marker');
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c#>'{catalog,services}') x WHERE x->>'code'='crm_data_entry'),'unapproved service excluded');
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c#>'{catalog,packages}') x WHERE x->>'code'='starter_automation'),'inactive package excluded');
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c#>'{catalog,adjustments}') x WHERE x->>'code'='custom_api'),'unapproved adjustment excluded');
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c#>'{catalog,policies}') x WHERE x->>'code'='estimate_disclaimer'),'inactive policy excluded');
  PERFORM presales.test_assert(c#>'{catalog,faqs}'='[]'::jsonb,'unapproved FAQ excluded');
  PERFORM presales.commit_decision(89000001,(c->>'lease_token')::uuid,'{"state":{"api_key":"must-not-persist","nested":{"password":"also-private"}},"response":"Please do not share credentials"}');
  PERFORM presales.test_assert((SELECT state#>>'{nested,password}'='[REDACTED]' FROM presales.conversation_state WHERE conversation_id=(c->>'conversation_id')::uuid),'recursive sensitive key redaction');
  PERFORM presales.accept_update('{"update_id":89000002,"message_id":2,"chat_id":89000001,"user_id":89000001,"message_type":"unsupported","text":"attachment"}');
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c#>>'{envelope,message_type}'='unsupported','unsupported gets deterministic worker handling');
  PERFORM presales.commit_decision(89000002,(c->>'lease_token')::uuid,'{"state":{},"response":"Please send text"}');
  PERFORM presales.accept_update(jsonb_build_object('update_id',89000003,'message_id',3,'chat_id',89000001,'user_id',89000001,'text',repeat('x',5000)));
  c := presales.claim_inbox();
  PERFORM presales.test_assert(c#>>'{envelope,message_type}'='too_long','too long gets deterministic worker handling');
  FOR k IN 1..5 LOOP
    PERFORM presales.fail_inbox(89000003,(c->>'lease_token')::uuid,'failure',true);
    IF k<5 THEN
      UPDATE presales.inbox_jobs SET available_at=clock_timestamp()-interval '1 second' WHERE update_id=89000003;
      c := presales.claim_inbox();
    END IF;
  END LOOP;
  PERFORM presales.test_assert((SELECT status='dead_letter' AND attempts=5 FROM presales.inbox_jobs WHERE update_id=89000003),'five attempts dead letter');
  PERFORM presales.test_assert((SELECT count(*)=1 FROM presales.outbox_jobs WHERE job_type='legacy_job' AND payload='{"preserve":true}'::jsonb),'legacy outbox preserved');
  PERFORM presales.test_assert(NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='presales' AND p.proname<>'test_assert' AND p.prosecdef),'functions use invoker');
END $$;
ROLLBACK;
