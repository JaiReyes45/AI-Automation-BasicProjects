import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Store} from '../src/store.mjs';
import {serve} from '../src/server.mjs';
import {request} from 'node:http';
test('serves public shell but protects data, permits same origin and provides inspector export',async()=>{
 const store=new Store(':memory:');
 const runner={inventory:async()=>({skills:[],capabilities:{}}),launch:async()=>({runId:'new'}),cancel:async()=>{}};
 const server=await serve(store,{port:0,token:'test',runner});const base=`http://127.0.0.1:${server.address().port}`;const headers={Authorization:'Bearer test'};
 try{
  assert.equal((await fetch(base+'/')).status,200);
  assert.equal((await fetch(base+'/health',{headers:{...headers,Origin:base}})).status,200);
  const hostileStatus=await new Promise((resolve,reject)=>{const req=request(base+'/health',{headers:{...headers,Host:'evil.example'}},res=>{res.resume();resolve(res.statusCode);});req.on('error',reject);req.end();});
  assert.equal(hostileStatus,403);
  assert.equal((await (await fetch(base+'/inventory?workspace=C%3A%5Cdemo',{headers})).json()).skills.length,0);
  store.append({runId:'r',sourceId:'x',sequence:1,type:'tool.completed',status:'failed',payload:{itemId:'i',exitCode:7}});
  assert.equal((await (await fetch(base+'/runs/r',{headers})).json()).events.length,1);
  assert.equal((await fetch(base+'/runs/r/export',{headers})).status,200);
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r));store.close();}
});
