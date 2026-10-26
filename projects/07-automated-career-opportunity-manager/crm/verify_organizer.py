"""Rolled-back synthetic checks; never calls Gmail, Calendar or Ollama."""
import time
import uuid
from datetime import datetime, timezone, timedelta
from psycopg.types.json import Jsonb
from crm.server import connect, manual, view
from crm import organizer
from crm.workspace import application_emails


def rejects(fn, error=ValueError):
    try:
        fn()
    except error:
        return
    raise AssertionError('Expected validation failure')


with connect() as db:
    key = 'organizer-'+uuid.uuid4().hex
    try:
        app = dict(id=key, account='demo@example.test', company='Calendar Example', role='QA Engineer Intern',
                   original_role='QA Engineer Intern', stage='submitted', source='Gmail', threads=['synthetic-thread'],
                   last_event='2026-10-24T18:00:00+00:00', nextAction=None)
        db.execute('INSERT INTO career.applications VALUES (%s,%s,1)', (key, Jsonb(app)))
        envelope = dict(account='demo@example.test', id=key, subject='Synthetic interview', sender='HR <hr@example.test>',
                        body='Full body\nOn Monday wrote:\nOriginal quoted message', received_at='2026-10-24T18:00:00+00:00', thread_id='synthetic-thread')
        db.execute('INSERT INTO career.messages(account,id,envelope,result) VALUES (%s,%s,%s,%s)',
                   ('demo@example.test', key, Jsonb(envelope), Jsonb({'application_id':key,'classification':{'stage':'submitted'}})))
        original = next(a for a in view(db) if a['id']==key)
        assert original['submitted_on']=='2026-10-25'
        manual(db, dict(app, version=1, stage='interview', job_description='Python QA automation'))
        updated = next(a for a in view(db) if a['id']==key)
        assert updated['submitted_on']=='2026-10-25'
        assert updated['job_description']=='Python QA automation'
        assert 'Original quoted message' in application_emails(db,key)['items'][0]['body']
        edit = organizer.preview(db, {'kind':'edit','application_id':key,'stage':'reviewing','nextAction':'Prepare portfolio'})
        assert db.execute('SELECT data FROM career.applications WHERE id=%s',(key,)).fetchone()[0]['stage']=='interview'
        assert organizer.confirm(db, {'id':edit['id']})['state']=='completed'
        rejects(lambda: organizer.confirm(db, {'id':edit['id']}), LookupError)
        reply = dict(kind='reply',application_id=key,message_id=key,to='hr@example.test',subject='Re: Synthetic interview',body='Thank you. I confirm my availability.')
        rejects(lambda:organizer.preview(db,dict(reply,to='noreply@example.test')))
        rejects(lambda:organizer.preview(db,dict(reply,to='hr@example.test\nBcc: wrong@example.test')))
        proposal=organizer.preview(db,reply)
        assert organizer.claim(db,'reply','demo@example.test')['jobs']==[]
        organizer.confirm(db,{'id':proposal['id']})
        assert organizer.claim(db,'reply','different@example.test')['jobs']==[]
        job=next(j for j in organizer.claim(db,'reply','demo@example.test')['jobs'] if j['id']==proposal['id'])
        rejects(lambda:organizer.finish(db,{'id':job['id'],'lease':'stale','ok':True}),LookupError)
        organizer.finish(db,{'id':job['id'],'lease':job['lease'],'ok':False,'uncertain':True,'error':'Synthetic timeout'})
        assert db.execute('SELECT state FROM career.actions WHERE id=%s',(job['id'],)).fetchone()[0]=='uncertain'
        assert not organizer.claim(db,'reply','demo@example.test')['jobs']
        current=datetime.now(timezone.utc)
        organizer.import_calendar(db,{'items':[],'calendar_name':'Synthetic calendar'})
        meeting=dict(kind='meeting',application_id=key,title='Synthetic interview',start=(current+timedelta(days=400)).isoformat(),end=(current+timedelta(days=400,hours=1)).isoformat(),attendees=[])
        rejects(lambda:organizer.preview(db,dict(meeting,end=meeting['start'])))
        proposal=organizer.preview(db,meeting)
        organizer.confirm(db,{'id':proposal['id']})
        rejects(lambda:organizer.preview(db,meeting))
        job=next(j for j in organizer.claim(db,'meeting')['jobs'] if j['id']==proposal['id'])
        organizer.finish(db,dict(id=job['id'],lease=job['lease'],ok=True,external_id=job['event_id']))
        event=db.execute('SELECT data FROM career.calendar_events WHERE id=%s',(job['event_id'],)).fetchone()[0]
        assert event['sync_state']=='synced'
        assert db.execute('SELECT data FROM career.applications WHERE id=%s',(key,)).fetchone()[0]['stage']=='reviewing'
        print('PASS: stable Manila submission date, description persistence, complete email text, reviewed edits/replies/meetings, account isolation, no pre-confirm execution, duplicate confirmation, stale leases, uncertain mail, calendar clashes and independent hiring stage.')
    finally:
        db.rollback()
