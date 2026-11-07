import {readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomBytes} from 'node:crypto';
import {Store} from './store.mjs';
import {serve} from './server.mjs';
import {Runner} from './runner.mjs';
import {discoverSkills} from './inventory.mjs';
import {exportBundle} from './diagnostics.mjs';
import {seedDemo} from './demo.mjs';
import {SiteStore} from './site/store.mjs';
import {ApprovalRegistry} from './site/approvals.mjs';
import {OperationsClient} from './site/operations-client.mjs';
import {Scheduler} from './site/scheduler.mjs';
const [command,...args]=process.argv.slice(2);
const store=new Store(process.env.ACC_DB??'.data/events.db');store.recoverAbandoned();
const runner=new Runner(store);
try{
 if(command==='serve'){
  const siteStore=new SiteStore(store.db),approvalRegistry=new ApprovalRegistry({siteStore}),scheduler=new Scheduler({siteStore,runner,approvalRegistry});runner.maxConcurrency=1;
  const operationsClient=process.env.OPERATIONS_BASE_URL&&process.env.OPERATIONS_OWNER_TOKEN?new OperationsClient({baseUrl:process.env.OPERATIONS_BASE_URL,ownerToken:process.env.OPERATIONS_OWNER_TOKEN}):undefined;
  const token=process.env.ACC_TOKEN??randomBytes(32).toString('hex');
  const server=await serve(store,{port:Number(process.env.PORT??4317),token,runner,siteStore,approvalRegistry,scheduler,operationsClient});
  console.log(`Dashboard http://127.0.0.1:${server.address().port}\nBearer token (paste into dashboard): ${token}`);
  const stop=async()=>{await scheduler.close();approvalRegistry.close();await runner.close();server.closeAllConnections();server.close(()=>{store.close();process.exit(0);});};process.once('SIGINT',stop);process.once('SIGTERM',stop);
 }else if(command==='import'){
  let count=0;for(const line of readFileSync(args[0],'utf8').split(/\r?\n/).filter(Boolean)){try{if(store.append(JSON.parse(line)))count++;}catch{console.error('Rejected invalid fixture event');process.exitCode=1;}}console.log(`Imported ${count} events`);store.close();
 }else if(command==='launch'){
  const prompt=readFileSync(args[1],'utf8');const {runId}=await runner.launch({workspace:resolve(args[0]??'.'),prompt,captureContent:args.includes('--capture-content'),effort:process.env.ACC_EFFORT??'medium',...(process.env.ACC_MODEL?{model:process.env.ACC_MODEL}:{})});
  console.log(`Run ${runId}`);const cancel=()=>void runner.cancel(runId).catch(()=>{});process.once('SIGINT',cancel);
  const result=await runner.wait(runId);process.removeListener('SIGINT',cancel);console.log(JSON.stringify(result));process.exitCode=result.status==='completed'?0:1;await runner.close();store.close();
 }else if(command==='inventory'){console.log(JSON.stringify(await discoverSkills(resolve(args[0]??'.')),null,2));store.close();
 }else if(command==='demo'){console.log(JSON.stringify(seedDemo(store)));store.close();
 }else if(command==='export'){const runId=args[0];const bundle=exportBundle({...store.project(runId),events:store.events(runId),details:store.details(runId)});writeFileSync(args[1]??`${runId}-diagnostics.json`,JSON.stringify(bundle,null,2));store.close();
 }else if(command==='retention'){const days=Number(args[0]);if(!Number.isInteger(days)||days<1||days>3650)throw new Error('Days must be 1â€“3650');console.log(JSON.stringify({removed:store.purgeBefore(Date.now()-days*86400000)}));store.close();
 }else{console.error('Usage: serve | import <jsonl> | launch <workspace> <prompt.txt> [--capture-content] | inventory <workspace> | demo | export <runId> [file] | retention <days>');store.close();process.exitCode=1;}
}catch{await runner.close();store.close();console.error('Operation failed. Check runtime authentication, workspace, arguments and selected model.');process.exitCode=1;}
