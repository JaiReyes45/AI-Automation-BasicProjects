import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Store} from '../src/store.mjs';

test('run details retain expected skills and reject persistence of prompts',()=>{
 const s=new Store(':memory:');
 try {
  s.saveDetails('r',{workspaceLabel:'demo',prompt:'never persist this',expectedSkills:[{id:'a',name:'lint'}],captureContent:false});
  assert.equal(s.details('r').prompt,undefined);
  assert.equal(s.details('r').expectedSkills[0].name,'lint');
  s.append({runId:'r',sourceId:'1',sequence:1,type:'tool.completed',payload:{output:'password=hunter2',itemId:'a'}},{captureContent:false});
  assert.equal(s.events('r')[0].payload.output,undefined);
  s.append({runId:'r',sourceId:'2',sequence:2,type:'tool.completed',payload:{output:'password=hunter2',itemId:'a'}},{captureContent:true});
  assert.doesNotMatch(s.events('r')[1].payload.output,/hunter2/);
 }finally{s.close();}
});
test('retention removes only old terminal runs and their details',()=>{
 const s=new Store(':memory:');
 try {
  s.append({runId:'old',sourceId:'1',sequence:1,type:'run.completed',status:'completed'});
  s.saveDetails('old',{workspaceLabel:'demo'});
  s.append({runId:'live',sourceId:'1',sequence:1,type:'run.started',status:'running'});
  assert.equal(s.purgeBefore(Date.now()+1000),1);
  assert.equal(s.events('old').length,0);assert.equal(s.details('old'),null);assert.equal(s.events('live').length,1);
 }finally{s.close();}
});
