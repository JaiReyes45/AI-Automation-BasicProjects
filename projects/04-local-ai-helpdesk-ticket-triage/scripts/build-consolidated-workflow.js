const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, '..', 'workflows');
const specs = [
  ['01-ticket-intake-validation.json', '01 — Intake and validation', 'POST intake: validates, persists the durable receipt, and starts classification/routing.'],
  ['02-ai-classification-v2.json', '02 — AI classification', 'Builds a fixed prompt, calls internal Ollama, and validates the model contract.'],
  ['03-routing-sla-persistence.json', '03 — Routing, SLA, and persistence', 'Applies deterministic safety/routing/SLA rules and persists ticket, audit, review, and outbox data.'],
  ['04-notification-outbox-worker.json', '04 — Notification worker', 'Scheduled worker: claims outbox rows, sends Mailpit messages, retries, and captures exhausted failures.'],
  ['05-human-review-resolution.json', '05 — Human review', 'Reviewer webhook: validates a decision, resolves the task, updates the ticket, and audits it.'],
  ['06-error-capture-dead-letter.json', '06 — Error capture / dead letter', 'Sanitizes a failed stage and stores bounded replay context plus a ticket audit event.'],
  ['07-failed-job-reprocessing.json', '07 — Failed-job reprocessing', 'Reviewer-triggered replay: atomically claims a job and restarts classification/routing or resets a notification.'],
  ['08-sla-breach-monitor.json', '08 — SLA breach monitor', 'Scheduled monitor: detects each elapsed SLA once, audits it, and queues one escalation notification.'],
];
const source = specs.map(spec => JSON.parse(fs.readFileSync(path.join(dir, spec[0]), 'utf8')));
const notes = specs.map((spec, index) => ({
  parameters: { content: '## ' + spec[1] + '\\n\\n' + spec[2], height: 520, width: 1100, color: [2, 4, 5, 6, 3, 1, 7, 0][index] },
  id: 'unified-note-' + String(index + 1).padStart(2, '0'),
  name: 'Note — ' + spec[1],
  type: 'n8n-nodes-base.stickyNote',
  typeVersion: 1,
  position: [0, 0],
}));
const merged = {
  id: 'helpdesk-unified-v1',
  name: 'Helpdesk - Unified Operations 01-08 (inactive)',
  active: false,
  versionId: 'bb4727e7-8e33-4b0e-87d7-467c37845047',
  settings: { executionOrder: 'v1' },
  pinData: {},
  tags: [],
  meta: { templateCredsSetupCompleted: false },
  nodes: source.flatMap(workflow => workflow.nodes).filter(node => ![
    'Execute AI Classification', 'Execute Routing and SLA',
    'From Intake Workflow', 'From AI Classification Workflow',
    'From Failed Stage', 'Capture Classification Failure',
    'Capture Notification Failure',
  ].includes(node.name)).concat(notes),
  connections: Object.assign({}, ...source.map(workflow => workflow.connections)),
};
for (const name of ['Execute AI Classification', 'Execute Routing and SLA', 'From Intake Workflow', 'From AI Classification Workflow', 'From Failed Stage', 'Capture Classification Failure', 'Capture Notification Failure']) delete merged.connections[name];
for (const value of Object.values(merged.connections)) {
  value.main = (value.main || []).map(branch => branch.filter(edge => ![
    'Execute AI Classification', 'Execute Routing and SLA',
    'From Intake Workflow', 'From AI Classification Workflow',
    'From Failed Stage', 'Capture Classification Failure',
    'Capture Notification Failure',
  ].includes(edge.node)));
}
merged.connections['Build Classification Input'] = { main: [[{ node: 'Build Fixed Prompt', type: 'main', index: 0 }]] };
merged.connections['Validate Classification Contract'] = { main: [[{ node: 'Deterministic Routing and SLA', type: 'main', index: 0 }], [{ node: 'Build Classification Failure Capture', type: 'main', index: 0 }]] };
merged.connections['Build Classification Failure Capture'] = { main: [[{ node: 'Sanitize Failure for DLQ', type: 'main', index: 0 }]] };
merged.connections['Build Notification Failure Capture'] = { main: [[{ node: 'Sanitize Failure for DLQ', type: 'main', index: 0 }]] };
const origins = [[0, 0], [2350, 0], [3650, 0], [5650, 0], [7900, 0], [2350, 760], [4200, 1520], [7300, 1520]];
const sectionFor = new Map();
source.forEach((workflow, index) => workflow.nodes.forEach(node => sectionFor.set(node.name, index)));
const counters = Array(8).fill(0);
for (const node of merged.nodes) {
  if (node.type === 'n8n-nodes-base.stickyNote') continue;
  const section = sectionFor.get(node.name);
  const slot = counters[section]++;
  const columns = section === 3 ? 4 : 99;
  node.position = [origins[section][0] + 80 + (slot % columns) * 250, origins[section][1] + 230 + Math.floor(slot / columns) * 190];
}
for (let index = 0; index < notes.length; index++) {
  notes[index].parameters.width = index === 3 ? 1120 : Math.max(900, counters[index] * 250 + 160);
  notes[index].position = origins[index];
}
const names = new Set();
for (const node of merged.nodes) {
  if (names.has(node.name)) throw new Error('duplicate node name: ' + node.name);
  names.add(node.name);
}
for (const entry of Object.entries(merged.connections)) {
  if (!names.has(entry[0])) throw new Error('unknown connection source: ' + entry[0]);
  for (const branch of entry[1].main || []) for (const edge of branch) {
    if (!names.has(edge.node)) throw new Error('unknown connection target: ' + edge.node);
  }
}
fs.writeFileSync(path.join(dir, '09-unified-helpdesk-operations.json'), JSON.stringify(merged, null, 2) + '\n');
console.log('built inactive unified workflow with ' + merged.nodes.length + ' nodes');
