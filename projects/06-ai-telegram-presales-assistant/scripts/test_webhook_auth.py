"""Reject an unauthenticated request to the actual loaded local and public intake."""
import json,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
q="""SELECT json_agg(row_to_json(w)) FROM webhook_entity w WHERE "workflowId"='p06Workflow01';"""
p=subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d','presales','-At'],input=q,text=True,capture_output=True,check=True)
rows=json.loads(p.stdout)
assert rows,'No loaded production webhook'
row=rows[0]
path='/webhook/'+row['webhookPath']
# n8n stores the path and optional dynamic webhook prefix separately.
if row.get('webhookId'):path='/webhook/'+row['webhookId']+'/'+row['webhookPath']
js=r"""(async()=>{const path=PATH;for(const [name,base]of [['local','http://127.0.0.1:5678'],['public',process.env.WEBHOOK_URL.replace(/\/$/,'')]]){const r=await fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({update_id:1}),signal:AbortSignal.timeout(15000)});console.log(name+'_unauthenticated_webhook',r.status);if(r.status!==403)process.exitCode=1;}})().catch(()=>{console.log('webhook_auth_check_failed');process.exitCode=1;});""".replace('PATH',json.dumps(path))
p=subprocess.run(['docker','exec','-i','project06-presales-n8n-1','node'],input=js,text=True,capture_output=True)
print(p.stdout);raise SystemExit(p.returncode)
