"""User-controlled review, tasks and recovery. Every mutation is auditable."""
import uuid
from datetime import datetime, timezone, timedelta, date
from psycopg.types.json import Jsonb
from workflow.engine import current_text
from crm.sync import labels_for, queue_application

STAGES = {'submitted','reviewing','information','assessment','interview','offer','accepted','hired','rejected','withdrawn','closed'}
CATEGORIES = {'reply','assessment','interview','followup','other'}
MANILA = timezone(timedelta(hours=8))


def now():
    return datetime.now(timezone.utc).isoformat()


def lock(db):
    db.execute('SELECT pg_advisory_xact_lock(70031)')


def text(value, maximum=300, required=True):
    if value is None and not required:
        return ''
    if not isinstance(value, str) or len(value) > maximum or (required and not value.strip()):
        raise ValueError('Check the required fields and their length.')
    return value.strip()


def audit(db, kind, data):
    db.execute('INSERT INTO career.audit(kind,data) VALUES (%s,%s)', (kind, Jsonb(dict(data, at=now()))))


def reviews(db):
    rows = db.execute("""SELECT m.account,m.id,m.envelope,m.result,m.revision FROM career.messages m
        JOIN career.label_jobs j ON j.account=m.account AND j.message_id=m.id
        WHERE j.eligible AND (m.result->>'application_id' IS NULL OR m.result ? 'resolution')
        ORDER BY m.envelope->>'received_at' DESC""").fetchall()
    return {'items': [dict(account=a,id=i,revision=v,subject=m.get('subject','No subject'),
        sender=m.get('sender','Unknown sender'),received_at=m['received_at'],
        body=current_text(m.get('html_text') or m['body'])[:8000],result=r) for a,i,m,r,v in rows]}


def resolve(db, body):
    lock(db)
    account, message_id = text(body.get('account')), text(body.get('id'))
    row = db.execute("""SELECT m.envelope,m.result,m.revision FROM career.messages m
        JOIN career.label_jobs j ON j.account=m.account AND j.message_id=m.id
        WHERE m.account=%s AND m.id=%s AND j.eligible FOR UPDATE OF m""", (account,message_id)).fetchone()
    if not row:
        raise ValueError('This message is not in the review queue.')
    message, result, revision = row
    if revision != body.get('revision') or result.get('resolution'):
        raise LookupError('This message has already changed. Refresh the review queue.')
    action = body.get('action')
    if action not in {'link','create','ignore','opportunity'}:
        raise ValueError('Choose how to resolve this message.')
    note = text(body.get('note'), 1000, False)
    stage = body.get('stage')
    if stage is not None and stage not in STAGES:
        raise ValueError('Choose a valid hiring stage.')
    app = None
    if action == 'create':
        if stage is None:
            raise ValueError('Choose the confirmed stage for the new application.')
        company, role = text(body.get('company')), text(body.get('role'))
        existing = db.execute("""SELECT 1 FROM career.applications WHERE data->>'account'=%s
            AND lower(data->>'company')=lower(%s) AND lower(data->>'role')=lower(%s)
            AND data->>'stage' NOT IN ('rejected','withdrawn','closed','hired')""", (account,company,role)).fetchone()
        if existing:
            raise ValueError('An active application already has this company and role. Link it instead.')
        app = dict(id=str(uuid.uuid4()),account=account,company=company,role=role,original_role=role,
                   reference=None,threads=[],source='Gmail · reviewed',stage=stage,nextAction=None,
                   last_event=message['received_at'])
    elif action == 'link':
        found = db.execute('SELECT data,version FROM career.applications WHERE id=%s FOR UPDATE', (text(body.get('application_id')),)).fetchone()
        if not found:
            raise ValueError('Choose an existing application.')
        app, version = found
        if body.get('application_version') != version:
            raise LookupError('The application changed. Refresh before linking.')
        if app['account'] not in (account, 'manual'):
            raise ValueError('The application belongs to a different mailbox.')
        if stage is not None and stage != app['stage']:
            incoming = datetime.fromisoformat(message['received_at'].replace('Z','+00:00'))
            latest = datetime.fromisoformat(app['last_event'].replace('Z','+00:00'))
            if incoming < latest:
                raise ValueError('This email is older than the current stage. Link without changing the stage, then edit the application if needed.')
            if app['stage'] in {'hired','rejected','withdrawn','closed'}:
                raise ValueError('This application is closed. Link without changing its stage.')
            app.update(stage=stage,last_event=message['received_at'])
        app['account'] = account
    if app:
        if message.get('thread_id') and message['thread_id'] not in app['threads']:
            app['threads'].append(message['thread_id'])
        db.execute('INSERT INTO career.applications VALUES (%s,%s,1) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,version=career.applications.version+1', (app['id'],Jsonb(app)))
        event = dict(description='Reviewed email: '+('created application' if action=='create' else 'linked to application')+(' · stage '+stage if stage else ''),
                     date=now(),source='review',message_id=message_id,email_date=message['received_at'],note=note,
                     evidence=result.get('classification',{}).get('evidence',[]))
        db.execute('INSERT INTO career.events(application_id,data) VALUES (%s,%s)', (app['id'],Jsonb(event)))
        queue_application(db,app)
    labels = labels_for(app) if app else ['Career/Stage/Opportunity Discovered'] if action=='opportunity' else []
    resolution = dict(action=action,at=now(),note=note,application_id=app['id'] if app else None)
    result.update(resolution=resolution,application_id=resolution['application_id'])
    db.execute('UPDATE career.messages SET result=%s,revision=revision+1 WHERE account=%s AND id=%s', (Jsonb(result),account,message_id))
    db.execute("""UPDATE career.label_jobs SET application_id=%s,labels=%s,state='pending',generation=generation+1,
        attempts=0,next_attempt=0,error=NULL WHERE account=%s AND message_id=%s""", (resolution['application_id'],Jsonb(labels),account,message_id))
    audit(db,'review',dict(account=account,message_id=message_id,**resolution))
    return {'ok':True}


def tasks(db):
    return {'items':[dict(data,id=key,version=version) for key,data,version in db.execute('SELECT id,data,version FROM career.tasks ORDER BY data->>\'created_at\' DESC')]}


def save_task(db, body):
    lock(db)
    key, application_id = text(body.get('id')), text(body.get('application_id'))
    title = text(body.get('title'))
    category, status, due_on = body.get('category'), body.get('status'), body.get('due_on')
    if category not in CATEGORIES or status not in {'open','done'}:
        raise ValueError('Choose a task category and status.')
    if due_on is not None:
        if not isinstance(due_on,str) or date.fromisoformat(due_on).isoformat()!=due_on:
            raise ValueError('Enter a date as YYYY-MM-DD, or leave it blank.')
    if not db.execute('SELECT 1 FROM career.applications WHERE id=%s',(application_id,)).fetchone():
        raise ValueError('Choose an application for this task.')
    old = db.execute('SELECT data,version FROM career.tasks WHERE id=%s',(key,)).fetchone()
    if (old[1] if old else 0) != body.get('version',0):
        raise LookupError('This task changed. Refresh before editing.')
    data = dict(application_id=application_id,title=title,category=category,status=status,due_on=due_on,
                created_at=old[0]['created_at'] if old else now(),updated_at=now(),
                completed_at=(old[0].get('completed_at') if old and old[0]['status']=='done' else now()) if status=='done' else None)
    db.execute('INSERT INTO career.tasks VALUES (%s,%s,1) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,version=career.tasks.version+1',(key,Jsonb(data)))
    audit(db,'task',dict(task_id=key,application_id=application_id,status=status,title=title))
    if not old or old[0]['status'] != status:
        db.execute('INSERT INTO career.events(application_id,data) VALUES (%s,%s)',(application_id,Jsonb(dict(description=('Task completed: ' if status=='done' else 'Task reopened: ' if old else 'Task added: ')+title,date=now(),source='task'))))
    return {'ok':True}


def deliveries(db):
    return {'items':[dict(id=i,state=s,attempts=a,error=e,subject=m.get('subject','No subject'),generation=g,
        received_at=m['received_at'],retry_allowed=datetime.fromisoformat(m['received_at'].replace('Z','+00:00'))>datetime.now(timezone.utc)-timedelta(days=7))
        for i,s,a,e,m,g in db.execute("""SELECT j.id,j.state,j.attempts,j.error,m.envelope,j.generation FROM career.label_jobs j
        JOIN career.messages m ON m.account=j.account AND m.id=j.message_id WHERE j.eligible AND j.state<>'delivered' ORDER BY j.id""")]}


def retry_delivery(db, body):
    lock(db)
    row = db.execute("""SELECT j.state,j.generation,m.envelope FROM career.label_jobs j JOIN career.messages m
        ON m.account=j.account AND m.id=j.message_id WHERE j.id=%s AND j.eligible FOR UPDATE OF j""",(body['id'],)).fetchone()
    if not row or row[0] not in ('failed','expired') or row[1]!=body.get('generation'):
        raise LookupError('This delivery changed. Refresh the recovery list.')
    if datetime.fromisoformat(row[2]['received_at'].replace('Z','+00:00'))<datetime.now(timezone.utc)-timedelta(days=7):
        raise ValueError('This email is outside the authorized seven-day window. Its CRM record is retained.')
    db.execute("UPDATE career.label_jobs SET state='pending',generation=generation+1,attempts=0,next_attempt=0,error=NULL WHERE id=%s",(body['id'],))
    audit(db,'label_retry',dict(job_id=body['id']))
    return {'ok':True}


def application_emails(db, application_id):
    import re
    from html import unescape
    from email.utils import parseaddr
    if not db.execute('SELECT 1 FROM career.applications WHERE id=%s',(application_id,)).fetchone():
        raise ValueError('Application not found')
    rows=db.execute("SELECT envelope FROM career.messages WHERE result->>'application_id'=%s ORDER BY (envelope->>'received_at')::timestamptz DESC",(application_id,)).fetchall()
    items=[]
    for m, in rows:
        body=m.get('html_text') or m['body']
        # Display text only, retaining quoted content. Never render active mail HTML.
        body=re.sub(r'<(?:script|style)\b[^>]*>.*?</(?:script|style)>','',body,flags=re.I|re.S)
        body=unescape(re.sub(r'<[^>]+>','',body))
        sender=parseaddr(m.get('reply_to') or m.get('sender',''))[1]
        items.append(dict(id=m['id'],account=m['account'],thread_id=m.get('thread_id'),
            subject=m.get('subject','No subject'),sender=m.get('sender',''),reply_to=sender,
            received_at=m['received_at'],body=body,has_more=len(m['body'])>=45000 or len(m.get('html_text',''))>=20000))
    return {'items':items}
