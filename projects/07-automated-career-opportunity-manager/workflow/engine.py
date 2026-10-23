"""Conservative, deterministic classification. No network access or AI execution."""
import re
from datetime import datetime
from html import unescape

STAGES = ['submitted', 'reviewing', 'information', 'assessment', 'interview', 'offer', 'accepted', 'hired']
RULES = [
    ('rejected', r'not moving forward|not been selected|unsuccessful|regret to inform'),
    ('offer', r'pleased to offer you|offer of employment|offer you the position'),
    ('interview', r'invite you to (?:an? |the )?interview|schedule (?:an? |your )interview|interview invitation'),
    ('assessment', r'complete (?:the |our |a )?(?:technical |coding )?(?:assessment|test)|coding challenge'),
    ('information', r'please (?:send|provide|share).*(?:portfolio|availability|documents|information|resume)'),
    ('reviewing', r'application is (?:being |under )review|reviewing your application'),
    ('submitted', r'application (?:has been |was )?received|received your application|thank you for applying'),
]

def current_text(body):
    # Remove common quoted replies before stripping markup.
    body = re.split(r'<blockquote\b|<[^>]+class=[\"\'][^\"\']*gmail_quote', body, flags=re.I)[0]
    body = re.sub(r'<(?:script|style)\b[^>]*>.*?</(?:script|style)>', '', body, flags=re.I | re.S)
    body = re.sub(r'<(?:br\s*/?|/p|/div)>', '\n', body, flags=re.I)
    body = unescape(re.sub(r'<[^>]*>', '', body))
    body = re.split(r'(?im)^\s*(?:On .+wrote:|From:|-----Original Message-----|>).*', body)[0]
    return body.strip()

def classify(message):
    if not isinstance(message, dict):
        raise ValueError('Expected an email object')
    for field in ('account', 'id', 'received_at', 'body'):
        if not isinstance(message.get(field), str) or not message[field].strip():
            raise ValueError(f'Missing {field}')
    when = datetime.fromisoformat(message['received_at'].replace('Z', '+00:00'))
    if when.tzinfo is None:
        raise ValueError('received_at must include a timezone')
    for key in ('thread_id', 'subject', 'sender'):
        if message.get(key) is not None and not isinstance(message[key], str):
            raise ValueError(f'{key} must be text')
    text = current_text(message['body'])
    # The body, not an old reply subject, determines progression.
    hits = [(stage, re.search(pattern, text, re.I)) for stage, pattern in RULES]
    hits = [(stage, match.group(0)) for stage, match in hits if match]
    fields = {}
    ambiguous_fields = False
    for key in ('company', 'role', 'reference'):
        values = set(v.strip() for v in re.findall(rf'(?im)^{key}:[ \t]*([^\n]*)', text) if v.strip())
        fields[key] = next(iter(values)) if len(values) == 1 else None
        ambiguous_fields |= len(values) > 1
    role = fields['role']
    normalized = None
    if role:
        if re.search(r'\b(qa|quality assurance)\b.*intern', role, re.I): normalized = 'QA Engineer Intern'
        elif re.search(r'software.*intern', role, re.I): normalized = 'Software Engineer Intern'
        elif re.search(r'\bit\b.*intern', role, re.I): normalized = 'IT Intern'
    stage = hits[0][0] if len(hits) == 1 else None
    reason = 'conflicting_signals' if len(hits) > 1 else 'unrecognized_message' if not hits else None
    if re.search(r'jobs? (?:recommended|you may like)|recommended vacancies', text, re.I):
        stage, reason = None, 'opportunity_only'
    if ambiguous_fields:
        stage, reason = None, 'conflicting_identity'
    if hits and re.search(r"\b(if|might|may|not yet|not an? offer|do not|don't|will review|will be reviewed)\b", text, re.I):
        stage, reason = None, 'uncertain_language'
    if hits and stage != 'rejected' and re.search(r'\b(?:not|never)\b', text, re.I):
        stage, reason = None, 'uncertain_language'
    return dict(stage=stage, evidence=[x[1] for x in hits], reason=reason,
                normalized_role=normalized, original_role=role,
                company=fields['company'], reference=fields['reference'], deadline=None)

def decide(message, result, applications):
    """Return an application match or a reason for review; never match by company alone."""
    if result['reason']: return None, result['reason']
    candidates = [a for a in applications if a['account'] == message['account']]
    reference, thread = result['reference'], message.get('thread_id')
    matches = [a for a in candidates if reference and a.get('reference') == reference]
    thread_matches = [a for a in candidates if thread and thread in a.get('threads', [])]
    if matches and any(a['id'] not in {m['id'] for m in matches} for a in thread_matches):
        return None, 'identity_conflict'
    if not matches:
        matches = thread_matches
    if len(matches) != 1:
        # Even company+role matches are reviewed: an opening may be a reapplication.
        if matches: return None, 'ambiguous_match'
        if result['stage'] == 'submitted' and all(result[k] for k in ('company', 'normalized_role', 'reference')):
            return None, 'create'
        return None, 'unmatched_application'
    app = matches[0]
    if result['company'] and result['company'].casefold() != app['company'].casefold(): return None, 'identity_conflict'
    if result['original_role'] and result['original_role'].casefold() != app['original_role'].casefold(): return None, 'identity_conflict'
    if reference and app.get('reference') and reference != app['reference']: return None, 'identity_conflict'
    incoming = datetime.fromisoformat(message['received_at'].replace('Z', '+00:00'))
    latest = datetime.fromisoformat(app['last_event'].replace('Z', '+00:00'))
    if incoming < latest: return None, 'stale_event'
    if app['stage'] in ('rejected', 'hired', 'withdrawn', 'closed'): return None, 'closed_application'
    if result['stage'] in STAGES and app['stage'] in STAGES and STAGES.index(result['stage']) < STAGES.index(app['stage']):
        return None, 'stage_regression'
    return app, 'update'
