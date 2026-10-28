"""Match identity independently from stage interpretation; evidence is inspectable."""
import re
from email.utils import parseaddr
from workflow.engine import current_text


def address(value):
    return parseaddr(value or '')[1].casefold()


def match_application(message, classification, applications):
    candidates = [a for a in applications if a.get('account') == message.get('account')]
    reference, thread = classification.get('reference'), message.get('thread_id')
    refs = [a for a in candidates if reference and a.get('reference') == reference]
    threads = [a for a in candidates if thread and thread in a.get('threads', [])]
    result = dict(application_id=None, disposition='review', candidates=[], reasons=[], rule_version=1)
    if reference and threads and any(a.get('reference') and a['reference'] != reference for a in threads):
        return dict(result, reasons=['reference_thread_conflict'])
    matches, reason = (refs, 'application_reference') if refs else (threads, 'known_thread')
    if not matches:
        sender = address(message.get('sender'))
        body = re.sub(r'\s+', ' ', current_text(message.get('body',''))).casefold()
        matches = [a for a in candidates
                   if a.get('stage') not in ('rejected','hired','withdrawn','closed')
                   and sender and sender in [address(c) for c in a.get('verified_contacts', [])]
                   and len(a.get('original_role', a.get('role',''))) >= 4
                   and re.search(r'(?<!\w)'+re.escape(a.get('original_role',a.get('role','')).casefold())+r'(?!\w)', body)]
        reason = 'verified_contact_and_role'
    result['candidates'] = [dict(id=a['id'], company=a.get('company'), role=a.get('original_role',a.get('role'))) for a in matches]
    result['reasons'] = [reason] if matches else ['no_supported_identity']
    if len(matches) == 1:
        app = matches[0]
        if classification.get('company') and classification['company'].casefold() != app.get('company','').casefold():
            return dict(result, reasons=['company_conflict'])
        if classification.get('original_role') and classification['original_role'].casefold() != app.get('original_role',app.get('role','')).casefold():
            return dict(result, reasons=['role_conflict'])
        result.update(application_id=app['id'], disposition='matched')
    elif matches:
        result['reasons'] = ['multiple_applications']
    return result


def is_career_message(message, classification):
    if classification.get('reason') == 'opportunity_only':
        return False
    if classification.get('stage') or classification.get('company') or classification.get('original_role'):
        return True
    body = current_text(message.get('body',''))
    value = message.get('subject','')+'\n'+body
    return bool(re.search(r'\b(interview|internship|intern|recruit(?:er|ment|ing)?|shortlist(?:ed)?|job offer|job application|your application|application (?:received|submitted|update)|coding (?:test|challenge)|employment|onboarding|deployment|assessment)\b', value, re.I))
