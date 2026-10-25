"""Conservative provider rules. Unknown identity always remains in review."""
import re
import hashlib
from email.utils import parseaddr
from workflow.engine import classify, current_text, decide

PARSER_VERSION = 4
ROLE_LABELS = ['IT Intern', 'QA Engineer Intern', 'Software Engineer Intern',
               'Business Application Intern', 'Data Engineer Intern', 'Other Internship']


def normalize_role(role):
    if not re.search(r'\bintern(?:ship)?\b', role, re.I):
        return None
    for pattern, label in [
        (r'\bqa\b|quality assurance', 'QA Engineer Intern'),
        (r'business application', 'Business Application Intern'),
        (r'data engineer', 'Data Engineer Intern'),
        (r'software|programmer|developer', 'Software Engineer Intern'),
        (r'\bit\b|information technology', 'IT Intern'),
    ]:
        if re.search(pattern, role, re.I):
            return label
    return role.strip()


def role_label(role):
    return role if role in ROLE_LABELS else 'Other Internship'


def classify_live(message):
    result = classify(message)
    text = re.sub(r'\s+', ' ', current_text(message['body']))
    domain = parseaddr(message.get('sender', ''))[1].lower().partition('@')[2]
    jobstreet = domain in ('jobstreet.com', 'jobstreet.com.ph') or domain.endswith(('.jobstreet.com', '.jobstreet.com.ph'))
    subject = message.get('subject', '')
    if jobstreet and re.search(r'job .*?(?:has (?:now )?expired|has closed)|no longer taking applications', text, re.I):
        result.update(stage=None, reason='listing_expired_not_application_closed')
        return result
    if jobstreet:
        match = re.search(r'your application for (.{2,160}?) was successfully submitted to (.{2,180}?)(?:\s*%%|\.\s+(?:You|Your|Track|View|Never)\b|$)', text, re.I)
        if match and message.get('thread_id'):
            if re.search(r'\b(?:if|might|may|not)\b', text[max(0,match.start()-40):match.start()], re.I):
                result.update(stage=None, reason='uncertain_language')
                return result
            role, company = (v.strip().rstrip('.') for v in match.groups())
            normalized = normalize_role(role)
            if normalized:
                return dict(stage='submitted', evidence=[match.group(0)], reason=None,
                            normalized_role=normalized, original_role=role, company=company,
                            reference='jobstreet:' + hashlib.sha256((message['thread_id']+'\n'+company.casefold()+'\n'+role.casefold()).encode()).hexdigest(),
                            identity_kind='jobstreet_confirmation', deadline=None)
    # A confirmation missing an employer/reference remains unmatched.
    if domain == 'indeed.com' or domain.endswith('.indeed.com'):
        if re.search(r'^Your application has been submitted\.', text, re.I):
            role = re.match(r'^Indeed Application:\s*(.{2,160})$', subject, re.I)
            result.update(stage='submitted', reason=None, evidence=['Your application has been submitted.'])
            if role:
                result.update(original_role=role[1], normalized_role=normalize_role(role[1]))
            return result
    if domain == 'myworkday.com' or domain.endswith('.myworkday.com'):
        received = re.search(r'Thank you for applying for the role of (.{2,160}?)\s*\.', text, re.I)
        identity = re.match(r'^\[([^\]]+)\] Application Received for (.+)$', subject, re.I)
        if received and identity and received[1].strip().casefold() == identity[2].strip().casefold():
            result.update(stage='submitted', reason=None, evidence=[received[0]],
                          company=identity[1], original_role=received[1].strip(),
                          normalized_role=normalize_role(received[1]))
            return result
    patterns = [
        ('rejected', r'we regret to inform you that we have chosen not to move forward with your application'),
        ('reviewing', r'you have been shortlisted for the .{2,160}? role'),
        ('assessment', r'invites you to take the PI (?:Behavioral|Cognitive) Assessment'),
    ]
    matches = [(stage, re.search(pattern, text, re.I)) for stage, pattern in patterns]
    matches = [(stage, match) for stage, match in matches if match]
    if len(matches) == 1 and result['reason'] in ('unrecognized_message', 'uncertain_language'):
        stage, match = matches[0]
        prefix = text[max(0, match.start()-50):match.start()]
        if not re.search(r'\b(?:if|might|may|not|never)\b', prefix, re.I):
            result.update(stage=stage, reason=None, evidence=[match[0]])
    if re.search(r'your job alert|job recommendations|background could be a match|new jobs - Job Alert', text + ' ' + subject, re.I) and not re.search(r'your application.*(?:received|submitted)|you have been shortlisted', text, re.I):
        result.update(stage=None, reason='opportunity_only')
    return result


def decide_live(message, result, applications):
    # Gmail groups some different JobStreet confirmations into one conversation.
    # Only an explicit submission with both identity fields can split that thread.
    if result.get('identity_kind') == 'jobstreet_confirmation':
        matches = [a for a in applications if a['account'] == message['account']
                   and message.get('thread_id') in a.get('threads', [])
                   and a['company'].casefold() == result['company'].casefold()
                   and a['original_role'].casefold() == result['original_role'].casefold()]
        if len(matches) == 1:
            # Preserve the identity of records created by the earlier parser.
            result['reference'] = matches[0].get('reference')
        return decide(message, result, matches)
    return decide(message, result, applications)
