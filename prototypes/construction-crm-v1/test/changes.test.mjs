import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync,mkdirSync,symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {snapshotWorkspace,compareSnapshots} from '../src/changes.mjs';

function repo(t){const cwd=mkdtempSync(join(tmpdir(),'changes-'));t.after(()=>rmSync(cwd,{recursive:true,force:true}));const git=(...args)=>execFileSync('git',['-C',cwd,...args],{stdio:'pipe'});git('init');git('config','user.email','fixture@example.test');git('config','user.name','Fixture');return {cwd,git};}
test('snapshot compares the actual dirty baseline and keeps manual edits unattributed',t=>{
 const {cwd,git}=repo(t);writeFileSync(join(cwd,'file.txt'),'committed\n');writeFileSync(join(cwd,'.gitignore'),'ignored\n');git('add','.');git('commit','-m','fixture');
 writeFileSync(join(cwd,'file.txt'),'already dirty\n');writeFileSync(join(cwd,'untouched.txt'),'untracked baseline\n');writeFileSync(join(cwd,'ignored'),'excluded');
 const before=snapshotWorkspace(cwd);assert.equal(before.supported,true);assert.equal(before.dirty,true);assert.ok(before.head);
 assert.deepEqual(compareSnapshots(before,snapshotWorkspace(cwd)),[]);assert.ok(before.files.some(f=>f.path==='untouched.txt'));assert.ok(!before.files.some(f=>f.path==='ignored'));
 writeFileSync(join(cwd,'file.txt'),'manual edit\nAPI_KEY=very-private\n');rmSync(join(cwd,'untouched.txt'));writeFileSync(join(cwd,'new.txt'),'new\n');
 const after=snapshotWorkspace(cwd);const changes=compareSnapshots(before,after);assert.deepEqual(changes.map(c=>[c.path,c.kind]),[['file.txt','modified'],['new.txt','added'],['untouched.txt','deleted']]);
 assert.ok(changes.every(c=>c.attribution==='unattributed'&&c.diff===undefined));assert.doesNotMatch(JSON.stringify(after),/manual edit|very-private/);
 const captured=compareSnapshots(before,after,{captureContent:true});assert.match(captured[0].diff,/already dirty/);assert.match(captured[0].diff,/manual edit/);assert.doesNotMatch(captured[0].diff,/very-private|committed/);
});
test('snapshot rejects secrets, binary, huge and symlink files without reading target content',t=>{
 const {cwd}=repo(t);writeFileSync(join(cwd,'ok.txt'),'allowed');writeFileSync(join(cwd,'.env.local'),'PASSWORD=private');writeFileSync(join(cwd,'credentials.json'),'private');writeFileSync(join(cwd,'binary.dat'),Buffer.from([0,1,2]));writeFileSync(join(cwd,'huge.txt'),'x'.repeat(200000));
 const outside=mkdtempSync(join(tmpdir(),'outside-'));t.after(()=>rmSync(outside,{recursive:true,force:true}));writeFileSync(join(outside,'secret.txt'),'outside-private');
 // Windows permits directory junctions without Developer Mode; never follow them.
 symlinkSync(outside,join(cwd,'linked'),process.platform==='win32'?'junction':'dir');
 const snapshot=snapshotWorkspace(cwd);assert.equal(snapshot.supported,true);assert.ok(snapshot.files.some(f=>f.path==='ok.txt'&&f.hash));
 assert.ok(!snapshot.files.some(f=>/env|credentials/.test(f.path)));assert.equal(snapshot.files.find(f=>f.path==='binary.dat').omitted,'binary');assert.equal(snapshot.files.find(f=>f.path==='huge.txt').omitted,'size');assert.ok(!snapshot.files.some(f=>f.path.startsWith('linked/')&&f.hash));
 assert.doesNotMatch(JSON.stringify(snapshot),/outside-private|PASSWORD|allowed/);
});
test('non-Git workspaces and excessive file sets report unsupported instead of false deletions',t=>{
 const previous=process.env.GIT_CEILING_DIRECTORIES;process.env.GIT_CEILING_DIRECTORIES=tmpdir();t.after(()=>{if(previous===undefined)delete process.env.GIT_CEILING_DIRECTORIES;else process.env.GIT_CEILING_DIRECTORIES=previous;});
 const cwd=mkdtempSync(join(tmpdir(),'nongit-'));t.after(()=>rmSync(cwd,{recursive:true,force:true}));assert.equal(snapshotWorkspace(cwd).supported,false);
 const {cwd:root}=repo(t);mkdirSync(join(root,'many'));for(let i=0;i<2001;i++)writeFileSync(join(root,'many',`${i}.txt`),'x');
 const oversized=snapshotWorkspace(root);assert.equal(oversized.supported,false);assert.match(oversized.reason,/limit/i);assert.deepEqual(compareSnapshots({supported:true,files:[{path:'old',hash:'abc'}]},oversized),[]);
});
test('subdirectory workspace paths stay relative and skipped files never become claimed deletions',t=>{
 const {cwd,git}=repo(t);mkdirSync(join(cwd,'sub'));writeFileSync(join(cwd,'sub','inside.txt'),'inside');writeFileSync(join(cwd,'outside.txt'),'outside');git('add','.');
 const before=snapshotWorkspace(join(cwd,'sub'));assert.deepEqual(before.files.map(f=>f.path),['inside.txt']);
 writeFileSync(join(cwd,'sub','inside.txt'),Buffer.from([0]));const after=snapshotWorkspace(join(cwd,'sub'));assert.deepEqual(compareSnapshots(before,after),[]);
});
