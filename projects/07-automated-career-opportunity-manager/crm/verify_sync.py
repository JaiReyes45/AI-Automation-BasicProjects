"""Database integration checks in a rolled-back synthetic transaction; no Gmail calls."""
import uuid
from datetime import datetime, timezone, timedelta
from crm.server import connect, ingest, manual
from crm.sync import claim_jobs, finish_job, select_messages, require_recent

key = uuid.uuid4().hex
account = key + '@example.test'
clock = datetime.now(timezone.utc)
message = dict(account=account,id=key,thread_id=key,received_at=(clock-timedelta(minutes=2)).isoformat(),
               body='Company: Example Labs\nRole: QA Engineer Intern\nReference: '+key+'\nWe have received your application.')
with connect() as db:
 try:
  first=ingest(db,message)
  assert first['action']=='create'
  assert ingest(db,message)['duplicate']
  assert not select_messages(db,dict(account=account,messages=[{'id':key}]))['messages']
  job=claim_jobs(db,account)['jobs'][0]
  assert not claim_jobs(db,account)['jobs'], 'lease must exclude concurrent claim'
  assert not claim_jobs(db,'other@example.test')['jobs'], 'account isolation'
  failed=finish_job(db,dict(job,verified=False,error='provider_error'))
  assert not failed['delivered']
  state=db.execute('SELECT state,attempts,error FROM career.label_jobs WHERE id=%s',(job['job_id'],)).fetchone()
  assert state==('pending',1,'provider_error')
  assert not claim_jobs(db,account)['jobs'], 'backoff must prevent immediate retry'
  db.execute('UPDATE career.label_jobs SET next_attempt=0 WHERE id=%s',(job['job_id'],))
  retry=claim_jobs(db,account)['jobs'][0]
  assert retry['attempt']==2
  assert finish_job(db,dict(retry,verified=True))['delivered']
  message.update(id=key+'-2',received_at=(clock-timedelta(minutes=1)).isoformat(),body='We invite you to an interview.')
  assert ingest(db,message)['action']=='update'
  refreshed=claim_jobs(db,account)['jobs']
  assert len(refreshed)==2 and all('Career/Stage/interview' in j['labels'] for j in refreshed)
  assert finish_job(db,dict(retry,verified=True))['superseded'], 'old acknowledgement cannot clear new stage'
  assert db.execute('SELECT count(*) FROM career.events WHERE application_id=%s',(first['application_id'],)).fetchone()[0]==2
  for j in refreshed:
   db.execute('UPDATE career.label_jobs SET attempts=6 WHERE id=%s',(j['job_id'],))
   assert not finish_job(db,dict(j,attempt=6,verified=False))['delivered']
  assert not claim_jobs(db,account)['jobs'], 'retry cap'
  assert db.execute("SELECT count(*) FROM career.label_jobs WHERE account=%s AND state='failed'",(account,)).fetchone()[0]==2
  db.execute('UPDATE career.label_jobs SET state=%s,next_attempt=0 WHERE account=%s',('pending',account))
  claim_jobs(db,account)
  assert db.execute("SELECT count(*) FROM career.label_jobs WHERE account=%s AND state='failed'",(account,)).fetchone()[0]==2, 'crashed final attempt'
  require_recent(message)
  try:
   require_recent(dict(message,received_at=(clock-timedelta(days=8)).isoformat()))
   raise AssertionError('old mail must be rejected')
  except ValueError:pass
  print('PASS: persistence, duplicates, leases, account isolation, backoff, retry success/cap, progression label refresh, stale acknowledgement, seven-day boundary')
 finally:
  db.rollback()
