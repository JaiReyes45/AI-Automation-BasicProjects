import {open,realpath} from 'node:fs/promises';
import {basename,dirname,isAbsolute,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {CodexClient} from './codex.mjs';
import {redact} from './diagnostics.mjs';

const MAX_SKILLS=1000,MAX_SKILL_BYTES=128*1024;
const hash=value=>createHash('sha256').update(value).digest('hex');

async function skillFile(path){
 if(typeof path!=='string'||path.length>4096||!isAbsolute(path)||basename(path).toLowerCase()!=='skill.md')return null;
 const canonical=await realpath(path).catch(()=>resolve(path));
 let file;
 try{
  file=await open(canonical,'r');const stat=await file.stat();
  if(!stat.isFile()||stat.size>MAX_SKILL_BYTES)return {canonical,hash:null};
  const bytes=Buffer.alloc(MAX_SKILL_BYTES+1);const {bytesRead}=await file.read(bytes,0,bytes.length,0);
  if(bytesRead>MAX_SKILL_BYTES)return {canonical,hash:null};
  return {canonical,hash:hash(bytes.subarray(0,bytesRead))};
 }catch{return {canonical,hash:null};}finally{await file?.close().catch(()=>{});}
}

export async function discoverSkills(cwd,{clientFactory=()=>new CodexClient()}={}){
 let client;const skills=[];
 try{
  if(typeof cwd!=='string'||!isAbsolute(cwd))throw new Error('Workspace must be absolute');
  client=await clientFactory();await client.initialize();
  const result=await client.request('skills/list',{cwds:[resolve(cwd)],forceReload:false});
  if(!Array.isArray(result?.data))throw new Error('Invalid skills response');
  let count=0,truncated=false,errors=false;const byPath=new Map();
  for(const group of result.data.slice(0,32)){
   if(!Array.isArray(group.skills))continue;
   const records=[...group.skills,...(Array.isArray(group.errors)?group.errors:[]).map(e=>({path:e.path,name:basename(dirname(e.path??'')),scope:'unknown',enabled:false,description:'Skill metadata could not be loaded'}))];
   errors||=Boolean(group.errors?.length);
   for(const record of records){
    if(count++>=MAX_SKILLS){truncated=true;break;}
    const file=await skillFile(record.path);if(!file)continue;
    const key=process.platform==='win32'?file.canonical.toLowerCase():file.canonical;
    const available=record.enabled===true&&file.hash!==null;
    if(byPath.has(key)){byPath.get(key).available&&=available;continue;}
    const skill={id:`skill:${hash(key)}`,name:redact(typeof record.name==='string'?record.name:'Unnamed skill').slice(0,240),description:redact(typeof record.description==='string'?record.description:'').slice(0,2048),path:file.canonical,scope:typeof record.scope==='string'?record.scope.slice(0,80):'unknown',origin:'codex.skills/list',hash:file.hash,available,kind:'skill',plugin:typeof record.pluginId==='string'?record.pluginId.slice(0,240):null};
    byPath.set(key,skill);skills.push(skill);
   }
   if(truncated)break;
  }
  return {skills,capabilities:{skillsList:true,skillSelection:true,skillAttribution:false,truncated,inventoryErrors:errors}};
 }catch{
  return {skills:[],capabilities:{skillsList:false,skillSelection:false,skillAttribution:false,reason:'Codex skill inventory unavailable'}};
 }finally{await client?.close().catch(()=>{});}
}

export function selectSkills(inventory,ids){
 if(!Array.isArray(ids)||ids.length>MAX_SKILLS||ids.some(id=>typeof id!=='string'))throw new TypeError('Expected skill IDs must be an array of strings');
 if(new Set(ids).size!==ids.length)throw new Error('Duplicate skill ID');
 const skills=Array.isArray(inventory)?inventory:inventory?.skills;
 if(!Array.isArray(skills))throw new TypeError('Invalid inventory');
 const byId=new Map(skills.map(skill=>[skill.id,skill]));
 return ids.map(id=>{const skill=byId.get(id);if(!skill)throw new Error('Unknown skill ID');if(skill.available!==true)throw new Error('Selected skill is unavailable');return skill;});
}
