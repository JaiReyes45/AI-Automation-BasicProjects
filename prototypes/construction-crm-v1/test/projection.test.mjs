import test from 'node:test';
import assert from 'node:assert/strict';
import {projectEvents} from '../public/projection.mjs';
const events=[
 {id:1,sequence:1,type:'run.started',status:'running',payload:{}},
 {id:2,sequence:2,type:'tool.started',status:'running',payload:{itemId:'a',itemType:'commandExecution'}},
 {id:3,sequence:3,type:'tool.completed',status:'failed',payload:{itemId:'a',itemType:'commandExecution',exitCode:1}},
 {id:4,sequence:4,type:'run.completed',status:'completed',payload:{}}
];
test('failure remains visible in a completed run and replay is deterministic',()=>{
 const end=projectEvents(events,4);
 assert.equal(end.status,'completed'); assert.equal(end.failures.length,1);
 assert.equal(end.workers[0].status,'failed'); assert.equal(end.workers[0].itemId,'a');
 assert.equal(projectEvents(events,2).workers[0].status,'running');
 assert.deepEqual(projectEvents(events,4),projectEvents(events.slice(0,4),4));
});
test('terminal runs leave missing tool ends unknown rather than animating ongoing work',()=>{
 const p=projectEvents([{id:1,sequence:1,type:'run.started',status:'running'},{id:2,sequence:2,type:'tool.started',status:'running',payload:{itemId:'missing',itemType:'commandExecution'}},{id:3,sequence:3,type:'run.completed',status:'completed'}]);
 assert.equal(p.workers[0].status,'unknown');assert.equal(p.workers[0].endUnobserved,true);
});
