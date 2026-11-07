const MAX_TEXT=16*1024;
const REDACTED='[REDACTED]';
function bounded(text,bytes=MAX_TEXT){
 const buffer=Buffer.from(text);if(buffer.length<=bytes)return text;
 // Decode only complete UTF-8 code points.
 return new TextDecoder('utf-8',{fatal:false}).decode(buffer.subarray(0,bytes-16)).replace(/\uFFFD$/,'')+'\n[truncated]';
}

/** Best-effort secret filtering, before persistence. Never a guarantee for unknown secrets. */
export function redact(text){
 if(text===null||text===undefined)return '';
 let value=String(text).slice(0,1024*1024);
 value=value.replace(/-----BEGIN (?:[A-Z ]*PRIVATE KEY|OPENSSH PRIVATE KEY)-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)/g,REDACTED)
  .replace(/\b(Bearer|Basic)\s+[A-Za-z0-9._~+\/-]+=*/gi,`$1 ${REDACTED}`)
  .replace(/\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{16,}|(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]{16,}|AKIA[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]+)/g,REDACTED)
  .replace(/\b([a-z][a-z0-9+.-]*:\/\/)[^\s/@:]+:[^\s/@]+@/gi,`$1${REDACTED}@`)
  .replace(/(--[\w-]*(?:password|passwd|token|secret|api-key|credential)[\w-]*\s+)(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^\s]+)/gi,`$1${REDACTED}`)
  // JSON, shell assignments, dotenv and command flags. Values quoted with spaces stay covered.
  .replace(/((?:["']?[\w.-]*(?:api[_-]?key|access[_-]?key|private[_-]?key|secret|token|password|passwd|authorization|credential|database[_-]?url)[\w.-]*["']?)\s*(?:=|:)\s*)(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^\s,;}]+)/gi,`$1${REDACTED}`);
 return bounded(value);
}

function identity(event,key){return key==='runId'?event?.runId:event?.payload?.[key];}
function sameContext(a,b,requireTurn=false){
 if(!a?.runId||a.runId!==b?.runId)return false;
 for(const key of ['threadId','turnId']){
  const left=identity(a,key),right=identity(b,key);
  if((left!==undefined||right!==undefined)&&left!==right)return false;
 }
 return !requireTurn||typeof a.payload?.turnId==='string';
}

/** Correlation uses runtime identity only. Sequence order accommodates late delivery. */
export function inspectFailure(events,eventId){
 if(!Array.isArray(events))throw new TypeError('Events must be an array');
 const event=events.find(e=>e?.id===eventId||e?.sourceId===eventId);
 if(!event)throw new Error('Unknown event ID');
 const ordered=events.filter(e=>e&&e.runId===event.runId).slice().sort((a,b)=>(a.sequence??0)-(b.sequence??0)||(a.id??0)-(b.id??0));
 const index=ordered.indexOf(event),earlier=ordered.slice(0,index);
 const itemId=event.payload?.itemId;
 const related=typeof itemId==='string'?ordered.filter(e=>e!==event&&sameContext(e,event)&&e.payload?.itemId===itemId).slice(-40):[];
 const explicit=event.parentId??event.payload?.parentId;
 const parent=explicit!==undefined?ordered.find(e=>e.id===explicit||e.sourceId===explicit):earlier.findLast(e=>e.type==='run.started'&&sameContext(e,event,true));
 let category='unknown';
 if(event.type?.startsWith('tool.')&&event.status==='failed')category='tool_failure';
 else if(event.type==='approval.requested')category='approval';
 else if(['cancelled','interrupted'].includes(event.status))category=event.status;
 else if(event.type==='connection.closed')category='connection';
 else if(event.status==='failed')category='runtime_failure';
 return {event,category,preceding:earlier.slice(-8),...(parent?{parent}:{}),related,attribution:'unknown'};
}

function hideAbsolutePaths(text){
 return text.replace(/[A-Za-z]:[\\/][^\r\n"'<>|]*/g,'[absolute path]')
  .replace(/\\\\[^\r\n"'<>|]+/g,'[absolute path]')
  .replace(/(^|[\s("'=])\/(?:[^\s"'<>]+\/?)+/g,'$1[absolute path]');
}

/** A JSON-safe, bounded export. Content capture must be explicitly marked on the run. */
export function exportBundle(detail){
 const capture=detail?.details?.captureContent===true||detail?.captureContent===true;
 const seen=new WeakSet();let budget=1024*1024,nodes=20000;
 const clean=(value,depth=0)=>{
  if(depth>12||--nodes<0||budget<=0)return '[omitted: export limit]';
  if(value===null||typeof value==='boolean')return value;
  if(typeof value==='number')return Number.isFinite(value)?value:null;
  if(typeof value==='string'){const result=bounded(hideAbsolutePaths(redact(value)),Math.min(MAX_TEXT,Math.max(32,budget)));budget-=Buffer.byteLength(JSON.stringify(result))+8;return result;}
  if(typeof value!=='object')return undefined;
  if(seen.has(value))return '[omitted: repeated reference]';seen.add(value);
  if(Array.isArray(value)){
   const result=[];
   for(const item of value.slice(0,1000)){if(budget<=0||nodes<=0)break;result.push(clean(item,depth+1));budget-=2;}
   return result;
  }
  const result={};
  for(const [key,item] of Object.entries(value).slice(0,100)){
   if(budget<=0||nodes<=0)break;
   if(/^(?:[A-Za-z]:[\\/]|\/|\\\\)/.test(key))continue;
   if(/prompt|reasoning|^(?:input|arguments|workspace|cwd|workspacePath|absolutePath)$/i.test(key))continue;
   if(/token|password|secret|credential|api[_-]?key|authorization/i.test(key)){result[key]=REDACTED;continue;}
   if(!capture&&/^(?:command|output|stdout|stderr|diff|content|aggregatedOutput)$/i.test(key))continue;
   if(key==='path'&&typeof item==='string'&&(/^(?:[A-Za-z]:[\\/]|\/|\\\\)/.test(item)))continue;
   if(['__proto__','constructor','prototype'].includes(key))continue;
   budget-=Buffer.byteLength(JSON.stringify(key))+2;
   const next=clean(item,depth+1);if(next!==undefined)result[key]=next;
  }
  return result;
 };
 return clean(detail??{});
}
