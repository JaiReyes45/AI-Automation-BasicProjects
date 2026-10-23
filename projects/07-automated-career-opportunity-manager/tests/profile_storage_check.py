import importlib.util, tempfile, threading, json, urllib.request, urllib.error, base64
from pathlib import Path
from http.server import HTTPServer
spec=importlib.util.spec_from_file_location('profile_server','profile_service/server.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as tmp:
 m.ROOT=Path(tmp)
 server=HTTPServer(('127.0.0.1',0),m.Handler)
 threading.Thread(target=server.serve_forever,daemon=True).start()
 base='http://127.0.0.1:'+str(server.server_port)
 def req(path,body=None,auth=True):
  headers={'X-CareerFlow':'local-profile'} if auth else {}
  try:
   with urllib.request.urlopen(urllib.request.Request(base+path,data=json.dumps(body).encode() if body is not None else None,headers=headers)) as r:return r.status,r.read()
  except urllib.error.HTTPError as e:return e.code,e.read()
 assert req('/api/profile',{'name':'Synthetic Student'})[0]==200
 assert json.loads(req('/api/profile')[1])['profile']['name']=='Synthetic Student'
 assert req('/api/profile',{'name':'bad'},False)[0]==403
 assert req('/api/profile',{'github':'javascript:alert(1)'})[0]==400
 assert req('/api/documents',{'category':'Resume','name':'resume.pdf','content':base64.b64encode(b'%PDF-1.4 synthetic').decode()})[0]==200
 data=json.loads(req('/api/profile')[1]);url=data['documents'][0]['url']
 assert req(url)[1]==b'%PDF-1.4 synthetic'
 assert req('/api/documents',{'category':'Consent','url':'https://drive.google.com/example'})[0]==200
 assert req('/api/documents',{'category':'Resume','name':'script.html','content':'eA=='})[0]==400
 server.shutdown();server.server_close()
 server=HTTPServer(('127.0.0.1',0),m.Handler);threading.Thread(target=server.serve_forever,daemon=True).start();base='http://127.0.0.1:'+str(server.server_port)
 assert len(json.loads(req('/api/profile')[1])['documents'])==2
 server.shutdown();server.server_close()
 print('PASS: save/load, no-header rejection, unsafe links, upload/download, Drive link, forbidden extension, server restart persistence')
