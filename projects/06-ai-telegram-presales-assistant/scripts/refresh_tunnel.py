"""Refresh an existing local demo's temporary webhook base without exposing it."""
import argparse,os,pathlib,re,subprocess,urllib.request,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(args):
    p=subprocess.run(args,text=True,capture_output=True)
    if p.returncode:raise SystemExit('Operation failed: '+args[0]+' (details withheld to protect private configuration)')
    return p.stdout
def main():
    p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
    text=pathlib.Path(a.log).read_text(errors='replace')
    urls=re.findall(r'https://[a-z0-9-]+\.trycloudflare\.com',text)
    if not urls:raise SystemExit('Tunnel not ready: no generated HTTPS address in log.')
    url=urls[-1]+'/'
    for attempt in range(20):
        try:
            with urllib.request.urlopen(url+'healthz',timeout=8) as r:
                if r.status==200:break
        except Exception:pass
        time.sleep(1)
    else:raise SystemExit('Public health check failed; existing configuration was not changed.')
    env=ROOT/'.env';old=env.read_text()
    assert 'N8N_ENCRYPTION_KEY=' in old and 'POSTGRES_PASSWORD=' in old
    lines=[line for line in old.splitlines() if not line.startswith('WEBHOOK_URL=')]
    lines.append('WEBHOOK_URL='+url)
    backup=ROOT/'.runtime'/'before-tunnel-refresh.env'
    backup.parent.mkdir(exist_ok=True,mode=0o700)
    backup.write_text(old);os.chmod(backup,0o600)
    env.write_text('\n'.join(lines)+'\n');os.chmod(env,0o600)
    cmd=['docker','compose','--project-directory',str(ROOT)]
    run(cmd+['config','--quiet'])
    run(cmd+['up','-d','--no-deps','n8n'])
    for attempt in range(45):
        try:
            with urllib.request.urlopen('http://127.0.0.1:5686/healthz',timeout=2) as r:
                if r.status==200:break
        except Exception:pass
        time.sleep(1)
    else:raise SystemExit('n8n did not become healthy; private configuration backup retained.')
    print('Temporary HTTPS address refreshed; n8n recreated with existing credentials and volumes preserved.')
if __name__=='__main__':main()
