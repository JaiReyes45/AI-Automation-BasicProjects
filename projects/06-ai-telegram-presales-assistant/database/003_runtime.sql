BEGIN;

-- Existing data belongs to this private-chat bot; recover legacy chat identities.
ALTER TABLE presales.conversations ADD COLUMN IF NOT EXISTS telegram_chat_id bigint;
ALTER TABLE presales.messages ADD COLUMN IF NOT EXISTS telegram_chat_id bigint;
UPDATE presales.conversations c SET telegram_chat_id=u.telegram_user_id
  FROM presales.customers u WHERE u.id=c.customer_id AND c.telegram_chat_id IS NULL;
UPDATE presales.messages m SET telegram_chat_id=c.telegram_chat_id
  FROM presales.conversations c WHERE c.id=m.conversation_id AND m.telegram_chat_id IS NULL;
CREATE INDEX IF NOT EXISTS messages_incoming_chat_message_idx
  ON presales.messages(telegram_chat_id, telegram_message_id)
  WHERE direction = 'incoming' AND telegram_chat_id IS NOT NULL;
ALTER TABLE presales.customers ADD COLUMN IF NOT EXISTS contact_email text;
ALTER TABLE presales.leads ADD COLUMN IF NOT EXISTS score_approved boolean NOT NULL DEFAULT false;

ALTER TABLE presales.services ADD COLUMN IF NOT EXISTS approved boolean NOT NULL DEFAULT false;
ALTER TABLE presales.service_packages ADD COLUMN IF NOT EXISTS approved boolean NOT NULL DEFAULT false;
ALTER TABLE presales.pricing_adjustments ADD COLUMN IF NOT EXISTS approved boolean NOT NULL DEFAULT false;
ALTER TABLE presales.business_policies ADD COLUMN IF NOT EXISTS approved boolean NOT NULL DEFAULT false;
ALTER TABLE presales.faqs ADD COLUMN IF NOT EXISTS approved boolean NOT NULL DEFAULT false;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '003') THEN
    UPDATE presales.services SET approved = true;
    UPDATE presales.service_packages SET approved = true;
    UPDATE presales.pricing_adjustments SET approved = true;
    UPDATE presales.business_policies SET approved = true;
    UPDATE presales.faqs SET approved = true WHERE nullif(btrim(approved_by), '') IS NOT NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS presales.chat_sessions (
  chat_id bigint PRIMARY KEY,
  customer_id uuid NOT NULL REFERENCES presales.customers(id),
  conversation_id uuid NOT NULL UNIQUE REFERENCES presales.conversations(id)
);
INSERT INTO presales.chat_sessions(chat_id,customer_id,conversation_id)
  SELECT DISTINCT ON (telegram_chat_id) telegram_chat_id,customer_id,id FROM presales.conversations
  WHERE telegram_chat_id IS NOT NULL
  ORDER BY telegram_chat_id,(status IN ('closed','expired')),last_activity_at DESC,id
  ON CONFLICT(chat_id) DO NOTHING;
-- Legacy duplicate rows are preserved. The receipt selects a canonical message.
CREATE TABLE IF NOT EXISTS presales.chat_message_receipts (
  chat_id bigint NOT NULL,
  telegram_message_id bigint NOT NULL,
  message_id uuid NOT NULL REFERENCES presales.messages(id),
  PRIMARY KEY(chat_id,telegram_message_id)
);
INSERT INTO presales.chat_message_receipts(chat_id,telegram_message_id,message_id)
  SELECT DISTINCT ON (telegram_chat_id,telegram_message_id) telegram_chat_id,telegram_message_id,id
  FROM presales.messages WHERE direction='incoming' AND telegram_chat_id IS NOT NULL AND telegram_message_id IS NOT NULL
  ORDER BY telegram_chat_id,telegram_message_id,created_at,id ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS presales.consent_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES presales.customers(id),
  conversation_id uuid NOT NULL REFERENCES presales.conversations(id),
  update_id bigint NOT NULL UNIQUE,
  previous_status text NOT NULL,
  consent_status text NOT NULL CHECK (consent_status IN ('unknown','granted','denied','withdrawn')),
  evidence jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS presales.runtime_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS presales.inbox_jobs (
  update_id bigint PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES presales.conversations(id),
  customer_id uuid NOT NULL REFERENCES presales.customers(id),
  message_id uuid NOT NULL UNIQUE REFERENCES presales.messages(id),
  envelope jsonb NOT NULL CHECK (jsonb_typeof(envelope) = 'object'),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','completed','retry_wait','dead_letter')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  available_at timestamptz NOT NULL DEFAULT now(),
  lease_until timestamptz,
  lease_token uuid,
  last_error text,
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (status <> 'processing' OR (lease_token IS NOT NULL AND lease_until IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS inbox_conversation_order_idx
  ON presales.inbox_jobs(conversation_id,created_at,update_id) WHERE status <> 'completed';
CREATE INDEX IF NOT EXISTS inbox_due_idx ON presales.inbox_jobs(available_at,created_at)
  WHERE status IN ('pending','retry_wait','processing');

ALTER TABLE presales.outbox_jobs ADD COLUMN IF NOT EXISTS update_id bigint REFERENCES presales.inbox_jobs(update_id);
ALTER TABLE presales.outbox_jobs ADD COLUMN IF NOT EXISTS lease_until timestamptz;
ALTER TABLE presales.outbox_jobs ADD COLUMN IF NOT EXISTS lease_token uuid;
ALTER TABLE presales.outbox_jobs ADD COLUMN IF NOT EXISTS telegram_message_id bigint;
ALTER TABLE presales.outbox_jobs ADD COLUMN IF NOT EXISTS delivery_uncertain boolean NOT NULL DEFAULT false;
ALTER TABLE presales.outbox_jobs ADD COLUMN IF NOT EXISTS runtime_sequence bigserial;
CREATE UNIQUE INDEX IF NOT EXISTS outbox_runtime_update_uidx
  ON presales.outbox_jobs(update_id,job_type) WHERE update_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS outbox_conversation_order_idx
  ON presales.outbox_jobs(aggregate_id,created_at,id) WHERE status <> 'sent';
ALTER TABLE presales.dead_letter_events ADD COLUMN IF NOT EXISTS inbox_update_id bigint;

CREATE OR REPLACE FUNCTION presales.redact_text(p text) RETURNS text
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
BEGIN
  IF p IS NULL THEN RETURN NULL; END IF;
  IF p ~* '((password|passwd|secret|api[ _-]?key|access[ _-]?token|authorization|private[ _-]?key)(["'']?[[:space:]]*[:=]|[[:space:]]+is[[:space:]])|bearer[[:space:]]|BEGIN[[:space:]]+.*PRIVATE KEY|sk-[a-zA-Z0-9_-]{12,}|[0-9]{6,12}:[a-zA-Z0-9_-]{20,})'
    THEN RETURN '[REDACTED SENSITIVE TEXT]'; END IF;
  RETURN regexp_replace(regexp_replace(p,
    '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}', '[REDACTED EMAIL]', 'g'),
    '[+]?[0-9]([ .()-]*[0-9]){9,15}', '[REDACTED PHONE]', 'g');
END $$;

CREATE OR REPLACE FUNCTION presales.redact_json(p jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE r jsonb; k text; v jsonb;
BEGIN
  CASE jsonb_typeof(p)
  WHEN 'object' THEN
    r := '{}'::jsonb;
    FOR k,v IN SELECT key,value FROM jsonb_each(p) LOOP
      r := r || jsonb_build_object(k, CASE WHEN k ~* '(password|passwd|secret|api[_-]?key|access[_-]?token|authorization|credential|private[_-]?key)'
        THEN '"[REDACTED]"'::jsonb ELSE presales.redact_json(v) END);
    END LOOP;
    RETURN r;
  WHEN 'array' THEN
    SELECT coalesce(jsonb_agg(presales.redact_json(value) ORDER BY ordinality),'[]'::jsonb)
      INTO r FROM jsonb_array_elements(p) WITH ORDINALITY;
    RETURN r;
  WHEN 'string' THEN RETURN to_jsonb(presales.redact_text(p #>> '{}'));
  ELSE RETURN p;
  END CASE;
END $$;

CREATE OR REPLACE FUNCTION presales.accept_update(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE u bigint; ch bigint; usr bigint; tm bigint; cid uuid; conv uuid; mid uuid;
  m jsonb; env jsonb; body text; consent text; old record; mt text;
BEGIN
  -- The flat envelope is produced by the trusted workflow AFTER Telegram validation.
  IF jsonb_typeof(p)='object' AND NOT (p ? 'message') THEN
    p := jsonb_build_object('update_id',p->'update_id','message',jsonb_build_object(
      'message_id',p->'message_id','date',p->'timestamp','text',p->'text','message_type',p->'message_type',
      'chat',jsonb_build_object('id',p->'chat_id','type',coalesce(p->>'chat_type','private')),
      'from',jsonb_build_object('id',p->'user_id','is_bot',coalesce(p->'is_bot','false'::jsonb),
        'username',p->'username','first_name',p->'display_name')));
  END IF;
  m := p->'message';
  IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR jsonb_typeof(m) IS DISTINCT FROM 'object'
    OR m#>>'{chat,type}' IS DISTINCT FROM 'private'
    OR m#>'{from,is_bot}' IS DISTINCT FROM 'false'::jsonb
    OR m ? 'sender_chat' OR m ? 'via_bot'
    OR coalesce(p->>'update_id','') !~ '^[0-9]{1,19}$'
    OR coalesce(m->>'message_id','') !~ '^[0-9]{1,19}$'
    OR coalesce(m#>>'{chat,id}','') !~ '^[0-9]{1,19}$'
    OR coalesce(m#>>'{from,id}','') !~ '^[0-9]{1,19}$'
    THEN RETURN jsonb_build_object('status','ignored','reason','unsupported_update'); END IF;
  BEGIN
    u := (p->>'update_id')::bigint; ch := (m#>>'{chat,id}')::bigint;
    usr := (m#>>'{from,id}')::bigint; tm := (m->>'message_id')::bigint;
  EXCEPTION WHEN numeric_value_out_of_range THEN
    RETURN jsonb_build_object('status','ignored','reason','invalid_identifier');
  END;
  IF ch <= 0 OR usr <> ch OR tm <= 0 THEN
    RETURN jsonb_build_object('status','ignored','reason','invalid_private_identity'); END IF;
  -- Lock update first, then chat; concurrent duplicates share the same order.
  PERFORM pg_advisory_xact_lock(hashtextextended('presales.update:' || u::text,0));
  PERFORM pg_advisory_xact_lock(hashtextextended('presales.chat:' || ch::text,0));
  SELECT x.id AS message_id,x.conversation_id,c.customer_id,x.telegram_update_id INTO old
    FROM presales.messages x JOIN presales.conversations c ON c.id=x.conversation_id
    WHERE x.telegram_update_id=u OR x.id=(SELECT r.message_id FROM presales.chat_message_receipts r WHERE r.chat_id=ch AND r.telegram_message_id=tm)
    ORDER BY (x.telegram_update_id=u) DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('status','duplicate','update_id',u,'original_update_id',old.telegram_update_id,
      'message_id',old.message_id,'conversation_id',old.conversation_id,'customer_id',old.customer_id);
  END IF;
  IF EXISTS (SELECT 1 FROM presales.processed_updates WHERE update_id=u) THEN
    RETURN jsonb_build_object('status','duplicate','update_id',u); END IF;
  INSERT INTO presales.customers(telegram_user_id,username,display_name)
    VALUES(usr,presales.redact_text(m#>>'{from,username}'),presales.redact_text(btrim(concat_ws(' ',m#>>'{from,first_name}',m#>>'{from,last_name}'))))
    ON CONFLICT(telegram_user_id) DO UPDATE SET updated_at=clock_timestamp()
    RETURNING id,consent_status INTO cid,consent;
  SELECT conversation_id INTO conv FROM presales.chat_sessions WHERE chat_id=ch;
  IF conv IS NOT NULL AND EXISTS(SELECT 1 FROM presales.conversations c WHERE c.id=conv
      AND (c.status IN ('closed','expired') OR c.last_activity_at<clock_timestamp()-interval '24 hours'))
    AND NOT EXISTS(SELECT 1 FROM presales.inbox_jobs i WHERE i.conversation_id=conv AND i.status<>'completed') THEN
    UPDATE presales.conversations SET status='expired',updated_at=clock_timestamp() WHERE id=conv AND status NOT IN ('closed','expired');
    conv := NULL;
  END IF;
  IF conv IS NULL THEN
    INSERT INTO presales.conversations(customer_id,telegram_chat_id,status)
      VALUES(cid,ch,'active') RETURNING id INTO conv;
    INSERT INTO presales.chat_sessions VALUES(ch,cid,conv)
      ON CONFLICT(chat_id) DO UPDATE SET customer_id=EXCLUDED.customer_id,conversation_id=EXCLUDED.conversation_id;
  END IF;
  INSERT INTO presales.conversation_state(conversation_id,state)
    VALUES(conv,jsonb_build_object('requirements','{}'::jsonb,'consent',consent)) ON CONFLICT DO NOTHING;
  mt := coalesce(m->>'message_type','text');
  IF mt NOT IN ('text','unsupported','too_long','sensitive') THEN mt := 'unsupported'; END IF;
  IF jsonb_typeof(m->'text') IS DISTINCT FROM 'string' OR length(btrim(m->>'text'))=0 THEN mt := 'unsupported'; END IF;
  IF length(m->>'text')>4096 THEN mt := 'too_long'; END IF;
  body := CASE mt WHEN 'unsupported' THEN '[UNSUPPORTED MESSAGE]' WHEN 'too_long' THEN '[MESSAGE TOO LONG]'
    WHEN 'sensitive' THEN '[REDACTED SENSITIVE TEXT]' ELSE presales.redact_text(m->>'text') END;
  IF body='[REDACTED SENSITIVE TEXT]' THEN mt := 'sensitive'; END IF;
  -- Only an exact /contact command, received AFTER consent, can save an email.
  IF mt='text' AND consent='granted' AND btrim(m->>'text') ~* '^/contact[[:space:]]+[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$' THEN
    UPDATE presales.customers SET contact_email=regexp_replace(btrim(m->>'text'),'^/contact[[:space:]]+','','i'),
      updated_at=clock_timestamp() WHERE id=cid;
    body := '/contact [EMAIL STORED WITH CONSENT]';
  END IF;
  env := jsonb_build_object('update_id',u,'chat_id',ch,'user_id',usr,'telegram_message_id',tm,
    'text',body,'message_type',mt,'sent_at',CASE WHEN jsonb_typeof(m->'date')='number' THEN m->'date' ELSE 'null'::jsonb END,
    'username',presales.redact_text(m#>>'{from,username}'),
    'display_name',presales.redact_text(btrim(concat_ws(' ',m#>>'{from,first_name}',m#>>'{from,last_name}'))));
  INSERT INTO presales.messages(conversation_id,direction,telegram_update_id,telegram_message_id,telegram_chat_id,text_content,message_type)
    VALUES(conv,'incoming',u,tm,ch,body,mt) RETURNING id INTO mid;
  INSERT INTO presales.chat_message_receipts(chat_id,telegram_message_id,message_id) VALUES(ch,tm,mid);
  INSERT INTO presales.inbox_jobs(update_id,conversation_id,customer_id,message_id,envelope)
    VALUES(u,conv,cid,mid,env);
  INSERT INTO presales.processed_updates(update_id,message_id) VALUES(u,mid);
  UPDATE presales.conversations SET last_activity_at=clock_timestamp(),updated_at=clock_timestamp() WHERE id=conv;
  RETURN jsonb_build_object('status','accepted','update_id',u,'conversation_id',conv,'customer_id',cid,'message_id',mid,'telegram_message_id',tm);
END $$;

CREATE OR REPLACE FUNCTION presales.claim_inbox() RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE j presales.inbox_jobs%ROWTYPE; cat jsonb; st jsonb; cs text;
BEGIN
  FOR j IN SELECT i.* FROM presales.inbox_jobs i
    WHERE ((i.status IN ('pending','retry_wait') AND i.available_at <= clock_timestamp())
       OR (i.status='processing' AND i.lease_until <= clock_timestamp()))
      AND NOT EXISTS(SELECT 1 FROM presales.inbox_jobs prev WHERE prev.conversation_id=i.conversation_id
        AND prev.status <> 'completed' AND (prev.created_at,prev.update_id)<(i.created_at,i.update_id))
    ORDER BY i.created_at,i.update_id FOR UPDATE OF i SKIP LOCKED
  LOOP
    IF NOT pg_try_advisory_xact_lock(hashtextextended('presales.inbox:' || j.conversation_id::text,0)) THEN CONTINUE; END IF;
    IF EXISTS(SELECT 1 FROM presales.inbox_jobs other WHERE other.conversation_id=j.conversation_id
      AND other.update_id<>j.update_id AND other.status='processing' AND other.lease_until>clock_timestamp()) THEN CONTINUE; END IF;
    IF j.attempts >= 5 THEN
      UPDATE presales.inbox_jobs SET status='dead_letter',lease_until=NULL,lease_token=NULL,
        last_error='attempts_exhausted',updated_at=clock_timestamp() WHERE update_id=j.update_id;
      INSERT INTO presales.dead_letter_events(source_type,source_id,inbox_update_id,error_message)
        VALUES('inbox',j.message_id,j.update_id,'attempts_exhausted');
      CONTINUE;
    END IF;
    UPDATE presales.inbox_jobs SET status='processing',attempts=attempts+1,lease_token=gen_random_uuid(),
      lease_until=clock_timestamp()+interval '600 seconds',updated_at=clock_timestamp()
      WHERE update_id=j.update_id RETURNING * INTO j;
    SELECT state INTO st FROM presales.conversation_state WHERE conversation_id=j.conversation_id;
    SELECT jsonb_build_object('requirements','{}'::jsonb) || coalesce(st,'{}'::jsonb)
      || jsonb_build_object('consent',consent_status,'contact_present',consent_status='granted' AND contact_email IS NOT NULL)
      INTO st FROM presales.customers WHERE id=j.customer_id;
    SELECT status INTO cs FROM presales.conversations WHERE id=j.conversation_id;
    SELECT jsonb_build_object(
      'services',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.code),'[]'::jsonb) FROM presales.services s WHERE active AND approved),
      'packages',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.code),'[]'::jsonb) FROM presales.service_packages s WHERE active AND approved),
      'adjustments',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.code),'[]'::jsonb) FROM presales.pricing_adjustments s WHERE active AND approved),
      'policies',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.code),'[]'::jsonb) FROM presales.business_policies s WHERE active AND approved),
      'faqs',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id),'[]'::jsonb) FROM presales.faqs s WHERE active AND approved)
    ) INTO cat;
    RETURN jsonb_build_object('update_id',j.update_id,'lease_token',j.lease_token,'lease_until',j.lease_until,
      'attempts',j.attempts,'conversation_id',j.conversation_id,'customer_id',j.customer_id,'message_id',j.message_id,
      'envelope',j.envelope,'state',st,'conversation_status',cs,'catalog',cat);
  END LOOP;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION presales.commit_decision(p_update_id bigint,p_lease_token uuid,p_decision jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE j presales.inbox_jobs%ROWTYPE; d jsonb; st jsonb; consent text; previous_consent text; ob uuid; owner_ob uuid;
  est uuid; ld uuid; ht uuid; v jsonb; reply text; res jsonb; cs text; owner_chat bigint; contact text;
  old_reason text; notify_owner boolean := false; disclaimer text; ceiling numeric; human_review boolean; est_status text;
BEGIN
  SELECT * INTO j FROM presales.inbox_jobs WHERE update_id=p_update_id FOR UPDATE;
  IF NOT FOUND OR p_lease_token IS NULL OR j.lease_token IS DISTINCT FROM p_lease_token THEN
    RAISE EXCEPTION 'invalid or stale inbox claim' USING ERRCODE='55000'; END IF;
  IF j.status='completed' THEN RETURN j.result || jsonb_build_object('status','duplicate'); END IF;
  IF j.status <> 'processing' OR j.lease_until <= clock_timestamp() THEN
    RAISE EXCEPTION 'expired or inactive inbox claim' USING ERRCODE='55000'; END IF;
  IF jsonb_typeof(p_decision) IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_decision->'state') IS DISTINCT FROM 'object'
    OR jsonb_typeof(p_decision->'response') IS DISTINCT FROM 'string'
    OR length(btrim(p_decision->>'response')) NOT BETWEEN 1 AND 4096 THEN
    RAISE EXCEPTION 'decision requires object state and nonempty response <=4096 characters' USING ERRCODE='22023'; END IF;
  FOREACH consent IN ARRAY ARRAY['estimate','lead','handoff'] LOOP
    IF p_decision ? consent AND jsonb_typeof(p_decision->consent) NOT IN ('object','null') THEN
      RAISE EXCEPTION 'invalid optional decision record' USING ERRCODE='22023'; END IF;
  END LOOP;
  d := presales.redact_json(p_decision - 'lease_token'); reply := d->>'response';
  SELECT consent_status,contact_email INTO previous_consent,contact FROM presales.customers WHERE id=j.customer_id FOR UPDATE;
  consent := coalesce(d->>'consent_status',previous_consent);
  IF consent NOT IN ('unknown','granted','denied','withdrawn') THEN
    RAISE EXCEPTION 'invalid consent status' USING ERRCODE='22023'; END IF;
  st := CASE WHEN coalesce((d->>'reset')::boolean,false)
    THEN jsonb_build_object('requirements','{}'::jsonb) ELSE d->'state' END;
  st := st || jsonb_build_object('consent',consent);
  UPDATE presales.customers SET consent_status=consent,
    contact_email=CASE WHEN consent='granted' THEN contact_email ELSE NULL END,
    updated_at=clock_timestamp() WHERE id=j.customer_id;
  IF d->>'consent_status' IS NOT NULL THEN
    INSERT INTO presales.consent_events(customer_id,conversation_id,update_id,previous_status,consent_status,evidence)
      VALUES(j.customer_id,j.conversation_id,j.update_id,previous_consent,consent,
        jsonb_build_object('message_id',j.message_id,'text',j.envelope->>'text','source','telegram_private_message',
          'decision_evidence',coalesce(d->'consent_evidence','{}'::jsonb)));
  END IF;
  UPDATE presales.conversation_state SET state=st,
    missing_information=CASE WHEN jsonb_typeof(st->'missing_information')='array' THEN st->'missing_information' ELSE '[]'::jsonb END,
    updated_at=clock_timestamp() WHERE conversation_id=j.conversation_id;
  SELECT status INTO cs FROM presales.conversations WHERE id=j.conversation_id FOR UPDATE;
  IF jsonb_typeof(d->'estimate')='object' AND cs='handed_off' THEN
    RAISE EXCEPTION 'automated estimates disabled after handoff' USING ERRCODE='22023'; END IF;
  IF jsonb_typeof(d->'estimate')='object' THEN
    v := d->'estimate';
    IF (v->>'package_code' IS NULL) = (v->>'service_code' IS NULL) THEN
      RAISE EXCEPTION 'estimate requires exactly one service or package code' USING ERRCODE='22023'; END IF;
    IF v->>'package_code' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM presales.service_packages
      WHERE code=(v->>'package_code')::text AND active AND approved) THEN
      RAISE EXCEPTION 'estimate package not approved/active' USING ERRCODE='22023'; END IF;
    IF v->>'service_code' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM presales.services
      WHERE code=(v->>'service_code')::text AND active AND approved) THEN
      RAISE EXCEPTION 'estimate service not approved/active' USING ERRCODE='22023'; END IF;
    SELECT policy_value->>'text' INTO disclaimer FROM presales.business_policies
      WHERE code='estimate_disclaimer' AND active AND approved;
    SELECT (policy_value->>'amount')::numeric INTO ceiling FROM presales.business_policies
      WHERE code='automatic_estimate_ceiling' AND active AND approved;
    IF disclaimer IS NULL OR v->>'disclaimer' IS DISTINCT FROM disclaimer OR ceiling IS NULL THEN
      RAISE EXCEPTION 'current approved estimate disclaimer and ceiling required' USING ERRCODE='22023'; END IF;
    IF jsonb_typeof(v->'total_min') IS DISTINCT FROM 'number' OR jsonb_typeof(v->'total_max') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'estimate totals must be JSON numbers' USING ERRCODE='22023'; END IF;
    SELECT coalesce(bool_or(s.requires_human),false) INTO human_review FROM presales.services s WHERE s.code=v->>'service_code';
    human_review := human_review OR (v->>'total_max')::numeric>ceiling;
    IF human_review AND jsonb_typeof(d->'handoff') IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'estimate requires human handoff at this price or service' USING ERRCODE='22023'; END IF;
    est_status := CASE WHEN human_review OR jsonb_typeof(d->'handoff')='object' THEN 'human_review' ELSE 'preliminary' END;
    INSERT INTO presales.estimates(conversation_id,service_code,package_code,total_min,total_max,currency,calculation,disclaimer,status)
      VALUES(j.conversation_id,(v->>'service_code')::text,(v->>'package_code')::text,
        (v->>'total_min')::numeric,(v->>'total_max')::numeric,coalesce(v->>'currency','PHP'),
        coalesce(v->'calculation','{}'::jsonb),(v->>'disclaimer')::text,est_status) RETURNING id INTO est;
  END IF;
  IF jsonb_typeof(d->'lead')='object' AND consent='granted' AND contact IS NOT NULL THEN
    v := d->'lead';
    INSERT INTO presales.leads(customer_id,conversation_id,score,status,reasons,summary,score_approved)
      VALUES(j.customer_id,j.conversation_id,(v->>'score')::integer,
        CASE WHEN coalesce((v->>'approved')::boolean,false) THEN (v->>'status')::text ELSE 'unqualified' END,
        coalesce(v->'reasons','[]'::jsonb),(v->>'summary')::text,coalesce((v->>'approved')::boolean,false))
      ON CONFLICT(conversation_id) DO UPDATE SET score=EXCLUDED.score,status=EXCLUDED.status,
        reasons=EXCLUDED.reasons,summary=EXCLUDED.summary,score_approved=EXCLUDED.score_approved,updated_at=clock_timestamp() RETURNING id INTO ld;
  END IF;
  IF jsonb_typeof(d->'handoff')='object' OR coalesce((d->>'privacy_delete_requested')::boolean,false) THEN
    v := CASE WHEN jsonb_typeof(d->'handoff')='object' THEN d->'handoff' ELSE
      jsonb_build_object('reason','privacy_delete_requested','priority','high','summary','Customer requested deletion. Human review required.') END;
    SELECT id,reason INTO ht,old_reason FROM presales.handoff_tickets WHERE conversation_id=j.conversation_id
      AND status IN ('open','acknowledged','in_progress') ORDER BY created_at,id LIMIT 1 FOR UPDATE;
    IF ht IS NULL THEN
      INSERT INTO presales.handoff_tickets(conversation_id,reason,priority,summary)
        VALUES(j.conversation_id,(v->>'reason')::text,coalesce(v->>'priority','normal'),(v->>'summary')::text) RETURNING id INTO ht;
      notify_owner := true;
    ELSE
      notify_owner := old_reason IS DISTINCT FROM v->>'reason';
      UPDATE presales.handoff_tickets SET reason=(v->>'reason')::text,priority=coalesce(v->>'priority','normal'),
        summary=(v->>'summary')::text,updated_at=clock_timestamp() WHERE id=ht;
    END IF;
  END IF;
  UPDATE presales.conversations SET status=CASE WHEN ht IS NOT NULL OR cs='handed_off' THEN 'handed_off' ELSE 'awaiting_customer' END,
    updated_at=clock_timestamp() WHERE id=j.conversation_id;
  INSERT INTO presales.audit_events(conversation_id,event_type,actor,correlation_id,input_reference,output_summary,metadata)
    VALUES(j.conversation_id,coalesce(d->>'event_type','decision_committed'),'system',j.update_id::text,j.message_id::text,
      'Decision committed; Telegram reply queued.',jsonb_build_object('estimate_id',est,'lead_id',ld,'handoff_id',ht,
        'reset',coalesce((d->>'reset')::boolean,false),'privacy_delete_requested',coalesce((d->>'privacy_delete_requested')::boolean,false)));
  INSERT INTO presales.outbox_jobs(job_type,aggregate_id,update_id,payload)
    VALUES('telegram_reply',j.conversation_id,j.update_id,jsonb_build_object('chat_id',(j.envelope->>'chat_id')::bigint,'text',reply))
    RETURNING id INTO ob;
  IF ht IS NOT NULL AND notify_owner THEN
    SELECT (value #>> '{}')::bigint INTO owner_chat FROM presales.runtime_settings WHERE key='owner_chat_id';
    IF owner_chat IS NOT NULL THEN
      INSERT INTO presales.outbox_jobs(job_type,aggregate_id,update_id,payload)
        VALUES('owner_notify',j.conversation_id,j.update_id,jsonb_build_object('chat_id',owner_chat,
          'text',left(concat_ws(E'\n','Pre-sales handoff recorded',
            'Ticket: ' || ht::text,'Conversation: ' || j.conversation_id::text,
            'Reason: ' || (v->>'reason'),'Priority: ' || coalesce(v->>'priority','normal'),
            'Summary: ' || (v->>'summary'),
            CASE WHEN consent='granted' AND contact IS NOT NULL THEN 'Contact: ' || contact END),4096))) RETURNING id INTO owner_ob;
    END IF;
  END IF;
  res := jsonb_build_object('status','completed','update_id',j.update_id,'conversation_id',j.conversation_id,
    'customer_id',j.customer_id,'message_id',j.message_id,'outbox_id',ob,'owner_outbox_id',owner_ob,'estimate_id',est,'lead_id',ld,'handoff_id',ht);
  UPDATE presales.inbox_jobs SET status='completed',result=res,lease_until=NULL,last_error=NULL,updated_at=clock_timestamp()
    WHERE update_id=j.update_id;
  RETURN res;
END $$;

CREATE OR REPLACE FUNCTION presales.commit_decision(p_update_id bigint,p_decision jsonb) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
  SELECT presales.commit_decision(p_update_id,(p_decision->>'lease_token')::uuid,p_decision);
$$;

CREATE OR REPLACE FUNCTION presales.fail_inbox(p_update_id bigint,p_lease_token uuid,p_error text,p_retryable boolean DEFAULT true) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE j presales.inbox_jobs%ROWTYPE; s text; err text;
BEGIN
  SELECT * INTO j FROM presales.inbox_jobs WHERE update_id=p_update_id FOR UPDATE;
  IF NOT FOUND OR p_lease_token IS NULL OR j.lease_token IS DISTINCT FROM p_lease_token
    OR j.status <> 'processing' OR j.lease_until <= clock_timestamp() THEN
    RAISE EXCEPTION 'invalid or expired inbox claim' USING ERRCODE='55000'; END IF;
  s := CASE WHEN coalesce(p_retryable,false) AND j.attempts < 5 THEN 'retry_wait' ELSE 'dead_letter' END;
  err := left(coalesce(presales.redact_text(p_error),'worker_failure'),1000);
  UPDATE presales.inbox_jobs SET status=s,last_error=err,lease_token=NULL,lease_until=NULL,
    available_at=clock_timestamp()+make_interval(secs => (5*power(2,least(j.attempts-1,6)))::integer),
    updated_at=clock_timestamp() WHERE update_id=p_update_id;
  IF s='dead_letter' THEN
    INSERT INTO presales.dead_letter_events(source_type,source_id,inbox_update_id,error_message)
      VALUES('inbox',j.message_id,j.update_id,err); END IF;
  RETURN jsonb_build_object('status',s,'update_id',p_update_id);
END $$;

CREATE OR REPLACE FUNCTION presales.replay_inbox(p_update_id bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
BEGIN
  UPDATE presales.inbox_jobs SET status='pending',attempts=0,available_at=clock_timestamp(),
    lease_token=NULL,lease_until=NULL,last_error=NULL,updated_at=clock_timestamp()
    WHERE update_id=p_update_id AND status='dead_letter';
  IF NOT FOUND THEN RAISE EXCEPTION 'only dead-letter inbox jobs can be replayed' USING ERRCODE='55000'; END IF;
  UPDATE presales.dead_letter_events SET replay_status='replayed',replayed_at=clock_timestamp()
    WHERE source_type='inbox' AND inbox_update_id=p_update_id AND replay_status='pending';
  INSERT INTO presales.audit_events(event_type,actor,correlation_id) VALUES('inbox_replayed','human',p_update_id::text);
  RETURN jsonb_build_object('status','pending','update_id',p_update_id);
END $$;

CREATE OR REPLACE FUNCTION presales.claim_outbox() RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE j presales.outbox_jobs%ROWTYPE;
BEGIN
  -- An expired send may have reached Telegram: quarantine, never auto-resend.
  FOR j IN SELECT * FROM presales.outbox_jobs WHERE job_type IN ('telegram_reply','owner_notify') AND update_id IS NOT NULL
    AND status='processing' AND lease_until <= clock_timestamp() FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE presales.outbox_jobs SET status='dead_letter',delivery_uncertain=true,lease_token=NULL,lease_until=NULL,
      last_error='delivery_unknown: lease expired',updated_at=clock_timestamp() WHERE id=j.id;
    INSERT INTO presales.dead_letter_events(source_type,source_id,error_message)
      VALUES('outbox',j.id,'delivery_unknown: lease expired');
  END LOOP;
  SELECT o.* INTO j FROM presales.outbox_jobs o WHERE o.job_type IN ('telegram_reply','owner_notify') AND o.update_id IS NOT NULL
    AND o.status IN ('pending','retry_wait') AND o.available_at <= clock_timestamp() AND o.attempts<5
    AND NOT EXISTS(SELECT 1 FROM presales.outbox_jobs prev WHERE prev.payload->>'chat_id'=o.payload->>'chat_id'
      AND prev.job_type IN ('telegram_reply','owner_notify') AND prev.update_id IS NOT NULL AND prev.status<>'sent'
      AND prev.runtime_sequence<o.runtime_sequence)
    ORDER BY o.runtime_sequence LIMIT 1 FOR UPDATE OF o SKIP LOCKED;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF NOT pg_try_advisory_xact_lock(hashtextextended('presales.delivery:' || (j.payload->>'chat_id'),0)) THEN RETURN NULL; END IF;
  IF EXISTS(SELECT 1 FROM presales.outbox_jobs other WHERE other.id<>j.id
    AND other.payload->>'chat_id'=j.payload->>'chat_id' AND other.job_type IN ('telegram_reply','owner_notify')
    AND other.status='processing' AND other.lease_until>clock_timestamp()) THEN RETURN NULL; END IF;
  UPDATE presales.outbox_jobs SET status='processing',attempts=attempts+1,lease_token=gen_random_uuid(),
    lease_until=clock_timestamp()+interval '120 seconds',updated_at=clock_timestamp() WHERE id=j.id RETURNING * INTO j;
  RETURN jsonb_build_object('id',j.id,'outbox_id',j.id,'lease_token',j.lease_token,'lease_until',j.lease_until,
    'attempts',j.attempts,'update_id',j.update_id,'job_type',j.job_type,'payload',j.payload);
END $$;

CREATE OR REPLACE FUNCTION presales.finish_outbox(p_outbox_id uuid,p_lease_token uuid,p_outcome text,
  p_telegram_message_id bigint,p_error text) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE j presales.outbox_jobs%ROWTYPE; s text; err text;
BEGIN
  SELECT * INTO j FROM presales.outbox_jobs WHERE id=p_outbox_id AND job_type IN ('telegram_reply','owner_notify') AND update_id IS NOT NULL FOR UPDATE;
  IF NOT FOUND OR p_lease_token IS NULL OR j.lease_token IS DISTINCT FROM p_lease_token THEN
    RAISE EXCEPTION 'invalid or stale outbox claim' USING ERRCODE='55000'; END IF;
  IF j.status='sent' AND p_outcome='sent' AND j.telegram_message_id=p_telegram_message_id THEN
    RETURN jsonb_build_object('status','duplicate','outbox_id',j.id); END IF;
  IF j.status <> 'processing' OR j.lease_until <= clock_timestamp() THEN
    RAISE EXCEPTION 'expired or inactive outbox claim' USING ERRCODE='55000'; END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('sent','retry','dead_letter','unknown') THEN
    RAISE EXCEPTION 'invalid delivery outcome' USING ERRCODE='22023'; END IF;
  IF p_outcome='sent' THEN
    IF p_telegram_message_id IS NULL OR p_telegram_message_id<=0 THEN
      RAISE EXCEPTION 'successful delivery requires Telegram message ID' USING ERRCODE='22023'; END IF;
    IF j.job_type='telegram_reply' THEN
      INSERT INTO presales.messages(conversation_id,direction,telegram_chat_id,telegram_message_id,text_content)
        VALUES(j.aggregate_id,'outgoing',(j.payload->>'chat_id')::bigint,p_telegram_message_id,(j.payload->>'text')::text);
    END IF;
    UPDATE presales.outbox_jobs SET status='sent',telegram_message_id=p_telegram_message_id,
      lease_until=NULL,delivery_uncertain=false,last_error=NULL,updated_at=clock_timestamp() WHERE id=j.id;
    RETURN jsonb_build_object('status','sent','outbox_id',j.id);
  END IF;
  s := CASE WHEN p_outcome='retry' AND j.attempts<5 THEN 'retry_wait' ELSE 'dead_letter' END;
  err := left(coalesce(presales.redact_text(p_error),p_outcome),1000);
  UPDATE presales.outbox_jobs SET status=s,delivery_uncertain=(p_outcome='unknown'),last_error=err,
    lease_token=NULL,lease_until=NULL,updated_at=clock_timestamp(),
    available_at=clock_timestamp()+make_interval(secs => (5*power(2,least(j.attempts-1,6)))::integer) WHERE id=j.id;
  IF s='dead_letter' THEN
    INSERT INTO presales.dead_letter_events(source_type,source_id,error_message) VALUES('outbox',j.id,err); END IF;
  RETURN jsonb_build_object('status',s,'outbox_id',j.id);
END $$;

CREATE OR REPLACE FUNCTION presales.finish_outbox(p_outbox_id uuid,p_lease_token uuid,p_result jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE outcome text; http_status integer; delay_seconds integer; result jsonb;
  requested_delay numeric; failure_text text;
BEGIN
  IF jsonb_typeof(p_result) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'delivery result must be an object' USING ERRCODE='22023'; END IF;
  IF coalesce(p_result->>'status','') ~ '^[0-9]{3}$' THEN http_status := (p_result->>'status')::integer; END IF;
  IF p_result->'ok'='true'::jsonb THEN outcome := 'sent';
  ELSIF http_status=429 THEN outcome := 'retry';
  ELSIF http_status BETWEEN 400 AND 499 THEN outcome := 'dead_letter';
  ELSIF p_result->>'status' IN ('retry','dead_letter','unknown') THEN outcome := p_result->>'status';
  ELSE outcome := 'unknown'; END IF;
  failure_text := p_result->>'error';
  IF outcome='retry' AND p_result->>'retry_after' IS NOT NULL THEN
    IF p_result->>'retry_after' ~ '^[0-9]+([.][0-9]+)?$' THEN
      requested_delay := (p_result->>'retry_after')::numeric;
      IF requested_delay>86400 THEN
        outcome := 'dead_letter';
        failure_text := 'retry_after exceeds one day; quarantined for operator review';
      ELSE
        -- Round UP: a fractional delay must never shorten Telegram's interval.
        delay_seconds := ceil(requested_delay)::integer;
      END IF;
    ELSE
      outcome := 'dead_letter';
      failure_text := 'invalid retry_after; quarantined for operator review';
    END IF;
  END IF;
  result := presales.finish_outbox(p_outbox_id,p_lease_token,outcome,(p_result->>'message_id')::bigint,failure_text);
  IF result->>'status'='retry_wait' AND delay_seconds IS NOT NULL THEN
    UPDATE presales.outbox_jobs SET available_at=greatest(available_at,clock_timestamp()+make_interval(secs=>delay_seconds))
      WHERE id=p_outbox_id;
  END IF;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION presales.replay_outbox(p_outbox_id uuid,p_acknowledge_possible_duplicate boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
DECLARE j presales.outbox_jobs%ROWTYPE;
BEGIN
  SELECT * INTO j FROM presales.outbox_jobs WHERE id=p_outbox_id AND job_type IN ('telegram_reply','owner_notify') AND update_id IS NOT NULL FOR UPDATE;
  IF NOT FOUND OR j.status<>'dead_letter' THEN
    RAISE EXCEPTION 'only dead-letter runtime outbox jobs can be replayed' USING ERRCODE='55000'; END IF;
  IF j.delivery_uncertain AND NOT coalesce(p_acknowledge_possible_duplicate,false) THEN
    RAISE EXCEPTION 'delivery uncertain; explicit duplicate-risk acknowledgement required' USING ERRCODE='55000'; END IF;
  UPDATE presales.outbox_jobs SET status='pending',attempts=0,available_at=clock_timestamp(),
    lease_token=NULL,lease_until=NULL,last_error=NULL,delivery_uncertain=false,updated_at=clock_timestamp() WHERE id=j.id;
  UPDATE presales.dead_letter_events SET replay_status='replayed',replayed_at=clock_timestamp()
    WHERE source_type='outbox' AND source_id=j.id AND replay_status='pending';
  INSERT INTO presales.audit_events(conversation_id,event_type,actor,correlation_id,metadata)
    VALUES(j.aggregate_id,'outbox_replayed','human',j.id::text,jsonb_build_object('duplicate_risk_acknowledged',p_acknowledge_possible_duplicate));
  RETURN jsonb_build_object('status','pending','outbox_id',j.id);
END $$;

CREATE OR REPLACE FUNCTION presales.configure_owner_chat(p_chat_id bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, presales AS $$
BEGIN
  IF p_chat_id IS NULL OR p_chat_id<=0 THEN RAISE EXCEPTION 'positive private owner chat ID required' USING ERRCODE='22023'; END IF;
  INSERT INTO presales.runtime_settings(key,value) VALUES('owner_chat_id',to_jsonb(p_chat_id))
    ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,updated_at=clock_timestamp();
  INSERT INTO presales.audit_events(event_type,actor) VALUES('owner_chat_configured','human');
  RETURN jsonb_build_object('status','configured');
END $$;

REVOKE ALL ON presales.chat_sessions,presales.chat_message_receipts,presales.inbox_jobs,
  presales.consent_events,presales.runtime_settings FROM PUBLIC;
REVOKE ALL ON FUNCTION presales.redact_text(text),presales.redact_json(jsonb),presales.accept_update(jsonb),
  presales.claim_inbox(),presales.commit_decision(bigint,uuid,jsonb),presales.commit_decision(bigint,jsonb),
  presales.fail_inbox(bigint,uuid,text,boolean),presales.replay_inbox(bigint),presales.claim_outbox(),
  presales.finish_outbox(uuid,uuid,text,bigint,text),presales.finish_outbox(uuid,uuid,jsonb),
  presales.replay_outbox(uuid,boolean),presales.configure_owner_chat(bigint) FROM PUBLIC;
INSERT INTO presales.schema_migrations(version,description) VALUES('003','leased inbox and Telegram outbox runtime')
  ON CONFLICT(version) DO NOTHING;
COMMIT;
