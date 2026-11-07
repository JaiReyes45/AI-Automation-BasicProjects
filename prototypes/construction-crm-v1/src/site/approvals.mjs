import {createHash,randomUUID} from 'node:crypto';
import {resolve,relative,isAbsolute} from 'node:path';
import {redact} from '../diagnostics.mjs';
const supported=new Set(['item/commandExecution/requestApproval','item/fileChange/requestApproval']);
function stable(value){if(Array.isArray(value))return value.map(stable);if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,stable(value[k])]));return value;}
export class ApprovalRegistry {
 constructor({siteStore,clock=Date.now,timeoutMs=300000}){this.site=siteStore;this.clock=clock;this.timeoutMs=timeoutMs;this.pending=new Map();}
 request(input){
  const {method,params={},taskId,actorId,runId,projectId,signal,previewItems}=input,task=this.site.task(taskId),project=this.site.project(projectId);
  if(!supported.has(method)||!task||!project||task.projectId!==projectId||task.actorId!==actorId||!['running','verifying'].includes(task.state)||signal?.aborted)return Promise.resolve('decline');
  let preview;
  if(method==='item/commandExecution/requestApproval'){
   if(typeof params.command!=='string'||!params.command.trim()||typeof params.cwd!=='string'||(Array.isArray(params.availableDecisions)&&!params.availableDecisions.includes('accept')))return Promise.resolve('decline');
   const rel=relative(project.workspace,resolve(params.cwd));if(rel==='..'||rel.startsWith('..\\')||rel.startsWith('../')||isAbsolute(rel))return Promise.resolve('decline');
   preview={command:params.command,cwd:params.cwd,reason:params.reason??null,additionalPermissions:params.additionalPermissions??null,networkApprovalContext:params.networkApprovalContext??null};
  }else{
   if(params.grantRoot||!Array.isArray(previewItems?.changes)||!previewItems.changes.length)return Promise.resolve('decline');
   for(const change of previewItems.changes){if(typeof change.path!=='string'||typeof change.diff!=='string')return Promise.resolve('decline');const rel=relative(project.workspace,resolve(change.path));if(rel==='..'||rel.startsWith('..\\')||rel.startsWith('../')||isAbsolute(rel))return Promise.resolve('decline');}
   preview={changes:previewItems.changes,reason:params.reason??null};
  }
  const serialized=JSON.stringify(stable({method,params,preview}));if(Buffer.byteLength(serialized)>65536||redact(JSON.stringify(preview))!==JSON.stringify(preview))return Promise.resolve('decline');
  const waiting=this.site.transitionTask({taskId,expectedVersion:task.version,to:'waiting_approval'}),id=randomUUID();
  const record={id,runId,actorId,taskId,projectId,method,actionDigest:createHash('sha256').update(serialized).digest('hex'),scope:project.workspace,expiresAt:this.clock()+this.timeoutMs,stateVersion:waiting.version,preview,state:'pending'};
  this.site.db.prepare('INSERT INTO site_approvals VALUES(?,?)').run(id,JSON.stringify(record));this.site.emit('approval.requested','waiting_approval',waiting);
  return new Promise(resolveDecision=>{const timer=setTimeout(()=>this.finish(id,'decline','expired'),this.timeoutMs);timer.unref();const abort=()=>this.finish(id,'decline','client_closed');this.pending.set(id,{record,resolveDecision,timer,abort,signal,resumeState:task.state});signal?.addEventListener('abort',abort,{once:true});});
 }
 list(){this.expire();return [...this.pending.values()].map(x=>structuredClone(x.record));}
 expire(){for(const [id,p] of this.pending)if(this.clock()>=p.record.expiresAt)this.finish(id,'decline','expired');}
 decide({id,actionDigest,stateVersion,decision}){const p=this.pending.get(id);if(!p)throw new Error('Approval already decided or not pending');if(this.clock()>=p.record.expiresAt){this.finish(id,'decline','expired');throw new Error('Approval expired');}if(actionDigest!==p.record.actionDigest||stateVersion!==p.record.stateVersion||!['accept','decline'].includes(decision))throw new Error('Approval digest/version conflict');const t=this.site.task(p.record.taskId);if(t?.version!==p.record.stateVersion||t.state!=='waiting_approval'){this.finish(id,'decline','task_changed');throw new Error('Task version conflict');}this.finish(id,decision,'owner_decision');return {status:decision};}
 finish(id,decision,reason){const p=this.pending.get(id);if(!p)return;this.pending.delete(id);clearTimeout(p.timer);p.signal?.removeEventListener('abort',p.abort);p.record.state=reason==='expired'||reason==='client_closed'?'expired':decision==='accept'?'accepted':'declined';p.record.reason=reason;this.site.db.prepare('UPDATE site_approvals SET data=? WHERE id=?').run(JSON.stringify(p.record),id);const t=this.site.task(p.record.taskId);if(t?.state==='waiting_approval'&&t.version===p.record.stateVersion){const next=this.site.transitionTask({taskId:t.id,expectedVersion:t.version,to:reason==='client_closed'?'failed':p.resumeState});this.site.emit('approval.decided',decision==='accept'?'completed':'failed',next);}p.resolveDecision(decision);}
 cancelRun(runId){for(const [id,p] of this.pending)if(p.record.runId===runId)this.finish(id,'decline','client_closed');}
 close(){for(const id of [...this.pending.keys()])this.finish(id,'decline','client_closed');}
}
