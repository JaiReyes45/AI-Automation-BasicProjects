const {test}=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const {P06TelegramIntake}=require('../nodes/P06TelegramIntake.node');
const node=new P06TelegramIntake();
function context(header) {return {getCredentials:async()=>({accessToken:'synthetic-not-a-token'}),
 getWorkflow:()=>({id:'test'}),getNode:()=>({id:'intake'}),getHeaderData:()=>({'x-telegram-bot-api-secret-token':header}),
 getBodyData:()=>({update_id:123}),helpers:{returnJsonArray:x=>[{json:x}]},
 getResponseObject:()=>({status:s=>({json:()=>assert.equal(s,403)})})};}
test('durable intake acknowledges only after final node',()=>assert.equal(node.description.webhooks[0].responseMode,'lastNode'));
test('forged secret rejected without execution',async()=>assert.deepEqual(await node.webhook.call(context('bad')),{noWebhookResponse:true}));
test('valid secret authenticates update',async()=>{
 const s=crypto.createHmac('sha256','synthetic-not-a-token').update('p06-intake:test:intake').digest('hex');
 assert.equal((await node.webhook.call(context(s))).workflowData[0][0].json.update_id,123);
});
test('credential URL never exposed in errors',async()=>{
 const c=context();c.getNodeWebhookUrl=()=> 'https://example.invalid/webhook';c.helpers.httpRequest=async()=>{throw Error('token-bearing URL');};
 await assert.rejects(()=>node.webhookMethods.default.create.call(c),e=>!e.message.includes('token-bearing'));
});
