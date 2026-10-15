"""One synthetic extraction through the real local model; no customer data."""
import json,pathlib,subprocess,urllib.request,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
script="const E=require('/tmp/p06-verify/runtime/engine'); console.log(JSON.stringify(E.aiRequest({state:{requirements:{}},envelope:{text:'I receive customer inquiries by email and manually copy them into HubSpot. Can you automate this, and how much would it cost?'}})));"
request=json.loads(subprocess.run(['docker','exec','project06-presales-n8n-1','node','-e',script],text=True,capture_output=True,check=True).stdout)
t=time.time()
req=urllib.request.Request('http://127.0.0.1:11436/api/generate',data=json.dumps(request).encode(),headers={'Content-Type':'application/json'})
with urllib.request.urlopen(req,timeout=150) as resp:result=json.load(resp)
raw=result.get('response','')
check="const E=require('/tmp/p06-verify/runtime/engine'); let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>{const r=E.validateExtraction(s);console.log(JSON.stringify(r)); if(!r.valid)process.exit(1);});"
p=subprocess.run(['docker','exec','-i','project06-presales-n8n-1','node','-e',check],input=raw,text=True,capture_output=True)
print('elapsed_seconds',round(time.time()-t,1));print(p.stdout)
if p.returncode:raise SystemExit('Model schema failed')
v=json.loads(p.stdout)['value']
assert v['category']=='crm_automation',v
assert v['handoff_reason']=='none','Ordinary discovery should not require human escalation'
assert 'HubSpot' in v['applications'],'Named application must be extracted'
private=ROOT/'.runtime';private.mkdir(exist_ok=True,mode=0o700)
(private/'synthetic-extraction.json').write_text(json.dumps(v,indent=2))
print('Live Ollama synthetic CRM extraction passed')
