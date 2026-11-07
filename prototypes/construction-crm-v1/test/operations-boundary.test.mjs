import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Store} from '../src/store.mjs';
import {SiteStore} from '../src/site/store.mjs';
import {serve} from '../src/server.mjs';
import {OperationsClient} from '../src/site/operations-client.mjs';
import {tmpdir} from 'node:os';
test('hosted auth failure leaves Build usable and hosted events dispatch zero local runs',async()=>{const raw=new Store(':memory:'),siteStore=new SiteStore(raw.db);siteStore.createProject({id:'p',workspace:tmpdir()});let starts=0;const operationsClient=new OperationsClient({baseUrl:'https://operations.example.invalid',ownerToken:'remote-token',fetchImpl:async()=>new Response('{}',{status:401})}),runner={active:new Map(),launch:()=>{starts++;}};const server=await serve(raw,{port:0,token:'local-token',siteStore,runner,operationsClient});const base=`http://127.0.0.1:${server.address().port}`,headers={Authorization:'Bearer local-token'};try{assert.equal((await fetch(base+'/site/operations/snapshot',{headers})).status,401);assert.equal((await fetch(base+'/site/snapshot?projectId=p',{headers})).status,200);assert.equal(starts,0);}finally{server.closeAllConnections();await new Promise(r=>server.close(r));raw.close();}});
