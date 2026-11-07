import {test} from 'node:test';
import assert from 'node:assert/strict';
import {CodexClient,normalize,outcomeCode} from '../src/codex.mjs';
test('normalizes actual protocol lifecycle and excludes content/identity-like arbitrary fields',()=>{
 const e=normalize({method:'item/completed',params:{threadId:'t',turnId:'v',item:{id:'i',type:'commandExecution',status:'completed',exitCode:7,command:'secret'}}},'r',2);
 assert.equal(e.type,'tool.completed');assert.equal(e.status,'failed');assert.equal(e.payload.exitCode,7);assert.equal(e.payload.command,undefined);
 assert.equal(e.payload.itemId,'i');assert.equal(e.payload.threadId,'t');assert.equal(e.payload.turnId,'v');assert.equal(e.payload.method,'item/completed');
 assert.equal(normalize({method:'item/reasoning/textDelta',params:{delta:'private'}},'r',3),null);
});
test('failed/cancelled/interrupted launch outcomes return unsuccessful exit codes',()=>{
 assert.equal(outcomeCode('completed'),0);for(const s of ['failed','cancelled','interrupted','unknown'])assert.notEqual(outcomeCode(s),0);
});
test('bounds pending requests and rejects oversized outbound frames',async()=>{
 const c=new CodexClient({command:process.execPath,args:['test/fixtures/rpc-child.mjs'],timeoutMs:2000,maxPending:1});
 try{await c.initialize();c.timeoutMs=100;const first=c.request('hang',{});await assert.rejects(c.request('echo',{}),/busy/);await assert.rejects(first,/timed out/);await assert.rejects(c.request('echo',{value:'a'.repeat(5*1024*1024)}),/large/);}finally{await c.close();}
});
test('client handles fragmented protocol, server requests, timeout and child exit',async()=>{
 const c=new CodexClient({command:process.execPath,args:['test/fixtures/rpc-child.mjs'],timeoutMs:500});
 try{await c.initialize();assert.equal((await c.request('echo',{value:7})).value,7);
 assert.equal((await c.request('ask',{})).denied,true);
 await assert.rejects(c.request('hang',{}),/timed out/);
 await assert.rejects(c.request('exit',{}),/closed/);
 }finally{await c.close();}
});
test('interruption failure is handled so the caller can always finalize its run',async()=>{
 const c=new CodexClient({command:process.execPath,args:['test/fixtures/rpc-child.mjs'],timeoutMs:2000});
 try{await c.initialize();c.timeoutMs=100;assert.equal(await c.interrupt('thread','turn'),false);}finally{await c.close();}
});
test('runtime errors remain inspectable without retaining raw error text',()=>{
 const e=normalize({method:'error',params:{error:{message:'secret transport detail'}}},'r',4);
 assert.equal(e.type,'runtime.failed');assert.equal(e.status,'failed');assert.equal(e.payload.stderr,undefined);
});
test('client can defer a supported approval and settles it only once',async()=>{let release;const c=new CodexClient({command:process.execPath,args:['test/fixtures/rpc-child.mjs'],timeoutMs:2000,approvalHandler:()=>new Promise(r=>{release=r;})});try{await c.initialize();const result=c.request('ask',{});await new Promise(r=>setTimeout(r,80));assert.equal(typeof release,'function');release('accept');assert.equal((await result).denied,false);}finally{await c.close();}});
