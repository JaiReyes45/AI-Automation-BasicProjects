import {spawn} from 'node:child_process';
import {EventEmitter,once} from 'node:events';
import {validateSiteEvent} from '../contracts/site-event.mjs';

export class CodexClient extends EventEmitter {
 constructor({command='codex',args=['app-server','--stdio'],timeoutMs=15000,maxPending=32,approvalHandler}={}) {
  super();this.next=0;this.pending=new Map();this.timeoutMs=timeoutMs;this.maxPending=maxPending;this.closed=false;this.approvalAbort=new AbortController();this.items=new Map();let buffer='';
  this.child=spawn(command,args,{stdio:['pipe','pipe','pipe'],windowsHide:true});
  this.child.stderr.on('data',()=>{}); // Do not persist potentially sensitive runtime diagnostics.
  this.child.stdout.setEncoding('utf8');this.child.stdout.on('data',chunk=>{
   buffer+=chunk;if(Buffer.byteLength(buffer)>4*1024*1024){this.child.kill();return;}
   let end;while((end=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,end);buffer=buffer.slice(end+1);let m;try{m=JSON.parse(line);}catch{this.child.kill();return;}
    if(m.method&&m.id!==undefined){
     this.emit('notification',{method:'approval.requested',params:m.params??{}});
     if(m.method==='item/commandExecution/requestApproval'||m.method==='item/fileChange/requestApproval'){
      if(typeof approvalHandler==='function')Promise.resolve().then(()=>approvalHandler({method:m.method,params:m.params??{},signal:this.approvalAbort.signal,previewItems:this.items.get(m.params?.itemId)})).then(decision=>this.send({id:m.id,result:{decision:decision==='accept'?'accept':'decline'}})).catch(()=>this.send({id:m.id,result:{decision:'decline'}}));
      else this.send({id:m.id,result:{decision:'decline'}});
     }
     else this.send({id:m.id,error:{code:-32601,message:'Unsupported server request'}});
    }else if(m.method){if(m.method==='item/started'&&m.params?.item?.id){if(this.items.size>=100)this.items.delete(this.items.keys().next().value);this.items.set(m.params.item.id,m.params.item);}if(m.method==='item/completed')this.items.delete(m.params?.item?.id);this.emit('notification',m);}
    else if(this.pending.has(m.id)){const p=this.pending.get(m.id);clearTimeout(p.timer);this.pending.delete(m.id);m.error?p.reject(new Error(`RPC ${m.error.code}: request rejected`)):p.resolve(m.result);}
   }
  });
  const closed=()=>{if(this.closed)return;this.closed=true;this.approvalAbort.abort();this.items.clear();for(const p of this.pending.values()){clearTimeout(p.timer);p.reject(new Error('Codex connection closed'));}this.pending.clear();this.emit('closed');};
  this.child.on('error',closed);this.child.on('exit',closed);this.child.stdin.on('error',closed);
 }
 send(m){if(!this.closed)this.child.stdin.write(JSON.stringify(m)+'\n');}
 request(method,params){
  if(this.closed)return Promise.reject(new Error('Codex connection closed'));
  if(this.pending.size>=this.maxPending||this.child.stdin.writableNeedDrain)return Promise.reject(new Error('Codex connection busy'));
  if(Buffer.byteLength(JSON.stringify({method,params}))>1024*1024)return Promise.reject(new Error('Request too large'));
  return new Promise((resolve,reject)=>{const id=++this.next;const timer=setTimeout(()=>{this.pending.delete(id);reject(new Error(`${method} timed out`));},this.timeoutMs);this.pending.set(id,{resolve,reject,timer});this.send({id,method,params});});}
 async initialize(){const info=await this.request('initialize',{clientInfo:{name:'agent_control_center',version:'0.1.0'},capabilities:{experimentalApi:true}});this.send({method:'initialized',params:{}});return info;}
 async interrupt(threadId,turnId){try{await this.request('turn/interrupt',{threadId,turnId});return true;}catch{return false;}}
 async close(){if(this.closed)return;const ended=once(this.child,'exit').catch(()=>{});this.child.stdin.end();const timer=setTimeout(()=>this.child.kill(),1000);await ended;clearTimeout(timer);}
}

export function normalize(m,runId,sequence) {
 const p=m.params??{};const item=p.item??{};let type,status='running';const payload={method:m.method,threadId:p.threadId??p.thread?.id,turnId:p.turnId??p.turn?.id,itemId:item.id};
 if(m.method==='thread/started')type='session.started';
 else if(m.method==='turn/started')type='run.started';
 else if(m.method==='turn/completed'){type='run.completed';status=({completed:'completed',failed:'failed',interrupted:'cancelled'})[p.turn?.status]??'unknown';}
 else if(m.method==='approval.requested'){type='approval.requested';status='waiting';}
 else if(m.method==='error'){type='runtime.failed';status='failed';}
 else if(['item/started','item/completed'].includes(m.method)&&['commandExecution','fileChange','mcpToolCall','dynamicToolCall','webSearch'].includes(item.type)){
  type=m.method==='item/started'?'tool.started':'tool.completed';status=type==='tool.started'?'running':(item.status==='failed'||item.status==='declined'||(typeof item.exitCode==='number'&&item.exitCode!==0))?'failed':item.status==='completed'?'completed':'unknown';payload.itemType=item.type;payload.exitCode=item.exitCode;
 }else return null;
 return {runId,sourceId:`rpc:${sequence}`,sequence,type,status,observedAt:Date.now(),payload};
}
export function outcomeCode(status){return status==='completed'?0:1;}
export function recordRuntimeEvent({rawEvent,runId,actorId,taskId,projectId,sequence}){
 const base={eventId:`${runId}:${sequence}`,sourceEventId:`${runId}:${sequence}`,source:'build-runtime',mode:'build',projectId,actorId,taskId,sequence,evidence:'direct',receivedAt:Date.now()};
 if(rawEvent.method==='thread/tokenUsage/updated'){const t=rawEvent.params?.tokenUsage?.total;if(!t)return null;return validateSiteEvent({...base,type:'usage.observed',status:'running',usage:{measured:true,inputTokens:t.inputTokens,outputTokens:t.outputTokens,cachedTokens:t.cachedInputTokens}});}
 const e=normalize(rawEvent,runId,sequence);if(!e?.type.startsWith('tool.'))return null;return validateSiteEvent({...base,type:e.status==='failed'?'tool.failed':e.type,status:e.status});
}
