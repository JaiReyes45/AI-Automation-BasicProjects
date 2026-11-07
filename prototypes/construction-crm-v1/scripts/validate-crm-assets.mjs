import {readFileSync,lstatSync,realpathSync} from 'node:fs';
import {resolve,relative,isAbsolute,sep} from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
export const REQUIRED_WORKFLOWS=['00-orchestrator','01-intake','02-extraction','03-scoring','04-outbox-legacy','05-replay-legacy','10-website-legacy','11-gmail-template','20-hubspot-template'];
export function validateCrmAssets(root){
 root=resolve(root);let manifest;try{manifest=JSON.parse(readFileSync(resolve(root,'manifest.json'),'utf8'));}catch{throw new Error('Missing required CRM manifest');}
 if(manifest.version!==1||!Array.isArray(manifest.assets)||!manifest.assets.length)throw new Error('Empty or invalid asset manifest');
 const required=[...REQUIRED_WORKFLOWS.map(n=>`workflows/${n}.json`),'database/001-core.sql','database/002-scoring-outbox.sql',...['valid-lead','duplicate-lead','invalid-extraction'].map(n=>`fixtures/${n}.json`)];
 const paths=new Set(manifest.assets.map(a=>a.path));for(const p of required)if(!paths.has(p))throw new Error(`Missing required asset: ${p}`);
 const ids=new Set(),data=[];
 for(const a of manifest.assets){
  if(!a.path||isAbsolute(a.path)||a.path.includes('..')||a.path.includes('\\')||!['recovered','derived','reconstructed'].includes(a.origin))throw new Error('Unsafe asset path or provenance');
  const file=resolve(root,a.path);let stat;try{for(const segment of a.path.split('/').map((_,i,all)=>resolve(root,...all.slice(0,i+1))))if(lstatSync(segment).isSymbolicLink())throw new Error('Unsafe symlink');stat=lstatSync(file);}catch(e){if(/symlink/.test(e.message))throw e;throw new Error(`Missing required asset: ${a.path}`);}
  if(!stat.isFile()||relative(root,realpathSync(file)).startsWith(`..${sep}`))throw new Error('Unsafe asset');
  const bytes=readFileSync(file),text=bytes.toString('utf8');
  if(/"(?:access_token|refresh_token|client_secret|private_app_token)"\s*:\s*"(?!REPLACE|CONFIGURE|PLACEHOLDER)[^"]+"/i.test(text))throw new Error(`Credential secret in ${a.path}`);
  if(a.path.startsWith('workflows/')){const d=JSON.parse(text);if(d.active!==false)throw new Error('Active workflow export');if(!d.id||ids.has(d.id))throw new Error('Duplicate workflow identity');ids.add(d.id);if(!Array.isArray(d.nodes)||!d.nodes.length)throw new Error('Empty workflow');if(d.nodes.some(n=>n.credentials))throw new Error('Private credential references must be configured separately');}
  data.push({a,bytes});
 }
 for(const {a,bytes} of data)if(createHash('sha256').update(bytes).digest('hex')!==a.sha256)throw new Error(`Checksum mismatch: ${a.path}`);
 return {workflowCount:ids.size,migrationCount:manifest.assets.filter(a=>/^database\/\d.*\.sql$/.test(a.path)).length,fixtureCount:manifest.assets.filter(a=>a.path.startsWith('fixtures/')).length,provenance:manifest.assets};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){try{const r=validateCrmAssets(process.argv[2]??'integrations/lead-crm');console.log(JSON.stringify({workflowCount:r.workflowCount,migrationCount:r.migrationCount,fixtureCount:r.fixtureCount}));}catch(e){console.error(e.message);process.exitCode=1;}}
