import {EventEmitter} from 'node:events';
import {randomUUID} from 'node:crypto';
import {statSync} from 'node:fs';
import {resolve,basename,isAbsolute} from 'node:path';
import {CodexClient,normalize} from './codex.mjs';
import {discoverSkills,selectSkills} from './inventory.mjs';
import {snapshotWorkspace,compareSnapshots} from './changes.mjs';

export class Runner extends EventEmitter {
 constructor(store,{clientFactory=options=>new CodexClient(options),inventory=discoverSkills,deadlineMs=20*60*1000,maxConcurrency=2}={}){
  super();this.store=store;this.clientFactory=clientFactory;this.inventory=inventory;this.deadlineMs=deadlineMs;this.active=new Map();this.history=new Map();this.maxConcurrency=maxConcurrency;
 }
 async models(){const client=this.clientFactory({});try{await client.initialize();const response=await client.request('model/list',{});const models=(response?.data??[]).filter(m=>typeof m.id==='string'&&/^[\w.-]{1,80}$/.test(m.id)).map(m=>({id:m.id,label:String(m.displayName??m.id).slice(0,100),isDefault:m.isDefault===true}));if(!models.length)throw new Error('Runtime advertised no available models');return models;}finally{await client.close();}}
 async launch(input,{onRunCreated,onNotification,approvalHandler}={}){
  if(this.active.size>=Math.min(this.maxConcurrency,2))throw new Error('Run concurrency limit reached');
  if(!input||typeof input.workspace!=='string'||!isAbsolute(input.workspace)||!statSync(input.workspace).isDirectory())throw new Error('Choose an absolute workspace directory');
  if(typeof input.prompt!=='string'||!input.prompt.trim()||Buffer.byteLength(input.prompt)>32768)throw new Error('Prompt must contain 1â€“32768 bytes');
  const effort=input.effort??'medium';if(!['low','medium','high','xhigh','max'].includes(effort))throw new Error('Invalid reasoning effort');
  if(input.model!==undefined && (typeof input.model!=='string'||!/^[\w.-]{1,80}$/.test(input.model)))throw new Error('Invalid model');
  const workspace=resolve(input.workspace);const inventory=await this.inventory(workspace);const selected=selectSkills(inventory,input.expectedSkillIds??[]);
  if(this.active.size>=Math.min(this.maxConcurrency,2))throw new Error('Run concurrency limit reached');
  const baseline=snapshotWorkspace(workspace);const runId=randomUUID();let sequence=0;let finished=false;let threadId,turnId;
  let client;let done;const completion=new Promise(r=>done=r);
  const details={workspaceLabel:basename(workspace),expectedSkills:selected,inventory:inventory.skills,capabilities:inventory.capabilities,captureContent:input.captureContent===true,changes:[],diagnostics:[],model:input.model??'account default',effort};
  const append=(type,status,payload={})=>this.store.append({runId,sourceId:`local:${++sequence}`,sequence,type,status,payload},{captureContent:details.captureContent});
  this.store.beginRun(runId,details);
  try{onRunCreated?.({runId});client=this.clientFactory({approvalHandler});}catch(error){append('connection.closed','interrupted',{code:5});throw error;}
  let deadline;
  const finalize=async(status,reason)=>{
   if(finished)return completion;finished=true;clearTimeout(deadline);
   try{
    if(reason)append('connection.closed',status,{code:reason});
    const after=snapshotWorkspace(workspace);details.changes=compareSnapshots(baseline,after,{captureContent:details.captureContent});details.capabilities={...details.capabilities,changeInspection:baseline.supported&&after.supported};
    if(!baseline.supported)details.diagnostics.push({code:'git_unavailable',message:baseline.reason??'Git snapshots unavailable'});
    if(!after.supported)details.diagnostics.push({code:'final_snapshot_unavailable',message:after.reason??'Final Git snapshot unavailable; changes are unknown'});
    this.store.saveDetails(runId,details);append('details.updated',status);
   }catch{append('details.failed','failed');}
   finally{await client.close();this.active.delete(runId);done(this.store.project(runId));this.emit('finished',runId);}
  };
  const cancel=async()=>{if(threadId&&turnId)await client.interrupt(threadId,turnId);await finalize('interrupted',1);};
  this.active.set(runId,{client,cancel,completion});this.history.set(runId,completion);if(this.history.size>100)this.history.delete(this.history.keys().next().value);
  client.on('notification',m=>{
   if(finished)return;
   try{
    if(threadId&&m.params?.threadId&&m.params.threadId!==threadId)return;
    onNotification?.({runId,rawEvent:m});
    const event=normalize(m,runId,++sequence);
    if(event){
     const item=m.params?.item??{};
     if(details.captureContent){event.payload.command=item.command;event.payload.output=item.aggregatedOutput;event.payload.stderr=item.error?.message??m.params?.error?.message;}
     this.store.append(event,{captureContent:details.captureContent});
     if(event.type==='run.completed')void finalize(event.status);
    }
   }catch{void finalize('interrupted',2);}
  });
  client.on('closed',()=>{if(!finished)void finalize('interrupted',3);});
  deadline=setTimeout(()=>void cancel(),this.deadlineMs);deadline.unref();
  void (async()=>{try{
   await client.initialize();if(finished)return;
   const started=await client.request('thread/start',{cwd:workspace,ephemeral:true,sandbox:'workspace-write',approvalPolicy:'on-request',...(input.model?{model:input.model}:{})});threadId=started.thread.id;if(finished)return;
   const text=selected.map(s=>`$${s.name}`).join(' ')+(selected.length?'\n':'')+input.prompt;
   const turn=await client.request('turn/start',{threadId,input:[{type:'text',text},...selected.map(s=>({type:'skill',name:s.name,path:s.path}))],effort});turnId=turn.turn.id;
  }catch{await finalize('interrupted',4);}})();
  return {runId};
 }
 async wait(runId){return this.history.get(runId)??this.store.project(runId);}
 async cancel(runId){const run=this.active.get(runId);if(!run)throw new Error('Run is not active');await run.cancel();}
 async close(){await Promise.all([...this.active.values()].map(r=>r.cancel()));}
}
