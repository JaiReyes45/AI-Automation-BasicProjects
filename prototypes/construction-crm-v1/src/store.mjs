import {DatabaseSync} from 'node:sqlite';
import {mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import {redact} from './diagnostics.mjs';

// Only structural metadata reaches disk. Text content is intentionally excluded.
function metadata(payload={},captureContent=false) {
 const out={};
 for(const key of ['exitCode','durationMs','itemType','decision','code','threadId','turnId','itemId','method']) {
  if(typeof payload[key]==='number' && Number.isFinite(payload[key])) out[key]=payload[key];
  if(['itemType','decision','threadId','turnId','itemId','method'].includes(key) && typeof payload[key]==='string' && /^[a-zA-Z0-9_.:/-]{1,160}$/.test(payload[key])) out[key]=payload[key];
 }
 if(captureContent)for(const key of ['command','output','stderr','diff'])if(typeof payload[key]==='string')out[key]=redact(payload[key]).slice(0,16384);
 return out;
}
export class Store {
 constructor(file) {
  if(file!==':memory:') mkdirSync(dirname(file),{recursive:true});
  this.db=new DatabaseSync(file);
  this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
   CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY AUTOINCREMENT,run_id TEXT NOT NULL,source_id TEXT NOT NULL,sequence INTEGER NOT NULL,body TEXT NOT NULL,UNIQUE(run_id,source_id));
   CREATE INDEX IF NOT EXISTS run_sequence ON events(run_id,sequence,id);
   CREATE TABLE IF NOT EXISTS owners(run_id TEXT PRIMARY KEY,pid INTEGER NOT NULL);
   CREATE TABLE IF NOT EXISTS run_details(run_id TEXT PRIMARY KEY,body TEXT NOT NULL);
   PRAGMA user_version=3;`);
 }
 append(input,{captureContent=false}={}) {
  if(!input || typeof input!=='object' || !/^[a-zA-Z0-9_.:-]{1,160}$/.test(input.runId??'') || !/^[a-zA-Z0-9_.:/-]{1,240}$/.test(input.sourceId??'') || !Number.isSafeInteger(input.sequence)||input.sequence<0 || !/^[a-z.]{1,80}$/.test(input.type??'')) throw new Error('Invalid event');
  if(input.status!==undefined && !['running','completed','failed','cancelled','interrupted','waiting','unknown'].includes(input.status)) throw new Error('Invalid status');
  const max=this.db.prepare('SELECT MAX(sequence) AS n FROM events WHERE run_id=?').get(input.runId).n;
  const event={runId:input.runId,sourceId:input.sourceId,sequence:input.sequence,type:input.type,status:input.status??'unknown',observedAt:Number.isFinite(input.observedAt)?input.observedAt:null,ingestedAt:Date.now(),late:max!==null&&input.sequence<max,evidence:'direct',payload:metadata(input.payload,captureContent)};
  const result=this.db.prepare('INSERT INTO events(run_id,source_id,sequence,body) VALUES(?,?,?,?) ON CONFLICT(run_id,source_id) DO NOTHING').run(event.runId,event.sourceId,event.sequence,JSON.stringify(event));
  if(result.changes&&(event.type==='run.completed'||event.type==='connection.closed'))this.db.prepare('DELETE FROM owners WHERE run_id=?').run(event.runId);
  return result.changes?{...event,id:Number(result.lastInsertRowid)}:null;
 }
 saveDetails(runId,input){
  if(!/^[a-zA-Z0-9_.:-]{1,160}$/.test(runId))throw new Error('Invalid run');
  const safe={};for(const key of ['workspaceLabel','expectedSkills','inventory','captureContent','changes','diagnostics','model','effort','capabilities','synthetic'])if(input[key]!==undefined)safe[key]=input[key];
  const clean=value=>typeof value==='string'?redact(value).slice(0,16384):Array.isArray(value)?value.slice(0,500).map(clean):value&&typeof value==='object'?Object.fromEntries(Object.entries(value).slice(0,100).filter(([key])=>!['prompt','cwd','workspace','authorization','token'].includes(key)).map(([k,v])=>[k,clean(v)])):value;
  const text=JSON.stringify(clean(safe));if(Buffer.byteLength(text)>2*1024*1024)throw new Error('Run details too large');
  this.db.prepare('INSERT INTO run_details VALUES(?,?) ON CONFLICT(run_id) DO UPDATE SET body=excluded.body').run(runId,text);
 }
 details(runId){const row=this.db.prepare('SELECT body FROM run_details WHERE run_id=?').get(runId);return row?JSON.parse(row.body):null;}
 beginRun(runId,details){
  this.db.exec('BEGIN IMMEDIATE');
  try{this.saveDetails(runId,details);this.ownRun(runId,process.pid);this.append({runId,sourceId:'local:0',sequence:0,type:'run.started',status:'running'});this.db.exec('COMMIT');}
  catch(error){this.db.exec('ROLLBACK');throw error;}
 }
 purgeBefore(timestamp){if(!Number.isFinite(timestamp))throw new Error('Invalid retention cutoff');let count=0;
  this.db.exec('BEGIN IMMEDIATE');try{for(const run of this.runs()){
   if(!['completed','failed','cancelled','interrupted'].includes(run.status))continue;
   const latest=this.db.prepare('SELECT MAX(json_extract(body,\'$.ingestedAt\')) AS time FROM events WHERE run_id=?').get(run.runId).time;
   if(latest<timestamp){this.db.prepare('DELETE FROM events WHERE run_id=?').run(run.runId);this.db.prepare('DELETE FROM run_details WHERE run_id=?').run(run.runId);count++;}
  }this.db.exec('COMMIT');}catch(e){this.db.exec('ROLLBACK');throw e;}return count;
 }
 ownRun(runId,pid){this.db.prepare('INSERT INTO owners VALUES(?,?)').run(runId,pid);}
 recoverAbandoned(){for(const row of this.db.prepare('SELECT * FROM owners').all()){
  try{process.kill(row.pid,0);continue;}catch(e){if(e.code!=='ESRCH')continue;}
  const max=this.db.prepare('SELECT MAX(sequence) AS n FROM events WHERE run_id=?').get(row.run_id).n??0;
  this.append({runId:row.run_id,sourceId:'recovery:interrupted',sequence:max+1,type:'connection.closed',status:'interrupted'});
 }}
 decode(rows){return rows.map(row=>({...JSON.parse(row.body),id:Number(row.id)}));}
 events(runId){return this.decode(this.db.prepare('SELECT id,body FROM events WHERE run_id=? ORDER BY sequence,id').all(runId));}
 after(id,limit=1000){return this.decode(this.db.prepare('SELECT id,body FROM events WHERE id>? ORDER BY id LIMIT ?').all(id,limit));}
 runs(){return this.db.prepare('SELECT DISTINCT run_id FROM events ORDER BY run_id').all().map(r=>this.project(r.run_id));}
 project(runId){const events=this.events(runId);let status='unknown';for(const e of events){if(e.type.startsWith('run.')||e.type==='connection.closed')status=e.status;}return {runId,status,eventCount:events.length};}
 close(){this.db.close();}
}
