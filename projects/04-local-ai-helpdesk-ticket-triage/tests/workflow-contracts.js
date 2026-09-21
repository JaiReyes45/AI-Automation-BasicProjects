const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '../../..');
const dir = path.join(root, 'workflows/04-local-ai-helpdesk-ticket-triage');
const files = ['01-ticket-intake-validation.json','02-ai-classification-v2.json','03-routing-sla-persistence.json','04-notification-outbox-worker.json','05-human-review-resolution.json','06-error-capture-dead-letter.json','07-failed-job-reprocessing.json','08-sla-breach-monitor.json'];
let passed = 0;
const ok = fn => { fn(); passed++; };
const read = name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));

for (const name of files) ok(() => assert.equal(read(name).active, false, `${name} must remain inactive`));
for (const name of files) ok(() => assert(!/(password|api[_-]?key|authorization|bearer|token)\s*[:=]/i.test(fs.readFileSync(path.join(dir, name), 'utf8')), `${name} contains a secret-like field`));

const classify = read('02-ai-classification-v2.json');
ok(() => assert(classify.nodes.some(n => n.name === 'Capture Classification Failure')));
const notify = read('04-notification-outbox-worker.json');
ok(() => assert(notify.nodes.some(n => n.name === 'Capture Notification Failure')));
ok(() => assert(JSON.stringify(notify).includes('notification_type')));
const replay = read('07-failed-job-reprocessing.json');
ok(() => assert(replay.nodes.some(n => n.name === 'Claim Failed Job Atomically')));
ok(() => assert(replay.nodes.some(n => n.name === 'Reset Notification for Retry')));
const sla = read('08-sla-breach-monitor.json');
ok(() => assert.equal(sla.nodes[0].parameters.rule.interval[0].minutesInterval, 5));
ok(() => assert(JSON.stringify(sla).includes('ON CONFLICT (ticket_id) DO NOTHING')));
console.log(`${passed} workflow contract tests passed`);
