"""Create a private, consistent backup and optionally verify an isolated restore.
Run from the repository root. Never commit the generated .runtime/backups folder.
"""
import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PREFIX='project07-automated-career-opportunity-manager-'
PG=PREFIX+'postgres-1'

def run(args, **kwargs):
    result=subprocess.run(args,capture_output=True,**kwargs)
    if result.returncode:
        raise RuntimeError('Operation failed: '+args[0]+' '+args[1]+'. Raw output withheld because backups contain private data.')
    return result.stdout

def counts(database='careerflow', extra=None):
    sql="SELECT 'applications',count(*) FROM career.applications UNION ALL SELECT 'messages',count(*) FROM career.messages UNION ALL SELECT 'events',count(*) FROM career.events UNION ALL SELECT 'credentials',count(*) FROM credentials_entity UNION ALL SELECT 'workflows',count(*) FROM workflow_entity"
    if extra:
        for table in extra:
            if table not in ('tasks','audit'):
                raise ValueError('Unexpected backup table')
            sql+=" UNION ALL SELECT '"+table+"',count(*) FROM career."+table
    raw=run(['docker','exec',PG,'psql','-U','careerflow','-d',database,'-At','-F',':','-c',sql],text=True)
    return dict((key,int(value)) for key,value in (line.split(':') for line in raw.splitlines()))

def verify(folder):
    manifest=json.loads((folder/'manifest.json').read_text())
    for name,digest in manifest['sha256'].items():
        path=(folder/name).resolve()
        if not path.is_relative_to(folder.resolve()) or not path.is_file():
            raise ValueError('Invalid backup member')
        if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
            raise ValueError('Backup checksum mismatch')
    database='careerflow_restore_'+uuid.uuid4().hex
    created=False
    try:
        run(['docker','exec',PG,'psql','-U','careerflow','-d','postgres','-v','ON_ERROR_STOP=1','-c','CREATE DATABASE '+database],text=True)
        created=True
        run(['docker','exec','-i',PG,'pg_restore','-U','careerflow','--no-owner','--no-acl','--exit-on-error','-d',database],input=(folder/'postgres.dump').read_bytes())
        assert counts(database,[t for t in ('tasks','audit') if t in manifest['counts']])==manifest['counts'], 'Restored row counts differ'
        profile=folder/'profile'/'profile.sqlite'
        if profile.exists():
            with sqlite3.connect('file:'+profile.as_posix()+'?mode=ro',uri=True) as db:
                assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
                for body, in db.execute('SELECT body FROM documents'):
                    doc=json.loads(body)
                    if doc['url'].startswith('/api/files/'):
                        assert (folder/'profile'/'files'/doc['id']).is_file(), 'Missing profile document'
        return {'checksums':'passed','isolated_postgres_restore':'passed','profile_integrity':'passed','counts':manifest['counts']}
    finally:
        if created:
            # This name is generated above and exists only for this isolated check.
            run(['docker','exec',PG,'psql','-U','careerflow','-d','postgres','-v','ON_ERROR_STOP=1','-c','DROP DATABASE '+database],text=True)

def backup():
    destination=ROOT/'.runtime'/'backups'/(datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8])
    destination.mkdir(parents=True,mode=0o700)
    os.chmod(destination,0o700)
    paused=[]
    try:
        for service in ['n8n','crm','profile','engine']:
            name=PREFIX+service+'-1'
            raw=run(['docker','inspect','--format','{{.State.Running}}',name],text=True)
            if raw.strip()=='true':
                run(['docker','stop',name],text=True)
                paused.append(name)
        (destination/'postgres.dump').write_bytes(run(['docker','exec',PG,'pg_dump','-U','careerflow','-Fc','careerflow']))
        shutil.copyfile(ROOT/'.env',destination/'.env')
        for service,path,output in [('profile','/data','profile'),('n8n','/home/node/.n8n','n8n-data'),('engine','/data','synthetic-engine')]:
            run(['docker','cp',PREFIX+service+'-1:'+path,str(destination/output)],text=True)
        digests={}
        for path in destination.rglob('*'):
            if path.is_file() and not path.is_symlink():
                os.chmod(path,0o600)
                digests[path.relative_to(destination).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
        manifest=dict(created_at=datetime.now(timezone.utc).isoformat(),counts=counts(extra=['tasks','audit']),sha256=digests)
        (destination/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        os.chmod(destination/'manifest.json',0o600)
    finally:
        if paused:
            run(['docker','start',*reversed(paused)],text=True)
    return destination

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--verify',action='store_true')
    parser.add_argument('--verify-existing',type=Path)
    args=parser.parse_args()
    folder=args.verify_existing.resolve() if args.verify_existing else backup()
    result={'backup_path':str(folder)}
    if args.verify or args.verify_existing:
        result['verification']=verify(folder)
        (ROOT/'docs'/'backup-verification.json').write_text(json.dumps(result['verification'],indent=2)+'\n')
    print(json.dumps(result,indent=2))
