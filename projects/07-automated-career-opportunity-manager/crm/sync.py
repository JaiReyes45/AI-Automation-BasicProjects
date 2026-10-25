"""Durable label delivery with leases, bounded retries and generation checks."""
import time
from datetime import datetime, timezone, timedelta
from psycopg.types.json import Jsonb
from crm.classifier import PARSER_VERSION, role_label


def labels_for(app):
    return ['Career/Stage/' + app['stage'], 'Career/Role/' + role_label(app['role'])]


def queue_application(db, app):
    db.execute("""UPDATE career.label_jobs SET labels=%s,generation=generation+1,
        state='pending',attempts=0,next_attempt=0,error=NULL
        WHERE application_id=%s AND labels<>%s""",
        (Jsonb(labels_for(app)), app['id'], Jsonb(labels_for(app))))


def select_messages(db, body):
    account, messages = body['account'], body['messages']
    if not isinstance(messages, list) or len(messages) > 2000:
        raise ValueError('Message batch too large')
    known = {i: r for i, r in db.execute('SELECT id,result FROM career.messages WHERE account=%s', (account,))}
    selected = []
    for message in messages:
        key = message['id']
        prior = known.get(key)
        # Earlier broad-query jobs become eligible only after the focused query selects them.
        db.execute('UPDATE career.label_jobs SET eligible=true WHERE account=%s AND message_id=%s', (account, key))
        if not prior or (not prior.get('resolution') and not prior.get('application_id') and prior.get('parser_version', 1) < PARSER_VERSION):
            selected.append(message)
    return {'messages': selected, 'matched': len(messages)}


def claim_jobs(db, account):
    timestamp = time.time()
    db.execute("UPDATE career.connection SET data=data || %s WHERE id=1 AND data->>'account'=%s",
               (Jsonb({'last_label_check': datetime.now(timezone.utc).isoformat()}), account))
    db.execute("""UPDATE career.label_jobs j SET state='expired',error='outside_window' FROM career.messages m
        WHERE j.account=%s AND j.eligible AND j.state='pending' AND m.account=j.account AND m.id=j.message_id
        AND (m.envelope->>'received_at')::timestamptz<=now()-interval '7 days'""", (account,))
    rows = db.execute("""SELECT j.id,j.message_id,j.labels,j.generation,j.attempts
        FROM career.label_jobs j JOIN career.messages m ON m.account=j.account AND m.id=j.message_id
        WHERE j.account=%s AND j.eligible AND j.state='pending' AND j.next_attempt<=%s
        AND j.attempts<6 AND (m.envelope->>'received_at')::timestamptz>now()-interval '7 days'
        ORDER BY j.id LIMIT 25 FOR UPDATE OF j SKIP LOCKED""", (account, timestamp)).fetchall()
    jobs = []
    for key, message_id, labels, generation, attempts in rows:
        db.execute('UPDATE career.label_jobs SET attempts=attempts+1,next_attempt=%s WHERE id=%s', (timestamp+600, key))
        jobs.append(dict(job_id=key, account=account, message_id=message_id,
                         labels=labels, generation=generation, attempt=attempts+1))
    db.execute("UPDATE career.label_jobs SET state='failed',error='retry_limit' WHERE account=%s AND attempts>=6 AND state='pending' AND next_attempt<=%s", (account, timestamp))
    return {'jobs': jobs}


def finish_job(db, body):
    row = db.execute('SELECT generation,attempts FROM career.label_jobs WHERE id=%s FOR UPDATE', (body['job_id'],)).fetchone()
    if not row:
        raise ValueError('Unknown job')
    if row[0] != body['generation'] or row[1] != body['attempt']:
        return {'ok': True, 'superseded': True}
    success = body.get('verified') is True
    error = body.get('error', 'provider_error')
    if error not in ('provider_error', 'label_readback_mismatch', 'missing_label', 'authorization', 'not_found'):
        error = 'provider_error'
    terminal = row[1] >= 6 or error == 'not_found'
    db.execute('UPDATE career.label_jobs SET state=%s,error=%s,next_attempt=%s WHERE id=%s',
               ('delivered' if success else 'failed' if terminal else 'pending',
                None if success else error, time.time()+min(3600, 60*2**(row[1]-1)), body['job_id']))
    return {'ok': True, 'delivered': success}


def require_recent(message):
    received = datetime.fromisoformat(message['received_at'].replace('Z', '+00:00'))
    if received < datetime.now(timezone.utc)-timedelta(days=7) or received > datetime.now(timezone.utc)+timedelta(minutes=5):
        raise ValueError('Outside authorized seven-day window')
