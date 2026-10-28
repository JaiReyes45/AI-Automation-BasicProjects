// Exercise the actual exported n8n normalizer with a synthetic multipart email.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const workflow = JSON.parse(fs.readFileSync(path.join(__dirname, '../workflows/06-gmail-crm-sync.json'), 'utf8'));
const code = workflow.nodes.find(n => n.name === 'Normalize email').parameters.jsCode;
const part = (mimeType, value) => ({mimeType, body: {data: Buffer.from(value).toString('base64url')}});
const message = {
  id: 'synthetic', threadId: 'synthetic-thread', internalDate: '1793019600000', labelIds:['INBOX'],
  payload: {headers: [{name:'Subject',value:'Indeed Application: Software Developer Intern'}, {name:'From',value:'indeedapply@indeed.com'},
    {name:'Message-ID',value:'<original@example.test>'}, {name:'References',value:'<first@example.test> <second@example.test>'},
    {name:'In-Reply-To',value:'<second@example.test>'}, {name:'Reply-To',value:'Recruiter <recruiter@example.test>'},
    {name:'To',value:'Demo <demo@example.test>'}, {name:'To',value:'Other <other@example.test>'}],
    parts: [part('text/plain','Your application has been submitted. Good luck!'),
      part('text/html','<style>.hidden{display:none}</style><script>danger()</script><p>&nbsp;&zwnj;Application submitted Software Developer Intern</p><p>The following items were sent to Example &amp; Co.. Good luck!</p>')]}
};
const run = new Function('$json', '$', code);
const selector = (name) => ({first: () => ({json: name === 'Start mailbox page'
  ? {run_id:'synthetic-run',lease_token:'synthetic-lease'} : {emailAddress:'demo@example.test'}})});
const result = run(message, selector).json;
assert.equal(result.body, 'Your application has been submitted. Good luck!');
assert.match(result.html_text, /The following items were sent to Example & Co\.\. Good luck!/);
assert.doesNotMatch(result.html_text, /danger|display:none|<p>|&nbsp;|&zwnj;/);
assert.equal(result.thread_id, 'synthetic-thread');
assert.equal(result.direction, 'received');
assert.equal(result.rfc_message_id, '<original@example.test>');
assert.equal(result.references, '<first@example.test> <second@example.test>');
assert.equal(result.in_reply_to, '<second@example.test>');
assert.equal(result.reply_to, 'Recruiter <recruiter@example.test>');
assert.equal(result.to, 'Demo <demo@example.test>\nOther <other@example.test>');
assert.deepEqual(result.headers, message.payload.headers);
assert.equal(result.mail_sync_run_id, 'synthetic-run');
const sent = run({...message,labelIds:['SENT'],payload:{...message.payload,headers:[{name:'From',value:'alias@example.test'}]}}, selector).json;
assert.equal(sent.direction, 'sent', 'Gmail SENT label identifies aliases without guessing from address');
const htmlOnly = run({...message, payload:{...message.payload, parts:[message.payload.parts[1]]}}, selector).json;
assert.equal(htmlOnly.body, htmlOnly.html_text);
const quoted = run({...message,payload:{headers:[],parts:[part('text/html','<div>Thank you.</div><blockquote>Please share your availability.</blockquote>')]}},selector).json;
assert.equal(quoted.current_body,'Thank you.');
assert.match(quoted.body,/Please share/,'Full email text remains available for inspection');
const execute = (name, items, json={}) => new Function('$input','$json','$', workflow.nodes.find(n=>n.name===name).parameters.jsCode)(
  {all:()=>items.map(value=>({json:value}))}, json, selector);
assert.deepEqual(execute('Check message reads', [{statusCode:200,body:message},{statusCode:404,body:{}}]),
  [{json:{failed:true,error:'provider_error'}}], 'A partial Gmail read must fail the whole page without acknowledging missing mail');
assert.equal(execute('Check stored', [{statusCode:200,body:{}},{statusCode:503,body:{}}])[0].json.stored, false);
assert.equal(execute('Check stored', [{statusCode:200,body:{duplicate:true}}])[0].json.stored, true);
assert.equal(execute('Read failure', [], {statusCode:403})[0].json.error, 'authorization');
const empty = execute('Describe page', [], {body:{}})[0].json;
assert.deepEqual(empty.message_ids, []);
assert.equal(empty.next_page_token, null);
const paths = name => (workflow.connections[name]?.main||[]).map(branch=>branch.map(edge=>edge.node));
assert.deepEqual(paths('Has messages')[1], ['Acknowledge page'], 'An empty selected batch must acknowledge its listed IDs');
assert.deepEqual(paths('Messages stored')[1], ['Read failure']);
assert.deepEqual(paths('Page fetched')[1], ['Read failure']);
assert.deepEqual(paths('Messages readable')[1], ['Read failure']);
console.log('PASS: MIME evidence, reply headers, sent direction, empty pages and failure-before-acknowledgment transport contracts.');
