"""Account-scoped, resumable Gmail capture; provider access stays in n8n.

We deliberately use fixed received-time windows with a 24-hour overlap rather
than Gmail history IDs: an expired history ID otherwise needs a second recovery
protocol. This captures incoming and Sent messages, without subject filters.
It is not a mailbox mirror: retroactively imported mail older than the overlap,
deleted mail, drafts, spam and trash need an explicit bounded historical read.

Each worker invocation processes at most one page of 100 IDs. It acknowledges
only after every ID exists in career.messages, then releases its lease. A fixed
window's checkpoint advances only on an exhausted successful run. Interruptions
resume the last acknowledged page; expired provider tokens restart that same
window (message ingestion is idempotent). No function grants label eligibility.
Callers must commit each endpoint transaction before returning its response.
"""
import hashlib
import json
import math
import secrets
import time
import uuid
from datetime import datetime, timezone, timedelta

PAGE_SIZE = 100
LEASE_SECONDS = 900
ERRORS = {'provider_error', 'authorization', 'invalid_page_token', 'ingest_error',
          'not_found', 'page_limit', 'interrupted'}


def _instant(value):
    if not isinstance(value, str):
        raise ValueError('Expected an ISO timestamp with timezone')
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('Expected an ISO timestamp with timezone')
    return parsed.astimezone(timezone.utc)


def _now():
    return datetime.fromtimestamp(time.time(), timezone.utc)


def _account(value):
    if not isinstance(value, str) or not 3 <= len(value) <= 320 or '@' not in value or any(c.isspace() for c in value):
        raise ValueError('A Gmail account is required')
    return value.lower()


def _empty(account):
    return dict(account=account, strategy='received_time_overlap', complete_from=None,
                complete_through=None, last_completed_at=None, last_error=None,
                runs={}, lease=None, backfill=None, last_mode=None)


def _load(db, account, create=False):
    if create:
        db.execute('INSERT INTO career.mail_sync_accounts(account,state) VALUES (%s,%s::jsonb) ON CONFLICT(account) DO NOTHING',
                   (account, json.dumps(_empty(account))))
    row = db.execute('SELECT state FROM career.mail_sync_accounts WHERE account=%s FOR UPDATE', (account,)).fetchone()
    return row[0] if row else _empty(account)


def _save(db, state):
    db.execute('UPDATE career.mail_sync_accounts SET state=%s::jsonb WHERE account=%s',
               (json.dumps(state), state['account']))


def _public(state):
    lease = state.get('lease')
    interrupted = bool(lease and lease['expires'] <= time.time())
    runs = state.get('runs', {})
    active = next((r for r in runs.values() if lease and r['id'] == lease['run_id']), None)
    pending = active or runs.get('incremental') or runs.get('backfill')
    queued = state.get('backfill') and state['backfill']['status'] != 'complete'
    status = ('interrupted' if interrupted else 'running' if lease else
              'attention' if state.get('last_error') else 'catching_up' if pending or queued else
              'healthy' if state.get('complete_through') and
              (_now() - _instant(state['complete_through'])).total_seconds() < 900 else
              'behind' if state.get('complete_through') else 'not_started')
    return {k:state.get(k) for k in ('account','strategy','complete_from','complete_through','last_completed_at','backfill')} | {
        'status':status, 'last_error':'interrupted' if interrupted else state.get('last_error'),
        'active_run':({k:pending.get(k) for k in ('id','mode','after','before','page_index','processed','state')}
                      if pending else None),
        'overlap_hours':24, 'page_size':PAGE_SIZE, 'label_window_days':7,
        'limitations':'Received-time capture excludes drafts, spam and trash. Mail imported with older timestamps requires a historical read. Local computer and Docker must be awake.'}


def coverage(db, account=None):
    if account is not None:
        row = db.execute('SELECT state FROM career.mail_sync_accounts WHERE account=%s', (_account(account),)).fetchone()
        return _public(row[0] if row else _empty(_account(account)))
    return {'accounts':[_public(row[0]) for row in db.execute('SELECT state FROM career.mail_sync_accounts ORDER BY account')]}


def request_backfill(db, body):
    account = _account(body.get('account'))
    before = _instant(body['before']) if body.get('before') else _now()
    days = body.get('days', 90)
    if not isinstance(days, int) or isinstance(days, bool) or not 1 <= days <= 90:
        raise ValueError('Historical reads must cover 1 to 90 days')
    after = _instant(body['after']) if body.get('after') else before - timedelta(days=days)
    if before > _now() or not timedelta(0) < before-after <= timedelta(days=90):
        raise ValueError('Historical reads require a past range of at most 90 days')
    state = _load(db, account, True)
    existing = state.get('backfill')
    if existing and existing['status'] != 'complete':
        if existing['after'] == after.isoformat() and existing['before'] == before.isoformat():
            return {'ok':True, 'duplicate':True, 'coverage':_public(state)}
        raise ValueError('A historical read is already pending')
    state['backfill'] = dict(after=after.isoformat(), before=before.isoformat(),
                             next_before=before.isoformat(), status='pending', requested_at=_now().isoformat())
    _save(db, state)
    return {'ok':True, 'coverage':_public(state)}


def _new_run(state, mode):
    if mode == 'backfill':
        request = state.get('backfill')
        if not request or request['status'] == 'complete':
            raise ValueError('A historical read requires a pending request')
        before = _instant(request['next_before'])
        after = max(_instant(request['after']), before-timedelta(days=30))
    else:
        after = _instant(state['complete_through'])-timedelta(days=1) if state.get('complete_through') else _now()-timedelta(days=7)
        before = min(_now(), after+timedelta(days=30))
    query = f'after:{math.floor(after.timestamp())-1} before:{math.ceil(before.timestamp())+1} -in:drafts -in:spam -in:trash'
    return dict(id=str(uuid.uuid4()),mode=mode,after=after.isoformat(),before=before.isoformat(),
                query=query,page_token=None,page_index=0,processed=0,exhausted=False,
                state='running',started_at=_now().isoformat(),last_page=None,seen_tokens=[])


def start_run(db, body):
    account = _account(body.get('account'))
    state = _load(db, account, True)
    old_lease = state.get('lease')
    if old_lease and old_lease['expires'] > time.time():
        return {'account':account, 'should_run':False, 'reason':'busy', 'coverage':_public(state)}
    if old_lease:
        state['last_error'] = 'interrupted'
    mode = body.get('mode')
    if mode not in (None, 'incremental', 'backfill'):
        raise ValueError('Unknown mailbox mode')
    # Fair scheduling; old active work and queued history retain their own cursor.
    if mode is None:
        has_backfill = bool(state.get('backfill') and state['backfill']['status'] != 'complete')
        mode = 'backfill' if has_backfill and state.get('last_mode') == 'incremental' else 'incremental'
    run = state['runs'].get(mode)
    if run is None:
        run = _new_run(state, mode)
        state['runs'][mode] = run
    run['state'] = 'running'
    token = secrets.token_urlsafe(24)
    state['lease'] = dict(run_id=run['id'],token=token,expires=time.time()+LEASE_SECONDS,pages=0)
    state['last_mode'] = mode
    # A crash after the final acknowledgment needs no provider replay. Its
    # committed page already proves the complete window is durable.
    if run['exhausted']:
        state['lease']['pages'] = 1
        _save(db, state)
        recovered = finish_run(db, dict(account=account,run_id=run['id'],lease_token=token,success=True))
        return dict(account=account,should_run=False,reason='recovered_completed_run',coverage=recovered['coverage'])
    _save(db, state)
    return dict(account=account,run_id=run['id'],mode=mode,query=run['query'],after=run['after'],before=run['before'],
                page_token=run['page_token'],page_index=run['page_index'],max_results=PAGE_SIZE,
                max_pages=1,should_run=True,lease_token=token,coverage=_public(state))


def _owned(state, body):
    lease = state.get('lease')
    if not lease or lease['expires'] <= time.time() or lease['run_id'] != body.get('run_id') or not secrets.compare_digest(lease['token'], str(body.get('lease_token', ''))):
        raise ValueError('The mailbox lease is expired or belongs to another worker')
    run = next((r for r in state['runs'].values() if r['id'] == body['run_id']), None)
    if not run:
        raise ValueError('Unknown mailbox run')
    return run


def validate_message(db, message):
    if not message.get('mail_sync_run_id') and not message.get('mail_sync_lease_token'):
        return False
    account = _account(message.get('account'))
    state = _load(db, account)
    run = _owned(state, {'run_id':message.get('mail_sync_run_id'), 'lease_token':message.get('mail_sync_lease_token')})
    received = _instant(message.get('received_at'))
    # Gmail's epoch search has whole-second precision; overlap absorbs the edge.
    if not _instant(run['after'])-timedelta(seconds=1) <= received <= _instant(run['before'])+timedelta(seconds=1):
        raise ValueError('Message is outside the active mailbox read window')
    return True


def record_page(db, body):
    account = _account(body.get('account'))
    state = _load(db, account)
    run = _owned(state, body)
    ids = body.get('message_ids')
    if not isinstance(ids, list) or len(ids) > PAGE_SIZE or any(not isinstance(i, str) or not i or len(i)>512 for i in ids):
        raise ValueError('Invalid message page')
    ids = sorted(set(ids))
    next_token = body.get('next_page_token') or None
    if next_token is not None and (not isinstance(next_token, str) or len(next_token)>4096):
        raise ValueError('Invalid page token')
    marker = dict(index=body.get('page_index'), token=body.get('page_token') or None, next=next_token,
                  digest=hashlib.sha256(json.dumps(ids).encode()).hexdigest())
    previous = run.get('last_page')
    if previous and marker['index'] == previous['index']:
        if marker != previous:
            raise ValueError('Conflicting page replay')
        return dict(ok=True, replay=True, run_id=run['id'], page_index=run['page_index'],
                    page_token=run['page_token'], exhausted=run['exhausted'])
    if marker['index'] != run['page_index'] or marker['token'] != run['page_token']:
        raise ValueError('Unexpected page cursor')
    if state['lease']['pages'] >= 1:
        raise ValueError('Worker page limit reached; finish and resume')
    if run['exhausted']:
        raise ValueError('Mailbox run is already exhausted')
    if next_token and (next_token == marker['token'] or next_token in run['seen_tokens']):
        raise ValueError('Provider page token did not advance')
    if ids:
        placeholders = ','.join(['%s']*len(ids))
        stored = {r[0] for r in db.execute(f'SELECT id FROM career.messages WHERE account=%s AND id IN ({placeholders})', (account,*ids))}
        if stored != set(ids):
            raise ValueError('Every listed message must be stored before acknowledging its page')
    run.update(page_index=run['page_index']+1,page_token=next_token,exhausted=next_token is None,
               last_page=marker,processed=run['processed']+len(ids))
    if next_token:
        run['seen_tokens'].append(next_token)
    state['lease']['pages'] += 1
    _save(db, state)
    return dict(ok=True,replay=False,run_id=run['id'],page_index=run['page_index'],page_token=next_token,exhausted=run['exhausted'])


def finish_run(db, body):
    account = _account(body.get('account'))
    state = _load(db, account)
    previous = state.get('last_finish')
    if previous and previous['run_id'] == body.get('run_id') and previous['lease_token'] == body.get('lease_token'):
        return previous['response']
    run = _owned(state, body)
    success = body.get('success') is True
    if success and not state['lease']['pages']:
        raise ValueError('A successful worker must acknowledge its page first')
    complete = success and run['exhausted']
    if success:
        state['last_error'] = None
        run['state'] = 'paused'
    else:
        error = body.get('error', 'provider_error')
        state['last_error'] = error if error in ERRORS else 'provider_error'
        run['state'] = 'failed'
        if error == 'invalid_page_token':
            run.update(page_token=None,page_index=0,last_page=None,processed=0,seen_tokens=[],exhausted=False)
    if complete:
        if run['mode'] == 'incremental':
            state['complete_through'] = run['before']
            state['complete_from'] = state.get('complete_from') or run['after']
            state['last_completed_at'] = _now().isoformat()
        else:
            request = state['backfill']
            request['next_before'] = run['after']
            request['status'] = 'complete' if _instant(run['after']) <= _instant(request['after']) else 'pending'
            # Extend continuous coverage only when this historical window touches it.
            if state.get('complete_from') and _instant(run['before']) >= _instant(state['complete_from']):
                state['complete_from'] = min(_instant(run['after']),_instant(state['complete_from'])).isoformat()
        del state['runs'][run['mode']]
    state['lease'] = None
    response = dict(ok=True,complete=complete,processed=run['processed'],
                    reason='complete' if complete else 'page_limit' if success else state['last_error'],coverage=_public(state))
    state['last_finish'] = dict(run_id=body['run_id'],lease_token=body['lease_token'],response=response)
    _save(db, state)
    return response
