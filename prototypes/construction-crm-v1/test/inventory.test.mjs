import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {discoverSkills,selectSkills} from '../src/inventory.mjs';

test('inventory preserves duplicate names and scopes, hashes actual files, and rejects unavailable selections',async()=>{
 const cwd=await mkdtemp(join(tmpdir(),'inventory-'));let closed=false;
 try {
  const paths=[join(cwd,'user','SKILL.md'),join(cwd,'repo','SKILL.md'),join(cwd,'missing','SKILL.md')];
  for(const path of paths.slice(0,2)){await mkdir(join(path,'..'),{recursive:true});await writeFile(path,'---\nname: same\n---\nDo not execute this.');}
  const clientFactory=()=>({initialize:async()=>{},request:async(method,params)=>{
   assert.equal(method,'skills/list');assert.deepEqual(params.cwds,[cwd]);
   return {data:[{cwd,errors:[],skills:paths.map((path,i)=>({name:'same',description:'metadata',path,scope:i?'repo':'user',enabled:i!==1,pluginId:i===1?'plugin-x':null}))}]};
  },close:async()=>{closed=true;}});
  const result=await discoverSkills(cwd,{clientFactory});assert.equal(closed,true);
  assert.equal(result.skills.length,3);assert.equal(new Set(result.skills.map(s=>s.id)).size,3);
  assert.deepEqual(result.skills.map(s=>s.available),[true,false,false]);
  assert.equal(result.skills[0].hash,createHash('sha256').update('---\nname: same\n---\nDo not execute this.').digest('hex'));
  assert.equal(result.skills[1].plugin,'plugin-x');assert.equal(result.skills[0].kind,'skill');
  assert.deepEqual(selectSkills(result,[result.skills[0].id]),[result.skills[0]]);
  assert.throws(()=>selectSkills(result,[result.skills[1].id]),/unavailable/i);
  assert.throws(()=>selectSkills(result,['missing']),/unknown/i);
  assert.throws(()=>selectSkills(result,[result.skills[0].id,result.skills[0].id]),/duplicate/i);
  assert.deepEqual((await discoverSkills(cwd,{clientFactory})).skills.map(s=>s.id),result.skills.map(s=>s.id));
 } finally {await rm(cwd,{recursive:true,force:true});}
});

test('inventory reports protocol failure without exposing runtime errors',async()=>{
 let closed=false;
 const result=await discoverSkills(process.cwd(),{clientFactory:()=>({initialize:async()=>{throw Error('API_KEY=private');},close:async()=>{closed=true;}})});
 assert.deepEqual(result.skills,[]);assert.equal(result.capabilities.skillsList,false);assert.equal(closed,true);
 assert.doesNotMatch(JSON.stringify(result),/private/);
});
test('inventory keeps disabled/error entries but rejects oversized and arbitrary protocol file paths',async()=>{
 const cwd=await mkdtemp(join(tmpdir(),'inventory-limits-'));
 try{
  await mkdir(join(cwd,'huge'));const huge=join(cwd,'huge','SKILL.md');await writeFile(huge,'x'.repeat(200000));
  const bad=join(cwd,'missing','SKILL.md');const arbitrary=join(cwd,'credentials.json');await writeFile(arbitrary,'secret');
  const result=await discoverSkills(cwd,{clientFactory:()=>({initialize:async()=>{},request:async()=>({data:[{skills:[{path:huge,name:'huge',enabled:true},{path:arbitrary,name:'bad',enabled:true}],errors:[{path:bad,message:'secret error'}]}]}),close:async()=>{}})});
  assert.equal(result.skills.length,2);assert.ok(result.skills.every(s=>s.hash===null&&s.available===false));assert.equal(result.capabilities.inventoryErrors,true);assert.doesNotMatch(JSON.stringify(result),/secret error|credentials\.json/);
 }finally{await rm(cwd,{recursive:true,force:true});}
});
