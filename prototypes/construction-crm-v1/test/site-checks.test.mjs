import {test} from 'node:test';
import assert from 'node:assert/strict';
import {tmpdir} from 'node:os';
import {mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {Store} from '../src/store.mjs';
import {SiteStore} from '../src/site/store.mjs';
import {runTaskCheck} from '../src/site/checks.mjs';
test('checks record real exit evidence and timeout cannot mean passed',async t=>{const dir=mkdtempSync(join(tmpdir(),'site-check-')),raw=new Store(':memory:'),site=new SiteStore(raw.db);t.after(()=>{raw.close();rmSync(dir,{recursive:true,force:true});});site.createProject({id:'p',workspace:dir});site.createTask({id:'task',projectId:'p',criteria:[{id:'fail',kind:'runtime_check',command:process.execPath,argv:['-e','console.log("tests passed");process.exit(1)']},{id:'hang',kind:'runtime_check',command:process.execPath,argv:['-e','setInterval(()=>{},1000)']},{id:'pass',kind:'runtime_check',command:process.execPath,argv:['-e','process.exit(0)']}]});site.transitionTask({taskId:'task',expectedVersion:0,to:'running'});site.transitionTask({taskId:'task',expectedVersion:1,to:'verifying'});const context={siteStore:site,artifactRoot:dir};const fail=await runTaskCheck({taskId:'task',criterionId:'fail'},context);assert.equal(fail.passed,false);assert.equal(fail.exitCode,1);const hang=await runTaskCheck({taskId:'task',criterionId:'hang'},{...context,timeoutMs:50});assert.equal(hang.passed,false);assert.equal(hang.timedOut,true);const pass=await runTaskCheck({taskId:'task',criterionId:'pass'},context);assert.equal(pass.passed,true);assert.equal(pass.exitCode,0);});
