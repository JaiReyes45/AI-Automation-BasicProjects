"""Read aggregate local sync health; never export accounts, messages or credentials."""
import json
import subprocess
from pathlib import Path

code = """
import json
from datetime import datetime,timezone
from crm.server import connect
with connect() as db:
 connection=db.execute('SELECT data FROM career.connection WHERE id=1').fetchone()
 data=connection[0] if connection else {}
 report={k:data.get(k) for k in ['last_checked','last_sync_completed','last_sync_processed','last_label_check']}
 report['checked_at']=datetime.now(timezone.utc).isoformat()
 report['applications']=db.execute('SELECT count(*) FROM career.applications').fetchone()[0]
 report['eligible_jobs']={s:n for s,n in db.execute('SELECT state,count(*) FROM career.label_jobs WHERE eligible GROUP BY state')}
 report['legacy_excluded']=db.execute('SELECT count(*) FROM career.label_jobs WHERE NOT eligible').fetchone()[0]
 report['review_messages']=db.execute("SELECT count(*) FROM career.messages m JOIN career.label_jobs j ON m.account=j.account AND m.id=j.message_id WHERE j.eligible AND NOT (m.result ? 'resolution') AND m.result->>'action' NOT IN ('create','update','opportunity_only')").fetchone()[0]
 report['workflows']=[dict(id=i,active=a) for i,a in db.execute("SELECT id,active FROM workflow_entity WHERE id IN ('project07GmailSync','project07GmailReconcile')")]
 report['scheduled_executions']=[dict(workflow=w,status=s if d is None else 'not_retained',mode=m,started=str(t),payload_retained=d is None) for w,s,m,t,d in db.execute('SELECT "workflowId",status,mode,"startedAt","deletedAt" FROM execution_entity WHERE "workflowId" IN (%s,%s) AND mode=%s ORDER BY id DESC LIMIT 4',('project07GmailSync','project07GmailReconcile','trigger'))]
 print(json.dumps(report))
"""
r=subprocess.run(['docker','exec','project07-automated-career-opportunity-manager-crm-1','python','-c',code],capture_output=True,text=True,check=False)
if r.returncode:
    raise SystemExit('Status unavailable; check local containers. Raw output withheld.')
report=json.loads(r.stdout)
Path(__file__).resolve().parents[1].joinpath('docs/d3-scheduled-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
