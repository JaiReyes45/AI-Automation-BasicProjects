"""Admin create/update/approval validation using a disposable database only."""
import json,pathlib,subprocess,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
DB='p06_verify_20261014';key='admin_fixture_'+uuid.uuid4().hex
def sql(q):
    return subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d',DB,'-At','-v','ON_ERROR_STOP=1'],input=q,text=True,capture_output=True,check=True).stdout.strip()
path=ROOT/'.runtime/admin-fixture.json'
assert sql("SELECT count(*) FROM presales.business_policies WHERE code='"+key+"';")=='0'
try:
    for fields in ({'policy_text':'Synthetic admin test','policy_value':{'enabled':False},'approved':False},{'approved':True,'active':False}):
        path.write_text(json.dumps({'table':'business_policies','key':key,'fields':fields}))
        p=subprocess.run(['python3',str(ROOT/'scripts/admin.py'),'upsert','--database',DB,'--file',str(path)],text=True,capture_output=True)
        assert p.returncode==0,p.stderr
    assert sql("SELECT approved AND NOT active FROM presales.business_policies WHERE code='"+key+"';")=='t'
    assert sql("SELECT count(*) FROM presales.audit_events WHERE metadata->>'key'='"+key+"';")=='2'
    path.write_text(json.dumps({'table':'business_policies','key':key,'fields':{'unsafe_column':'reject'}}))
    p=subprocess.run(['python3',str(ROOT/'scripts/admin.py'),'upsert','--database',DB,'--file',str(path)],text=True,capture_output=True)
    assert p.returncode!=0
    print('Disposable-database admin create/update/approve/deactivate/audit and invalid-field rejection passed.')
finally:
    # Only this run's unique synthetic records; never existing catalog entries.
    sql("BEGIN; DELETE FROM presales.audit_events WHERE metadata->>'key'='"+key+"'; DELETE FROM presales.business_policies WHERE code='"+key+"'; COMMIT;")
