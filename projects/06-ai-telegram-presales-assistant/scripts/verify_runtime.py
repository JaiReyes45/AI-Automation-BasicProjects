"""Checks on a clean disposable database plus live read-only catalog export."""
import json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
DB=sys.argv[1] if len(sys.argv)>1 else 'presales'
def run(args,**kw):return subprocess.run(args,check=True,text=True,capture_output=True,**kw)
def sql(q,db=DB):
    return run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d',db,'-At','-v','ON_ERROR_STOP=1'],input=q).stdout.strip()
catalog=sql("SELECT json_build_object('services',(SELECT json_agg(t) FROM presales.services t WHERE active AND approved),'packages',(SELECT json_agg(t) FROM presales.service_packages t WHERE active AND approved),'adjustments',(SELECT json_agg(t) FROM presales.pricing_adjustments t WHERE active AND approved),'policies',(SELECT json_agg(t) FROM presales.business_policies t WHERE active AND approved),'faqs',(SELECT json_agg(t) FROM presales.faqs t WHERE active AND approved));")
private=ROOT/'.runtime';private.mkdir(mode=0o700,exist_ok=True)
(private/'test-catalog.json').write_text(catalog)
run(['docker','cp',str(private/'test-catalog.json'),'project06-presales-n8n-1:/tmp/p06-test-catalog.json'])
# Copy exact files to avoid docker cp nesting directories on repeated runs.
run(['docker','exec','project06-presales-n8n-1','mkdir','-p','/tmp/p06-verify/runtime','/tmp/p06-verify/tests','/tmp/p06-verify/nodes'])
run(['docker','cp',str(ROOT/'runtime/engine.js'),'project06-presales-n8n-1:/tmp/p06-verify/runtime/engine.js'])
run(['docker','cp',str(ROOT/'tests/engine.test.js'),'project06-presales-n8n-1:/tmp/p06-verify/tests/engine.test.js'])
run(['docker','cp',str(ROOT/'tests/intake.test.js'),'project06-presales-n8n-1:/tmp/p06-verify/tests/intake.test.js'])
run(['docker','cp',str(ROOT/'nodes/P06TelegramIntake.node.js'),'project06-presales-n8n-1:/tmp/p06-verify/nodes/P06TelegramIntake.node.js'])
p=subprocess.run(['docker','exec','project06-presales-n8n-1','node','--test','/tmp/p06-verify/tests/engine.test.js','/tmp/p06-verify/tests/intake.test.js'],text=True,capture_output=True)
print(p.stdout);print(p.stderr);sys.exit(p.returncode)
