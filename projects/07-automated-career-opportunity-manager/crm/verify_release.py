"""Release API checks using unique synthetic records, cleaned in finally."""
import json, os, uuid, urllib.request, urllib.error, http.cookiejar
from datetime import datetime, timezone, timedelta
from crm.server import connect

key=uuid.uuid4().hex
account=key+'@example.test'
apps=[]
clock=datetime.now(timezone.utc)
client=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

def request(path,body=None,worker=False,anonymous=False):
    headers={'Content-Type':'application/json','X-CareerFlow':'local-profile'}
    if worker:headers['Authorization']='Bearer '+os.environ['CAREERFLOW_WORKFLOW_TOKEN']
    req=urllib.request.Request('http://127.0.0.1:8780'+path,data=json.dumps(body).encode() if body is not None else None,headers=headers)
    opener=urllib.request.build_opener() if anonymous else client
    try:
        with opener.open(req,timeout=10) as r:return r.status,json.load(r)
    except urllib.error.HTTPError as e:return e.code,json.load(e)

def app():
    return next(a for a in request('/api/crm/applications')[1]['applications'] if a['id']==apps[0])

def email(suffix,body,minutes):
    message=dict(account=account,id=key+suffix,thread_id=key+suffix,received_at=(clock-timedelta(minutes=minutes)).isoformat(),subject='Synthetic release check',sender='recruiter@example.test',body=body)
    status,result=request('/internal/ingest',message,True)
    assert status==200,result
    return message,result

def review(m):
    return next(i for i in request('/api/crm/review')[1]['items'] if i['account']==account and i['id']==m['id'])

try:
    for route in ['review','tasks','deliveries','status']:
        assert request('/api/crm/'+route,anonymous=True)[0]==401
    assert request('/api/crm/review/resolve',{},anonymous=True)[0]==401
    assert request('/api/crm/login',{'password':os.environ['CAREERFLOW_APP_PASSWORD']})[0]==200
    m,_=email('-create','A confirmation without a known provider layout.',60)
    r=review(m)
    decision=dict(account=account,id=m['id'],revision=r['revision'],action='create',company='Release Example '+key,role='QA Engineer Intern',stage='submitted',note='Synthetic acceptance check')
    assert request('/api/crm/review/resolve',dict(decision,stage=None))[0]==400
    assert request('/api/crm/review/resolve',decision)[0]==200
    with connect() as db:
        apps.append(db.execute('SELECT id FROM career.applications WHERE data->>\'account\'=%s',(account,)).fetchone()[0])
    assert request('/api/crm/review/resolve',decision)[0]==409
    assert request('/internal/ingest',m,True)[1]['duplicate']
    for index,stage in enumerate(['reviewing','information','assessment','interview','offer','accepted','hired']):
        m,_=email('-'+stage,'An update needing explicit review.',50-index*5)
        r=review(m);a=app()
        body=dict(account=account,id=m['id'],revision=r['revision'],action='link',application_id=a['id'],application_version=a['version'],stage=stage,note='Verified synthetic '+stage)
        assert request('/api/crm/review/resolve',dict(body,application_version=-1))[0]==409
        assert request('/api/crm/review/resolve',body)[0]==200
        assert app()['stage']==stage
    a=app()
    task=dict(id=key+'-task',application_id=a['id'],title='Send onboarding documents',category='reply',status='open',due_on=None,version=0)
    assert request('/api/crm/tasks',dict(task,due_on='2026-02-31'))[0]==400
    assert request('/api/crm/tasks',task)[0]==200
    saved=next(t for t in request('/api/crm/tasks')[1]['items'] if t['id']==task['id'])
    assert saved['due_on'] is None
    assert request('/api/crm/tasks',dict(saved,status='done'))[0]==200
    assert app()['stage']=='hired'
    assert request('/api/crm/tasks',dict(saved,status='open'))[0]==409
    m,_=email('-stale','A late old email.',90);r=review(m);a=app()
    body=dict(account=account,id=m['id'],revision=r['revision'],action='link',application_id=a['id'],application_version=a['version'],stage='interview')
    assert request('/api/crm/review/resolve',body)[0]==400
    assert request('/api/crm/review/resolve',dict(body,stage=None))[0]==200
    assert app()['stage']=='hired'
    for action in ['ignore','opportunity']:
        m,_=email('-'+action,'Unclear message.',10);r=review(m)
        assert request('/api/crm/review/resolve',dict(account=account,id=m['id'],revision=r['revision'],action=action))[0]==200
        assert request('/internal/ingest',m,True)[1]['duplicate']
    with connect() as db:
        job=db.execute('SELECT id,generation FROM career.label_jobs WHERE account=%s LIMIT 1',(account,)).fetchone()
        db.execute("UPDATE career.label_jobs SET state='failed',attempts=6,error='provider_error' WHERE id=%s",(job[0],))
    assert request('/api/crm/deliveries/retry',dict(id=job[0],generation=job[1]))[0]==200
    assert request('/api/crm/deliveries/retry',dict(id=job[0],generation=job[1]))[0]==409
    assert request('/api/crm/logout',{})[0]==200
    assert request('/api/crm/tasks')[0]==401
    print('PASS: review creation/link/dismiss/opportunity, submission-to-hired pipeline, stale/conflict protection, audit, task completion independent of stage, recovery and logout')
finally:
    with connect() as db:
        owned=[r[0] for r in db.execute('SELECT id FROM career.applications WHERE data->>\'account\'=%s',(account,))]
        db.execute('DELETE FROM career.audit WHERE data->>\'account\'=%s OR data->>\'task_id\'=%s OR data->>\'application_id\'=ANY(%s)',(account,key+'-task',owned))
        db.execute('DELETE FROM career.audit WHERE kind=%s AND (data->>\'job_id\')::bigint IN (SELECT id FROM career.label_jobs WHERE account=%s)',('label_retry',account))
        db.execute('DELETE FROM career.tasks WHERE id=%s',(key+'-task',))
        db.execute('DELETE FROM career.label_jobs WHERE account=%s',(account,))
        db.execute('DELETE FROM career.messages WHERE account=%s',(account,))
        for i in owned:
            db.execute('DELETE FROM career.events WHERE application_id=%s',(i,))
            db.execute('DELETE FROM career.applications WHERE id=%s',(i,))
