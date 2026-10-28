"""Evidence-backed private interview holds; scheduling is separate from hiring stage."""
import hashlib
import re
import time
from datetime import datetime, date, time as day_time, timezone, timedelta
from workflow.engine import current_text

MANILA = timezone(timedelta(hours=8))
ISO = r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:Z|[+-]\d{2}:\d{2})'
MONTHS = {name.lower(): i for i,name in enumerate(('January','February','March','April','May','June','July','August','September','October','November','December'),1)}


def stamp(value):
    result=datetime.fromisoformat(value.replace('Z','+00:00'))
    if result.tzinfo is None: raise ValueError('A timezone is required.')
    return result


def parse_interview(message):
    body=current_text(message.get('current_body',message.get('body','')))
    result=dict(state='availability_requested',start=None,end=None,evidence=None,reason='No explicit interview time range.')
    if not re.search(r'\binterview\b',body,re.I):
        return dict(result,state='none')
    if re.search(r'\b(?:not|never)\s+(?:been\s+)?cancel',body,re.I):
        return dict(result,reason='Negated cancellation requires review.')
    if re.search(r'interview.{0,35}\bcancell?ed\b|\bcancell?ed\b.{0,35}interview',body,re.I):
        return dict(result,state='cancelled',evidence=body[:500],reason=None)
    confirmed=bool(re.search(r'interview\s+(?:(?:has been|is)\s+)?confirmed|\bconfirming\s+(?:your|the)\s+interview',body,re.I))
    result['state']='confirmed' if confirmed else 'tentative'
    times=re.findall(ISO,body)
    a=b=None
    if len(times)==2:
        try:a,b=map(stamp,times)
        except ValueError:return dict(result,reason='Unrecognized date or time.')
    elif len(times)>2:
        return dict(result,reason='Multiple proposed times require a choice.')
    else:
        dates=list(re.finditer(r'\b('+ '|'.join(MONTHS)+r')\s+(\d{1,2}),?\s+(\d{4})\b',body,re.I))
        dm=dates[0] if len(dates)==1 else None
        clocks=re.findall(r'\b(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\b',body,re.I)
        tz=re.search(r'\b(PHT|Philippine(?:s)? time|Manila time|(?:UTC|GMT)(?:[+-]\d{1,2}(?::?\d{2})?)?)\b',body,re.I)
        if dm and len(clocks)==2 and tz:
            offset=timezone.utc if tz[1].upper() in ('UTC','GMT') else MANILA
            explicit=re.fullmatch(r'(?:UTC|GMT)([+-])(\d{1,2})(?::?(\d{2}))?',tz[1],re.I)
            if explicit:
                hours,minutes=int(explicit[2]),int(explicit[3] or 0)
                if hours>14 or minutes>59 or (hours==14 and minutes):return dict(result,reason='Invalid timezone offset.')
                offset=timezone(timedelta(minutes=(hours*60+minutes)*(1 if explicit[1]=='+' else -1)))
            def clock(parts):
                h,m,half=parts
                if not 1<=int(h)<=12 or not 0<=int(m or 0)<=59: raise ValueError('Invalid time')
                return int(h)%12+(12 if half.upper()=='PM' else 0),int(m or 0)
            try:
                day=date(int(dm[3]),MONTHS[dm[1].lower()],int(dm[2]))
                a=datetime.combine(day,day_time(*clock(clocks[0])),offset)
                b=datetime.combine(day,day_time(*clock(clocks[1])),offset)
            except ValueError:
                return dict(result,reason='Unrecognized date or time.')
    if a is None or b is None:
        if re.search(r'\bavailability\b',body,re.I): result['state']='availability_requested'
        return result
    if b<=a or b-a>timedelta(hours=8):
        return dict(result,reason='End time must follow start time within eight hours.')
    return dict(result,start=a.isoformat(),end=b.isoformat(),evidence=body[:1000],reason=None)


def event_key(message, application_id):
    return hashlib.sha256((message['account']+'\n'+str(application_id or '')+'\n'+str(message.get('thread_id') or message['id'])).encode()).hexdigest()[:40]


def free_slots(events, day, minutes=30, not_before=None):
    if minutes not in (15,30,45,60): raise ValueError('Choose 15, 30, 45 or 60 minutes.')
    d=date.fromisoformat(day)
    if d.weekday()>4: return []
    current=datetime.combine(d,day_time(9),MANILA);limit=datetime.combine(d,day_time(17),MANILA)
    result=[]
    while current+timedelta(minutes=minutes)<=limit and len(result)<6:
        end=current+timedelta(minutes=minutes)
        blocked=bool(not_before and current<not_before)
        for event in events:
            if event.get('status') in ('cancelled','not_in_window'): continue
            try:
                if current<stamp(event['end']) and end>stamp(event['start']): blocked=True;break
            except (KeyError,TypeError,ValueError):
                # Invalid imported times cannot establish free availability.
                blocked=True;break
        if not blocked: result.append(dict(start=current.isoformat(),end=end.isoformat()))
        current+=timedelta(minutes=30)
    return result


def ingest(db, message, outcome):
    if message.get('direction')=='sent' or outcome.get('resolution', {}).get('action') in ('ignore','opportunity'): return None
    proposal=parse_interview(message)
    if proposal['state'] in ('none','availability_requested'): return None
    from psycopg.types.json import Jsonb
    application_id=outcome.get('application_id')
    key=event_key(message,application_id)
    existing=db.execute('SELECT data,version FROM career.calendar_events WHERE id=%s FOR UPDATE',(key,)).fetchone()
    # A newly linked unmatched request keeps its original event identity.
    if not existing:
        rows=db.execute("SELECT id,data,version FROM career.calendar_events WHERE data->>'source_account'=%s AND data->>'source_thread_id'=%s AND data->>'automation'='true'",(message['account'],message.get('thread_id') or message['id'])).fetchall()
        if len(rows)==1: key,old,version=rows[0];existing=(old,version)
    old=existing[0] if existing else {}
    application_id=application_id or old.get('application_id')
    if old.get('source_message_id')==message['id']:
        if application_id and old.get('application_id')!=application_id:
            app=db.execute('SELECT data FROM career.applications WHERE id=%s',(application_id,)).fetchone()
            link=dict(application_id=application_id,title=('Tentative interview · ' if old.get('status')=='tentative' else 'Interview · ')+(app[0]['company'] if app else 'Employer'))
            db.execute('UPDATE career.calendar_events SET data=data || %s,version=version+1 WHERE id=%s',(Jsonb(link),key))
            db.execute("UPDATE career.actions SET data=data || %s WHERE kind='meeting' AND data->>'event_id'=%s AND state IN ('queued','processing')",(Jsonb(link),key))
        return key
    if old.get('source_received_at') and stamp(message['received_at'])<=stamp(old['source_received_at']): return None
    if proposal['state']=='cancelled':
        if not existing: return None
        proposal.update(start=old['start'],end=old['end'])
    if not proposal['start'] or stamp(proposal['start'])<datetime.now(timezone.utc): return None
    if old.get('attendees') or old.get('source') not in (None,'careerflow'):
        # Never automatically modify guest-bearing or independently created events.
        return None
    app=db.execute('SELECT data FROM career.applications WHERE id=%s',(application_id,)).fetchone() if application_id else None
    company=app[0]['company'] if app else 'Employer (application needs review)'
    clashes=[]
    if proposal['state']!='cancelled':
        for other,event in db.execute("SELECT id,data FROM career.calendar_events WHERE COALESCE(data->>'status','') NOT IN ('cancelled','not_in_window')"):
            if other==key: continue
            try:
                if stamp(proposal['start'])<stamp(event['end']) and stamp(proposal['end'])>stamp(event['start']): clashes.append(event.get('title','Calendar event'))
            except (KeyError,ValueError): continue
    revision=existing[1]+1 if existing else 1
    data=dict(old,application_id=application_id,title=('Tentative interview · ' if proposal['state']=='tentative' else 'Interview · ')+company,
              start=proposal['start'],end=proposal['end'],location='',description='Private CareerFlow reminder. See the linked employer email; this event does not send a reply or invitation.',
              attendees=[],source='careerflow',automation=True,status=proposal['state'],scheduling_state=proposal['state'],
              sync_state='conflict' if clashes else 'queued',google_id=key,event_id=key,revision=revision,
              source_account=message['account'],source_message_id=message['id'],source_thread_id=message.get('thread_id') or message['id'],
              source_received_at=message['received_at'],evidence=proposal['evidence'],conflicts=clashes)
    db.execute('INSERT INTO career.calendar_events VALUES (%s,%s,%s) ON CONFLICT(id) DO UPDATE SET data=EXCLUDED.data,version=EXCLUDED.version',(key,Jsonb(data),revision))
    db.execute("UPDATE career.actions SET state='superseded' WHERE kind='meeting' AND state='queued' AND data->>'event_id'=%s",(key,))
    if not clashes:
        action_key='auto-'+hashlib.sha256((key+'\n'+message['id']).encode()).hexdigest()
        job=dict(data,operation='upsert',event_version=revision,private_hold=True)
        db.execute("INSERT INTO career.actions(id,kind,state,data,created) VALUES (%s,'meeting','queued',%s,%s) ON CONFLICT(id) DO NOTHING",(action_key,Jsonb(job),time.time()))
    return key
