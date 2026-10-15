"""Print structural metadata only; never credentials or customer message content."""
import json, subprocess

def query(sql):
    p = subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d','presales','-At','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True,check=True)
    return p.stdout.strip()

rows=json.loads(query("SELECT coalesce(json_agg(json_build_object('id',id,'name',name,'active',active,'nodes',nodes,'connections',connections)),'[]') FROM workflow_entity;"))
for w in rows:
    for n in w['nodes']:
        p=n.get('parameters',{})
        n.clear() if False else None
        for k in list(n):
            if k not in ('name','type','typeVersion','parameters','credentials'): del n[k]
        n['parameters']={k:v for k,v in p.items() if k in ('operation','query','options','jsCode','mode','updates','chatId','text')}
    print(json.dumps(w,ensure_ascii=True))
print('counts',query("SELECT json_build_object('customers',(SELECT count(*) FROM presales.customers),'messages',(SELECT count(*) FROM presales.messages),'conversations',(SELECT count(*) FROM presales.conversations),'audit',(SELECT count(*) FROM presales.audit_events));"))
