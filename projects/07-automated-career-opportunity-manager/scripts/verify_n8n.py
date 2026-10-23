"""Run imported workflows and retain only synthetic verification summaries."""
import json
import subprocess
from pathlib import Path

CONTAINER='project07-automated-career-opportunity-manager-n8n-1'

def execute(id, expected_success):
    result=subprocess.run(['docker','exec','-e','N8N_RUNNERS_BROKER_PORT=5680',CONTAINER,'n8n','execute','--id='+id,'--rawOutput'],capture_output=True,text=True)
    output=result.stdout
    start=output.find('{\n  "data"')
    if start < 0: raise RuntimeError('No structured execution result for '+id+': '+result.stderr[-300:])
    execution=json.JSONDecoder().raw_decode(output[start:])[0]
    status=execution.get('status')
    if (status == 'success') != expected_success: raise RuntimeError(f'{id}: unexpected status {status}')
    run=execution['data']['resultData']
    summary={'workflow':id,'status':status,'last_node':run.get('lastNodeExecuted')}
    if id=='project07Scenario':
        payload=run['runData']['Passed'][0]['data']['main'][0][0]['json']
        assert payload['result']=='PASS'
        summary['checks']={k:v for k,v in payload.items() if k!='status'}
    return summary

def main():
    summaries=[execute('project07Intake',True),execute('project07Delivery',True),
               execute('project07Scenario',True),execute('project07ExpectedFailure',False)]
    target=Path(__file__).resolve().parents[1]/'docs'/'n8n-verification.json'
    target.write_text(json.dumps(summaries,indent=2)+'\n')
    print(json.dumps(summaries,indent=2))

if __name__=='__main__': main()
