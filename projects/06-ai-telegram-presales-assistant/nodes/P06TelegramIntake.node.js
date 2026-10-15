'use strict';
const crypto = require('crypto');

// A minimal Telegram adapter: acknowledge only after the durable inbox commit.
// The token stays inside n8n's encrypted credential store and process memory.
async function secret(context) {
  const c = await context.getCredentials('telegramApi');
  return crypto.createHmac('sha256', c.accessToken)
    .update('p06-intake:' + context.getWorkflow().id + ':' + context.getNode().id).digest('hex');
}
async function api(context, method, body) {
  const c = await context.getCredentials('telegramApi');
  try {
    const r = await context.helpers.httpRequest({method:'POST',
      url:(c.baseUrl || 'https://api.telegram.org').replace(/\/$/,'') + '/bot' + c.accessToken + '/' + method,
      body,json:true,timeout:15000});
    if (!r.ok) throw new Error('Telegram rejected registration');
    return r.result;
  } catch (_) {
    // HTTP helper errors may contain the token-bearing URL; never propagate them.
    throw new Error('Telegram webhook operation failed. Check connectivity and the stored Telegram credential.');
  }
}
class P06TelegramIntake {
  constructor() {
    this.description = {
      displayName:'Durable Telegram Intake',name:'p06TelegramIntake',group:['trigger'],version:1,
      description:'Receive authenticated Telegram updates; acknowledge after persistence',
      defaults:{name:'Durable Telegram Intake'},inputs:[],outputs:['main'],
      credentials:[{name:'telegramApi',required:true}],properties:[],
      webhooks:[{name:'default',httpMethod:'POST',responseMode:'lastNode',path:'webhook'}],
    };
    this.webhookMethods = {default:{
      async checkExists() {
        return (await api(this,'getWebhookInfo',{})).url === this.getNodeWebhookUrl('default');
      },
      async create() {
        await api(this,'setWebhook',{url:this.getNodeWebhookUrl('default'),
          allowed_updates:['message'],secret_token:await secret(this),drop_pending_updates:false});
        return true;
      },
      async delete() {
        if ((await api(this,'getWebhookInfo',{})).url === this.getNodeWebhookUrl('default'))
          await api(this,'deleteWebhook',{drop_pending_updates:false});
        return true;
      },
    }};
  }
  async webhook() {
    const provided = this.getHeaderData()['x-telegram-bot-api-secret-token'];
    const expected = await secret(this);
    const valid = typeof provided === 'string' && Buffer.byteLength(provided) === Buffer.byteLength(expected)
      && crypto.timingSafeEqual(Buffer.from(provided),Buffer.from(expected));
    if (!valid) {
      this.getResponseObject().status(403).json({ok:false});
      return {noWebhookResponse:true};
    }
    return {workflowData:[this.helpers.returnJsonArray(this.getBodyData())]};
  }
}
module.exports = {P06TelegramIntake};
