import {EventEmitter} from 'node:events';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {Store} from '../src/store.mjs';
import {Runner} from '../src/runner.mjs';
import {exportBundle,inspectFailure} from '../src/diagnostics.mjs';

const secret='pilot-secret-value';
function git(cwd,args){const result=spawnSync('git',args,{cwd,encoding:'utf8',windowsHide:true});if(result.status!==0)throw new Error(`Disposable project Git ${args[0]} failed`);}
function project(root,name){const dir=join(root,name);mkdirSync(dir);git(dir,['init','--quiet']);writeFileSync(join(dir,'answer.txt'),'baseline\n');git(dir,['add','answer.txt']);git(dir,['-c','user.name=Automated Pilot','-c','user.email=pilot@example.invalid','commit','--quiet','-m','synthetic baseline']);return dir;}

// Only the external model transport is deterministic. Store, Runner, Git snapshots,
// command failure, optional capture and disk persistence are the production code.
class FixtureRuntime extends EventEmitter{
 constructor(workspace,scenario){super();this.workspace=workspace;this.scenario=scenario;this.closed=false;}
 async initialize(){}
 event(method,extra={}){if(!this.closed)this.emit('notification',{method,params:{threadId:'pilot-thread',turnId:'pilot-turn',...extra}});}
 async request(method){
  if(method==='thread/start')return {thread:{id:'pilot-thread'}};
  if(method==='turn/start'){
   this.timer=setTimeout(()=>this.run(),5);return {turn:{id:'pilot-turn'}};
  }
  throw new Error('Unexpected fixture request');
 }
 run(){
  this.event('turn/started',{turn:{id:'pilot-turn',status:'inProgress'}});
  if(this.scenario==='crashed-run'){this.emit('closed');return;}
  if(this.scenario==='success'){writeFileSync(join(this.workspace,'answer.txt'),'fixture change\n');this.event('item/completed',{item:{id:'edit-1',type:'fileChange',status:'completed'}});}
  if(this.scenario==='failed-command'){
   this.event('item/started',{item:{id:'test-1',type:'commandExecution',status:'inProgress'}});
   const result=spawnSync(process.execPath,['-e',"process.stderr.write('synthetic assertion failed');process.exit(7)"],{cwd:this.workspace,encoding:'utf8',windowsHide:true});
   this.event('item/completed',{item:{id:'test-1',type:'commandExecution',status:'completed',exitCode:result.status,aggregatedOutput:result.stderr}});
  }
  if(this.scenario==='missing-late-events'){
   // Deliberately no item/started. Runner must not invent the missing event.
   this.event('item/completed',{item:{id:'orphan-1',type:'commandExecution',status:'completed',exitCode:0}});
   this.event('turn/completed',{turn:{id:'pilot-turn',status:'completed'}});
   this.event('item/started',{item:{id:'too-late',type:'commandExecution',status:'inProgress'}});return;
  }
  if(this.scenario==='manual-drift-privacy'){
   // Simulate an unrelated user edit with no fileChange event. Attribution stays unknown.
   writeFileSync(join(this.workspace,'answer.txt'),`manual edit\npassword=${secret}\n`);
   writeFileSync(join(this.workspace,'.env'),`API_TOKEN=${secret}`);
   this.event('item/completed',{item:{id:'capture-1',type:'commandExecution',status:'completed',exitCode:0,command:`echo password=${secret}`,aggregatedOutput:`token=${secret}`}});
  }
  this.event('turn/completed',{turn:{id:'pilot-turn',status:'completed'}});
 }
 async interrupt(){return true;}
 async close(){this.closed=true;clearTimeout(this.timer);}
}

export async function runPilot(){
 // Kept for inspection. No automatic recursive cleanup of projects or databases.
 const root=mkdtempSync(join(tmpdir(),'acc-five-project-pilot-'));
 const scenarios=[];
 for(const id of ['success','failed-command','crashed-run','missing-late-events','manual-drift-privacy']){
  const workspace=project(root,id),db=join(root,`${id}.sqlite`);let store=new Store(db);
  const runtime=new FixtureRuntime(workspace,id),runner=new Runner(store,{clientFactory:()=>runtime,inventory:async()=>({skills:[],capabilities:{synthetic:true}}),deadlineMs:5000});
  let runId;
  try{
   // Baseline dirt must not be claimed as a run change.
   if(id==='manual-drift-privacy')writeFileSync(join(workspace,'preexisting.txt'),'pre-existing user dirt\n');
   ({runId}=await runner.launch({workspace,prompt:'synthetic pilot prompt',expectedSkillIds:[],captureContent:id==='manual-drift-privacy'}));
   await Promise.race([runner.wait(runId),new Promise((_,reject)=>{const timer=setTimeout(()=>reject(new Error('Pilot run timed out')),7000);timer.unref();})]);
   await runner.close();store.close();store=new Store(db);
   const result=store.project(runId),events=store.events(runId),details=store.details(runId);
   assert.equal(result.status,id==='crashed-run'?'interrupted':'completed');
   const evidence={id,passed:true,runStatus:result.status,eventCount:events.length};
   if(id==='success'){assert.deepEqual(details.changes.map(c=>c.path),['answer.txt']);assert.equal(readFileSync(join(workspace,'answer.txt'),'utf8'),'fixture change\n');evidence.changedPaths=details.changes.map(c=>c.path);}
   if(id==='failed-command'){const failed=events.find(e=>e.type==='tool.completed');assert.equal(failed.status,'failed');assert.equal(failed.payload.exitCode,7);assert.equal(inspectFailure(events,failed.id).related.length,1);evidence.toolStatus=failed.status;evidence.exitCode=failed.payload.exitCode;}
   if(id==='crashed-run')assert.ok(events.some(e=>e.type==='connection.closed'&&e.status==='interrupted'));
   if(id==='missing-late-events'){
    assert.equal(events.filter(e=>e.type==='tool.started').length,0);assert.equal(events.filter(e=>e.type==='tool.completed').length,1);
    // The recorder ingestion boundary also accepts out-of-order imported evidence.
    const late=store.append({runId,sourceId:'pilot:late',sequence:0,type:'tool.completed',status:'unknown',payload:{itemId:'import-late'}});assert.equal(late.late,true);
    assert.equal(store.append({runId,sourceId:'pilot:late',sequence:0,type:'tool.completed',status:'unknown'}),null);
    evidence.lateEvents=store.events(runId).filter(e=>e.late).length;evidence.missingStartPreserved=true;evidence.postCompletionIgnored=true;
   }
   if(id==='manual-drift-privacy'){
    assert.deepEqual(details.changes.map(c=>c.path),['answer.txt']);assert.equal(details.changes[0].attribution,'unattributed');assert.equal(events.filter(e=>e.payload.itemType==='fileChange').length,0);
    const serialized=JSON.stringify({events,details});assert.doesNotMatch(serialized,new RegExp(secret));assert.doesNotMatch(JSON.stringify(exportBundle({events,details})),/synthetic pilot prompt|pilot-secret-value/);
    evidence.attribution=details.changes[0].attribution;evidence.secretRedacted=true;evidence.preexistingDirtExcluded=true;
   }
   scenarios.push(evidence);
  }finally{await runner.close();store.close();}
 }
 return {automated:true,transport:'deterministic external model fixture',root,scenarios,humanMedianDiagnosisSeconds:null,humanPilot:'pending; no human participants timed'};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){try{console.log(JSON.stringify(await runPilot(),null,2));}catch(error){console.error(`Automated pilot failed: ${error.message}`);process.exitCode=1;}}
