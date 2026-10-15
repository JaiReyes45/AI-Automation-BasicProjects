"""Check generated workflow hygiene without reading .env or decrypted credentials."""
import hashlib,json,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
files=sorted((ROOT/'workflows').glob('*.json'))
assert len(files)==13,'Expected exactly workflows 00–12'
engine=(ROOT/'runtime/engine.js').read_text().split('module.exports=')[0]
count=0
for index,path in enumerate(files):
    raw=path.read_text();w=json.loads(raw)
    assert w['id']==f'p06Workflow{index:02d}' and w['active'] is False and not w['pinData']
    assert not re.search(r'\b\d{6,12}:[A-Za-z0-9_-]{25,}|trycloudflare\.com|owner_chat_id\s*[:=]\s*\d',raw),'Possible private data in export'
    for n in w['nodes']:
        assert not n.get('credentials'),'Credential references must be privately bound'
        js=n.get('parameters',{}).get('jsCode','')
        if 'function validateExtraction' in js:assert js.startswith(engine),'Stale embedded engine';count+=1
print('Public exports verified: 13 inactive, credential-free workflows;',count,'current engine embeddings.')
print('Engine SHA256:',hashlib.sha256((ROOT/'runtime/engine.js').read_bytes()).hexdigest())
for name in ('.env','.runtime/bound-workflows.json'):
    p=subprocess.run(['git','check-ignore',str(ROOT/name)],text=True,capture_output=True)
    assert p.returncode==0,name+' is not ignored by Git'
print('Local environment and private bindings are ignored by Git. No commit or push performed.')
