"""Exercise n8n's lastNode HTTP contract with delayed/failed PostgreSQL work.
This temporary native webhook neither changes Telegram registration nor writes customer data.
Custom Telegram authentication is tested separately. Always unpublish the probe afterward.
"""
import json,pathlib,subprocess,time,uuid,urllib.request,urllib.error
ROOT=pathlib.Path(__file__).resolve().parents[1]
private=ROOT/'.runtime'
def run(args):return subprocess.run(args,text=True,capture_output=True,check=True)
items=json.loads((private/'bound-workflows.json').read_text())
pg=next(n for w in items for n in w['nodes'] if n['type']=='n8n-nodes-base.postgres').copy()
path='p06-ack-probe-'+uuid.uuid4().hex
pg.update(name='Delayed Database Check',parameters={'operation':'executeQuery','query':'SELECT pg_sleep(1), 1 / $1::integer AS database_marker;','options':{'queryReplacement':'={{ [$json.body.fail === true ? 0 : 1] }}'}})
webhook={'id':str(uuid.uuid4()),'webhookId':str(uuid.uuid4()),'name':'Temporary HTTP Probe','type':'n8n-nodes-base.webhook','typeVersion':2.1,'parameters':{'httpMethod':'POST','path':path,'responseMode':'lastNode','options':{}},'position':[0,0]}
pg['position']=[240,0]
last={'id':str(uuid.uuid4()),'name':'After Database','type':'n8n-nodes-base.code','typeVersion':2,'position':[480,0],'parameters':{'jsCode':'return [{json:{database_step_completed:true}}];'}}
nodes=[webhook,pg,last]
w={'id':'p06AckContractTest','name':'Project06 HTTP ACK Contract Test — Inactive After Verification','active':False,'nodes':nodes,'connections':{a['name']:{'main':[[{'node':b['name'],'type':'main','index':0}]]} for a,b in zip(nodes,nodes[1:])},'settings':{'executionOrder':'v1','saveDataSuccessExecution':'none','saveDataErrorExecution':'none','saveManualExecutions':False},'pinData':{}}
file=private/'ack-contract-workflow.json';file.write_text(json.dumps(w))
def restart():
    run(['docker','restart','project06-presales-n8n-1'])
    for _ in range(45):
        try:
            with urllib.request.urlopen('http://127.0.0.1:5686/healthz',timeout=2) as r:
                if r.status==200:return
        except (OSError,urllib.error.URLError):pass
        time.sleep(1)
    raise RuntimeError('n8n did not become healthy')
run(['docker','cp',str(file),'project06-presales-n8n-1:/tmp/p06-ack-test.json'])
run(['docker','exec','project06-presales-n8n-1','n8n','import:workflow','--input=/tmp/p06-ack-test.json'])
try:
    run(['docker','exec','project06-presales-n8n-1','n8n','publish:workflow','--id=p06AckContractTest'])
    restart();time.sleep(2)
    results=[]
    for fail in (False,True):
        req=urllib.request.Request('http://127.0.0.1:5686/webhook/'+path,data=json.dumps({'fail':fail}).encode(),headers={'Content-Type':'application/json'})
        for attempt in range(30):
            start=time.monotonic()
            try:
                with urllib.request.urlopen(req,timeout=20) as r:status=r.status;body=json.load(r)
            except urllib.error.HTTPError as e:status=e.code;body={}
            if status!=404:break
            time.sleep(1) # Health endpoint becomes ready before workflow activation finishes.
        elapsed=time.monotonic()-start
        if fail:assert status>=500,('Database failure was acknowledged',status)
        else:assert status==200 and elapsed>=0.9 and body.get('database_step_completed') is True,(status,elapsed,body)
        results.append({'database_failure':fail,'http_status':status,'elapsed_seconds':round(elapsed,2)})
    (private/'ack-contract-result.json').write_text(json.dumps(results,indent=2))
    print('Native lastNode PostgreSQL delay/failure HTTP tests passed:',json.dumps(results))
finally:
    run(['docker','exec','project06-presales-n8n-1','n8n','unpublish:workflow','--id=p06AckContractTest'])
    restart()
    print('Temporary ACK probe unpublished; normal workflows restored.')
