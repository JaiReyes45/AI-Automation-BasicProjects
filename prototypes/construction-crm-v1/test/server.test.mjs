import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Store} from '../src/store.mjs';
import {serve} from '../src/server.mjs';
test('authenticates ingestion, rejects hostile origins and resumes SSE from stored cursor',async()=>{
 const store=new Store(':memory:');const server=await serve(store,{port:0,token:'test-token'});
 const url=`http://127.0.0.1:${server.address().port}`; const headers={Authorization:'Bearer test-token','Content-Type':'application/json'};
 try {
 assert.equal((await fetch(url+'/runs')).status,401);
 assert.equal((await fetch(url+'/runs',{headers:{...headers,Origin:'https://evil.example'}})).status,403);
 assert.equal((await fetch(url+'/events',{method:'POST',headers,body:'{}'})).status,400);
 for(let n=1;n<4;n++)assert.equal((await fetch(url+'/events',{method:'POST',headers,body:JSON.stringify({runId:'r',sourceId:`e${n}`,sequence:n,type:'run.started',status:'running'})})).status,201);
 const response=await fetch(url+'/stream',{headers:{...headers,'Last-Event-ID':'1'}});
 const reader=response.body.getReader();const chunk=new TextDecoder().decode((await reader.read()).value);
 assert.match(chunk,/id: 2/);assert.doesNotMatch(chunk,/id: 1\n/);await reader.cancel();
 assert.equal((await (await fetch(url+'/runs/r',{headers})).json()).eventCount,3);
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));store.close();}
});
test('large captured events survive SSE backpressure and retain their resume cursor',async()=>{
 const store=new Store(':memory:');const server=await serve(store,{port:0,token:'large'});const base=`http://127.0.0.1:${server.address().port}`;
 for(let n=1;n<=3;n++)store.append({runId:'big',sourceId:`b${n}`,sequence:n,type:'tool.completed',payload:{output:'x'.repeat(16000),command:'y'.repeat(16000)}},{captureContent:true});
 const controller=new AbortController();const timeout=setTimeout(()=>controller.abort(),3000);
 try{const r=await fetch(base+'/stream',{headers:{Authorization:'Bearer large'},signal:controller.signal});const reader=r.body.getReader();let text='';while(!text.includes('id: 3\n')){const part=await reader.read();assert.equal(part.done,false);text+=new TextDecoder().decode(part.value);}assert.match(text,/id: 1\n/);await reader.cancel();}
 finally{clearTimeout(timeout);controller.abort();server.closeAllConnections();await new Promise(r=>server.close(r));store.close();}
});
