import {execFileSync} from 'node:child_process';
import {lstatSync,realpathSync,openSync,fstatSync,readSync,closeSync,constants} from 'node:fs';
import {isAbsolute,join,relative,resolve,sep} from 'node:path';
import {createHash} from 'node:crypto';
import {redact} from './diagnostics.mjs';

const MAX_FILES=2000,MAX_FILE_BYTES=128*1024,MAX_TOTAL_BYTES=8*1024*1024;
// Contents live only in memory. Serializing a baseline never enables content capture.
const contents=new WeakMap();
const secretName=path=>path.split('/').some(part=>/^(?:\.env(?:\..*)?|\.npmrc|\.pypirc|\.netrc|\.aws|\.ssh|id_(?:rsa|dsa|ecdsa|ed25519)(?:\.pub)?|credentials?(?:\..*)?|secrets?(?:\..*)?|auth\.json|.*\.(?:pem|key|p12|pfx|keystore))$/i.test(part));
const safePath=path=>typeof path==='string'&&path.length<=4096&&!isAbsolute(path)&&!path.includes('\\')&&!path.split('/').some(part=>part==='..'||part==='.'||part==='.git')&&!/[\x00-\x1f\x7f]/.test(path);

function git(cwd,args){return execFileSync('git',['--no-optional-locks','-c','core.fsmonitor=false','-C',cwd,...args],{encoding:'utf8',windowsHide:true,timeout:5000,maxBuffer:2*1024*1024,stdio:['ignore','pipe','pipe'],env:{...process.env,GIT_OPTIONAL_LOCKS:'0'}});}
function failed(reason){return {supported:false,reason,files:[]};}

export function snapshotWorkspace(cwd){
 let root,paths,head,dirty;
 try{
  if(typeof cwd!=='string'||!isAbsolute(cwd))return failed('Workspace must be an absolute directory');
  root=realpathSync(cwd);if(!lstatSync(root).isDirectory())return failed('Workspace is not a directory');
  if(git(root,['rev-parse','--is-inside-work-tree']).trim()!=='true')return failed('Workspace is not a Git work tree');
  paths=[...new Set(git(root,['ls-files','-z','--cached','--others','--exclude-standard','--','.']).split('\0').filter(Boolean))].sort();
  if(paths.length>MAX_FILES)return failed('Workspace file count exceeds snapshot limit');
  try{head=git(root,['rev-parse','--verify','HEAD']).trim();}catch{/* Unborn repositories have no HEAD. */}
  dirty=git(root,['status','--porcelain=v1','-z','--untracked-files=normal','--','.']).length>0;
 }catch{return failed('Git workspace snapshot unavailable');}
 const files=[],text=new Map();let total=0;
 for(const path of paths){
  if(!safePath(path)||secretName(path))continue;
  const entry={path,hash:null};let descriptor;
  try{
   let cursor=root,linked=false;
   for(const part of path.split('/')){cursor=join(cursor,part);if(lstatSync(cursor).isSymbolicLink()){linked=true;break;}}
   if(linked){entry.omitted='symlink';files.push(entry);continue;}
   const absolute=resolve(root,...path.split('/'));const actual=realpathSync(absolute),rel=relative(root,actual);
   if(rel==='..'||rel.startsWith(`..${sep}`)||isAbsolute(rel)){entry.omitted='outside-workspace';files.push(entry);continue;}
   descriptor=openSync(absolute,constants.O_RDONLY|(constants.O_NOFOLLOW??0));const stat=fstatSync(descriptor);
   if(!stat.isFile()){entry.omitted='not-file';files.push(entry);continue;}
   if(stat.size>MAX_FILE_BYTES){entry.omitted='size';files.push(entry);continue;}
   if(total+stat.size>MAX_TOTAL_BYTES)return failed('Workspace content exceeds snapshot limit');
   const bytes=Buffer.alloc(MAX_FILE_BYTES+1);const length=readSync(descriptor,bytes,0,bytes.length,0);total+=length;
   if(length>MAX_FILE_BYTES){entry.omitted='size';files.push(entry);continue;}
   const data=bytes.subarray(0,length);let value;
   try{value=new TextDecoder('utf-8',{fatal:true}).decode(data);}catch{entry.omitted='binary';files.push(entry);continue;}
   if(data.includes(0)||/[\x01-\x08\x0b\x0c\x0e-\x1f]/.test(value)){entry.omitted='binary';files.push(entry);continue;}
   entry.hash=createHash('sha256').update(data).digest('hex');text.set(path,value);
   files.push(entry);
  }catch(error){if(error.code==='ENOENT')continue;entry.omitted='unreadable';files.push(entry);}
  finally{if(descriptor!==undefined)closeSync(descriptor);}
 }
 const snapshot={supported:true,files,...(head?{head}:{}),dirty};contents.set(snapshot,text);return snapshot;
}

export function compareSnapshots(before,after,{captureContent=false}={}){
 if(!before?.supported||!after?.supported||!Array.isArray(before.files)||!Array.isArray(after.files))return [];
 const left=new Map(before.files.filter(f=>safePath(f.path)&&!secretName(f.path)).map(f=>[f.path,f]));
 const right=new Map(after.files.filter(f=>safePath(f.path)&&!secretName(f.path)).map(f=>[f.path,f]));const changes=[];
 for(const path of [...new Set([...left.keys(),...right.keys()])].sort()){
  const a=left.get(path),b=right.get(path);
  if(a?.omitted||b?.omitted)continue; // An omitted file is unknown, not evidence of a change.
  if((a?.hash??null)===(b?.hash??null))continue;
  const change={path,beforeHash:a?.hash??null,afterHash:b?.hash??null,kind:!a?'added':!b?'deleted':'modified',attribution:'unattributed'};
  if(captureContent){
   const old=contents.get(before)?.get(path),next=contents.get(after)?.get(path);
   if((!a||old!==undefined)&&(!b||next!==undefined)){
    // Bounded whole-file diff; no quadratic edit-distance work on arbitrary input.
    change.diff=redact(`--- a/${path}\n+++ b/${path}\n${a?old.split('\n').map(line=>`-${line}`).join('\n'):''}\n${b?next.split('\n').map(line=>`+${line}`).join('\n'):''}`);
   }else change.omitted='content-unavailable';
  }
  changes.push(change);
 }
 return changes;
}
