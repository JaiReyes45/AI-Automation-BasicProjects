"""Local-only profile and document store, exposed through the loopback web proxy."""
from contextlib import contextmanager
import base64
import json
import os
import re
import sqlite3
import uuid
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse

ROOT = Path(os.environ.get('PROFILE_DATA', '/data'))
FIELDS = {'name','email','phone','location','school','course','year','hours','availability','linkedin','github','portfolio','drive','notes'}

@contextmanager
def connect():
    ROOT.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(ROOT / 'profile.sqlite')
    db.execute('CREATE TABLE IF NOT EXISTS profile (id INTEGER PRIMARY KEY, body TEXT)')
    db.execute('CREATE TABLE IF NOT EXISTS documents (id TEXT PRIMARY KEY, body TEXT)')
    try:
        with db:
            yield db
    finally:
        db.close()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def respond(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json')
        self.send_header('Cache-Control','no-store')
        self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        with connect() as db:
            if self.path == '/api/profile':
                row = db.execute('SELECT body FROM profile WHERE id=1').fetchone()
                return self.respond(200, {'profile':json.loads(row[0]) if row else {}, 'documents':[json.loads(r[0]) for r in db.execute('SELECT body FROM documents ORDER BY rowid DESC')]})
            if re.fullmatch(r'/api/files/[a-f0-9]{32}', self.path):
                key = self.path.rsplit('/',1)[1]
                row = db.execute('SELECT body FROM documents WHERE id=?',(key,)).fetchone()
                if row:
                    path = ROOT / 'files' / key
                    if path.is_file():
                        self.send_response(200)
                        self.send_header('Content-Type','application/octet-stream')
                        self.send_header('Content-Disposition','attachment; filename="document' + Path(json.loads(row[0])['name']).suffix + '"')
                        self.send_header('X-Content-Type-Options','nosniff')
                        self.end_headers()
                        self.wfile.write(path.read_bytes())
                        return
        self.respond(404, {'error':'Not found'})
    def do_POST(self):
        # Custom header + no CORS prevents cross-origin browser writes.
        if self.headers.get('X-CareerFlow') != 'local-profile':
            return self.respond(403, {'error':'Same-origin app request required'})
        try:
            size = int(self.headers.get('Content-Length','0'))
            if not 0 < size <= 12_000_000: raise ValueError('Request too large')
            data = json.loads(self.rfile.read(size))
            with connect() as db:
                if self.path == '/api/profile':
                    if not isinstance(data, dict) or set(data)-FIELDS: raise ValueError('Invalid profile fields')
                    for k,v in data.items():
                        if not isinstance(v,str) or len(v)>3000: raise ValueError('Invalid field length')
                        if k in {'linkedin','github','portfolio','drive'} and v and (urlparse(v).scheme != 'https' or not urlparse(v).netloc): raise ValueError('Links must use https://')
                    db.execute('INSERT OR REPLACE INTO profile VALUES (1,?)',(json.dumps(data),))
                elif self.path == '/api/documents':
                    category = data.get('category','').strip()
                    if not category or len(category)>120: raise ValueError('Enter a requirement name')
                    key = uuid.uuid4().hex
                    link = data.get('url','')
                    if link:
                        if len(link)>2000 or urlparse(link).scheme != 'https' or not urlparse(link).netloc: raise ValueError('Enter an HTTPS document link')
                        doc = {'id':key,'category':category,'name':'Linked document','url':link,'size':0}
                    else:
                        name = data.get('name','')
                        if len(name)>200 or Path(name).suffix.lower() not in {'.pdf','.docx','.png','.jpg','.jpeg'}: raise ValueError('Use PDF, DOCX, PNG or JPG')
                        content = base64.b64decode(data.get('content',''),validate=True)
                        if not 0 < len(content) <= 8*1024*1024: raise ValueError('File must be between 1 byte and 8 MB')
                        (ROOT/'files').mkdir(exist_ok=True)
                        (ROOT/'files'/key).write_bytes(content)
                        doc = {'id':key,'category':category,'name':name,'url':'/api/files/'+key,'size':len(content)}
                    db.execute('INSERT INTO documents VALUES (?,?)',(key,json.dumps(doc)))
                else: return self.respond(404,{'error':'Not found'})
            self.respond(200,{'ok':True})
        except (ValueError, TypeError, AttributeError):
            self.respond(400,{'error':'Check your fields, HTTPS links and file type/size (8 MB maximum).'})
        except (OSError, sqlite3.Error):
            self.respond(503,{'error':'Local storage unavailable. Try again; your form has not been cleared.'})

if __name__ == '__main__': HTTPServer(('0.0.0.0',8770),Handler).serve_forever()
