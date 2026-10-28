"""Synthetic integration acceptance; roll back all writes and never contact providers."""
import time
import uuid
from pathlib import Path
from datetime import datetime, timezone, timedelta
from psycopg.types.json import Jsonb
from crm.server import connect, ingest
from crm import engagement, notifications, organizer, interviews, workspace, sync, mail_sync, assistant


with connect() as db:
    try:
        # Transactional DDL permits testing new migrations against the existing schema.
        for path in sorted((Path(__file__).resolve().parents[1]/'database').glob('*.sql')):
            db.execute(path.read_text())
        prefix='acceptance-'+uuid.uuid4().hex
        account=prefix+'@example.test'
        current=datetime.now(timezone.utc)
        def msg(key,body,direction='received',seconds=0):
            return dict(account=account,id=prefix+key,thread_id=prefix,sender='HR <hr@example.test>',
                        subject='Internship interview',body=body,received_at=(current+timedelta(seconds=seconds)).isoformat(),
                        direction=direction,rfc_message_id='<'+prefix+key+'@example.test>',headers=[],current_body=body,references='',in_reply_to='')
        request=msg('request','Please share your availability for an interview.')
        ingest(db,request);ingest(db,request)
        tasks=[t for t in engagement.today(db)['needs_response'] if t.get('source_account')==account]
        assert len(tasks)==1 and tasks[0]['application_id'] is None and not tasks[0]['due_on']
        key=tasks[0]['id']
        assert db.execute('SELECT count(*) FROM career.notifications WHERE task_id=%s',(key,)).fetchone()[0]==1
        code=notifications.create_pairing(db)
        device=notifications.redeem_pairing(db,dict(code=code['code']))
        assert notifications.authenticate(db,'Bearer '+device['token'])==device['device_id']
        try:notifications.redeem_pairing(db,dict(code=code['code']));raise AssertionError('Pair code reused')
        except ValueError:pass
        # Suppress other jobs transactionally so the claim belongs to this fixture.
        db.execute("UPDATE career.notifications SET state='suppressed' WHERE task_id<>%s",(key,))
        job=notifications.claim(db,device['device_id'])['jobs'][0]
        notifications.finish(db,dict(id=job['id'],lease=job['lease'],outcome='failed'),device['device_id'])
        notifications.command(db,dict(id=job['id'],action='retry'))
        assert notifications.claim(db,device['device_id'])['jobs']
        db.execute("UPDATE career.notifications SET lease_until=0 WHERE task_id=%s",(key,))
        assert next(n for n in notifications.list_items(db)['items'] if n['task_id']==key)['state']=='uncertain'
        reply=msg('reply','I am available on Monday at 10 AM.','sent',1)
        reply['in_reply_to']=request['rfc_message_id']
        ingest(db,reply)
        assert db.execute('SELECT data FROM career.tasks WHERE id=%s',(key,)).fetchone()[0]['status']=='done'
        assert db.execute('SELECT state FROM career.notifications WHERE task_id=%s',(key,)).fetchone()[0]=='suppressed'
        assert any(t.get('source_account')==account for t in engagement.today(db)['waiting'])
        # User corrections survive replay and preserved evidence.
        corrected=msg('documents','Please send your resume.',seconds=2)
        ingest(db,corrected)
        task=next(t for t in engagement.today(db)['needs_response'] if t.get('source_message_id')==corrected['id'])
        workspace.save_task(db,dict(task,status='done'))
        ingest(db,corrected)
        assert db.execute('SELECT data FROM career.tasks WHERE id=%s',(task['id'],)).fetchone()[0]['status']=='done'
        plain_request=dict(msg('plain-request','Could you share your availability for a short call?',seconds=2),subject='Hello',thread_id=prefix+'new')
        assert ingest(db,plain_request)['action']!='ignored'
        assert db.execute("SELECT count(*) FROM career.tasks WHERE data->>'source_message_id'=%s",(plain_request['id'],)).fetchone()[0]==1
        # Explicit private future holds, stale snapshot and stale result protection.
        a=current+timedelta(days=400);b=a+timedelta(minutes=30)
        invitation=msg('slot',f'Your interview is confirmed from {a.isoformat()} to {b.isoformat()}.',seconds=3)
        result=ingest(db,invitation)
        event_id=interviews.event_key(invitation,result.get('application_id'))
        event=db.execute('SELECT data FROM career.calendar_events WHERE id=%s',(event_id,)).fetchone()[0]
        assert event['attendees']==[] and event['scheduling_state']=='confirmed'
        app_key=prefix+'app'
        db.execute('INSERT INTO career.applications VALUES (%s,%s,1)',(app_key,Jsonb(dict(id=app_key,account=account,company='Synthetic Employer',role='IT Intern',stage='submitted',threads=[]))))
        interviews.ingest(db,invitation,dict(application_id=app_key))
        assert db.execute('SELECT data FROM career.calendar_events WHERE id=%s',(event_id,)).fetchone()[0]['application_id']==app_key
        organizer.import_calendar(db,{'items':[]})
        jobs=organizer.claim(db,'meeting')['jobs'];job=next(j for j in jobs if j['event_id']==event_id)
        later=msg('reschedule',f'Your interview is confirmed from {(a+timedelta(hours=2)).isoformat()} to {(b+timedelta(hours=2)).isoformat()}.',seconds=4)
        ingest(db,later)
        assert organizer.finish(db,dict(id=job['id'],lease=job['lease'],ok=True))['superseded']
        snapshot=dict(id=event_id,start={'dateTime':a.isoformat()},end={'dateTime':b.isoformat()},status='confirmed',extendedProperties={'private':{'careerflow_event':event_id}})
        organizer.import_calendar(db,dict(items=[snapshot]))
        event=db.execute('SELECT data FROM career.calendar_events WHERE id=%s',(event_id,)).fetchone()[0]
        assert event['start']==(a+timedelta(hours=2)).isoformat()
        job=next(j for j in organizer.claim(db,'meeting')['jobs'] if j['event_id']==event_id)
        organizer.finish(db,dict(id=job['id'],lease=job['lease'],ok=True))
        cancel=msg('cancel','Your interview has been cancelled.',seconds=5)
        ingest(db,cancel)
        assert db.execute('SELECT data FROM career.calendar_events WHERE id=%s',(event_id,)).fetchone()[0]['scheduling_state']=='cancelled'
        assert sync.select_messages(db,dict(account=account,messages=[{'id':request['id']}]))['messages']==[]
        ordinary=dict(msg('ordinary','Dinner at six','sent',6),subject='Dinner',thread_id=prefix+'personal')
        assert ingest(db,ordinary)['action']=='ignored'
        assert not db.execute('SELECT envelope FROM career.messages WHERE account=%s AND id=%s',(account,ordinary['id'])).fetchone()[0]['body']
        reverse_request=dict(msg('reverse-request','Please share your availability for an interview.',seconds=-10),subject='Hello',thread_id=prefix+'reverse')
        reverse_reply=dict(msg('reverse-reply','I am available Monday at 10 AM.','sent',-9),subject='Re: Hello',thread_id=prefix+'reverse',in_reply_to=reverse_request['rfc_message_id'])
        ingest(db,reverse_reply);ingest(db,reverse_request)
        assert db.execute("SELECT data->>'status' FROM career.tasks WHERE data->>'source_message_id'=%s",(reverse_request['id'],)).fetchone()[0]=='done'
        # Historical checkpoint and bounded account coverage on PostgreSQL.
        run=mail_sync.start_run(db,dict(account=account))
        assert run
        answer=assistant.chat(db,dict(message='What needs my response?'))
        assert 'sources' in answer and 'completeness' in answer and 'coverage' in answer
        print('PASS: PostgreSQL requests/replay, sent reconciliation, corrections, scoped alert pairing/retry/expiry, private holds/reschedule/cancel, stale calendar guards, checkpoint and deterministic assistant.')
    finally:
        db.rollback()
