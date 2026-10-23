"""Loopback-only workflow adapter and durable test store; not the production backend."""
import json
import os
import sqlite3
import uuid
import hmac
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from workflow.engine import classify, decide

class Store:
    def __init__(self, path):
        self.path = str(path)
        with self.connect() as db:
            db.executescript('''
              CREATE TABLE IF NOT EXISTS applications(id TEXT PRIMARY KEY, data TEXT NOT NULL);
              CREATE TABLE IF NOT EXISTS messages(account TEXT, id TEXT, result TEXT NOT NULL, PRIMARY KEY(account,id));
              CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY, application_id TEXT, message_id TEXT, data TEXT);
              CREATE TABLE IF NOT EXISTS outbox(id TEXT PRIMARY KEY, payload TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending');
              CREATE TABLE IF NOT EXISTS delivery_attempts(id INTEGER PRIMARY KEY, job_id TEXT, success INTEGER, error TEXT);
              CREATE TABLE IF NOT EXISTS mock_labels(account TEXT, message_id TEXT, labels TEXT, PRIMARY KEY(account,message_id));
            ''')

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=15)
        try:
            with db:
                yield db
        finally:
            db.close()

    def ingest(self, message):
        result = classify(message)
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            old = db.execute('SELECT result FROM messages WHERE account=? AND id=?', (message['account'], message['id'])).fetchone()
            if old: return dict(json.loads(old[0]), duplicate=True)
            apps = [json.loads(row[0]) for row in db.execute('SELECT data FROM applications')]
            app, action = decide(message, result, apps)
            outcome = dict(classification=result, action=action, duplicate=False, application_id=None)
            if action in ('create', 'update'):
                if app is None:
                    app = dict(id=str(uuid.uuid4()), account=message['account'], company=result['company'],
                               original_role=result['original_role'], role=result['normalized_role'],
                               reference=result['reference'], threads=[])
                thread = message.get('thread_id')
                if thread and thread not in app['threads']: app['threads'].append(thread)
                app.update(stage=result['stage'], last_event=message['received_at'])
                db.execute('INSERT OR REPLACE INTO applications VALUES (?,?)', (app['id'], json.dumps(app)))
                db.execute('INSERT INTO events VALUES (?,?,?,?)', (str(uuid.uuid4()), app['id'], message['id'], json.dumps(result)))
                outcome['application_id'] = app['id']
                labels = ['Career/Stage/' + result['stage'], 'Career/Role/' + app['role']]
            else:
                labels = ['Career/System/Needs Review'] if action != 'opportunity_only' else ['Career/Stage/Opportunity Discovered']
            job = dict(account=message['account'], message_id=message['id'], labels=labels,
                       application_id=outcome['application_id'])
            db.execute('INSERT INTO outbox(id,payload) VALUES (?,?)', (str(uuid.uuid4()), json.dumps(job)))
            db.execute('INSERT INTO messages VALUES (?,?,?)', (message['account'], message['id'], json.dumps(outcome)))
            return outcome

    def deliver_mock(self, inject_failure=False):
        """Exercise label synchronization locally; never calls Google's API."""
        stage_labels = {'submitted':'Application Submitted', 'reviewing':'Under Review',
                        'information':'Additional Information Requested', 'assessment':'Assessment',
                        'interview':'Interview', 'offer':'Offer Received', 'rejected':'Rejected'}
        delivered = failed = 0
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            jobs = db.execute("SELECT id,payload FROM outbox WHERE state IN ('pending','failed') ORDER BY rowid LIMIT 100").fetchall()
            for job_id, raw in jobs:
                job = json.loads(raw)
                attempts = db.execute('SELECT COUNT(*) FROM delivery_attempts WHERE job_id=?', (job_id,)).fetchone()[0]
                if inject_failure:
                    inject_failure = False
                    db.execute('INSERT INTO delivery_attempts(job_id,success,error) VALUES (?,0,?)', (job_id, 'Simulated mailbox unavailable'))
                    db.execute('UPDATE outbox SET state=? WHERE id=?', ('dead' if attempts >= 2 else 'failed', job_id))
                    failed += 1
                    continue
                app_row = db.execute('SELECT data FROM applications WHERE id=?', (job['application_id'],)).fetchone()
                if app_row:
                    app = json.loads(app_row[0])
                    wanted = ['Career/Stage/' + stage_labels[app['stage']], 'Career/Role/' + app['role']]
                    # All messages confidently linked to this application reflect its current stage.
                    related = [json.loads(row[0]) for row in db.execute('SELECT payload FROM outbox')]
                    targets = [j for j in related if j.get('application_id') == app['id']]
                else:
                    wanted, targets = job['labels'], [job]
                for target in targets:
                    existing = db.execute('SELECT labels FROM mock_labels WHERE account=? AND message_id=?', (target['account'],target['message_id'])).fetchone()
                    labels = json.loads(existing[0]) if existing else ['INBOX']
                    # Only this app's stage and role namespace is replaced.
                    labels = [label for label in labels if not label.startswith(('Career/Stage/', 'Career/Role/'))] + wanted
                    db.execute('INSERT OR REPLACE INTO mock_labels VALUES (?,?,?)', (target['account'],target['message_id'],json.dumps(sorted(set(labels)))))
                db.execute('INSERT INTO delivery_attempts(job_id,success,error) VALUES (?,1,NULL)', (job_id,))
                db.execute("UPDATE outbox SET state='delivered' WHERE id=?", (job_id,))
                delivered += 1
        return dict(mode='synthetic_mailbox', delivered=delivered, failed=failed, **self.status())

    def status(self):
        with self.connect() as db:
            states = dict(db.execute('SELECT state,COUNT(*) FROM outbox GROUP BY state'))
            return dict(applications=db.execute('SELECT COUNT(*) FROM applications').fetchone()[0],
                        events=db.execute('SELECT COUNT(*) FROM events').fetchone()[0],
                        messages=db.execute('SELECT COUNT(*) FROM messages').fetchone()[0],
                        review_items=sum(json.loads(row[0])['action'] not in ('create','update','opportunity_only') for row in db.execute('SELECT result FROM messages')),
                        outbox=states, gmail_connected=False)

def serve():
    token = os.environ.get('CAREERFLOW_WORKFLOW_TOKEN')
    if not token: raise SystemExit('Set CAREERFLOW_WORKFLOW_TOKEN before starting the service.')
    path = Path(os.environ.get('CAREERFLOW_DB', 'workflow/local.sqlite3'))
    store = Store(path)
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_): pass  # Do not log email content or credentials.
        def do_GET(self):
            if self.path != '/health': self.send_error(404); return
            body = b'{"status":"ok","mode":"synthetic_mailbox"}'
            self.send_response(200); self.send_header('Content-Length', str(len(body)))
            self.end_headers(); self.wfile.write(body)
        def do_POST(self):
            if not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + token):
                self.send_error(401); return
            if self.path not in ('/ingest', '/deliver', '/status'): self.send_error(404); return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if length <= 0 or length > 100000: raise ValueError('Invalid body size')
                message = json.loads(self.rfile.read(length))
                if not isinstance(message, dict): raise ValueError('Expected an object')
                if self.path == '/ingest':
                    # This sprint's service deliberately accepts synthetic mailboxes only.
                    account = message.get('account', '')
                    if not isinstance(account, str) or not account.endswith(('.test', '.invalid')):
                        raise ValueError('Synthetic mailboxes only')
                    result = store.ingest(message)
                elif self.path == '/deliver':
                    if not isinstance(message.get('inject_failure', False), bool): raise ValueError('Invalid fault flag')
                    result = store.deliver_mock(message.get('inject_failure', False))
                else: result = store.status()
                body = json.dumps(result).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers(); self.wfile.write(body)
            except (ValueError, TypeError): self.send_error(400, 'Invalid email envelope')
            except sqlite3.Error: self.send_error(503, 'Storage unavailable; retry this message')
    ThreadingHTTPServer((os.environ.get('CAREERFLOW_BIND', '127.0.0.1'), 8765), Handler).serve_forever()

if __name__ == '__main__': serve()
