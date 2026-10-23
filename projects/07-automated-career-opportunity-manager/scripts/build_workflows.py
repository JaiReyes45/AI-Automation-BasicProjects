"""Generate inactive, secret-free n8n workflows for the local synthetic sprint."""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'workflows'
CREDENTIAL = {'httpHeaderAuth': {'id': 'project07EngineHeader', 'name': 'Project 07 local engine'}}

def node(name, kind, parameters, x, **extra):
    return dict(id=name.lower().replace(' ', '-'), name=name, type='n8n-nodes-base.'+kind,
                typeVersion={'manualTrigger':1,'code':2,'httpRequest':4.2,'stopAndError':1,'stickyNote':1}[kind],
                position=[x,300], parameters=parameters, **extra)

def code(name, source, x): return node(name,'code',{'jsCode':source},x)
def http(name, endpoint, body, x):
    return node(name,'httpRequest',dict(method='POST',url='http://engine:8765/'+endpoint,
        authentication='genericCredentialType',genericAuthType='httpHeaderAuth',
        sendBody=True,specifyBody='json',jsonBody=body,options={'timeout':15000}),x,
        credentials=CREDENTIAL,retryOnFail=True,maxTries=3,waitBetweenTries=1000,
        onError='continueErrorOutput')

def save(id, name, nodes, filename):
    failure=node('Inspect failure and retry','stopAndError',{'errorMessage':'Workflow stopped. Inspect the failed HTTP node. Fix its input or service health, then retry; message IDs prevent duplicate records.'},600)
    failure['position']=[600,560]
    links={}
    for a,b in zip(nodes,nodes[1:]): links[a['name']]={'main':[[{'node':b['name'],'type':'main','index':0}]]}
    for a in nodes:
        if a['type'].endswith('httpRequest'):
            links.setdefault(a['name'],{'main':[[]]})['main'].append([{'node':failure['name'],'type':'main','index':0}])
    note=node('Read before running','stickyNote',{'content':'## Project 07 — synthetic mailbox only\nNo Gmail access. HTTP steps call a private Docker service. Application state and label jobs are durable. Workflows stay inactive; use Execute workflow. Live OAuth and Gmail labels are D3.2.','height':180,'width':650},0)
    note['position']=[0,0]
    data=dict(id=id,name=name,active=False,nodes=nodes+[failure,note],connections=links,
              settings={'executionOrder':'v1','saveDataErrorExecution':'all','saveDataSuccessExecution':'all'},pinData={})
    (OUT/filename).write_text(json.dumps(data,indent=2)+'\n')

fixture="""const run = Date.now().toString();
return [{json:{account:'demo@example.test', id:'demo-'+run, thread_id:'thread-'+run,
received_at:new Date().toISOString(),
body:'Company: Example Labs\\nRole: QA Engineer Intern\\nReference: APP-'+run+'\\nWe have received your application.'}}];"""
manual=lambda:node('Execute manually','manualTrigger',{},0)
save('project07Intake','Project 07 · 01 Synthetic email intake',[
    manual(),code('Synthetic email',fixture,240),http('Classify match and save','ingest','={{ JSON.stringify($json) }}',480),
    code('Review result',"return $input.all().map(i=>({json:{...i.json,next_step:['create','update'].includes(i.json.action)?'Run label delivery':'Inspect review reason before changing an application'}}));",720)
], '01-synthetic-intake.json')
save('project07Delivery','Project 07 · 02 Simulated label delivery',[
    manual(),http('Deliver pending label jobs','deliver','{}',240),
    code('Verify delivery',"if (($json.outbox.failed || 0) + ($json.outbox.dead || 0) > 0) throw new Error('Label delivery needs attention. Retry transient failed jobs; inspect dead jobs.'); return [{json:$json}];",480)
], '02-simulated-label-delivery.json')
save('project07Scenario','Project 07 · 03 End-to-end duplicate and recovery test',[
    manual(),code('Synthetic email',fixture,220),
    http('Save submission','ingest','={{ JSON.stringify($json) }}',440),
    http('Replay same email','ingest',"={{ JSON.stringify($('Synthetic email').first().json) }}",660),
    code('Verify duplicate',"if (!$json.duplicate || $json.application_id !== $('Save submission').first().json.application_id) throw new Error('Duplicate invariant failed'); return [{json:$json}];",880),
    http('Receive interview','ingest',"={{ JSON.stringify({...$('Synthetic email').first().json,id:$('Synthetic email').first().json.id+'-interview',received_at:new Date(Date.now()+1000).toISOString(),body:'We invite you to an interview.'}) }}",1100),
    code('Verify advancement',"if ($json.action !== 'update' || $json.classification.stage !== 'interview') throw new Error('Interview advancement failed'); return [{json:$json}];",1320),
    http('Simulate mailbox outage','deliver','{"inject_failure":true}',1540),
    code('Verify visible failure',"if ($json.failed !== 1) throw new Error('Fault injection was not observed'); return [{json:$json}];",1760),
    http('Retry delivery','deliver','{}',1980),
    code('Passed',"if (($json.outbox.failed||0)+($json.outbox.dead||0)>0) throw new Error('Recovery failed'); return [{json:{result:'PASS',duplicate_verified:true,interview_verified:true,recovery_verified:true,gmail_connected:false,status:$json}}];",2200)
], '03-controlled-scenario.json')
save('project07ExpectedFailure','Project 07 · 04 Expected invalid-input failure',[
    manual(),http('Reject malformed email','ingest','{"account":"demo@example.test"}',240)
], '04-expected-failure.json')
print('Generated four inactive, synthetic workflows.')
