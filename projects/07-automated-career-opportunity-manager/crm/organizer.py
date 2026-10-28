"""Reviewed actions and a durable calendar. The model cannot execute mutations."""
import re
import time
import uuid
from datetime import datetime, timezone, timedelta
from email.utils import parseaddr
from psycopg.types.json import Jsonb
from crm.workspace import lock, audit, text, now

MANILA = timezone(timedelta(hours=8))


def stamp(value):
    result = datetime.fromisoformat(text(value).replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('Meeting times must include a timezone.')
    return result


def email(value):
    value = text(value)
    if '\n' in value or '\r' in value or parseaddr(value)[1] != value or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', value):
        raise ValueError('Enter a valid recipient email address.')
    return value


def application(db, key):
    row = db.execute('SELECT data,version FROM career.applications WHERE id=%s', (text(key),)).fetchone()
    if not row:
        raise ValueError('Choose an existing application.')
    return row


def calendar(db):
    row = db.execute('SELECT data FROM career.calendar_connection WHERE id=1').fetchone()
    return {'connection': row[0] if row else {'connected': False},
            'items': [dict(data, id=key, version=version) for key, data, version in
                      db.execute('SELECT id,data,version FROM career.calendar_events ORDER BY data->>\'start\'')]}


def actions(db):
    return {'items': [dict(data, id=key, kind=kind, state=state) for key, kind, state, data in db.execute(
        "SELECT id,kind,state,data FROM career.actions WHERE state<>'preview' ORDER BY created DESC LIMIT 80")]}


def preview(db, body):
    kind = body.get('kind')
    app, version = application(db, body.get('application_id'))
    data = dict(application_id=app['id'], application_version=version, company=app['company'], role=app['role'])
    if kind == 'edit':
        from crm.workspace import STAGES
        stage = body.get('stage', app['stage'])
        if stage not in STAGES:
            raise ValueError('Choose a valid stage.')
        data.update(stage=stage, previous_stage=app['stage'],
                    nextAction=text(body.get('nextAction', app.get('nextAction')), 300, False) or None)
    elif kind == 'reply':
        message_id = text(body.get('message_id'))
        row = db.execute("SELECT envelope FROM career.messages WHERE id=%s AND result->>'application_id'=%s", (message_id, app['id'])).fetchone()
        if not row:
            raise ValueError('Choose an email linked to this application.')
        recipient = email(body.get('to'))
        if re.search(r'no.?reply|do.?not.?reply|indeedapply', recipient, re.I):
            raise ValueError('This address does not accept replies. Enter the employer contact instead.')
        data.update(message_id=message_id, account=row[0]['account'], thread_id=row[0].get('thread_id'),
                    to=recipient, subject=text(body.get('subject'), 300), body=text(body.get('body'), 12000))
        if '\n' in data['subject'] or '\r' in data['subject']:
            raise ValueError('Use a single-line subject.')
    elif kind == 'meeting':
        connection=db.execute('SELECT data FROM career.calendar_connection WHERE id=1').fetchone()
        if not connection or (datetime.now(timezone.utc)-stamp(connection[0]['last_sync'])).total_seconds()>900:
            raise ValueError('Google Calendar must sync recently before booking. Open Connections and check the Calendar workflow.')
        start, end = stamp(body.get('start')), stamp(body.get('end'))
        if end <= start or end-start > timedelta(days=1):
            raise ValueError('End time must follow start time, within one day.')
        if start < datetime.now(timezone.utc)-timedelta(minutes=5):
            raise ValueError('Choose a future meeting time.')
        attendees = body.get('attendees', [])
        if not isinstance(attendees, list) or len(attendees) > 10:
            raise ValueError('Use up to ten attendees.')
        overlaps = []
        for event, in db.execute("SELECT data FROM career.calendar_events WHERE COALESCE(data->>'status','') NOT IN ('cancelled','not_in_window')"):
            try:
                a, b = stamp(event['start']), stamp(event['end'])
                if start < b and end > a:
                    overlaps.append(event.get('title', 'Calendar event'))
            except (ValueError, KeyError):
                continue
        if overlaps:
            raise ValueError('This time overlaps '+', '.join(overlaps[:3])+'. Choose another time.')
        data.update(title=text(body.get('title')), start=start.isoformat(), end=end.isoformat(),
                    location=text(body.get('location'), 1000, False),
                    description=text(body.get('description'), 4000, False),
                    attendees=list(dict.fromkeys(email(a) for a in attendees)), event_id=uuid.uuid4().hex)
    else:
        raise ValueError('Unsupported action.')
    key = uuid.uuid4().hex
    db.execute('INSERT INTO career.actions(id,kind,state,data,created) VALUES (%s,%s,%s,%s,%s)',
               (key, kind, 'preview', Jsonb(data), time.time()))
    return {'id': key, 'kind': kind, 'state': 'preview', 'data': data}


def confirm(db, body):
    lock(db)
    row = db.execute('SELECT kind,state,data,created FROM career.actions WHERE id=%s FOR UPDATE', (text(body.get('id')),)).fetchone()
    if not row or row[1] != 'preview':
        raise LookupError('This preview was already confirmed or no longer exists.')
    kind, _, data, created = row
    if time.time()-created > 1800:
        raise ValueError('This preview expired. Review a fresh preview.')
    app, version = application(db, data['application_id'])
    if version != data['application_version']:
        raise LookupError('The application changed. Review a fresh preview.')
    state = 'queued'
    if kind == 'edit':
        from crm.server import manual
        manual(db, dict(app, version=version, stage=data['stage'], nextAction=data['nextAction']))
        state = 'completed'
    if kind == 'meeting':
        # Recheck clashes at confirmation, including another tab's new local event.
        check = preview(db, dict(data, kind='meeting'))
        db.execute('DELETE FROM career.actions WHERE id=%s AND state=%s', (check['id'], 'preview'))
        data.update(event_version=1, status='confirmed', operation='create')
        event = dict(data, source='careerflow', status='confirmed', scheduling_state='confirmed', revision=1, sync_state='queued', google_id=data['event_id'])
        db.execute('INSERT INTO career.calendar_events VALUES (%s,%s,1)', (data['event_id'], Jsonb(event)))
    db.execute('UPDATE career.actions SET state=%s,data=%s WHERE id=%s', (state, Jsonb(data), body['id']))
    audit(db, 'confirmed_action', dict(action_id=body['id'], kind=kind, application_id=app['id']))
    return {'ok': True, 'state': state}


def claim(db, kind, account=None):
    if kind not in ('reply', 'meeting'):
        raise ValueError('Invalid action worker')
    lock(db)
    # A sent message has no safe automatic retry after a lost acknowledgement.
    db.execute("UPDATE career.actions SET state='uncertain',data=data || %s WHERE kind='reply' AND state='processing' AND lease<%s",
               (Jsonb({'error': 'Delivery outcome unknown. Check Gmail Sent before composing another reply.'}), time.time()))
    if kind == 'meeting':
        db.execute("UPDATE career.actions SET state='queued' WHERE kind='meeting' AND state='processing' AND lease<%s", (time.time(),))
    if kind == 'reply':
        email(account)
    rows = db.execute("SELECT id,data,attempts FROM career.actions WHERE kind=%s AND state='queued' AND attempts<5 AND (%s='meeting' OR data->>'account'=%s) ORDER BY created LIMIT 5 FOR UPDATE", (kind,kind,account)).fetchall()
    jobs = []
    for key, data, attempts in rows:
        if kind == 'meeting':
            current = db.execute('SELECT data FROM career.calendar_events WHERE id=%s', (data['event_id'],)).fetchone()
            if not current or current[0].get('revision', 1) != data.get('event_version', 1):
                db.execute("UPDATE career.actions SET state='superseded' WHERE id=%s", (key,))
                continue
            connection = db.execute('SELECT data FROM career.calendar_connection WHERE id=1').fetchone()
            if not connection or (datetime.now(timezone.utc)-stamp(connection[0]['last_sync'])).total_seconds()>900:
                continue
            clashes=[event for other,event in db.execute("SELECT id,data FROM career.calendar_events WHERE COALESCE(data->>'status','') NOT IN ('cancelled','not_in_window')")
                if data.get('status') != 'cancelled' and other != data['event_id'] and stamp(data['start'])<stamp(event['end']) and stamp(data['end'])>stamp(event['start'])]
            if clashes:
                db.execute("UPDATE career.actions SET state='failed',data=data || %s WHERE id=%s",(Jsonb({'error':'A calendar conflict appeared before booking. Choose another time.'}),key))
                db.execute("UPDATE career.calendar_events SET data=data || %s WHERE id=%s",(Jsonb({'sync_state':'conflict','error':'Calendar conflict before booking.'}),data['event_id']))
                continue
        lease = uuid.uuid4().hex
        db.execute("UPDATE career.actions SET state='processing',lease=%s,lease_token=%s,attempts=attempts+1 WHERE id=%s", (time.time()+600, lease, key))
        jobs.append(dict(data, id=key, lease=lease, attempt=attempts+1))
    return {'jobs': jobs}


def finish(db, body):
    lock(db)
    row = db.execute('SELECT kind,state,data,lease_token FROM career.actions WHERE id=%s FOR UPDATE', (text(body.get('id')),)).fetchone()
    if not row or row[1] != 'processing' or body.get('lease') != row[3]:
        raise LookupError('This action lease is no longer current.')
    kind, _, data, _ = row
    if kind == 'meeting':
        current = db.execute('SELECT data FROM career.calendar_events WHERE id=%s', (data['event_id'],)).fetchone()
        if not current or current[0].get('revision', 1) != data.get('event_version', 1):
            db.execute("UPDATE career.actions SET state='superseded' WHERE id=%s", (body['id'],))
            return {'ok': True, 'superseded': True}
    ok = body.get('ok') is True
    state = 'completed' if ok else ('uncertain' if kind == 'reply' and body.get('uncertain') else 'failed')
    data.update(completed_at=now() if ok else None, external_id=body.get('external_id'),
                error=None if ok else text(body.get('error', 'Provider could not complete the action.'), 500))
    db.execute('UPDATE career.actions SET state=%s,data=%s WHERE id=%s', (state, Jsonb(data), body['id']))
    if kind == 'meeting':
        db.execute('UPDATE career.calendar_events SET data=data || %s,version=version+1 WHERE id=%s',
                   (Jsonb({'sync_state': 'synced' if ok else 'failed', 'error': data['error']}), data['event_id']))
    if ok and data.get('application_id'):
        db.execute('INSERT INTO career.events(application_id,data) VALUES (%s,%s)', (data['application_id'], Jsonb(dict(
            description='Reply sent' if kind == 'reply' else 'Interview calendar updated', date=now(), source='confirmed_action'))))
    return {'ok': True}


def import_calendar(db, body):
    items = body.get('items', [])
    if not isinstance(items, list) or len(items) > 2000:
        raise ValueError('Calendar batch is too large')
    lock(db)
    seen=[]
    for event in items:
        key = text(event.get('id'))
        start, end = event.get('start', {}), event.get('end', {})
        if not start or not end:
            if event.get('status')=='cancelled':
                db.execute("UPDATE career.calendar_events SET data=data || %s WHERE data->>'google_id'=%s",(Jsonb({'status':'cancelled'}),key))
            continue
        all_day = 'date' in start
        a = start.get('dateTime') or start['date']+'T00:00:00+08:00'
        b = end.get('dateTime') or end['date']+'T00:00:00+08:00'
        stamp(a); stamp(b)
        seen.append(key)
        owned = event.get('extendedProperties', {}).get('private', {}).get('careerflow_event')
        existing = db.execute('SELECT data FROM career.calendar_events WHERE id=%s', (owned or 'google-'+key,)).fetchone()
        # Preserve newer local intent until its worker has acknowledged it.
        if existing and existing[0].get('sync_state') in ('queued', 'conflict', 'failed'):
            continue
        data = dict(existing[0] if existing else {}, title=event.get('summary', 'Untitled event'), start=a, end=b,
                    all_day=all_day, location=event.get('location', ''), description=event.get('description', ''),
                    attendees=[x['email'] for x in event.get('attendees', []) if x.get('email')],
                    source='careerflow' if owned and existing else 'google', status=event.get('status', 'confirmed'),
                    sync_state='synced', google_id=key, html_link=event.get('htmlLink'), updated=event.get('updated'))
        if owned and existing:
            data['scheduling_state'] = event.get('status', 'confirmed')
        db.execute('INSERT INTO career.calendar_events VALUES (%s,%s,1) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,version=career.calendar_events.version+1',
                   (owned if owned and existing else 'google-'+key, Jsonb(data)))
    if body.get('window_start') and body.get('window_end'):
        db.execute("UPDATE career.calendar_events SET data=data || %s WHERE data->>'sync_state'='synced' AND NOT (data->>'google_id'=ANY(%s)) AND (data->>'start')::timestamptz>%s AND (data->>'start')::timestamptz<%s",(Jsonb({'status':'not_in_window'}),seen,stamp(body['window_start'])+timedelta(minutes=1),stamp(body['window_end'])-timedelta(minutes=1)))
    db.execute('INSERT INTO career.calendar_connection VALUES (1,%s) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data',
               (Jsonb({'connected': True, 'last_sync': now(), 'calendar_name': body.get('calendar_name', 'Primary calendar'), 'window_start':body.get('window_start'),'window_end':body.get('window_end')}),))
    return {'ok': True, 'processed': len(items)}
