"""Exercise real decision commits in an isolated schema, always rolled back."""
import pathlib,subprocess,uuid,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
schema='presales_routing_'+uuid.uuid4().hex[:12]
sources=['001_core_presales_schema.sql','002_catalog_and_rules.sql','003_runtime.sql']
if '--baseline' not in sys.argv:sources+=['007_owner_notification_isolation.sql']*2
parts=['BEGIN;']
for source in sources:
    text=(ROOT/'database'/source).read_text()
    parts.append('\n'.join(line for line in text.splitlines() if line not in ('BEGIN;','COMMIT;')).replace('presales',schema))
parts.append("""
DO $$
DECLARE c jsonb; r jsonb; dest bigint;
BEGIN
 FOR dest IN SELECT unnest(ARRAY[99000101::bigint,99000102::bigint]) LOOP
   PERFORM presales.configure_owner_chat(99000101);
   PERFORM presales.accept_update(jsonb_build_object('update_id',dest,'message_id',1,'chat_id',dest,'user_id',dest,'text','human please','message_type','text'));
   c:=presales.claim_inbox();
   r:=presales.commit_decision((c->>'update_id')::bigint,(c->>'lease_token')::uuid,
     '{"state":{"requirements":{}},"response":"Your review request is recorded.","handoff":{"reason":"customer_request","priority":"normal","summary":"Synthetic review"}}');
   IF r->>'handoff_id' IS NULL THEN RAISE EXCEPTION 'Ticket missing'; END IF;
   IF (SELECT count(*) FROM presales.outbox_jobs WHERE update_id=dest AND job_type='telegram_reply')<>1 THEN RAISE EXCEPTION 'Customer reply missing'; END IF;
   IF dest=99000101 AND r->>'owner_outbox_id' IS NOT NULL THEN RAISE EXCEPTION 'Internal owner summary leaked into customer chat'; END IF;
   IF dest=99000102 AND r->>'owner_outbox_id' IS NULL THEN RAISE EXCEPTION 'Separate owner notification missing'; END IF;
 END LOOP;
END $$;
ROLLBACK;
""".replace('presales',schema))
p=subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-X','-q','-U','presales','-d','presales','-v','ON_ERROR_STOP=1'],input='\n'.join(parts),text=True,capture_output=True)
if p.returncode:
    print(p.stderr[-1800:]);raise SystemExit(1)
print('PASS: same-chat internal note suppressed, separate owner notified, tickets/replies retained; test transaction rolled back.')
