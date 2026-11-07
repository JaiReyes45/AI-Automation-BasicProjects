import {spawn} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {redact} from '../diagnostics.mjs';
export async function runTaskCheck({taskId,criterionId},{siteStore,timeoutMs=120000,artifactRoot=resolve('.data/site-checks'),signal,captureContent=false}={}){
 const task=siteStore.task(taskId),criterion=task?.criteria.find(c=>c.id===criterionId),project=task&&siteStore.project(task.projectId);
 if(!criterion||criterion.kind!=='runtime_check'||!criterion.command||task.state!=='verifying')throw new Error('Configured verifier required for a verifying task');
 const id=randomUUID(),version=task.version;let output='',bytes=0,timedOut=false,aborted=signal?.aborted??false,child;
 const result=await new Promise(done=>{
  let ended=false,timer;const finish=(exitCode,error)=>{if(ended)return;ended=true;clearTimeout(timer);signal?.removeEventListener('abort',abort);done({exitCode,error});};
  const stop=()=>{if(!child?.pid)return;if(process.platform==='win32'){const kill=spawn('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});kill.on('error',()=>child.kill());}else{try{process.kill(-child.pid,'SIGKILL');}catch{child.kill();}}};
  const abort=()=>{aborted=true;stop();};
  try{child=spawn(criterion.command,criterion.argv??[],{cwd:project.workspace,shell:false,windowsHide:true,detached:process.platform!=='win32',stdio:['ignore','pipe','pipe']});}catch{return finish(null,'Unsupported verifier command');}
  const drain=chunk=>{bytes+=chunk.length;if(captureContent&&output.length<16384)output+=chunk.toString('utf8').slice(0,16384-output.length);};child.stdout.on('data',drain);child.stderr.on('data',drain);child.once('error',()=>finish(null,'Verifier could not start'));child.once('close',code=>finish(code,null));timer=setTimeout(()=>{timedOut=true;stop();},timeoutMs);signal?.addEventListener('abort',abort,{once:true});if(aborted)stop();
 });
 const current=siteStore.task(taskId),stale=current?.state!=='verifying'||current.version!==version;
 const evidence={id,taskId,criterionId,kind:'runtime_check',passed:result.exitCode===0&&!timedOut&&!aborted&&!stale,exitCode:result.exitCode,artifactRef:`checks/${id}.json`,timedOut,aborted,stale,outputBytes:bytes,error:result.error};
 mkdirSync(artifactRoot,{recursive:true});writeFileSync(join(artifactRoot,id+'.json'),JSON.stringify({...evidence,...(captureContent?{output:redact(output)}:{})},null,2),{mode:0o600});siteStore.recordEvidence(evidence);return evidence;
}
