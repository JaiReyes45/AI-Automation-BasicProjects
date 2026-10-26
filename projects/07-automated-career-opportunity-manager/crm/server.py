import hashlib,hmac,json,os,secrets,time,uuid
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import psycopg
from psycopg.types.json import Jsonb
from crm.classifier import classify_live,decide_live,PARSER_VERSION
from crm.sync import labels_for,queue_application,select_messages,claim_jobs,finish_job,require_recent
from datetime import datetime,timezone,date,timedelta
from urllib.parse import urlparse,unquote
from crm import workspace,organizer,assistant

STAGES={'submitted','reviewing','information','assessment','interview','offer','accepted','hired','rejected','withdrawn','closed'}
def now():return datetime.now(timezone.utc).isoformat()
def connect():return psycopg.connect(host='postgres',dbname='careerflow',user='careerflow',password=os.environ['POSTGRES_PASSWORD'])
def initialize():
 with connect() as db:db.execute(Path('/app/database/001_crm.sql').read_text())
def locked(db):db.execute('SELECT pg_advisory_xact_lock(70031)')
def view(db):
 result=[]
 for key,data,version in db.execute('SELECT id,data,version FROM career.applications ORDER BY id'):
  data=dict(data,id=key,version=version)
  confirmation=db.execute("SELECT min((envelope->>'received_at')::timestamptz) FROM career.messages WHERE result->>'application_id'=%s AND result->'classification'->>'stage'='submitted'",(key,)).fetchone()[0]
  data['submitted_on']=data.get('submitted_on') or (confirmation.astimezone(timezone(timedelta(hours=8))).date().isoformat() if confirmation else None)
  data['submitted_at']=confirmation.isoformat() if confirmation else None
  data['job_description']=data.get('job_description','')
  data['events']=[r[0] for r in db.execute('SELECT data FROM career.events WHERE application_id=%s ORDER BY id DESC',(key,))]
  result.append(data)
 return result

def manual(db,m):
 for key in ['id','company','role','source','stage']:
  if not isinstance(m.get(key),str) or not m[key].strip() or len(m[key])>300:raise ValueError('Required fields missing or too long')
 if m['stage'] not in STAGES:raise ValueError('Invalid stage')
 if m.get('nextAction') is not None and (not isinstance(m['nextAction'],str) or len(m['nextAction'])>300):raise ValueError('Invalid next action')
 if m.get('submitted_on') and date.fromisoformat(m['submitted_on']).isoformat()!=m['submitted_on']:raise ValueError('Enter the submission date as YYYY-MM-DD')
 if not isinstance(m.get('job_description',''),str) or len(m.get('job_description',''))>10000:raise ValueError('Job description is too long')
 locked(db)
 old=db.execute('SELECT data,version FROM career.applications WHERE id=%s',(m['id'],)).fetchone()
 if (old[1] if old else 0)!=m.get('version',0):raise LookupError('This application changed. Reload before editing again.')
 data=dict(old[0]) if old else dict(account='manual',threads=[],reference=None)
 changes=[]
 if not old:changes=['Manually created application']
 elif old[0]['stage']!=m['stage']:changes.append('Manual stage change: '+old[0]['stage']+' -> '+m['stage'])
 if old and any(old[0].get(k)!=m.get(k) for k in ['company','role','source','nextAction']):changes.append('Application details or next action edited manually')
 for k in ['company','role','source','stage','nextAction']:data[k]=m.get(k)
 for k in ['submitted_on','job_description']:
  if k in m:data[k]=m[k]
 data.update(id=m['id'])
 if not old or old[0]['role']!=m['role']:data['original_role']=m['role']
 if not old or old[0]['stage']!=m['stage']:data['last_event']=now()
 db.execute('INSERT INTO career.applications VALUES (%s,%s,1) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,version=career.applications.version+1',(m['id'],Jsonb(data)))
 queue_application(db,data)
 for description in changes:db.execute('INSERT INTO career.events(application_id,data) VALUES (%s,%s)',(m['id'],Jsonb(dict(description=description,date=now(),source='manual'))))
 return {'applications':view(db)}

def ingest(db,m):
 result=classify_live(m);locked(db)
 old=db.execute('SELECT result FROM career.messages WHERE account=%s AND id=%s',(m['account'],m['id'])).fetchone()
 if old and (old[0].get('resolution') or old[0].get('application_id') or old[0].get('parser_version',1)>=PARSER_VERSION):return dict(old[0],duplicate=True)
 apps=[r[0] for r in db.execute('SELECT data FROM career.applications')]
 app,action=decide_live(m,result,apps)
 outcome=dict(action=action,classification=result,application_id=None,duplicate=False,parser_version=PARSER_VERSION)
 if old:outcome['previous_review']=old[0]['action']
 if action in ('create','update'):
  if app is None:app=dict(id=str(uuid.uuid4()),account=m['account'],company=result['company'],original_role=result['original_role'],role=result['normalized_role'],reference=result['reference'],threads=[],source='Gmail',nextAction=None)
  if m.get('thread_id') and m['thread_id'] not in app['threads']:app['threads'].append(m['thread_id'])
  app.update(stage=result['stage'],last_event=m['received_at'])
  db.execute('INSERT INTO career.applications VALUES (%s,%s,1) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,version=career.applications.version+1',(app['id'],Jsonb(app)))
  db.execute('INSERT INTO career.events(application_id,data) VALUES (%s,%s)',(app['id'],Jsonb(dict(description='Email update: '+result['stage'],date=m['received_at'],source='email',message_id=m['id'],evidence=result['evidence']))))
  outcome['application_id']=app['id']
  queue_application(db,app)
 labels=['Career/System/Needs Review']
 if app:labels=labels_for(app)
 if action=='opportunity_only':labels=['Career/Stage/Opportunity Discovered']
 db.execute('INSERT INTO career.messages(account,id,envelope,result) VALUES (%s,%s,%s,%s) ON CONFLICT(account,id) DO UPDATE SET envelope=EXCLUDED.envelope,result=EXCLUDED.result,revision=career.messages.revision+1',(m['account'],m['id'],Jsonb(m),Jsonb(outcome)))
 db.execute("INSERT INTO career.label_jobs(account,message_id,application_id,labels,eligible) VALUES (%s,%s,%s,%s,true) ON CONFLICT(account,message_id) DO UPDATE SET application_id=EXCLUDED.application_id,labels=EXCLUDED.labels,state='pending',eligible=true,generation=career.label_jobs.generation+1,attempts=0,next_attempt=0,error=NULL",(m['account'],m['id'],outcome['application_id'],Jsonb(labels)))
 return outcome

class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def send(self,status,data,cookie=None):
  # Finish the transaction before the client can issue its next refresh.
  db=getattr(self,'db',None)
  if db is not None and not db.closed:
   if status<400:db.commit()
   else:db.rollback()
  raw=json.dumps(data).encode();self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(raw)))
  if cookie:self.send_header('Set-Cookie',cookie)
  self.end_headers();self.wfile.write(raw)
 def authorized(self,db):
  cookie=SimpleCookie();cookie.load(self.headers.get('Cookie',''));token=cookie.get('career_session')
  return token and db.execute('SELECT 1 FROM career.sessions WHERE token_hash=%s AND expires>%s',(hashlib.sha256(token.value.encode()).hexdigest(),time.time())).fetchone()
 def do_GET(self):self.handle_request(False)
 def do_POST(self):self.handle_request(True)
 def handle_request(self,post):
  try:
   with connect() as db:
    self.db=db
    if self.path=='/health':return self.send(200,{'ok':True})
    body={}
    if post:
     length=int(self.headers.get('Content-Length','0'))
     limit=10_000_000 if self.path=='/internal/calendar/import' else 100000
     if not 0<length<=limit:raise ValueError('Invalid body size')
     body=json.loads(self.rfile.read(length))
     if not isinstance(body,dict):raise ValueError('Expected JSON object')
    worker=self.path.startswith('/internal/')
    if worker:
     if not hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+os.environ['CAREERFLOW_WORKFLOW_TOKEN']):return self.send(401,{'error':'Unauthorized'})
    else:
     if post and self.headers.get('X-CareerFlow')!='local-profile':return self.send(403,{'error':'Same-origin request required'})
     if self.path=='/api/crm/login' and post:
      if not hmac.compare_digest(str(body.get('password','')).encode(),os.environ['CAREERFLOW_APP_PASSWORD'].encode()):time.sleep(1);return self.send(401,{'error':'Incorrect workspace password'})
      db.execute('DELETE FROM career.sessions WHERE expires<=%s',(time.time(),))
      token=secrets.token_urlsafe(32);db.execute('INSERT INTO career.sessions VALUES (%s,%s)',(hashlib.sha256(token.encode()).hexdigest(),time.time()+43200))
      return self.send(200,{'ok':True},'career_session='+token+'; HttpOnly; SameSite=Strict; Path=/; Max-Age=43200')
     if not self.authorized(db):return self.send(401,{'error':'Sign in to the local workspace'})
    if self.path=='/api/crm/assistant/status' and not post:return self.send(200,assistant.status())
    if self.path=='/api/crm/assistant/chat' and post:return self.send(200,assistant.chat(db,body))
    if self.path=='/api/crm/calendar' and not post:return self.send(200,organizer.calendar(db))
    if self.path=='/api/crm/actions' and not post:return self.send(200,organizer.actions(db))
    if self.path=='/api/crm/actions/preview' and post:return self.send(200,organizer.preview(db,body))
    if self.path=='/api/crm/actions/confirm' and post:return self.send(200,organizer.confirm(db,body))
    if self.path=='/internal/actions/claim' and post:return self.send(200,organizer.claim(db,body['kind'],body.get('account')))
    if self.path=='/internal/actions/result' and post:return self.send(200,organizer.finish(db,body))
    if self.path=='/internal/calendar/import' and post:return self.send(200,organizer.import_calendar(db,body))
    if self.path=='/api/crm/auth':return self.send(200,{'ok':True})
    if self.path=='/api/crm/logout' and post:
     cookie=SimpleCookie();cookie.load(self.headers.get('Cookie',''))
     db.execute('DELETE FROM career.sessions WHERE token_hash=%s',(hashlib.sha256(cookie['career_session'].value.encode()).hexdigest(),))
     return self.send(200,{'ok':True},'career_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0')
    if self.path=='/api/crm/review/resolve' and post:return self.send(200,workspace.resolve(db,body))
    if self.path=='/api/crm/tasks':return self.send(200,workspace.save_task(db,body) if post else workspace.tasks(db))
    if self.path=='/api/crm/deliveries' and not post:return self.send(200,workspace.deliveries(db))
    if self.path=='/api/crm/deliveries/retry' and post:return self.send(200,workspace.retry_delivery(db,body))
    if self.path.startswith('/api/crm/application-emails/') and not post:return self.send(200,workspace.application_emails(db,unquote(self.path.split('/')[-1])))
    if self.path=='/api/crm/applications':return self.send(200,manual(db,body) if post else {'applications':view(db)})
    if self.path=='/internal/ingest' and post:return self.send(200,ingest(db,body))
    if self.path=='/internal/gmail-ingest' and post:
     require_recent(body);return self.send(200,ingest(db,body))
    if self.path=='/internal/select-messages' and post:return self.send(200,select_messages(db,body))
    if self.path=='/internal/label-claim' and post:return self.send(200,claim_jobs(db,body['account']))
    if self.path=='/internal/label-result' and post:return self.send(200,finish_job(db,body))
    if self.path=='/internal/sync-complete' and post:
     db.execute("UPDATE career.connection SET data=data || %s WHERE id=1",(Jsonb(dict(last_sync_completed=now(),last_sync_processed=body.get('processed',0))),));return self.send(200,{'ok':True})
    if self.path=='/api/crm/review' and not post:return self.send(200,workspace.reviews(db))
    if self.path=='/internal/connection' and post:
     db.execute('INSERT INTO career.connection VALUES (1,%s) ON CONFLICT(id) DO UPDATE SET data=career.connection.data || EXCLUDED.data',(Jsonb(dict(gmail_connected=True,account=body['account'],last_checked=now())),));return self.send(200,{'ok':True})
    if self.path=='/internal/label-plan' and post:
     row=db.execute('SELECT id,application_id,labels FROM career.label_jobs WHERE account=%s AND message_id=%s',(body['account'],body['message_id'])).fetchone()
     if not row:raise ValueError('No job')
     labels=row[2]
     if row[1]:
      app=db.execute('SELECT data FROM career.applications WHERE id=%s',(row[1],)).fetchone()[0]
      labels=labels_for(app)
     return self.send(200,dict(job_id=row[0],account=body['account'],message_id=body['message_id'],labels=labels))
    if self.path=='/internal/label-ack' and post:
     db.execute("UPDATE career.label_jobs SET state='delivered',error=NULL WHERE id=%s",(body['job_id'],));return self.send(200,{'ok':True})
    if self.path=='/api/crm/status':
     row=db.execute('SELECT data FROM career.connection WHERE id=1').fetchone()
     state=dict(row[0] if row else {'gmail_connected':False})
     last=state.get('last_sync_completed')
     state['sync_state']='not_connected' if not state.get('gmail_connected') else 'waiting' if not last else 'healthy' if (datetime.now(timezone.utc)-datetime.fromisoformat(last)).total_seconds()<900 else 'attention'
     state['polling_enabled']=False
     if db.execute("SELECT to_regclass('workflow_entity')").fetchone()[0]:
      state['polling_enabled']=db.execute("SELECT count(*) FROM workflow_entity WHERE id IN ('project07GmailSync','project07GmailReconcile') AND active").fetchone()[0]==2
     return self.send(200,dict(state,review_count=db.execute("SELECT count(*) FROM career.messages m JOIN career.label_jobs j ON m.account=j.account AND m.id=j.message_id WHERE j.eligible AND NOT (result ? 'resolution') AND result->>'action' NOT IN ('create','update','opportunity_only')").fetchone()[0],label_jobs={s:c for s,c in db.execute('SELECT state,count(*) FROM career.label_jobs WHERE eligible GROUP BY state')}))
    return self.send(404,{'error':'Not found'})
  except LookupError as e:self.send(409,{'error':str(e)})
  except ValueError as e:self.send(400,{'error':str(e) if self.path.startswith('/api/crm/') else 'Invalid input'})
  except (TypeError,KeyError):self.send(400,{'error':'Check the required fields.'})
  except psycopg.Error:self.send(503,{'error':'Database unavailable; retry'})

if __name__=='__main__':
 initialize();ThreadingHTTPServer(('0.0.0.0',8780),Handler).serve_forever()
