"""Portable action workers. Imported inactive; credentials are references only."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'workflows'
SERVICE = {'httpHeaderAuth': {'id': 'project07EngineHeader', 'name': 'Project 07 local engine'}}
GMAIL = {}
for n in json.loads((OUT/'06-gmail-crm-sync.json').read_text(encoding='utf-8-sig'))['nodes']:
    if n.get('credentials', {}).get('gmailOAuth2'):
        GMAIL = {'gmailOAuth2': n['credentials']['gmailOAuth2']}
CALENDAR = {'googleCalendarOAuth2Api': {'id': 'rkf0GTF07ovWV6Ko', 'name': 'CareerFlow Calendar'}}


def node(name, kind, params, **kwargs):
    return dict(id=name, name=name, type='n8n-nodes-base.'+kind,
                typeVersion={'manualTrigger':1,'scheduleTrigger':1.2,'httpRequest':4.2,'code':2,'if':2.2}[kind],
                parameters=params, position=[0,300], **kwargs)


def code(name, js, each=False):
    return node(name,'code',{'jsCode':js,'mode':'runOnceForEachItem' if each else 'runOnceForAllItems'})


def http(name, url, body=None, credential=None, tolerate=False, send=False):
    credentials=credential or SERVICE
    key=next(iter(credentials))
    params={'url':url,'authentication':'genericCredentialType' if key=='httpHeaderAuth' else 'predefinedCredentialType',
            'genericAuthType' if key=='httpHeaderAuth' else 'nodeCredentialType':key,'options':{'timeout':25000}}
    if body is not None:params.update(method='POST',sendBody=True,specifyBody='json',jsonBody=body)
    if tolerate:params['options']['response']={'response':{'fullResponse':True,'neverError':True,'responseFormat':'json'}}
    return node(name,'httpRequest',params,credentials=credentials,retryOnFail=not send,maxTries=3,waitBetweenTries=1500,
                **({'onError':'continueRegularOutput'} if tolerate else {}))


def save(key,title,nodes,filename,minutes):
    links={}
    for i,n in enumerate(nodes):
        n['position']=[i*230,300]
        if i:links[nodes[i-1]['name']]={'main':[[{'node':n['name'],'type':'main','index':0}]]}
    timer=node('Scheduled worker','scheduleTrigger',{'rule':{'interval':[{'field':'minutes','minutesInterval':minutes}]}})
    timer['position']=[0,80]
    links[timer['name']]={'main':[[{'node':nodes[1]['name'],'type':'main','index':0}]]}
    nodes.append(timer)
    (OUT/filename).write_text(json.dumps(dict(id=key,name=title,active=False,nodes=nodes,connections=links,pinData={},
        settings={'executionOrder':'v1','timezone':'Asia/Manila','executionTimeout':240,'saveDataSuccessExecution':'none',
                  'saveDataErrorExecution':'none','saveManualExecutions':False}),indent=2)+'\n')


manual=lambda:node('Execute manually','manualTrigger',{})
nodes=[manual(),http('Connected Gmail','https://gmail.googleapis.com/gmail/v1/users/me/profile',credential=GMAIL),
    http('Claim approved replies','http://crm:8780/internal/actions/claim','={{ JSON.stringify({kind:"reply",account:$json.emailAddress}) }}'),
    code('Reply jobs','return ($json.jobs||[]).map(json=>({json}));'),
    http('Original headers','={{ "https://gmail.googleapis.com/gmail/v1/users/me/messages/"+encodeURIComponent($json.message_id)+"?format=metadata&metadataHeaders=Message-ID" }}',credential=GMAIL),
    code('Prepare reply',r"""const plan=$('Reply jobs').item.json;
const headers=$json.payload?.headers||[];const original=headers.find(h=>h.name.toLowerCase()==='message-id')?.value?.replace(/[\r\n]/g,'');
const subject='=?UTF-8?B?'+Buffer.from(plan.subject).toString('base64')+'?=';
const lines=['To: '+plan.to,'Subject: '+subject,'MIME-Version: 1.0','Content-Type: text/plain; charset=UTF-8','Content-Transfer-Encoding: base64'];
if(original){lines.push('In-Reply-To: '+original,'References: '+original);}
lines.push('',Buffer.from(plan.body).toString('base64'));
return {json:{...plan,raw:Buffer.from(lines.join('\r\n')).toString('base64url')}};""",True),
    http('Send confirmed reply','https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
         '={{ JSON.stringify({raw:$json.raw,threadId:$json.thread_id}) }}',GMAIL,True,True),
    code('Reply outcome',"const p=$('Prepare reply').item.json;const s=$json.statusCode||0;const ok=s>=200&&s<300&&!!$json.body?.id;return {json:{id:p.id,lease:p.lease,ok,external_id:$json.body?.id,uncertain:!s||s>=500||(s>=200&&s<300&&!ok),error:'Gmail delivery returned '+s+'. Check Sent before composing another reply.'}};",True),
    http('Record reply outcome','http://crm:8780/internal/actions/result','={{ JSON.stringify($json) }}')]
save('project07ApprovedReplies','Project 07 - 08 Send confirmed replies',nodes,'08-approved-replies.json',1)

listing=http('Read calendar events','=https://www.googleapis.com/calendar/v3/calendars/primary/events?singleEvents=true&orderBy=startTime&maxResults=100&timeMin={{ new Date(Date.now()-30*86400000).toISOString() }}&timeMax={{ new Date(Date.now()+180*86400000).toISOString() }}',credential=CALENDAR)
listing['parameters']['options']['pagination']={'pagination':{'paginationMode':'updateAParameterInEachRequest',
    'parameters':{'parameters':[{'type':'qs','name':'pageToken','value':'={{ $response.body.nextPageToken || "" }}'}]},
    'paginationCompleteWhen':'other','completeExpression':'={{ !$response.body.nextPageToken }}','limitPagesFetched':True,'maxRequests':20}}
nodes=[manual(),http('Primary calendar','https://www.googleapis.com/calendar/v3/calendars/primary',credential=CALENDAR),listing,
    code('Calendar snapshot',"const pages=$input.all();if(pages.at(-1).json.nextPageToken)throw new Error('Calendar exceeds 2000 events. Narrow the window.');return [{json:{calendar_name:$('Primary calendar').first().json.summary,window_start:new Date(Date.now()-30*86400000).toISOString(),window_end:new Date(Date.now()+180*86400000).toISOString(),items:pages.flatMap(p=>p.json.items||[])}}];"),
    http('Save calendar snapshot','http://crm:8780/internal/calendar/import','={{ JSON.stringify($json) }}'),
    http('Claim confirmed meetings','http://crm:8780/internal/actions/claim','={{ JSON.stringify({kind:"meeting"}) }}'),
    code('Meeting jobs','return ($json.jobs||[]).map(json=>({json}));'),
    http('Read existing event','={{ "https://www.googleapis.com/calendar/v3/calendars/primary/events/"+encodeURIComponent($json.event_id) }}',credential=CALENDAR,tolerate=True),
    code('Prepare calendar write',r"""const p=$('Meeting jobs').item.json;const b=$json.body||{};const s=$json.statusCode||0;
const base={...p,should_write:false,ok:false,error:'Calendar could not safely prepare this event.'};
if(p.status==='cancelled'&&(s===404||s===410))return {json:{...base,ok:true}};
if(s!==200&&s!==404)return {json:base};
if(s===200&&(b.extendedProperties?.private?.careerflow_event!==p.event_id||Number(b.extendedProperties?.private?.careerflow_revision||1)>Number(p.event_version||1)))return {json:{...base,error:'Calendar ownership or revision changed; review the event.'}};
if(s===200&&p.private_hold&&(b.attendees||[]).length)return {json:{...base,error:'Guests were added to this reminder; automatic changes are paused.'}};
if(s===200&&!b.etag)return {json:base};
const payload={summary:p.title,description:p.description||'',location:p.location||'',status:p.status||'confirmed',start:{dateTime:p.start,timeZone:'Asia/Manila'},end:{dateTime:p.end,timeZone:'Asia/Manila'},extendedProperties:{private:{...(b.extendedProperties?.private||{}),careerflow_event:p.event_id,careerflow_revision:String(p.event_version||1)}}};
if(s===404)payload.id=p.event_id;
if(!p.private_hold)payload.attendees=(p.attendees||[]).map(email=>({email}));
return {json:{...base,should_write:true,method:s===404?'POST':'PATCH',etag:b.etag||'*',payload,send_updates:!p.private_hold&&(p.attendees||[]).length?'all':'none'}};""",True),
    node('Safe to write','if',{'conditions':{'options':{'caseSensitive':True,'leftValue':'','typeValidation':'strict','version':2},'conditions':[{'id':'safe','leftValue':'={{ $json.should_write }}','rightValue':True,'operator':{'type':'boolean','operation':'true','singleValue':True}}],'combinator':'and'},'options':{}}),
    http('Write calendar event','={{ "https://www.googleapis.com/calendar/v3/calendars/primary/events"+($json.method==="PATCH"?"/"+encodeURIComponent($json.event_id):"")+"?sendUpdates="+$json.send_updates }}',
         '={{ JSON.stringify($json.payload) }}',CALENDAR,True,True),
    http('Read back event','={{ "https://www.googleapis.com/calendar/v3/calendars/primary/events/"+encodeURIComponent($("Meeting jobs").item.json.event_id) }}',credential=CALENDAR,tolerate=True),
    code('Meeting outcome',"const p=$('Meeting jobs').item.json;const b=$json.body||{};const cancelled=p.status==='cancelled';const ok=$json.statusCode===200&&b.id===p.event_id&&b.extendedProperties?.private?.careerflow_event===p.event_id&&Number(b.extendedProperties?.private?.careerflow_revision||1)===Number(p.event_version||1)&&b.status===(p.status||'confirmed')&&(!p.private_hold||!(b.attendees||[]).length)&&(cancelled||(Date.parse(b.start?.dateTime)===Date.parse(p.start)&&Date.parse(b.end?.dateTime)===Date.parse(p.end)));return {json:{id:p.id,lease:p.lease,ok,external_id:b.id,error:'Calendar readback did not confirm the event. Status '+($json.statusCode||0)}};",True),
    http('Record meeting outcome','http://crm:8780/internal/actions/result','={{ JSON.stringify($json) }}')]
save('project07Calendar','Project 07 - 09 Calendar and confirmed meetings',nodes,'09-calendar-meetings.json',5)
path=OUT/'09-calendar-meetings.json'
workflow=json.loads(path.read_text())
write=next(n for n in workflow['nodes'] if n['name']=='Write calendar event')
write['parameters'].update(method='={{ $json.method }}',sendHeaders=True,specifyHeaders='json',jsonHeaders='={{ JSON.stringify($json.method==="PATCH"?{"If-Match":$json.etag}:{}) }}')
workflow['connections']['Safe to write']['main'].append([{'node':'Record meeting outcome','type':'main','index':0}])
path.write_text(json.dumps(workflow,indent=2)+'\n')
print('Created inactive reviewed-action workflows with no execution data.')
