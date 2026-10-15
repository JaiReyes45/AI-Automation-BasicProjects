"""Local operator CLI: no Telegram or public webhook administration."""
import argparse,json,pathlib,subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('action',choices=['catalog','handoffs','analytics','unanswered','upsert','replay-inbox','replay-outbox','resolve-handoff'])
p.add_argument('--file',type=pathlib.Path,help='JSON object: table, key, fields; no credentials')
p.add_argument('--id');p.add_argument('--acknowledge-possible-duplicate',action='store_true')
p.add_argument('--database',default='presales',help='Use only a trusted project database; defaults to the live local project')
a=p.parse_args();args=[]
if not a.database.replace('_','').isalnum():p.error('Invalid database name')
if a.action=='catalog':query='SELECT code,name,price_min,price_max,active,approved FROM presales.services ORDER BY category,code;'
elif a.action=='handoffs':query="SELECT id,reason,priority,status,created_at FROM presales.handoff_tickets WHERE status IN ('open','acknowledged','in_progress') ORDER BY created_at;"
elif a.action=='unanswered':query="SELECT event_type,count(*) FROM presales.audit_events WHERE event_type IN ('human_handoff','discovery_question') GROUP BY event_type;"
elif a.action=='analytics':query="SELECT status,count(*) FROM presales.leads GROUP BY status; SELECT status,count(*) FROM presales.outbox_jobs GROUP BY status; SELECT event_type,count(*) FROM presales.audit_events GROUP BY event_type;"
elif a.action.startswith('replay-'):
    if not a.id:p.error('--id required')
    args=['-v','record_id='+a.id]
    query="SELECT presales.replay_inbox(:'record_id'::bigint);" if a.action=='replay-inbox' else "SELECT presales.replay_outbox(:'record_id'::uuid,"+str(a.acknowledge_possible_duplicate).lower()+');'
elif a.action=='resolve-handoff':
    if not a.id:p.error('--id required')
    args=['-v','record_id='+a.id]
    query="BEGIN; UPDATE presales.handoff_tickets SET status='resolved',updated_at=now() WHERE id=:'record_id'::uuid; UPDATE presales.conversations SET status='active',updated_at=now() WHERE id=(SELECT conversation_id FROM presales.handoff_tickets WHERE id=:'record_id'::uuid) AND NOT EXISTS(SELECT 1 FROM presales.handoff_tickets t WHERE t.conversation_id=presales.conversations.id AND t.status IN ('open','acknowledged','in_progress')); INSERT INTO presales.audit_events(event_type,actor,input_reference) VALUES ('handoff_resolved','human',:'record_id'); COMMIT;"
else:
    if not a.file:p.error('--file required')
    data=json.loads(a.file.read_text());table=data['table'];fields=data['fields'];key=data['key']
    allow={'services':{'category','name','description','price_min','price_max','currency','delivery_time','billing_unit','active','approved','requires_human'},'service_packages':{'name','description','price_min','price_max','active','approved','inclusions'},'pricing_adjustments':{'name','adjustment_type','amount_min','amount_max','percentage','requires_human','active','approved'},'faqs':{'question','answer','tags','active','approved','approved_by'},'business_policies':{'policy_text','policy_value','active','approved'}}
    if table not in allow or not fields or set(fields)-allow[table]:p.error('Unapproved table or field')
    pk='id' if table=='faqs' else 'code'
    record={pk:key,**fields};args=['-v','payload='+json.dumps(record)]
    # Identifiers are validated above; values use psql quoted variables.
    cols=list(record);select=','.join(cols);updates=','.join(f'{x}=EXCLUDED.{x}' for x in fields)
    sets=','.join(f'{x}=r.{x}' for x in fields)
    query=f"BEGIN; WITH r AS (SELECT * FROM jsonb_populate_record(NULL::presales.{table},:'payload'::jsonb)), changed AS (UPDATE presales.{table} t SET {sets} FROM r WHERE t.{pk}=r.{pk} RETURNING t.{pk}) INSERT INTO presales.{table} ({select}) SELECT {select} FROM r WHERE NOT EXISTS (SELECT 1 FROM changed); INSERT INTO presales.audit_events(event_type,actor,metadata) VALUES ('catalog_changed','human',jsonb_build_object('table','{table}','key',(:'payload'::jsonb)->>'{pk}')); COMMIT;"
subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d',a.database,'-v','ON_ERROR_STOP=1',*args],input=query,text=True,check=True)
