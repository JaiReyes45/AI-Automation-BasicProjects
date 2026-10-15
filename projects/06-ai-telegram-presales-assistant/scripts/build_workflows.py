"""Build credential-free, inactive n8n exports from tested runtime source."""
import json, pathlib, uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'workflows'; OUT.mkdir(exist_ok=True)
ENGINE=(ROOT/'runtime/engine.js').read_text().split('module.exports=')[0]

def node(name,kind,params=None,version=1,**extra):
    return dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,'presales/'+name)),name=name,type='n8n-nodes-base.'+kind,typeVersion=version,position=[0,0],parameters=params or {},**extra)
def code(name,body,engine=False):return node(name,'code',{'jsCode':(ENGINE+'\n' if engine else '')+body},2)
def trigger():return node('Subworkflow Input','executeWorkflowTrigger',{'inputSource':'passthrough'},1.2)
def manual():return node('Run Manually','manualTrigger')
def schedule(seconds=5):return node('Recovery Schedule','scheduleTrigger',{'rule':{'interval':[{'field':'seconds','secondsInterval':seconds}]}},1.2)
def pg(name,sql,params='[]'):
    return node(name,'postgres',{'operation':'executeQuery','query':sql,'options':{'queryReplacement':'={{ '+params+' }}'}},2.7)
def sub(n):return node('Run '+str(n).zfill(2),'executeWorkflow',{'workflowId':{'__rl':True,'value':f'p06Workflow{n:02d}','mode':'id'},'workflowInputs':{'mappingMode':'passThrough','value':{}},'options':{'waitForSubWorkflow':True}},1.3)
def iff(name,expr):return node(name,'if',{'conditions':{'options':{'caseSensitive':True,'typeValidation':'strict','version':2},'conditions':[{'id':name,'leftValue':'={{ '+expr+' }}','rightValue':'','operator':{'type':'boolean','operation':'true','singleValue':True}}],'combinator':'and'},'options':{}},2.2)
def http(name,expr):return node(name,'httpRequest',{'method':'POST','url':'http://ollama:11434/api/generate','sendBody':True,'contentType':'raw','rawContentType':'application/json','body':'={{ JSON.stringify('+expr+') }}','options':{'timeout':120000}},4.2,onError='continueRegularOutput')
def workflow(n,title,nodes,edges=None):
    for i,x in enumerate(nodes):x['position']=[i*240,0]
    cons={}
    for a,b,*idx in (edges if edges is not None else [(nodes[i]['name'],nodes[i+1]['name']) for i in range(len(nodes)-1)]):
        output=idx[0] if idx else 0
        conn=cons.setdefault(a,{'main':[]})['main']
        while len(conn)<=output:conn.append([])
        conn[output].append({'node':b,'type':'main','index':0})
    data={'id':f'p06Workflow{n:02d}','name':f'{n:02d} — {title}','active':False,'nodes':nodes,'connections':cons,'settings':{'executionOrder':'v1','saveDataSuccessExecution':'none','saveDataErrorExecution':'none','saveManualExecutions':False,'executionTimeout':300},'pinData':{},'tags':[]}
    (OUT/f'{n:02d}-{title.lower().replace(" ","-")}.json').write_text(json.dumps(data,indent=2)+'\n')

# 01 acknowledges only after durable, atomic database ingestion.
t=node('Durable Telegram Intake','p06TelegramIntake')
t['type']='CUSTOM.p06TelegramIntake'
t['webhookId']=str(uuid.uuid5(uuid.NAMESPACE_URL,'presales/durable-intake'))
workflow(1,'Telegram Intake Adapter',[t,code('Normalize and Validate','const e=normalize($json); return e.ignored?[]:[{json:e}];',True),sub(2)])
workflow(2,'Customer and Conversation Persistence',[trigger(),pg('Atomic Intake','SELECT presales.accept_update($1::jsonb) AS result;','[JSON.stringify($json)]'),code('Intake Result','return [{json:$json.result}];')])

# Commands never need a model; only one schema repair is possible.
nodes=[trigger(),code('Preflight','return [{json:preflight($json)}];',True),iff('Needs AI','!$json.skip_ai'),
       code('Prepare AI','return [{json:{...$json,ollama_request:aiRequest($json)}}];',True),http('Extract Facts','$json.ollama_request'),
       code('Validate Facts',"const c=$('Prepare AI').first().json; return [{json:applyExtraction(c,$json.response)}];",True),iff('Valid Facts','$json.ai_valid === true'),
       code('Prepare Repair','return [{json:{...$json,ollama_request:aiRequest($json,true)}}];',True),http('Repair Once','$json.ollama_request'),
       code('Validate Repair',"let c=applyExtraction($('Prepare Repair').first().json,$json.response); if(!c.ai_valid)c=escalate(c,'ai_unavailable_or_invalid'); return [{json:c}];",True),code('Validated Result','const c=$json; delete c.ollama_request; return [{json:c}];')]
workflow(3,'Intent and Requirement Extraction',nodes,[('Subworkflow Input','Preflight'),('Preflight','Needs AI'),('Needs AI','Prepare AI',0),('Needs AI','Validated Result',1),('Prepare AI','Extract Facts'),('Extract Facts','Validate Facts'),('Validate Facts','Valid Facts'),('Valid Facts','Validated Result',0),('Valid Facts','Prepare Repair',1),('Prepare Repair','Repair Once'),('Repair Once','Validate Repair'),('Validate Repair','Validated Result')])
for n,title,fn in [(4,'Service and Knowledge Search','retrieve'),(5,'Discovery Question Manager','discover'),(6,'Deterministic Estimate Builder','estimate'),(7,'Lead Qualification','qualify'),(8,'Human Handoff','handoff')]:
    workflow(n,title,[trigger(),code(title,'return [{json:'+fn+'($json)}];',True)])

steps=[sub(i) for i in range(3,9)]
commit=pg('Commit Decision','SELECT presales.commit_decision($1::bigint,$2::uuid,$3::jsonb) AS result;','[$json.update_id,$json.lease_token,JSON.stringify($json.decision)]')
for step in steps+[commit]:step['onError']='continueErrorOutput'
nodes=[schedule(),manual(),pg('Claim Inbox','SELECT presales.claim_inbox() AS result;'),code('Claimed Context','return $json.result?[{json:$json.result}]:[];')]+steps+[commit,code('Safe Failure',"const c=$('Claimed Context').first().json; return [{json:{update_id:c.update_id,lease_token:c.lease_token}}];"),pg('Retry Failed Decision',"SELECT presales.fail_inbox($1::bigint,$2::uuid,'decision_processing_failed',true) AS result;",'[$json.update_id,$json.lease_token]')]
edges=[('Recovery Schedule','Claim Inbox'),('Run Manually','Claim Inbox'),('Claim Inbox','Claimed Context'),('Claimed Context','Run 03')]+[(f'Run {i:02d}',f'Run {i+1:02d}') for i in range(3,8)]+[('Run 08','Commit Decision')]
edges += [(s['name'],'Safe Failure',1) for s in steps+[commit]]+[('Safe Failure','Retry Failed Decision')]
workflow(0,'Pre-Sales Orchestrator',nodes,edges)

send=node('Send Approved Reply','telegram',{'resource':'message','operation':'sendMessage','chatId':'={{ $json.payload.chat_id }}','text':'={{ $json.payload.text }}','additionalFields':{'appendAttribution':False,'parse_mode':'HTML'}},1.2,onError='continueRegularOutput')
send['parameters'].update({'replyMarkup':'replyKeyboard','replyKeyboard':{'rows':[{'row':{'buttons':[{'text':x,'additionalFields':{}} for x in row]}} for row in [['/services','/rates'],['/human','/privacy'],['/reset']]]},'replyKeyboardOptions':{'resize_keyboard':True}})
# Escape approved plain text for Telegram HTML, so customer facts cannot inject markup.
workflow(9,'Telegram Response Adapter',[schedule(3),manual(),pg('Claim Outbox','SELECT presales.claim_outbox() AS result;'),code('Delivery Job',"if(!$json.result)return []; const j=$json.result; j.payload.text=j.payload.text.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); return [{json:j}];"),send,
    code('Delivery Outcome',"const j=$('Delivery Job').first().json; return [{json:{id:j.id,lease_token:j.lease_token,result:deliveryOutcome($json)}}];",True),
    pg('Record Delivery','SELECT presales.finish_outbox($1::uuid,$2::uuid,$3::jsonb) AS result;','[$json.id,$json.lease_token,JSON.stringify($json.result)]')],
    [('Recovery Schedule','Claim Outbox'),('Run Manually','Claim Outbox'),('Claim Outbox','Delivery Job'),('Delivery Job','Send Approved Reply'),('Send Approved Reply','Delivery Outcome'),('Delivery Outcome','Record Delivery')])

# No public trigger: administrator edits through authenticated n8n or local CLI.
workflow(10,'Service Catalog Administration',[manual(),pg('Review Catalog','SELECT code,name,price_min,price_max,active FROM presales.services ORDER BY category,code;')])
workflow(11,'Analytics and Audit',[manual(),pg('Aggregate Analytics',"SELECT jsonb_build_object('inquiries',(SELECT count(*) FROM presales.messages WHERE direction='incoming'),'leads',(SELECT count(*) FROM presales.leads),'handoffs',(SELECT count(*) FROM presales.handoff_tickets),'pending_outbox',(SELECT count(*) FROM presales.outbox_jobs WHERE status IN ('pending','retry_wait')),'dead_letters',(SELECT count(*) FROM presales.dead_letter_events WHERE replay_status='pending')) AS metrics;")])
workflow(12,'Failure Retry and Replay',[manual(),pg('Review Failed Work',"SELECT id,source_type,error_message,replay_status,created_at FROM presales.dead_letter_events WHERE replay_status='pending' ORDER BY created_at;")])
print('Generated',len(list(OUT.glob('*.json'))),'inactive public-safe workflow exports')
