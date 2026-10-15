"""Synthetic n8n integration: real subworkflows, no Telegram send or live customer writes."""
import json,pathlib,subprocess,sys,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
case=sys.argv[1] if len(sys.argv)>1 else 'command'
assert case in ('command','estimate','model','memory','inventory','notebook','restaurant','transport','healthcare_admin')
def run(args,**kw):return subprocess.run(args,text=True,capture_output=True,check=True,**kw)
catalog=json.loads((ROOT/'.runtime/test-catalog.json').read_text())
context={'update_id':900000001,'envelope':{'text':'/start','message_type':'text'},'state':{'requirements':{}},'catalog':catalog}
if case=='estimate':
    context['envelope']['text']='/confirm'
    context['state'].update(pending_estimate=True,requirements={'business_problem':'Copy email orders into a sheet','category':'workflow_automation','applications':['Gmail','Sheets'],'workflow_complexity':'basic','volume':20,'ai':False,'custom_api':False,'database':False,'handoff':False,'reporting':False,'timeline_days':14})
elif case=='model':context['envelope']['text']='I receive customer inquiries by email and manually copy them into HubSpot. Can you automate this, and how much would it cost?'
elif case=='inventory':context['envelope']['text']="I have a local sari-sari store business, and I am tired of manually writing and updating my inventory."
elif case=='restaurant':context['envelope']['text']='i would like to automate the number of customers ordering at my local restaurant, because I manually count or list every customer and food they order'
elif case in ('transport','healthcare_admin'):
    context['envelope']['text']='i dont use any apps yet, just with my pen and notebook'
    context['state']={'requirements':{'business_problem':'Track vehicle maintenance' if case=='transport' else 'Track clinic office supply usage','category':'workflow_automation'},'pending_field':'applications'}
elif case=='notebook':
    context['envelope']['text']='notebook'
    context['state']={'requirements':{'business_problem':'Manually writing and updating store inventory','category':'workflow_automation'},'pending_field':'inventory_method','last_question':'How do you currently record your inventory—in a notebook, Excel or Google Sheets, or another app?'}
nodes=[{'id':str(uuid.uuid4()),'name':'Manual','type':'n8n-nodes-base.manualTrigger','typeVersion':1,'parameters':{},'position':[0,0]},
 {'id':str(uuid.uuid4()),'name':'Synthetic Context','type':'n8n-nodes-base.code','typeVersion':2,'parameters':{'jsCode':'return [{json:'+json.dumps(context)+'}];'},'position':[200,0]}]
if case=='memory':
    # Exercise the installed extraction code with deterministic model output.
    # No real AI request, customer writes or Telegram delivery in this probe.
    q="SELECT nodes::text FROM workflow_entity WHERE id='p06Workflow03';"
    installed=json.loads(run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d','presales','-At','-v','ON_ERROR_STOP=1'],input=q).stdout)
    code=next(n['parameters']['jsCode'] for n in installed if n['name']=='Validate Facts')
    assert "const c=$('Prepare AI').first().json;" in code
    setup="""const c=$json;
c.envelope.text='about 100';
c.state={requirements:{business_problem:'Copy orders into a sheet',category:'workflow_automation',applications:['gmail','sheets'],workflow_complexity:'basic'},last_question:'Approximately how many inquiries or items are processed per day?'};
const defaults={intent:'discovery',category:'crm_automation',crm_operation:'unknown',workflow_complexity:'unknown',volume:100,sensitive:false,conflict:false,handoff_reason:'none',missing_information:[],confidence:0.9};
$json.response=Object.fromEntries(Object.keys(extractionSchema.properties).map(k=>[k,defaults[k]??null]));"""
    code=code.replace("const c=$('Prepare AI').first().json;",setup)
    nodes.append({'id':str(uuid.uuid4()),'name':'Installed Extraction Regression','type':'n8n-nodes-base.code','typeVersion':2,'parameters':{'jsCode':code},'position':[400,0]})
for i in range(4 if case=='memory' else 3,9):
    w=json.loads(next((ROOT/'workflows').glob(f'{i:02d}-*.json')).read_text())
    nodes.append({'id':str(uuid.uuid4()),'name':f'Test {i:02d}','type':'n8n-nodes-base.executeWorkflow','typeVersion':1.3,'parameters':{'workflowId':{'__rl':True,'value':w['id'],'mode':'id'},'workflowInputs':{'mappingMode':'passThrough','value':{}},'options':{'waitForSubWorkflow':True}},'position':[i*200,0]})
if case in ('restaurant','transport','healthcare_admin'):
    # Replay a full conversation through installed workflows, carrying state
    # between turns. Only the initial request and named platform use real AI.
    calls=json.loads(json.dumps(nodes[2:]))
    turns=[(2,'applications','i dont use any apps yet, just with my pen and notebook'),(3,'order_entry_mode','enter orders myself'),(4,'target_platform','Google Sheets')] if case=='restaurant' else [(2,'manual_outcome','Prepare a daily summary'),(3,'target_platform','Google Sheets')]
    for turn,field,answer in turns:
        js="if($json.decision.handoff||$json.state.pending_field!=="+json.dumps(field)+")throw Error('restaurant turn "+str(turn)+" did not advance');$json.envelope.text="+json.dumps(answer)+";return [{json:$json}];"
        nodes.append({'id':str(uuid.uuid4()),'name':f'Prepare Restaurant Turn {turn}','type':'n8n-nodes-base.code','typeVersion':2,'parameters':{'jsCode':js},'position':[turn*1800,0]})
        for original in calls:
            n=json.loads(json.dumps(original));n['id']=str(uuid.uuid4());n['name']+=f' Turn {turn}';nodes.append(n)
checks={'command':"if(!$json.decision.response.includes('ChatterBox'))throw Error('start failed');",
 'transport':"if($json.decision.handoff||!$json.state.requirements.expected_result||!$json.state.requirements.applications.includes('sheets')||['applications','manual_outcome','target_platform'].includes($json.state.pending_field))throw Error('transport progression failed');",
 'healthcare_admin':"if($json.decision.handoff||!$json.state.requirements.expected_result||!$json.state.requirements.applications.includes('sheets')||['applications','manual_outcome','target_platform'].includes($json.state.pending_field))throw Error('healthcare admin progression failed');",
 'restaurant':"const r=$json.state.requirements;if($json.decision.handoff||r.order_entry_mode!=='staff_entry'||!r.applications.includes('sheets')||!r.business_problem||['applications','order_entry_mode','target_platform'].includes($json.state.pending_field))throw Error('restaurant end-to-end failed');",
 'inventory':"if($json.state.pending_field!=='inventory_method'||$json.decision.handoff)throw Error('inventory question failed');",
 'notebook':"if($json.state.pending_field!=='inventory_target'||$json.state.inventory_recording_method!=='manual'||$json.decision.handoff)throw Error('notebook progression failed');",
 'estimate':"if($json.decision.estimate?.total_min!==6000||$json.decision.estimate?.total_max!==12000)throw Error('estimate failed');",
 'model':"if($json.decision.event_type!=='discovery_question'||$json.decision.handoff)throw Error('model discovery failed');",
 'memory':"const r=$json.state.requirements;if(r.business_problem!=='Copy orders into a sheet'||r.volume!==100||r.category!=='crm_automation'||JSON.stringify(r.applications)!=='[\"gmail\",\"sheets\"]'||$json.decision.response==='What manual task would you like to automate?')throw Error('memory regression');"}
nodes.append({'id':str(uuid.uuid4()),'name':'Assert Synthetic Result','type':'n8n-nodes-base.code','typeVersion':2,'parameters':{'jsCode':checks[case]+"return [{json:{smoke_passed:true,case:"+json.dumps(case)+"}}];"},'position':[1800,0]})
cons={a['name']:{'main':[[{'node':b['name'],'type':'main','index':0}]]} for a,b in zip(nodes,nodes[1:])}
w={'id':'p06SmokeValidation','name':'Project06 Synthetic Integration Check','active':False,'nodes':nodes,'connections':cons,'settings':{'executionOrder':'v1','saveDataSuccessExecution':'none','saveDataErrorExecution':'none','saveManualExecutions':False},'pinData':{}}
path=ROOT/'.runtime/smoke-workflow.json';path.write_text(json.dumps(w))
run(['docker','cp',str(path),'project06-presales-n8n-1:/tmp/p06-smoke.json'])
run(['docker','exec','project06-presales-n8n-1','n8n','import:workflow','--input=/tmp/p06-smoke.json'])
p=subprocess.run(['docker','exec','-e','N8N_RUNNERS_ENABLED=false','-e','N8N_RUNNERS_BROKER_PORT=5689','-e','N8N_DIAGNOSTICS_ENABLED=false','project06-presales-n8n-1','n8n','execute','--id=p06SmokeValidation','--rawOutput'],text=True,capture_output=True)
# Save only synthetic output privately; successful final assertion is mandatory.
(ROOT/'.runtime'/('smoke-'+case+'.log')).write_text(p.stdout+p.stderr)
if '"smoke_passed":true' not in p.stdout.replace(' ','').replace('\n',''):
    print((p.stdout+p.stderr)[-3000:]);raise SystemExit('n8n synthetic integration failed')
print('n8n real subworkflow integration passed:',case)
