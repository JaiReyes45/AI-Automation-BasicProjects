import {test} from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {mkdtempSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.mjs';
import {Runner} from '../src/runner.mjs';
import {execFileSync} from 'node:child_process';

class Runtime extends EventEmitter {
 async initialize(){}
 async request(method,params){
  if(method==='thread/start')return {thread:{id:'t'}};
  if(method==='turn/start'){
   this.input=params.input;
   setTimeout(()=>{this.emit('notification',{method:'turn/started',params:{turn:{id:'turn',status:'inProgress'}}});this.emit('notification',{method:'item/completed',params:{item:{id:'tool1',type:'commandExecution',status:'completed',exitCode:7,aggregatedOutput:'password=supersecret'},threadId:'t',turnId:'turn'}});this.emit('notification',{method:'turn/completed',params:{turn:{id:'turn',status:'completed'}}});},10);
   return {turn:{id:'turn'}};
  }
 }
 async close(){}
 async interrupt(){return false;}
}
test('runner exposes per-run event hooks without retaining the prompt',async()=>{const dir=mkdtempSync(join(tmpdir(),'site-hook-')),store=new Store(':memory:'),runtime=new Runtime(),seen=[];const runner=new Runner(store,{clientFactory:()=>runtime,inventory:async()=>({skills:[],capabilities:{}})});try{let created;const {runId}=await runner.launch({workspace:dir,prompt:'private'},{onRunCreated:r=>{created=r.runId;},onNotification:r=>seen.push(r)});await runner.wait(runId);assert.equal(created,runId);assert.ok(seen.some(r=>r.rawEvent.method==='item/completed'));assert.ok(seen.every(r=>r.runId===runId));}finally{await runner.close();store.close();rmSync(dir,{recursive:true,force:true});}});
test('launch preflights skill input, records failed tool and preserves run result without persisting prompt',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'acc-run-'));const store=new Store(':memory:');const runtime=new Runtime();
 const inventory={skills:[{id:'s',name:'lint',path:join(dir,'SKILL.md'),available:true}],capabilities:{}};
 const runner=new Runner(store,{clientFactory:()=>runtime,inventory:async()=>inventory});
 try{const {runId}=await runner.launch({workspace:dir,prompt:'private prompt',expectedSkillIds:['s'],captureContent:true});await runner.wait(runId);
 assert.equal(store.project(runId).status,'completed');assert.equal(store.events(runId).find(e=>e.type==='tool.completed').status,'failed');
 assert.equal(runtime.input[1].type,'skill');assert.equal(store.details(runId).expectedSkills[0].name,'lint');assert.doesNotMatch(JSON.stringify(store.events(runId)),/supersecret|private prompt/);
 await assert.rejects(runner.launch({workspace:dir,prompt:'x',expectedSkillIds:['unknown']}),/skill/i);
 }finally{await runner.close();store.close();rmSync(dir,{recursive:true,force:true});}
});
test('oversized initial details rollback ownership before any runtime is spawned',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'acc-setup-'));const store=new Store(':memory:');let spawned=0;
 const skills=Array.from({length:500},(_,i)=>({id:`s${i}`,name:`skill${i}`,path:join(dir,`skill-${i}`,'SKILL.md'),available:true,description:'x'.repeat(2048)}));
 const runner=new Runner(store,{clientFactory:()=>{spawned++;return new Runtime();},inventory:async()=>({skills,capabilities:{}})});
 try{await assert.rejects(runner.launch({workspace:dir,prompt:'x',expectedSkillIds:skills.map(s=>s.id)}),/large/);
 assert.equal(spawned,0);assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM owners').get().n,0);assert.equal(store.db.prepare('SELECT COUNT(*) AS n FROM run_details').get().n,0);
 }finally{await runner.close();store.close();rmSync(dir,{recursive:true,force:true});}
});
test('unsupported final snapshots are explicit diagnostics rather than evidence of no changes',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'acc-final-'));execFileSync('git',['init',dir],{stdio:'ignore'});writeFileSync(join(dir,'baseline.txt'),'before');
 const store=new Store(':memory:');const runtime=new Runtime();const request=runtime.request.bind(runtime);
 runtime.request=async(method,params)=>{if(method==='turn/start')for(let i=0;i<2001;i++)writeFileSync(join(dir,`file-${i}.txt`),'x');return request(method,params);};
 const runner=new Runner(store,{clientFactory:()=>runtime,inventory:async()=>({skills:[],capabilities:{}})});
 try{const {runId}=await runner.launch({workspace:dir,prompt:'x'});await runner.wait(runId);const detail=store.details(runId);
 assert.equal(detail.capabilities.changeInspection,false);assert.ok(detail.diagnostics.some(d=>d.code==='final_snapshot_unavailable'));
 }finally{await runner.close();store.close();rmSync(dir,{recursive:true,force:true});}
});
test('runtime model selector exposes only advertised models without starting a model task',async()=>{const raw=new Store(':memory:');let closed=false,starts=0;const runtime=new Runtime();runtime.close=async()=>{closed=true;};runtime.request=async method=>{if(method==='model/list')return {data:[{id:'advertised-model',displayName:'Available model',isDefault:true},{id:'bad/id',isDefault:false}]};if(method==='turn/start')starts++;};const runner=new Runner(raw,{clientFactory:()=>runtime});try{assert.deepEqual(await runner.models(),[{id:'advertised-model',label:'Available model',isDefault:true}]);assert.equal(starts,0);assert.equal(closed,true);}finally{raw.close();}});
