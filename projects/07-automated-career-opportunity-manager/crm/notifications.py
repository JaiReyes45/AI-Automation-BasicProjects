"""Transactional desktop intent queue and narrowly scoped, revocable pairing."""
import hashlib
import re
import secrets
import time
import uuid
from datetime import datetime, timezone

MAX_ATTEMPTS = 5
LEASE_SECONDS = 120
PAIR_SECONDS = 300
TOKEN_SECONDS = 90 * 24 * 3600
FIELDS = 'id,task_id,data,state,attempts,created,next_attempt,lease_until,lease_token,device_id,delivered_at,read_at,snoozed_until,error'


def _json(value):
    from psycopg.types.json import Jsonb
    return Jsonb(value)


def _lock(db):
    db.execute('SELECT pg_advisory_xact_lock(70031)')


def _iso(value):
    return datetime.fromtimestamp(value, timezone.utc).isoformat() if value is not None else None


def _hash(value):
    return hashlib.sha256(value.encode()).hexdigest()


def _record(row):
    item = dict(zip(FIELDS.split(','), row))
    item.update(item.pop('data'))
    return item


def retry_delay(attempt):
    return min(3600, 30 * (2 ** max(0, min(int(attempt), 8) - 1)))


def delivery_state(item, task, now):
    if not task or task.get('status') != 'open' or item.get('read_at') is not None:
        return 'suppressed'
    if item.get('state') == 'processing':
        return 'uncertain' if (item.get('lease_until') or 0) <= now else None
    if item.get('state') not in ('pending', 'failed') or item.get('attempts', 0) >= MAX_ATTEMPTS:
        return None
    if max(item.get('snoozed_until') or 0, item.get('next_attempt') or 0) > now:
        return None
    return 'claimable'


def delivery_payload(item):
    return dict(id=item['id'], task_id=item['task_id'], title=item['title'], body=item['body'],
        href='/', lease=item['lease_token'], attempt=item['attempts'])


def enqueue(db, task):
    if task.get('actor', 'user') != 'user' or task.get('status') != 'open':
        return
    key = 'notice-' + _hash(task['id'])[:40]
    data = dict(title=task['title'], body='A request needs your response. Open CareerFlow to review the source and application.', href='/')
    db.execute("""INSERT INTO career.notifications(id,task_id,event_key,data,created)
        VALUES (%s,%s,%s,%s,%s) ON CONFLICT(event_key) DO NOTHING""", (key, task['id'], task['id'] + ':created', _json(data), time.time()))


def suppress_task(db, task_id):
    db.execute("""UPDATE career.notifications SET state='suppressed',lease_until=NULL,lease_token=NULL
        WHERE task_id=%s AND state IN ('pending','processing','failed','uncertain')""", (task_id,))


def normalize_pairing_code(value):
    if not isinstance(value, str):
        raise ValueError('Enter the temporary pairing code from CareerFlow.')
    normalized = value.replace('-', '').replace(' ', '').upper()
    if not re.fullmatch(r'[A-F0-9]{16}', normalized):
        raise ValueError('Enter the temporary pairing code from CareerFlow.')
    return normalized


def create_pairing(db):
    _lock(db)
    now = time.time()
    # Only the newest code can pair; an older setup screen cannot mint another device.
    db.execute('DELETE FROM career.notification_pairings')
    code = secrets.token_hex(8).upper()
    db.execute('INSERT INTO career.notification_pairings(code_hash,expires,created) VALUES (%s,%s,%s)', (_hash(code), now + PAIR_SECONDS, now))
    return dict(code='-'.join(code[i:i+4] for i in range(0, 16, 4)), expires_at=_iso(now + PAIR_SECONDS))


def redeem_pairing(db, body):
    """Caller must restrict this single public endpoint to localhost and rate limit."""
    code = normalize_pairing_code(body.get('code'))
    name = body.get('device_name', 'Windows desktop')
    if not isinstance(name, str) or not name.strip() or len(name) > 100:
        raise ValueError('Choose a short device name.')
    _lock(db)
    now = time.time()
    row = db.execute('DELETE FROM career.notification_pairings WHERE code_hash=%s AND expires>%s RETURNING code_hash', (_hash(code), now)).fetchone()
    if not row:
        raise ValueError('Pairing code expired or was already used. Create a new code in CareerFlow.')
    token, device_id = secrets.token_urlsafe(40), uuid.uuid4().hex
    db.execute('INSERT INTO career.notification_devices(id,token_hash,name,created,expires) VALUES (%s,%s,%s,%s,%s)',
        (device_id, _hash(token), name.strip(), now, now + TOKEN_SECONDS))
    return dict(token=token, device_id=device_id, expires_at=_iso(now + TOKEN_SECONDS))


def authenticate(db, authorization):
    if not isinstance(authorization, str) or not authorization.startswith('Bearer ') or len(authorization) > 200:
        return None
    row = db.execute('SELECT id FROM career.notification_devices WHERE token_hash=%s AND expires>%s AND NOT revoked',
        (_hash(authorization[7:]), time.time())).fetchone()
    if not row:
        return None
    db.execute('UPDATE career.notification_devices SET last_seen=%s WHERE id=%s', (time.time(), row[0]))
    return row[0]


def _refresh(db):
    """Expiry and completion remain visible even when the helper is no longer polling."""
    db.execute("""UPDATE career.notifications n SET state='suppressed',lease_token=NULL,lease_until=NULL
        FROM career.tasks t WHERE n.task_id=t.id AND (t.data->>'status'<>'open' OR n.read_at IS NOT NULL)
        AND n.state IN ('pending','processing','failed','uncertain')""")
    db.execute("""UPDATE career.notifications SET state='uncertain',lease_token=NULL,lease_until=NULL,
        error='Windows delivery acknowledgement was lost. Check the desktop before retrying.'
        WHERE state='processing' AND lease_until<=%s""", (time.time(),))


def claim(db, device_id):
    _lock(db)
    _refresh(db)
    now = time.time()
    rows = db.execute(f"""SELECT {','.join('n.' + f for f in FIELDS.split(','))},t.data
        FROM career.notifications n JOIN career.tasks t ON t.id=n.task_id
        WHERE n.state IN ('pending','failed') AND n.attempts<%s AND n.next_attempt<=%s
        AND COALESCE(n.snoozed_until,0)<=%s AND n.read_at IS NULL AND t.data->>'status'='open'
        ORDER BY n.created LIMIT 1 FOR UPDATE OF n""", (MAX_ATTEMPTS, now, now)).fetchall()
    jobs = []
    for row in rows:
        item = _record(row[:-1])
        if delivery_state(item, row[-1], now) != 'claimable':
            continue
        lease = secrets.token_urlsafe(24)
        db.execute("""UPDATE career.notifications SET state='processing',lease_token=%s,lease_until=%s,
            device_id=%s,attempts=attempts+1,error=NULL WHERE id=%s""", (lease, now + LEASE_SECONDS, device_id, item['id']))
        item.update(lease_token=lease, attempts=item['attempts']+1)
        jobs.append(delivery_payload(item))
    return {'jobs': jobs, 'poll_after_seconds': 20}


def finish(db, body, device_id):
    _lock(db)
    _refresh(db)
    row = db.execute(f'SELECT {FIELDS} FROM career.notifications WHERE id=%s FOR UPDATE', (body.get('id'),)).fetchone()
    if not row:
        raise LookupError('Notification no longer exists.')
    item = _record(row)
    if (item['state'] != 'processing' or not isinstance(body.get('lease'), str)
            or not secrets.compare_digest(body['lease'], item.get('lease_token') or '') or item['device_id'] != device_id):
        raise LookupError('This notification lease is no longer current.')
    outcome = body.get('outcome')
    if outcome not in ('delivered', 'failed', 'uncertain'):
        raise ValueError('Choose a valid delivery outcome.')
    # Never persist arbitrary helper/provider errors, which can contain credentials or message content.
    error = None if outcome == 'delivered' else ('Windows did not acknowledge display.' if outcome == 'uncertain' else 'Windows could not display this alert.')
    now = time.time()
    db.execute("""UPDATE career.notifications SET state=%s,delivered_at=%s,error=%s,next_attempt=%s,
        lease_token=NULL,lease_until=NULL WHERE id=%s""", (outcome, now if outcome == 'delivered' else None,
        error, now + retry_delay(item['attempts']), item['id']))
    return {'ok': True, 'state': outcome}


def command(db, body):
    _lock(db)
    action = body.get('action')
    if action == 'revoke_device':
        db.execute('UPDATE career.notification_devices SET revoked=true WHERE id=%s', (body.get('id'),))
        return {'ok': True}
    row = db.execute('SELECT n.state,t.data FROM career.notifications n JOIN career.tasks t ON t.id=n.task_id WHERE n.id=%s FOR UPDATE OF n', (body.get('id'),)).fetchone()
    if not row:
        raise ValueError('Choose an existing notification.')
    now = time.time()
    if action == 'read':
        db.execute("UPDATE career.notifications SET read_at=%s,state='suppressed',lease_token=NULL,lease_until=NULL WHERE id=%s", (now, body['id']))
    elif action in ('snooze', 'retry'):
        if row[1].get('status') != 'open':
            raise ValueError('This task is complete; its alert cannot be retried.')
        minutes = body.get('minutes', 60)
        if type(minutes) is not int or not 1 <= minutes <= 10080:
            raise ValueError('Choose a snooze of one minute to seven days.')
        if action == 'retry' and row[0] not in ('failed', 'uncertain'):
            raise ValueError('Only failed or uncertain deliveries need retrying.')
        db.execute("""UPDATE career.notifications SET state='pending',attempts=0,read_at=NULL,error=NULL,
            snoozed_until=%s,next_attempt=0,lease_token=NULL,lease_until=NULL WHERE id=%s""",
            (now + minutes*60 if action == 'snooze' else None, body['id']))
    else:
        raise ValueError('Choose read, snooze, retry or revoke_device.')
    return {'ok': True}


def list_items(db):
    _refresh(db)
    items = []
    for row in db.execute(f'SELECT {FIELDS} FROM career.notifications ORDER BY created DESC LIMIT 100'):
        item = _record(row)
        for key in ('lease_token', 'lease_until', 'device_id'):
            item.pop(key, None)
        item['created_at'] = _iso(item.pop('created'))
        for key in ('delivered_at', 'read_at', 'snoozed_until', 'next_attempt'):
            item[key] = _iso(item[key])
        items.append(item)
    devices = [dict(id=key, name=name, last_seen=_iso(seen), expires_at=_iso(expires), revoked=revoked)
        for key, name, seen, expires, revoked in db.execute('SELECT id,name,last_seen,expires,revoked FROM career.notification_devices ORDER BY created DESC')]
    return dict(items=items, devices=devices, local_uptime_required=True,
        delivery_note='Windows acceptance does not confirm the alert was read. Focus Assist or desktop settings may hide alerts.')
