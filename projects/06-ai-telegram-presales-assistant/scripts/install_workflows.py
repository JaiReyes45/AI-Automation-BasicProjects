"""Bind existing encrypted credentials privately; never export credential material."""
import json,pathlib,subprocess,os,argparse
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--publish',action='store_true');p.add_argument('--publish-internal',action='store_true');a=p.parse_args()
def run(args,**kw):return subprocess.run(args,check=True,text=True,capture_output=True,**kw)
def sql(q):return run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d','presales','-At','-v','ON_ERROR_STOP=1'],input=q).stdout.strip()
run(['docker','exec','project06-presales-n8n-1','mkdir','-p','/home/node/.n8n/custom'])
run(['docker','cp',str(ROOT/'nodes/P06TelegramIntake.node.js'),'project06-presales-n8n-1:/home/node/.n8n/custom/P06TelegramIntake.node.js'])
creds=json.loads(sql("SELECT coalesce(json_agg(json_build_object('id',id,'name',name,'type',type)),'[]') FROM credentials_entity WHERE type IN ('telegramApi','postgres');"))
bindings={}
for kind in ('telegramApi','postgres'):
    rows=[r for r in creds if r['type']==kind]
    if len(rows)!=1:raise SystemExit('Select one project credential for '+kind+' before installation.')
    bindings[kind]={k:rows[0][k] for k in ('id','name')}
project=sql('SELECT "projectId" FROM shared_workflow ORDER BY "createdAt" LIMIT 1;')
if not project:raise SystemExit('No existing owner project')
private=ROOT/'.runtime';private.mkdir(exist_ok=True,mode=0o700)
items=[]
for path in sorted((ROOT/'workflows').glob('*.json')):
    w=json.loads(path.read_text())
    for n in w['nodes']:
        typ=n['type'].rsplit('.',1)[-1]
        kind='telegramApi' if typ in ('telegram','telegramTrigger','p06TelegramIntake') else 'postgres' if typ=='postgres' else None
        if kind:n['credentials']={kind:bindings[kind]}
    items.append(w)
bound=private/'bound-workflows.json';bound.write_text(json.dumps(items));os.chmod(bound,0o600)
run(['docker','cp',str(bound),'project06-presales-n8n-1:/tmp/p06-bound-workflows.json'])
result=run(['docker','exec','project06-presales-n8n-1','n8n','import:workflow','--input=/tmp/p06-bound-workflows.json','--projectId='+project])
assert 'Successfully imported' in result.stdout,'Import confirmation missing; inspect private CLI output'
(private/'install-result.log').write_text(result.stdout+result.stderr)
os.chmod(private/'install-result.log',0o600)
print('Imported 13 workflows; detailed CLI output kept privately.')
if a.publish or a.publish_internal:
    for i in (list(range(2,9))+([0,1,9] if a.publish else [])):
        run(['docker','exec','project06-presales-n8n-1','n8n','publish:workflow','--id=p06Workflow'+str(i).zfill(2)])
        print('Published workflow',str(i).zfill(2))
print('Installed',len(items),'workflows; public files contain no credential references.')
