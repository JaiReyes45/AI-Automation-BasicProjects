import {CodexClient} from '../src/codex.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
const client=new CodexClient({timeoutMs:12000});const events=[];let finish;
const done=new Promise(resolve=>finish=resolve);
client.on('notification',m=>{events.push({method:m.method,itemType:m.params?.item?.type,status:m.params?.turn?.status,exitCode:m.params?.item?.exitCode,error:m.method==='error'?m.params?.error?.message:undefined});if(m.method==='turn/completed')finish();});
client.on('closed',()=>finish());
const timer=setTimeout(finish,60000);
try{
 await client.initialize();events.push({check:'initialize',status:'passed'});
 const cwd=resolve('.scratch/probe-project');mkdirSync(cwd,{recursive:true});writeFileSync(resolve(cwd,'SKILL.md'),'# Probe fixture\nRead and report this fixture.');
 const t=await client.request('thread/start',{cwd,ephemeral:true,sandbox:'workspace-write',approvalPolicy:'never'});events.push({check:'thread/start',status:'passed'});
 await client.request('turn/start',{threadId:t.thread.id,input:[{type:'text',text:'Integration test: read SKILL.md in this directory, write probe.txt containing hello, execute a command that exits with code 7, then report done. Work only in this directory.'}],effort:'low'});
 await done;
}catch(e){events.push({check:'probe',error:e.message});}
finally{clearTimeout(timer);await client.close();mkdirSync('.scratch',{recursive:true});writeFileSync('.scratch/probe-events.json',JSON.stringify(events,null,2));console.log(JSON.stringify(events));}
