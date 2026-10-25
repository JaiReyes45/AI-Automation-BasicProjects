"""Run inside the CRM container. Creates and removes only unique synthetic records."""
import json,os,uuid,urllib.request,urllib.error,http.cookiejar
from crm.server import connect
run=uuid.uuid4().hex
base='http://127.0.0.1:8780'
jar=http.cookiejar.CookieJar();client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
def req(path,body=None,worker=False,opener=client):
 headers={'X-CareerFlow':'local-profile'}
 if worker:headers['Authorization']='Bearer '+os.environ['CAREERFLOW_WORKFLOW_TOKEN']
 request=urllib.request.Request(base+path,data=json.dumps(body).encode() if body is not None else None,headers=headers)
 try:
  with opener.open(request) as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,{}
account=run+'@example.test';ids=[]
try:
 assert req('/api/crm/applications',opener=urllib.request.build_opener())[0]==401
 assert req('/internal/ingest',{})[0]==401
 assert req('/api/crm/login',{'password':'incorrect'})[0]==401
 assert req('/api/crm/login',{'password':os.environ['CAREERFLOW_APP_PASSWORD']})[0]==200
 message=dict(account=account,id=run,thread_id=run,received_at='2026-10-24T00:00:00+00:00',body='Company: Synthetic Labs\nRole: QA Engineer Intern\nReference: '+run+'\nWe have received your application.')
 status,first=req('/internal/ingest',message,True);assert status==200 and first['action']=='create';ids.append(first['application_id'])
 assert req('/internal/ingest',message,True)[1]['duplicate']
 message.update(id=run+'-2',received_at='2026-10-24T01:00:00+00:00',body='We invite you to an interview.')
 assert req('/internal/ingest',message,True)[1]['action']=='update'
 apps=req('/api/crm/applications')[1]['applications'];app=next(a for a in apps if a['id']==ids[0]);assert app['stage']=='interview' and len(app['events'])==2
 app['nextAction']='Confirm schedule';assert req('/api/crm/applications',app)[0]==200
 assert req('/api/crm/applications',app)[0]==409
 with connect() as db:
  stored=db.execute('SELECT data FROM career.applications WHERE id=%s',(ids[0],)).fetchone()[0];assert stored['nextAction']=='Confirm schedule'
  assert db.execute('SELECT count(*) FROM career.messages WHERE account=%s',(account,)).fetchone()[0]==2
 print('PASS: auth denial/login, workflow to CRM, duplicate handling, stage/history, durable action save, stale-write conflict')
finally:
 with connect() as db:
  db.execute('DELETE FROM career.label_jobs WHERE account=%s',(account,));db.execute('DELETE FROM career.messages WHERE account=%s',(account,))
  for key in ids:db.execute('DELETE FROM career.events WHERE application_id=%s',(key,));db.execute('DELETE FROM career.applications WHERE id=%s',(key,))
