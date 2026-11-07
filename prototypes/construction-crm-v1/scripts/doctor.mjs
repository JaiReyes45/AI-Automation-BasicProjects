import {spawnSync} from 'node:child_process';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

export async function doctor({nodeVersion=process.versions.node,probe=(command)=>spawnSync(command,['--version'],{encoding:'utf8',timeout:10000,maxBuffer:16384,windowsHide:true})}={}){
 const match=/^(\d+)\.(\d+)\.(\d+)$/.exec(nodeVersion);
 const nodeOK=!!match&&(Number(match[1])>22||(Number(match[1])===22&&Number(match[2])>=13));
 const checks=[{name:'Node.js',ok:nodeOK,version:match?match[0]:'unknown',action:nodeOK?'Use --experimental-sqlite for the built-in SQLite store.':'Install Node.js 22.13 or newer; built-in SQLite is required.'}];
 for(const [command,name,pattern,action] of [['codex','Codex CLI',/\bcodex(?:-cli)?\s+(\d+\.\d+\.\d+(?:[-+][\w.-]+)?)/i,'Install Codex CLI, add it to PATH, then authenticate separately with codex login.'],['git','Git',/\bgit version\s+(\d+\.\d+\.\d+(?:\.[\w.-]+)?)/i,'Install Git and add it to PATH; workspace change snapshots require Git.']]){
  let result;try{result=await probe(command);}catch{result={status:1};}
  // Extract only the version; never forward runtime stdout/stderr or credentials.
  const version=result.status===0?pattern.exec(String(result.stdout??''))?.[1]:undefined;
  checks.push({name,ok:!!version,version:version??'unavailable',action:version?'Available; this check does not verify account authentication or runtime capabilities.':action});
 }
 return {ok:checks.every(x=>x.ok),checks};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){const result=await doctor();console.log(JSON.stringify(result,null,2));if(!result.ok)process.exitCode=1;}
