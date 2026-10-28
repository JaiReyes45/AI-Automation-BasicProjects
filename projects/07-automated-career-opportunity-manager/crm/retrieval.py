"""Search the stored workspace before selecting bounded model evidence."""
import json
import re

STOP = set('a an the my me i to for in on of and or is are do does did can could please find search show tell which what how need needs response applications application'.split())


def retrieve(question, apps, tasks, messages, events, selected=None):
    terms=set(re.findall(r'[\w@.-]+',question.lower()))-STOP
    def rank(item):
        value=json.dumps(item,ensure_ascii=False).lower()
        score=sum(1 for term in terms if term in value)
        chosen=item.get('application_id',item.get('id'))==selected if selected else False
        return (chosen,score,item.get('received_at') or item.get('created_at') or '')
    def pick(items, limit):
        return sorted(items,key=rank,reverse=True)[:limit]
    records=pick(apps,25)
    # Evidence is selected across every stored message, not just the first two emails.
    mail=[{k:m.get(k) for k in ('id','account','application_id','subject','sender','received_at')} | {'body':m.get('body','')[:2000]} for m in pick(messages,6)]
    chosen_tasks=[dict(t,evidence=[str(e)[:500] for e in t.get('evidence',[])[:2]]) for t in pick(tasks,30)]
    facts=[{k:a.get(k) for k in ('id','company','role','stage','submitted_on','capture_state','nextAction','job_description')} for a in records]
    for fact in facts: fact['job_description']=(fact.get('job_description') or '')[:500]
    sources=[dict(type='task',id=t['id'],label=t['title'],application_id=t.get('application_id'),message_id=t.get('source_message_id'),account=t.get('source_account')) for t in chosen_tasks]
    sources += [dict(type='application',id=a['id'],application_id=a['id'],label=a.get('company','')+' · '+a.get('role','')) for a in facts]
    sources += [dict(type='email',id=m['id'],message_id=m['id'],account=m['account'],application_id=m.get('application_id'),label=m.get('subject','Employer message')) for m in mail]
    total=len(apps)+len(tasks)+len(messages)
    count=len(records)+len(chosen_tasks)+len(mail)
    return dict(applications=facts,tasks=chosen_tasks,emails=mail,calendar=events[:15],sources=sources,
                completeness=dict(records=count,total=total,limited=count<total),
                summary=dict(applications=sum(a.get('capture_state')!='saved' for a in apps),saved=sum(a.get('capture_state')=='saved' for a in apps),
                             open_tasks=sum(t.get('status')=='open' and t.get('actor','user')=='user' for t in tasks),
                             waiting=sum(t.get('status')=='open' and t.get('actor')=='employer' for t in tasks)))


def operational_answer(question, data):
    q=question.lower()
    answer=None
    sources=data['sources']
    if re.search(r'how many|total|count',q) and re.search(r'applications?|applied',q):
        s=data['summary'];answer=f"You have {s['applications']} application(s) and {s['saved']} saved opportunity/ies in CareerFlow. This counts stored records, not uncaptured applications."
    elif re.search(r'need.*(?:do|response|reply|attention)|what.*(?:next|today)|waiting|outstanding|overdue',q) and not re.search(r'draft|send|edit|book',q):
        waiting='waiting' in q
        items=[t for t in data['tasks'] if t.get('status')=='open' and (t.get('actor','user')=='employer')==waiting]
        title='Waiting for an employer' if waiting else 'Needs your response'
        answer=title+':\n'+('\n'.join('- '+t['title']+((' — due '+t['due_on']) if t.get('due_on') else ' — no explicit deadline') for t in items) if items else 'No matching open tasks in the retrieved records.')
        sources=[s for s in sources if s['type']=='task' and s['id'] in {t['id'] for t in items}]
        answer+=f"\nStored open response tasks: {data['summary']['open_tasks']}; waiting: {data['summary']['waiting']}."
    if answer is None:return None
    if data['completeness']['limited']:answer+='\nThe evidence list is limited; use Today to inspect all open tasks.'
    return dict(answer=answer,application_ids=list(dict.fromkeys(s['application_id'] for s in sources if s.get('application_id'))),proposal=None,sources=sources,completeness=data['completeness'])
