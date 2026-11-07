import {test} from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,mkdtempSync,mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';

test('release packages only named source files and hashes the copied bytes',async()=>{
 assert.ok(existsSync(new URL('../scripts/package.mjs',import.meta.url)),'source packager is implemented');
 const {packageSource,SOURCE_FILES}=await import('../scripts/package.mjs');
 const root=mkdtempSync(join(tmpdir(),'acc-package-test-'));
 for(const file of SOURCE_FILES){mkdirSync(join(root,file,'..'),{recursive:true});writeFileSync(join(root,file),'safe source');}
 mkdirSync(join(root,'src'),{recursive:true});writeFileSync(join(root,'src','private.db'),'PRIVATE');writeFileSync(join(root,'src','tokens.mjs'),'PRIVATE');
 const result=packageSource(root);
 assert.ok(!existsSync(join(result.directory,'src/private.db')));assert.ok(!existsSync(join(result.directory,'src/tokens.mjs')));
 assert.ok(!existsSync(join(result.directory,'.data')));assert.ok(!existsSync(join(result.directory,'fixtures/private-customer.json')));
 for(const file of result.manifest.files){assert.equal(file.sha256,createHash('sha256').update(readFileSync(join(result.directory,file.path))).digest('hex'));}
 assert.equal(result.manifest.files.length,SOURCE_FILES.length);
 assert.throws(()=>packageSource(root),/exist/i,'never deletes or overwrites a release');
});

test('doctor enforces SQLite Node minimum and reports versions without raw credential-bearing output',async()=>{
 assert.ok(existsSync(new URL('../scripts/doctor.mjs',import.meta.url)),'doctor is implemented');
 const {doctor}=await import('../scripts/doctor.mjs');
 const bad=await doctor({nodeVersion:'22.12.0',probe:command=>({status:0,stdout:command==='git'?'git version 2.50.0':'codex-cli 0.155.1\nBearer sensitive-token',stderr:''})});
 assert.equal(bad.ok,false);assert.equal(bad.checks.find(x=>x.name==='Node.js').ok,false);assert.doesNotMatch(JSON.stringify(bad),/sensitive-token|Bearer/);
 const good=await doctor({nodeVersion:'22.13.0',probe:command=>({status:0,stdout:command==='git'?'git version 2.50.0':'codex-cli 0.155.1'})});assert.equal(good.ok,true);
 const missing=await doctor({nodeVersion:'24.0.0',probe:()=>({status:1,stdout:'authorization=private'})});assert.equal(missing.ok,false);assert.doesNotMatch(JSON.stringify(missing),/private/);
});

test('five-project pilot verifies actual runner persistence, faults, drift and privacy',async()=>{
 assert.ok(existsSync(new URL('../scripts/pilot.mjs',import.meta.url)),'pilot is implemented');
 const {runPilot}=await import('../scripts/pilot.mjs');
 const result=await runPilot();
 assert.equal(result.scenarios.length,5);assert.ok(result.scenarios.every(s=>s.passed));assert.equal(result.humanMedianDiagnosisSeconds,null);
 assert.equal(result.scenarios.find(s=>s.id==='success').changedPaths[0],'answer.txt');
 assert.equal(result.scenarios.find(s=>s.id==='failed-command').toolStatus,'failed');
 assert.equal(result.scenarios.find(s=>s.id==='crashed-run').runStatus,'interrupted');
 assert.equal(result.scenarios.find(s=>s.id==='missing-late-events').lateEvents,1);
 assert.equal(result.scenarios.find(s=>s.id==='manual-drift-privacy').attribution,'unattributed');
});
