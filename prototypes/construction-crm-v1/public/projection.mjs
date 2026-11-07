export function projectEvents(events, count=events.length) {
 const ordered=[...events].sort((a,b)=>a.sequence-b.sequence || a.id-b.id).slice(0,count);
 let status='unknown'; const workers=new Map(), failures=[];
 for(const e of ordered){
  if(e.type.startsWith('run.') || e.type==='connection.closed') status=e.status;
  if(e.type.startsWith('tool.')){
   const key=e.payload?.itemId || `event:${e.id}`;
   const prior=workers.get(key) || {};
   workers.set(key,{itemId:e.payload?.itemId || null,type:e.payload?.itemType || prior.type || 'unknown',status:e.status,eventId:e.id});
  }
  if(e.status==='failed') failures.push(e.id);
 }
 if(['completed','failed','cancelled','interrupted'].includes(status))for(const worker of workers.values())if(['running','waiting'].includes(worker.status)){worker.status='unknown';worker.endUnobserved=true;}
 return {status,workers:[...workers.values()],failures,eventCount:ordered.length};
}
