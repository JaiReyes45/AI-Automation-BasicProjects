// Exercise the actual exported n8n normalizer with a synthetic multipart email.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const workflow = JSON.parse(fs.readFileSync(path.join(__dirname, '../workflows/06-gmail-crm-sync.json'), 'utf8'));
const code = workflow.nodes.find(n => n.name === 'Normalize email').parameters.jsCode;
const part = (mimeType, value) => ({mimeType, body: {data: Buffer.from(value).toString('base64url')}});
const message = {
  id: 'synthetic', threadId: 'synthetic-thread', internalDate: '1793019600000',
  payload: {headers: [{name:'Subject',value:'Indeed Application: Software Developer Intern'}, {name:'From',value:'indeedapply@indeed.com'}],
    parts: [part('text/plain','Your application has been submitted. Good luck!'),
      part('text/html','<style>.hidden{display:none}</style><script>danger()</script><p>&nbsp;&zwnj;Application submitted Software Developer Intern</p><p>The following items were sent to Example &amp; Co.. Good luck!</p>')]}
};
const run = new Function('$json', '$', code);
const selector = () => ({first: () => ({json: {emailAddress:'demo@example.test'}})});
const result = run(message, selector).json;
assert.equal(result.body, 'Your application has been submitted. Good luck!');
assert.match(result.html_text, /The following items were sent to Example & Co\.\. Good luck!/);
assert.doesNotMatch(result.html_text, /danger|display:none|<p>|&nbsp;|&zwnj;/);
assert.equal(result.thread_id, 'synthetic-thread');
const htmlOnly = run({...message, payload:{...message.payload, parts:[message.payload.parts[1]]}}, selector).json;
assert.equal(htmlOnly.body, htmlOnly.html_text);
console.log('PASS: exported MIME normalizer retains plain and HTML evidence, decodes entities and handles HTML-only messages.');
