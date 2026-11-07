import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {fileURLToPath} from 'node:url';
test('production qualification entry point exposes a working database health route',async()=>{const reservation=createServer();await new Promise(r=>reservation.listen(0,'127.0.0.1',r));const port=reservation.address().port;await new Promise(r=>reservation.close(r));const child=spawn(process.execPath,[fileURLToPath(new URL('../src/qualification-server.mjs',import.meta.url))],{env:{...process.env,WORKER_DATABASE_URL:process.env.OPS_TEST_DATABASE_URL,INTERNAL_ADAPTER_TOKEN:'synthetic-private-adapter-token-1234567890',INTERNAL_PORT:String(port),OLLAMA_URL:'',EXTRACTION_MODEL:''},stdio:'ignore',windowsHide:true});const exited=once(child,'exit');try{let response;for(let i=0;i<100;i++){try{response=await fetch(`http://127.0.0.1:${port}/health`);break;}catch{await new Promise(r=>setTimeout(r,25));}}assert.ok(response,'private listener starts');assert.equal(response.status,200);assert.equal((await response.json()).status,'ok');}finally{child.kill();await exited;}});
