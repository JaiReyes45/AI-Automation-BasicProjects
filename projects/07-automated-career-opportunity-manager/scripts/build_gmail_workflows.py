"""Build portable Gmail intake and reconciliation workflows, inactive on import."""
import json
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--only', choices=['05','06','07'], help='Regenerate one workflow without touching other exports')
args = parser.parse_args()

out = Path(__file__).resolve().parents[1] / 'workflows'
service = {'httpHeaderAuth': {'id': 'project07EngineHeader', 'name': 'Project 07 local engine'}}
gmail = {}
for path in sorted(out.glob('0[567]-*.json')):
    for n in json.loads(path.read_text(encoding='utf-8-sig'))['nodes']:
        if 'gmailOAuth2' in n.get('credentials', {}):
            gmail = {'gmailOAuth2': n['credentials']['gmailOAuth2']}

def node(name, kind, params, x=0, **kw):
    return dict(id=name, name=name, type='n8n-nodes-base.'+kind,
                typeVersion={'manualTrigger':1, 'scheduleTrigger':1.2, 'httpRequest':4.2, 'code':2, 'if':2.2}[kind],
                position=[x,300], parameters=params, **kw)

def code(name, js, each=False):
    return node(name, 'code', dict(jsCode=js, mode='runOnceForEachItem' if each else 'runOnceForAllItems'))

def http(name, url, body=None, google=False, tolerate=False):
    params = dict(url=url, options={'timeout':20000},
                  authentication='predefinedCredentialType' if google else 'genericCredentialType')
    params['nodeCredentialType' if google else 'genericAuthType'] = 'gmailOAuth2' if google else 'httpHeaderAuth'
    if google:
        params['options']['batching'] = {'batch':{'batchSize':1, 'batchInterval':750}}
    if tolerate:
        params['options']['response'] = {'response':{'fullResponse':True, 'neverError':True, 'responseFormat':'json'}}
    if body is not None:
        params.update(method='POST', sendBody=True, specifyBody='json', jsonBody=body)
    return node(name, 'httpRequest', params, credentials=gmail if google else service,
                retryOnFail=True, maxTries=3, waitBetweenTries=1500, **({'onError':'continueRegularOutput'} if tolerate else {}))

def condition(name, value):
    return node(name, 'if', {'conditions':{'options':{'caseSensitive':True,'typeValidation':'strict','version':2},
        'conditions':[{'leftValue':value,'rightValue':True,'operator':{'type':'boolean','operation':'true','singleValue':True}}], 'combinator':'and'}})

def edge(name):
    return {'node':name, 'type':'main', 'index':0}

def save(key, title, nodes, filename, branches=None, scheduled=False):
    if args.only and not filename.startswith(args.only+'-'):
        return
    for i,n in enumerate(nodes):
        n['position']=[i*220,300]
    links = {a['name']:{'main':[[edge(b['name'])]]} for a,b in zip(nodes,nodes[1:])}
    if branches:
        links.update(branches)
    if scheduled:
        trigger=node('Every five minutes','scheduleTrigger',{'rule':{'interval':[{'field':'minutes','minutesInterval':5}]}})
        trigger['position']=[0,80]
        nodes.append(trigger)
        links[trigger['name']]={'main':[[edge(nodes[1]['name'])]]}
    (out/filename).write_text(json.dumps(dict(id=key,name=title,active=False,nodes=nodes,connections=links,pinData={},
        settings={'executionOrder':'v1','timezone':'Asia/Manila','executionTimeout':240,
                  'saveDataSuccessExecution':'none','saveDataErrorExecution':'none','saveManualExecutions':False}),indent=2)+'\n')

def manual():
    return node('Execute manually','manualTrigger',{})

roles=['IT Intern','QA Engineer Intern','Software Engineer Intern','Business Application Intern','Data Engineer Intern','Other Internship']
labels=['Career/Stage/'+s for s in ['submitted','reviewing','information','assessment','interview','offer','accepted','hired','rejected','withdrawn','closed','Opportunity Discovered']]
labels+=['Career/Role/'+r for r in roles]+['Career/System/Needs Review']
nodes=[manual(),http('Existing labels','https://gmail.googleapis.com/gmail/v1/users/me/labels',google=True),
       code('Find missing','const required='+json.dumps(labels)+';return required.filter(name=>!($json.labels||[]).some(l=>l.name===name)).map(name=>({json:{name}}));'),
       http('Create label','https://gmail.googleapis.com/gmail/v1/users/me/labels',
            '={{ JSON.stringify({name:$json.name,labelListVisibility:"labelShow",messageListVisibility:"show"}) }}',True)]
save('project07GmailLabels','Project 07 - 05 Prepare Gmail labels',nodes,'05-gmail-labels.json')

normalize=r"""const m=$json;let parts=[];
function visit(p,type){if(!p)return;if(p.mimeType===type&&p.body?.data)parts.push(Buffer.from(p.body.data,'base64url').toString('utf8'));for(const child of p.parts||[])visit(child,type);}
visit(m.payload,'text/plain');const plain=parts.join('\n');parts=[];visit(m.payload,'text/html');
const rawHtml=parts.join('\n');
const stripHtml=s=>s.replace(/<!--[\s\S]*?-->/g,' ').replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1>/gi,' ').replace(/<(?:br\s*\/?|\/p|\/div)>/gi,'\n').replace(/<[^>]*>/g,' ');
const html=stripHtml(rawHtml);
const named={nbsp:' ',zwnj:'',zwj:'',amp:'&',lt:'<',gt:'>',quot:'"',apos:"'",bull:' '};
const decode=s=>s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi,(all,key)=>{if(key[0]==='#'){const n=parseInt(key.slice(key[1]?.toLowerCase()==='x'?2:1),key[1]?.toLowerCase()==='x'?16:10);return n>0&&n<=0x10ffff?String.fromCodePoint(n):' ';}return named[key.toLowerCase()]??all;}).replace(/[^\S\n]+/g,' ').trim();
const htmlText=decode(html);
const currentHtml=decode(stripHtml(rawHtml.split(/<blockquote\b|<[^>]+class=["'][^"']*gmail_quote/i)[0]));
const currentBody=(plain||currentHtml).split(/^\s*(?:On .+wrote:|From:|-----Original Message-----|>).*$/im)[0].trim();
const headers=m.payload?.headers||[];const header=n=>headers.filter(h=>h.name.toLowerCase()===n).map(h=>h.value).join('\n');
const run=$('Start mailbox page').first().json;
return {json:{account:$('Gmail account').first().json.emailAddress,id:m.id,thread_id:m.threadId,
received_at:new Date(Number(m.internalDate)).toISOString(),body:(plain||htmlText||'[No text body]').slice(0,45000),html_text:htmlText.slice(0,20000),current_body:currentBody.slice(0,45000),
subject:header('subject'),sender:header('from'),headers,label_ids:m.labelIds||[],
rfc_message_id:header('message-id'),references:header('references'),in_reply_to:header('in-reply-to'),
reply_to:header('reply-to'),to:header('to'),cc:header('cc'),direction:(m.labelIds||[]).includes('SENT')?'sent':'received',
mail_sync_run_id:run.run_id,mail_sync_lease_token:run.lease_token}};"""

# One page per scheduled invocation: PostgreSQL owns the resume token, fixed
# window and failure state. A provider error never advances the capture cursor.
nodes=[manual(), http('Gmail account','https://gmail.googleapis.com/gmail/v1/users/me/profile',google=True),
 http('Record connection','http://crm:8780/internal/connection','={{ JSON.stringify({account:$json.emailAddress}) }}'),
 http('Start mailbox page','http://crm:8780/api/workflows/mail/start',
      '={{ JSON.stringify({account:$("Gmail account").first().json.emailAddress}) }}'),
 condition('Lease acquired','={{ $json.should_run === true }}'),
 http('Fetch mailbox page','={{ "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults="+$json.max_results+"&q="+encodeURIComponent($json.query)+($json.page_token?"&pageToken="+encodeURIComponent($json.page_token):"") }}',google=True,tolerate=True),
 condition('Page fetched','={{ $json.statusCode === 200 && !!$json.body && !$json.body.error }}'),
 code('Describe page',"""const run=$('Start mailbox page').first().json;const page=$json.body;
const messages=page.messages||[];
if(!Array.isArray(messages)||messages.length>run.max_results||messages.some(m=>!m.id))throw new Error('Invalid Gmail page');
return [{json:{account:run.account,run_id:run.run_id,lease_token:run.lease_token,page_index:run.page_index,
page_token:run.page_token,next_page_token:page.nextPageToken||null,message_ids:[...new Set(messages.map(m=>m.id))],messages}}];"""),
 http('Select unprocessed','http://crm:8780/internal/select-messages','={{ JSON.stringify($json) }}'),
 condition('Has messages','={{ $json.messages.length > 0 }}'),
 code('Message IDs','return $json.messages.map(m=>({json:m}));'),
 http('Read message','={{ "https://gmail.googleapis.com/gmail/v1/users/me/messages/"+encodeURIComponent($json.id)+"?format=full" }}',google=True,tolerate=True),
 code('Check message reads',"""const items=$input.all();const failed=items.find(i=>i.json.statusCode!==200||!i.json.body?.id||!i.json.body?.payload);
if(failed)return [{json:{failed:true,error:[401,403].includes(failed.json.statusCode)?'authorization':'provider_error'}}];
return items.map((item,index)=>({json:item.json.body,pairedItem:{item:index}}));"""),
 condition('Messages readable','={{ $json.failed !== true }}'),
 code('Normalize email',normalize,True),
 code('Oldest first',"return $input.all().map((item,index)=>({json:item.json,pairedItem:{item:index}})).sort((a,b)=>a.json.received_at.localeCompare(b.json.received_at));"),
 http('Store in CRM','http://crm:8780/internal/gmail-ingest','={{ JSON.stringify($json) }}',tolerate=True),
 code('Check stored',"return [{json:{stored:$input.all().every(i=>i.json.statusCode===200&&!i.json.body?.error),error:'ingest_error'}}];"),
 condition('Messages stored','={{ $json.stored === true }}'),
 http('Acknowledge page','http://crm:8780/api/workflows/mail/page',
      '={{ JSON.stringify($("Describe page").first().json) }}'),
 http('Finish mailbox page','http://crm:8780/api/workflows/mail/finish',
      '={{ JSON.stringify({...$("Start mailbox page").first().json,success:true}) }}'),
 code('Read failure',"""const status=$json.statusCode||0;const run=$('Start mailbox page').first().json;
const error=$json.error==='authorization'||[401,403].includes(status)?'authorization':
status===400&&run.page_token?'invalid_page_token':$json.error==='ingest_error'?'ingest_error':'provider_error';
return [{json:{account:run.account,run_id:run.run_id,lease_token:run.lease_token,success:false,error}}];"""),
 http('Record mailbox failure','http://crm:8780/api/workflows/mail/finish','={{ JSON.stringify($json) }}')]
save('project07GmailSync','Project 07 - 06 Gmail to persistent CRM',nodes,'06-gmail-crm-sync.json',
     {'Lease acquired':{'main':[[edge('Fetch mailbox page')],[]]},
      'Page fetched':{'main':[[edge('Describe page')],[edge('Read failure')]]},
      'Has messages':{'main':[[edge('Message IDs')],[edge('Acknowledge page')]]},
      'Messages readable':{'main':[[edge('Normalize email')],[edge('Read failure')]]},
      'Messages stored':{'main':[[edge('Acknowledge page')],[edge('Read failure')]]},
      'Finish mailbox page':{'main':[]},'Record mailbox failure':{'main':[]}},True)

nodes=[manual(),http('Gmail account','https://gmail.googleapis.com/gmail/v1/users/me/profile',google=True),
 http('List Gmail labels','https://gmail.googleapis.com/gmail/v1/users/me/labels',google=True),
 http('Claim pending labels','http://crm:8780/internal/label-claim',
      "={{ JSON.stringify({account:$('Gmail account').first().json.emailAddress}) }}"),
 code('Label jobs','return ($json.jobs||[]).map(job=>({json:job}));'),
 code('Resolve label IDs',"""const all=$('List Gmail labels').first().json.labels||[];const plan=$json;
const add=plan.labels.map(name=>all.find(l=>l.name===name)?.id);
const remove=all.filter(l=>l.name.startsWith('Career/Stage/')||l.name.startsWith('Career/Role/')||l.name==='Career/System/Needs Review').map(l=>l.id).filter(id=>!add.includes(id));
return {json:{...plan,addLabelIds:add,removeLabelIds:remove,ready:add.every(Boolean)}};""",True),
 condition('Labels exist','={{ $json.ready }}'),
 http('Apply Gmail labels','={{ "https://gmail.googleapis.com/gmail/v1/users/me/messages/"+encodeURIComponent($json.message_id)+"/modify" }}',
      '={{ JSON.stringify({addLabelIds:$json.addLabelIds,removeLabelIds:$json.removeLabelIds}) }}',True,True),
 http('Read back labels','={{ "https://gmail.googleapis.com/gmail/v1/users/me/messages/"+encodeURIComponent($("Resolve label IDs").item.json.message_id)+"?format=minimal&fields=id,labelIds" }}',google=True,tolerate=True),
 code('Verify delivery',"""const plan=$('Resolve label IDs').item.json;
const labels=$json.body?.labelIds||[];const status=$json.statusCode||0;
const verified=status===200&&plan.addLabelIds.every(id=>labels.includes(id))&&plan.removeLabelIds.every(id=>!labels.includes(id));
return {json:{job_id:plan.job_id,generation:plan.generation,attempt:plan.attempt,verified,
error:status===404?'not_found':status===401||status===403?'authorization':status===200?'label_readback_mismatch':'provider_error'}};""",True),
 http('Record delivery','http://crm:8780/internal/label-result','={{ JSON.stringify($json) }}')]
missing=code('Missing label result',"return {json:{job_id:$json.job_id,generation:$json.generation,attempt:$json.attempt,verified:false,error:'missing_label'}};",True)
nodes.append(missing)
save('project07GmailReconcile','Project 07 - 07 Verify and retry Gmail labels',nodes,'07-gmail-label-reconcile.json',
     {'Labels exist':{'main':[[edge('Apply Gmail labels')],[edge('Missing label result')]]},
      'Record delivery':{'main':[]},'Missing label result':{'main':[[edge('Record delivery')]]}},True)
print('Prepared '+(args.only or 'all Gmail')+' workflow export(s); inactive until explicitly published.')
