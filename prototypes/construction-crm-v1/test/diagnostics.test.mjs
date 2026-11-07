import {test} from 'node:test';
import assert from 'node:assert/strict';
import {redact,inspectFailure,exportBundle} from '../src/diagnostics.mjs';

test('redact removes common credentials and bounds UTF-8 output',()=>{
 const text='API_KEY=top-secret\nexport DATABASE_URL="postgres://alice:password@localhost/db"\nAuthorization: Bearer abc.def.ghi\n{"password":"hunter2","token":"sensitive"}\nsk-proj-abcdefghijklmnopqrstuvwxyz\n-----BEGIN PRIVATE KEY-----\nkeybody\n-----END PRIVATE KEY-----';
 const output=redact(text);assert.match(output,/REDACTED/);for(const secret of ['top-secret','password@','abc.def.ghi','hunter2','sensitive','abcdefghijklmnopqrstuvwxyz','keybody'])assert.ok(!output.includes(secret),secret);
 assert.ok(Buffer.byteLength(redact('😀'.repeat(100000)))<=16384);assert.equal(redact(null),'');
});
test('failure inspection matches exact runtime IDs across late events and never infers skill causality',()=>{
 const event=(id,sequence,type,status,itemId,turnId='turn')=>({id,runId:'run',sourceId:`rpc:${id}`,sequence,type,status,payload:{itemId,turnId,threadId:'thread'}});
 const parent=event(1,1,'run.started','running');const start=event(2,2,'tool.started','running','tool');const other=event(3,3,'tool.started','running','other');const wrongTurn=event(4,4,'tool.started','running','tool','other-turn');const failure=event(5,5,'tool.completed','failed','tool');
 const result=inspectFailure([failure,wrongTurn,parent,other,start],5);assert.equal(result.event,failure);assert.equal(result.category,'tool_failure');assert.equal(result.parent,parent);assert.deepEqual(result.related,[start]);assert.ok(result.preceding.includes(start));assert.equal(result.attribution,'unknown');
 assert.throws(()=>inspectFailure([failure],'missing'),/unknown/i);
});
test('diagnostic export omits prompts and absolute paths and redacts opt-in content',()=>{
 const detail={runId:'r',status:'failed',events:[{id:1,payload:{command:'API_KEY=secret',output:'Authorization: Bearer abc123',prompt:'private-prompt',cwd:'C:\\Users\\Private Name\\project'}}],details:{workspace:'C:\\Users\\Private Name\\project',inventory:{skills:[{path:'/home/private/SKILL.md',name:'skill'}]},captureContent:true,changes:[{path:'file.txt',diff:'+ password=hunter2'}],prompt:'private-prompt'}};
 const bundle=exportBundle(detail);const text=JSON.stringify(bundle);for(const value of ['private-prompt','Private Name','/home/private','secret','abc123','hunter2'])assert.ok(!text.includes(value),value);assert.equal(bundle.details.changes[0].path,'file.txt');assert.match(bundle.events[0].payload.command,/REDACTED/);
 const metadata=exportBundle({...detail,details:{...detail.details,captureContent:false}});assert.equal(metadata.events[0].payload.command,undefined);assert.equal(metadata.details.changes[0].diff,undefined);
 const circular={runId:'r'};circular.loop=circular;assert.doesNotThrow(()=>JSON.stringify(exportBundle(circular)));
});
test('export does not retain absolute path object keys, encoded prompts, or credential flags',()=>{
 const input={details:{captureContent:true},events:[{payload:{command:'tool --password hunter2 --api-key abc-secret',message:'Read /home/private/myfile and C:\\Users\\Private Name\\workspace\\file.txt',user_prompt:'private-prompt'}}],'/home/private/data':{value:'private'},map:{'C:\\Users\\Name\\work':1}};
 const output=JSON.stringify(exportBundle(input));assert.doesNotMatch(output,/hunter2|abc-secret|private-prompt|\/home\/private|Private Name|Users/);
 assert.match(output,/tool/);
});
