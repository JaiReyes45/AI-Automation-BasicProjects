"""Send one explicitly labelled setup message to the privately configured owner.
Never auto-repeat: an interrupted send could have succeeded remotely.
"""
import json,pathlib,subprocess,os,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
private=ROOT/'.runtime';marker=private/'owner-test-attempted'
if marker.exists():raise SystemExit('Owner delivery test already attempted. Inspect Telegram before any manual repeat.')
items=json.loads((private/'bound-workflows.json').read_text())
pg=next(n for w in items for n in w['nodes'] if n['type']=='n8n-nodes-base.postgres').copy()
send=next(n for w in items for n in w['nodes'] if n['type']=='n8n-nodes-base.telegram').copy()
pg.update(name='Private Owner Destination',parameters={'operation':'executeQuery','query':"SELECT value #>> '{}' AS owner_chat_id FROM presales.runtime_settings WHERE key='owner_chat_id';",'options':{}})
send.update(name='Send Setup Notification')
send['parameters']['chatId']='={{ $json.owner_chat_id }}'
send['parameters']['text']='ChatterBox setup test: your human-handoff notification destination is connected. This is a technical test, not a customer lead. The assistant is ready for your /start test.'
manual={'id':str(uuid.uuid4()),'name':'Manual','type':'n8n-nodes-base.manualTrigger','typeVersion':1,'parameters':{},'position':[0,0]}
check={'id':str(uuid.uuid4()),'name':'Assert Delivery','type':'n8n-nodes-base.code','typeVersion':2,'parameters':{'jsCode':"if(!Number.isInteger($json.message_id)&&!Number.isInteger($json.result?.message_id))throw Error('Owner delivery unconfirmed; inspect Telegram before retry');return [{json:{owner_delivery_confirmed:true}}];"},'position':[600,0]}
nodes=[manual,pg,send,check]
for i,n in enumerate(nodes):n['position']=[i*240,0]
cons={a['name']:{'main':[[{'node':b['name'],'type':'main','index':0}]]} for a,b in zip(nodes,nodes[1:])}
w={'id':'p06OwnerDeliveryTest','name':'Project06 Owner Setup Test — Do Not Repeat','active':False,'nodes':nodes,'connections':cons,'settings':{'executionOrder':'v1','saveDataSuccessExecution':'none','saveDataErrorExecution':'none','saveManualExecutions':False},'pinData':{}}
path=private/'owner-delivery-test.json';path.write_text(json.dumps(w));os.chmod(path,0o600)
def run(args,**kw):return subprocess.run(args,text=True,capture_output=True,check=True,**kw)
run(['docker','cp',str(path),'project06-presales-n8n-1:/tmp/p06-owner-test.json'])
run(['docker','exec','project06-presales-n8n-1','n8n','import:workflow','--input=/tmp/p06-owner-test.json'])
with marker.open('x') as f:f.write('Send attempted; do not repeat automatically.\n')
p=subprocess.run(['docker','exec','-e','N8N_RUNNERS_ENABLED=false','-e','N8N_RUNNERS_BROKER_PORT=5689','project06-presales-n8n-1','n8n','execute','--id=p06OwnerDeliveryTest','--rawOutput'],text=True,capture_output=True)
log=private/'owner-test-result.log';log.write_text(p.stdout+p.stderr);os.chmod(log,0o600)
if '"owner_delivery_confirmed":true' not in p.stdout.replace(' ','').replace('\n',''):
    raise SystemExit('Owner setup delivery not confirmed; no automatic resend. Inspect private results and Telegram.')
print('Telegram confirmed delivery of one labelled owner setup notification.')
