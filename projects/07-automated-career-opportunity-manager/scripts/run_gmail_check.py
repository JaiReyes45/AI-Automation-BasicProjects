"""Execute a Project 07 live check; only aggregate evidence leaves process memory."""
import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

IDS = {'labels':'project07GmailLabels', 'intake':'project07GmailSync', 'reconcile':'project07GmailReconcile', 'calendar':'project07Calendar'}
parser=argparse.ArgumentParser()
parser.add_argument('--workflow', choices=IDS, default='intake')
args=parser.parse_args()
r=subprocess.run(['docker','exec','-e','N8N_RUNNERS_BROKER_PORT=5680',
    'project07-automated-career-opportunity-manager-n8n-1','n8n','execute','--id='+IDS[args.workflow],'--rawOutput'],
    capture_output=True,text=True,timeout=300)
start=r.stdout.find('{\n  "data"')
if start<0:
    raise SystemExit('No structured result. Raw output withheld; inspect local n8n.')
x=json.JSONDecoder().raw_decode(r.stdout[start:])[0]
result=x['data']['resultData']
runs=result.get('runData',{})
summary={'checked_at':datetime.now(timezone.utc).isoformat(),'status':x.get('status'),
         'last_node':result.get('lastNodeExecuted'),'counts':{},'actions':{}}
for name in ['Fetch mailbox page','Message IDs','Store in CRM','Label jobs','Record delivery','Create label','Meeting jobs','Record meeting outcome']:
    summary['counts'][name]=sum(len(items) for run in runs.get(name,[]) for items in run.get('data',{}).get('main',[]) if items)
for run in runs.get('Store in CRM',[]):
    for items in run.get('data',{}).get('main',[]):
        for item in items or []:
            payload=item.get('json',{})
            action=payload.get('body',payload).get('action','unknown')
            summary['actions'][action]=summary['actions'].get(action,0)+1
for name in ['Verify delivery','Select unprocessed']:
    for run in runs.get(name,[]):
        for items in run.get('data',{}).get('main',[]):
            for item in items or []:
                data=item.get('json',{})
                if name=='Select unprocessed':
                    summary['matched_messages']=data.get('matched')
                else:
                    category='verified' if data.get('verified') else data.get('error','unverified')
                    summary[category]=summary.get(category,0)+1
if result.get('error'):
    summary['error_type']=result['error'].get('name','unknown')
for name in ['Finish mailbox page','Record mailbox failure']:
    for run in runs.get(name,[]):
        for items in run.get('data',{}).get('main',[]):
            for item in items or []:
                data=item.get('json',{})
                summary['capture']={k:data.get(k) for k in ['complete','processed','reason']}
                summary['coverage']={k:data.get('coverage',{}).get(k) for k in ['status','complete_from','complete_through','last_error']}
path=Path(__file__).resolve().parents[1]/'docs/d3-sync-verification.json'
report=json.loads(path.read_text()) if path.exists() else {}
if args.workflow in report:
    history=report.setdefault('previous_runs',[])
    history.append(dict(report[args.workflow],workflow=args.workflow))
    report['previous_runs']=history[-8:]
report[args.workflow]=summary
path.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(summary))
if x.get('status')!='success':
    raise SystemExit('Workflow failed; raw mail data withheld.')
