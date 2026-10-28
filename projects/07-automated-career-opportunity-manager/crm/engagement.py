"""Evidence-backed email requests. Ingestion never commits its caller's transaction."""
import hashlib
import re
from datetime import datetime, timezone, date

from workflow.engine import current_text


REQUESTS = (
    ('availability', 'reply', 'Share your availability',
     r'\b(?:(?:please|could you|can you|would you|kindly)\b.{0,90}\b(?:share|send|provide|confirm|let .{0,12}know).{0,60}\b(?:availability|available|times? that work)|(?:what|when)\b.{0,25}\b(?:availability|available)|(?:are you|would you be) available|(?:may|can) (?:I|we) know your availability)'),
    ('documents', 'reply', 'Send the requested documents',
     r'\b(?:please|could you|can you|would you|kindly|we (?:need|require))\b.{0,70}\b(?:send|share|provide|upload|submit|attach)\b.{0,80}\b(?:resume|cv|portfolio|documents?|transcript|certificate|references?|identification)\b'),
    ('assessment', 'assessment', 'Complete the assessment',
     r'\b(?:(?:please|kindly|could you|can you|we (?:ask|invite|need|require) you to)\s+(?:\w+\s+){0,3}(?:complete|take|submit|finish)|(?:complete|take) (?:the|our|your))\b.{0,65}\b(?:assessment|test|coding challenge|exercise)\b'),
    ('interview', 'interview', 'Review the interview invitation',
     r'\b(?:invite you to (?:an? |the )?(?:\w+\s+){0,2}interview|(?:please|could you|can you|kindly)\b.{0,45}\b(?:confirm|attend|join|schedule)\b.{0,65}\binterview|your interview (?:is scheduled|has been scheduled))\b'),
    ('offer', 'reply', 'Review the employment offer',
     r'\b(?:pleased to offer you|offer you the (?:position|role)|offer of employment|please (?:review|sign|accept)\b.{0,50}\b(?:offer|employment contract))\b'),
)
NEGATED = re.compile(r"\b(?:do not|don't|no need to|need not|not required to|not (?:inviting|asking|offering)|no longer|not yet|will ask you|might ask you|if (?:selected|shortlisted|successful|your application))\b", re.I)
ALERT = re.compile(r'\b(?:your job alert|jobs? (?:recommended|you may like)|recommended vacancies|similar jobs you might like|unsubscribe from (?:these )?job alerts)\b', re.I)
REPLIES = {
    'availability': r'\b(?:I am|I\'m|I will be|I can be|my availability is|available (?:on|from|between|at)|(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday).{0,30}works for me)\b',
    'documents': r'\b(?:attached|enclosed|uploaded|submitted|here is|here are|please find)\b.{0,100}\b(?:resume|cv|portfolio|documents?|transcript|certificate|references?)\b',
    'assessment': r'\b(?:I (?:have )?(?:completed|finished|submitted) (?:the |my |your )?(?:(?:coding|technical) )?(?:assessment|test|challenge)|assessment (?:is |has been )?(?:completed|submitted))\b',
    'interview': r'\b(?:I confirm (?:my (?:attendance|availability)|(?:that )?I (?:can|will) attend|the interview)|I (?:can|will) attend (?:the |your )?interview|I accept (?:the|your) interview invitation|confirmed my attendance)\b',
    'offer': r'\b(?:I accept (?:the|your) offer|I decline (?:the|your) offer|signed (?:the|my|your) (?:offer|contract))\b',
}


def _json(value):
    from psycopg.types.json import Jsonb
    return Jsonb(value)


def _now():
    return datetime.now(timezone.utc).isoformat()


def _stamp(value):
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
        return parsed if parsed.tzinfo else None
    except (TypeError, ValueError, AttributeError):
        return None


def _key(account, message_id, kind):
    value = '\x00'.join((account, message_id, kind))
    return 'request-' + hashlib.sha256(value.encode()).hexdigest()[:40]


def _deadline(sentence):
    """Keep date-only precision; a meeting's proposed time is not a response deadline."""
    match = re.search(r'\b(?:by|before|no later than|deadline\s*(?:is|:)?|due\s*(?:on|:)?)[ \t]+(\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:\d{2}))?)', sentence, re.I)
    if not match:
        natural = re.search(r'\b(?:by|before|no later than|due on)\s+([A-Za-z]+ \d{1,2},? \d{4}|\d{1,2} [A-Za-z]+ \d{4})\b', sentence, re.I)
        if natural:
            for fmt in ('%B %d %Y', '%b %d %Y', '%d %B %Y', '%d %b %Y'):
                try:
                    parsed = datetime.strptime(natural[1].replace(',', ''), fmt)
                    return parsed.date().isoformat(), None, 'explicit'
                except ValueError:
                    continue
        return None, None, 'none'
    raw = match.group(1)
    try:
        day = date.fromisoformat(raw[:10]).isoformat()
    except ValueError:
        return None, None, 'none'
    exact = _stamp(raw) if 'T' in raw else None
    return day, exact.isoformat() if exact else None, 'explicit'


def extract_requests(message, outcome):
    """High precision requests from current message text, independent of hiring stage."""
    if message.get('direction') == 'sent' or outcome.get('resolution', {}).get('action') in ('ignore', 'opportunity'):
        return []
    body = current_text(message.get('current_body', message.get('body') or message.get('html_text','')))
    if ALERT.search(body) or ALERT.search(message.get('subject', '')):
        return []
    sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+|\n+', body) if s.strip()]
    result = []
    for kind, category, title, pattern in REQUESTS:
        evidence = [s for s in sentences if not NEGATED.search(s) and re.search(pattern, s, re.I)]
        if not evidence:
            continue
        due_on, due_at, origin = _deadline(evidence[0])
        result.append(dict(id=_key(message['account'], message['id'], kind),
            application_id=outcome.get('application_id'), title=title, category=category,
            status='open', actor='user', request_kind=kind, evidence=evidence[:5],
            source_account=message['account'], source_message_id=message['id'],
            source_thread_id=message.get('thread_id'), source_rfc_message_id=message.get('rfc_message_id'),
            due_on=due_on, due_at=due_at, deadline_origin=origin, corrected=False,
            created_at=message['received_at'], updated_at=_now(), completed_at=None))
    return result


def is_reply_candidate(message):
    """Keep recognizable sent replies even when a backfill has not reached the request yet."""
    if message.get('direction')!='sent':return False
    body=current_text(message.get('body',''))
    return bool((message.get('in_reply_to') or message.get('references')) and not NEGATED.search(body)
                and any(re.search(pattern,body,re.I) for pattern in REPLIES.values()))


def _header_ids(value):
    if isinstance(value, list):
        value = ' '.join(str(v) for v in value)
    if not isinstance(value, str):
        return []
    return re.findall(r'<[^<>\s]+>', value)


def reply_completions(message, candidates, thread_applications):
    """Resolve only requests addressed by this reply, with content and identity evidence."""
    sent = message.get('direction') == 'sent'
    body = current_text(message.get('current_body', message.get('body') or message.get('html_text','')))
    incoming_at = _stamp(message.get('received_at'))
    if not body or not incoming_at:
        return []
    direct = _header_ids(message.get('in_reply_to'))
    references = _header_ids(message.get('references'))
    references = direct or references[-1:]
    has_headers = bool(message.get('in_reply_to') or message.get('references'))
    unique = set(thread_applications)
    matches = []
    for task, source in candidates:
        source_at = _stamp(source.get('received_at'))
        if (task.get('status') != 'open' or task.get('corrected') or not source_at
                or incoming_at <= source_at or source.get('account') != message.get('account')):
            continue
        if (task.get('actor', 'user') == 'user') != sent:
            continue
        if has_headers:
            if not set(references).intersection(_header_ids(source.get('rfc_message_id'))):
                continue
        elif (not message.get('thread_id') or message.get('thread_id') != source.get('thread_id')
                or len(unique) != 1 or task.get('application_id') not in unique):
            continue
        kind = task.get('request_kind')
        if sent:
            pattern = REPLIES.get(kind)
            if not pattern or not re.search(pattern, body, re.I) or NEGATED.search(body) or re.search(
                    r"\b(?:not|never|haven't|didn't|cannot|can't)\b.{0,30}\b(?:attached|uploaded|submitted|completed|finished|attend|accepted)\b", body, re.I):
                continue
            if kind == 'availability' and not re.search(r'\b(?:available|availability|works for me)\b', body, re.I):
                continue
        matches.append((task, source_at))
    # Without exact headers, a thread is weaker evidence: handle only the latest request per kind.
    if not has_headers:
        latest = {}
        for task, at in matches:
            kind = task.get('request_kind')
            if kind not in latest or latest[kind][1] < at:
                latest[kind] = (task, at)
        matches = list(latest.values())
    return [task['id'] for task, _ in matches]


def _thread_apps(db, message):
    if not message.get('thread_id'):
        return []
    return [key for key, in db.execute("""SELECT id FROM career.applications
        WHERE data->>'account'=%s AND data->'threads' ? %s""", (message['account'], message['thread_id']))]


def _reconcile(db, message):
    from crm import notifications
    rows = db.execute("""SELECT t.id,t.data,m.envelope FROM career.tasks t JOIN career.messages m
        ON m.account=t.data->>'source_account' AND m.id=t.data->>'source_message_id'
        WHERE t.data->>'status'='open' AND t.data->>'source_account'=%s FOR UPDATE OF t""",
        (message['account'],)).fetchall()
    candidates = [(dict(data, id=key), source) for key, data, source in rows]
    completed = reply_completions(message, candidates, _thread_apps(db, message))
    for key in completed:
        db.execute("UPDATE career.tasks SET data=data || %s,version=version+1 WHERE id=%s", (_json(dict(
            status='done', completed_at=message['received_at'], updated_at=_now(),
            completion_source=dict(account=message['account'], message_id=message['id'], evidence=current_text(message.get('body', ''))[:1000]))), key))
        notifications.suppress_task(db, key)
    if completed and message.get('direction') == 'sent':
        apps = {task.get('application_id') for task, _ in candidates if task['id'] in completed}
        if len(apps) == 1:
            key = _key(message['account'], message['id'], 'employer_reply')
            waiting = dict(id=key, application_id=next(iter(apps)), title='Wait for the employer response',
                category='followup', status='open', actor='employer', request_kind='employer_reply',
                source_account=message['account'], source_message_id=message['id'], source_thread_id=message.get('thread_id'),
                evidence=[current_text(message.get('body', ''))[:1000]], due_on=None, due_at=None,
                deadline_origin='none', corrected=False, created_at=message['received_at'], updated_at=_now(), completed_at=None)
            db.execute('INSERT INTO career.tasks(id,data,version) VALUES (%s,%s,1) ON CONFLICT(id) DO NOTHING', (key, _json(waiting)))
    return completed


def ingest(db, message, outcome):
    """Call after messages are persisted, in the same transaction, including replay."""
    from crm import notifications
    db.execute('SELECT pg_advisory_xact_lock(70031)')
    created = []
    for task in extract_requests(message, outcome):
        inserted = db.execute('INSERT INTO career.tasks(id,data,version) VALUES (%s,%s,1) ON CONFLICT(id) DO NOTHING RETURNING id',
            (task['id'], _json(task))).fetchone()
        if inserted:
            created.append(task['id'])
            notifications.enqueue(db, task)
    if outcome.get('application_id'):
        relink(db, message['account'], message['id'], outcome['application_id'], automatic=True)
    completed = _reconcile(db, message)
    # A backfill can encounter a reply before its request. Reconcile already captured later mail.
    if created:
        for later, in db.execute("""SELECT envelope FROM career.messages WHERE account=%s
            AND envelope->>'thread_id'=%s AND (envelope->>'received_at')::timestamptz>%s::timestamptz
            ORDER BY (envelope->>'received_at')::timestamptz LIMIT 200""",
            (message['account'], message.get('thread_id'), message['received_at'])):
            completed.extend(_reconcile(db, later))
    return {'created': created, 'completed': completed}


def relink(db, account, message_id, application_id, automatic=False):
    """Review attaches the original evidence task instead of creating a second one."""
    db.execute('SELECT pg_advisory_xact_lock(70031)')
    rows = db.execute("SELECT id,data FROM career.tasks WHERE data->>'source_account'=%s AND data->>'source_message_id'=%s FOR UPDATE",
        (account, message_id)).fetchall()
    changed = []
    for key, data in rows:
        if data.get('application_id') == application_id or (automatic and (data.get('application_id') or data.get('corrected'))):
            continue
        data.update(application_id=application_id, updated_at=_now())
        db.execute('UPDATE career.tasks SET data=%s,version=version+1 WHERE id=%s', (_json(data), key))
        changed.append(key)
    return {'updated': changed}


def today(db):
    from crm import notifications
    apps = {key: data for key, data in db.execute('SELECT id,data FROM career.applications')}
    tasks = []
    for key, data, version in db.execute("SELECT id,data,version FROM career.tasks ORDER BY data->>'created_at' DESC"):
        app = apps.get(data.get('application_id'), {})
        tasks.append(dict(data, id=key, version=version, company=app.get('company'), role=app.get('role')))
    active = [t for t in tasks if t.get('status') == 'open']
    needs = [t for t in active if t.get('actor', 'user') == 'user']
    needs.sort(key=lambda t: (t.get('due_on') is None, t.get('due_at') or t.get('due_on') or '', t.get('created_at', '')))
    upcoming = [dict(data, id=key, version=version) for key, data, version in db.execute("""SELECT id,data,version FROM career.calendar_events
        WHERE COALESCE(data->>'status','') NOT IN ('cancelled','not_in_window') AND (data->>'end')::timestamptz>%s::timestamptz
        AND (data->>'application_id' IS NOT NULL OR data->>'automation'='true' OR lower(data->>'title') LIKE '%%interview%%')
        ORDER BY data->>'start' LIMIT 30""", (_now(),))]
    return dict(needs_response=needs, waiting=[t for t in active if t.get('actor') == 'employer'],
        upcoming=upcoming, review=[t for t in needs if not t.get('application_id')],
        handled=[t for t in tasks if t.get('status') == 'done'][:30], notifications=notifications.list_items(db),
        coverage={'local_uptime_required': True, 'note': 'Alerts require the computer, local services and paired helper to remain awake.'})
