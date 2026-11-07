import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {Store} from '../src/store.mjs';
import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

test('persists, deduplicates, orders late events and reconstructs after restart',()=>{
 const dir=mkdtempSync(join(tmpdir(),'acc-')); const file=join(dir,'events.db');
 try {
 let s=new Store(file);
 for(let n=1000;n>=1;n--) s.append({runId:'r',sourceId:`e${n}`,sequence:n,type:n===1000?'run.completed':'tool.completed',status:n===1000?'completed':'failed',payload:{command:'secret command',token:'sk-secret-value',exitCode:1}});
 assert.equal(s.append({runId:'r',sourceId:'e1',sequence:1,type:'tool.completed'}),null);
 assert.equal(s.events('r').length,1000);
 assert.equal(s.events('r')[0].sequence,1);
 assert.equal(s.events('r')[0].late,true);
 assert.equal(s.project('r').status,'completed');
 const before=s.project('r');s.close();s=new Store(file);
 assert.deepEqual(s.project('r'),before);
 assert.equal(s.events('r')[0].payload.command,undefined);
 s.close(); assert.equal(readFileSync(file).includes(Buffer.from('sk-secret-value')),false);
 } finally {rmSync(dir,{recursive:true,force:true});}
});

test('rejects malformed input without poisoning ingestion and reports interrupted work',()=>{
 const s=new Store(':memory:');
 assert.throws(()=>s.append({runId:'r',sequence:-1,type:'x'}));
 s.append({runId:'r',sourceId:'start',sequence:1,type:'run.started',status:'running'});
 s.append({runId:'r',sourceId:'disconnect',sequence:2,type:'connection.closed',status:'interrupted'});
 assert.equal(s.project('r').status,'interrupted');
 assert.equal(s.after(0).length,2);s.close();
});
test('recovers a genuinely abandoned run after its writer exits',()=>{
 const dir=mkdtempSync(join(tmpdir(),'acc-crash-'));const file=join(dir,'events.db');
 try{const script=`import {Store} from ${JSON.stringify(pathToFileURL(join(process.cwd(),'src/store.mjs')).href)}; const s=new Store(${JSON.stringify(file)});s.ownRun('crashed',process.pid);s.append({runId:'crashed',sourceId:'start',sequence:1,type:'run.started',status:'running'});process.exit(0);`;
 const child=spawnSync(process.execPath,['--experimental-sqlite','--input-type=module','-e',script]);assert.equal(child.status,0);
 const s=new Store(file);s.recoverAbandoned();assert.equal(s.project('crashed').status,'interrupted');s.recoverAbandoned();assert.equal(s.events('crashed').length,2);s.close();
 }finally{rmSync(dir,{recursive:true,force:true});}
});
