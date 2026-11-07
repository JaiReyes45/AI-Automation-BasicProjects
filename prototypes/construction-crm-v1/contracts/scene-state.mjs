import {validateSiteEvent} from './site-event.mjs';
export function projectScene({snapshot,events=[],cursors={}}={}){
 const s=snapshot?structuredClone(snapshot):{actors:{},tasks:{},skills:{},milestones:{},candidates:{},leads:{},crm:{},appointments:{},cursors:{},seen:[],versions:{},sources:{},usage:{inputTokens:null,outputTokens:null,cachedTokens:null,known:false}};
 const seen=new Set(s.seen);for(const [source,n] of Object.entries(cursors))s.cursors[source]=Math.max(s.cursors[source]??0,n);
 const ordered=events.map(validateSiteEvent).sort((a,b)=>a.source.localeCompare(b.source)||a.sequence-b.sequence||a.sourceEventId.localeCompare(b.sourceEventId));
 for(const e of ordered){
  const key=e.source+':'+e.sourceEventId;if(seen.has(key))continue;seen.add(key);s.cursors[e.source]=Math.max(s.cursors[e.source]??0,e.sequence);
  const latest=(entity)=>{const k=e.source+':'+entity;if((s.versions[k]??-1)>e.sequence)return false;s.versions[k]=e.sequence;return true;};
  if(e.mode==='build'&&e.actorId&&!s.actors[e.actorId])s.actors[e.actorId]={id:e.actorId,role:'builder',taskId:e.taskId??null,status:'queued',evidence:e.evidence};
  if(e.type==='actor.assigned'&&e.actorId&&latest('actor:'+e.actorId))s.actors[e.actorId]={...s.actors[e.actorId],role:e.role??'builder',taskId:e.taskId??null,status:s.tasks[e.taskId]?.state??s.actors[e.actorId].status,evidence:e.evidence};
  if(e.type.startsWith('task.')&&e.taskId&&latest('task:'+e.taskId)){
   const old=s.tasks[e.taskId];if(!old||!['cancelled','completed'].includes(old.state))s.tasks[e.taskId]={id:e.taskId,actorId:e.actorId??old?.actorId??null,state:e.status,evidence:e.evidence,eventId:e.eventId};
   if(e.actorId&&s.actors[e.actorId])s.actors[e.actorId].status=s.tasks[e.taskId].state;
  }
  if(e.type.startsWith('tool.')&&e.actorId&&s.actors[e.actorId]&&latest('tool:'+e.actorId))s.actors[e.actorId].activity=e.type==='tool.started'?'working':e.type==='tool.failed'?'failed':'idle';
  if(e.type.startsWith('skill.')&&e.actorId&&e.skillId){const k=e.actorId+':'+e.skillId;const old=s.skills[k]??{actorId:e.actorId,skillId:e.skillId,requested:false,observed:false};if(e.type==='skill.requested')old.requested=true;if(e.type==='skill.observed'&&e.evidence==='direct')old.observed=true;s.skills[k]=old;}
  if(e.type==='milestone.completed'&&e.milestoneId&&e.taskId&&['direct','synthetic'].includes(e.evidence)&&latest('milestone:'+e.milestoneId))s.candidates[e.milestoneId]={completed:true,taskId:e.taskId,eventId:e.eventId,evidence:e.evidence};
  const target=e.type.startsWith('appointment.')?'appointments':e.type.startsWith('lead.')?'leads':e.type.startsWith('crm.')?'crm':null;const targetId=target==='appointments'?e.appointmentId:e.leadId;
  if(target&&targetId&&latest(target+':'+targetId))s[target][targetId]={id:targetId,status:e.status,eventId:e.eventId,evidence:e.evidence,...(target==='appointments'&&e.leadId?{leadId:e.leadId}:{})};
  if(e.type==='usage.observed'&&e.actorId&&s.actors[e.actorId]&&latest('usage:'+e.actorId))s.actors[e.actorId].usage=e.usage??{measured:false};
 }
 for(const [id,candidate] of Object.entries(s.candidates))if(s.tasks[candidate.taskId]?.state==='completed')s.milestones[id]=candidate;
 s.seen=[...seen].sort();const actors=Object.values(s.actors),known=actors.length>0&&actors.every(a=>a.usage?.measured&&['inputTokens','outputTokens','cachedTokens'].every(k=>Number.isSafeInteger(a.usage[k])));
 s.usage={known,...Object.fromEntries(['inputTokens','outputTokens','cachedTokens'].map(k=>[k,known?actors.reduce((sum,a)=>sum+a.usage[k],0):null]))};return s;
}
