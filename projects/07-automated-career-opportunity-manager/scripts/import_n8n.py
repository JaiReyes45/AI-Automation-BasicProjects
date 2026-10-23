"""Import Project 07's inactive workflows and local service credential. Run from repo root."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONTAINER = 'project07-automated-career-opportunity-manager-n8n-1'

def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def main():
    config = dict(line.split('=', 1) for line in (ROOT/'.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
    token = config['CAREERFLOW_WORKFLOW_TOKEN']
    if len(token) < 24 or token.startswith('replace-'): raise SystemExit('Configure the local service token first.')
    credential = [{'id':'project07EngineHeader','name':'Project 07 local engine','type':'httpHeaderAuth',
                   'data':{'name':'Authorization','value':'Bearer '+token}}]
    temporary = '/tmp/project07-credential.json'
    writer = "let s='';process.stdin.on('data',d=>s+=d);process.stdin.on('end',()=>require('fs').writeFileSync(process.argv[1],s,{mode:0o600}));"
    try:
        run(['docker','exec','-i',CONTAINER,'node','-e',writer,temporary],input=json.dumps(credential),text=True)
        run(['docker','exec',CONTAINER,'n8n','import:credentials','--input='+temporary])
    finally:
        run(['docker','exec',CONTAINER,'node','-e',"require('fs').rmSync(process.argv[1],{force:true})",temporary])
    run(['docker','exec',CONTAINER,'n8n','import:workflow','--separate','--input=/projects/07-automated-career-opportunity-manager/workflows'])

if __name__ == '__main__': main()
