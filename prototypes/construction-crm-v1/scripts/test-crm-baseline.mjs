import {readFileSync,writeFileSync,mkdirSync,mkdtempSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {randomBytes,randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
import {validateCrmAssets} from './validate-crm-assets.mjs';

export function runCrmBaseline({composeFile=resolve('deploy/compose.test.yaml'),projectName=`construction-test-${randomBytes(5).toString('hex')}`}={}){
 if(!/^construction-test-[a-f0-9]{10}$/.test(projectName)||process.env.DATABASE_URL)throw new Error('Only a generated disposable test project is permitted; unset DATABASE_URL');
 const root=resolve('integrations/lead-crm'),assets=validateCrmAssets(root),base=resolve('.scratch/crm-baseline');mkdirSync(base,{recursive:true});const dir=mkdtempSync(join(base,'run-'));mkdirSync(join(dir,'workflows'));
 const password=randomBytes(18).toString('hex'),env={...process.env,CONSTRUCTION_TEST_PASSWORD:password,CONSTRUCTION_TEST_KEY:randomBytes(32).toString('hex'),CONSTRUCTION_TEST_ASSETS:dir.replaceAll('\\','/')};
 const checks=[];let serial=0;
 const docker=(args,input)=>execFileSync('docker',args,{env,input,encoding:'utf8',timeout:180000,maxBuffer:8*1024*1024,stdio:['pipe','pipe','pipe']});
 const compose=(args,input)=>docker(['compose','-f',composeFile,'-p',projectName,...args],input);
 const sql=q=>compose(['exec','-T','db','psql','-X','-v','ON_ERROR_STOP=1','-U','construction_test','-d','construction_test','-At'],q).trim();
 const alias=JSON.parse(readFileSync(join(root,'manifest.json'))).workflowAliases;
 for(const [name,id] of Object.entries(alias)){
  const d=JSON.parse(readFileSync(join(root,'workflows',name+'.json')));
  for(const n of d.nodes){if(n.type.endsWith('.postgres'))n.credentials={postgres:{id:'construction-test-pg',name:'Construction test PostgreSQL'}};if(n.type.endsWith('.httpRequest')&&String(n.parameters.url).includes('ollama:'))n.parameters.url='http://127.0.0.1:11434/api/generate';}
  writeFileSync(join(dir,'workflows',name+'.json'),JSON.stringify(d));
 }
 writeFileSync(join(dir,'credentials.json'),JSON.stringify([{id:'construction-test-pg',name:'Construction test PostgreSQL',type:'postgres',data:{host:'db',database:'construction_test',user:'construction_test',password,port:5432,ssl:'disable'}}]));
 writeFileSync(join(dir,'model-mock.cjs'),`require('node:http').createServer((req,res)=>{let b='';req.on('data',x=>b+=x);req.on('end',()=>{res.setHeader('content-type','application/json');res.end(JSON.stringify({response:JSON.stringify({schema_version:'1.0',service_category:'invoice_approval_automation',purchase_timeline:'days_31_90',decision_maker_status:'decision_maker',location_country_code:'PH',need_summary:'Automate invoice processing and approval routing for the operations team.',confidence:0.95})}));});}).listen(11434,'127.0.0.1');`);
 function execute(name,input){
  const id='construction-test-case-'+(++serial),d=JSON.parse(readFileSync(join(dir,'workflows',name+'.json'))),trigger=d.nodes.find(n=>n.type.endsWith('.executeWorkflowTrigger'));
  if(!trigger)throw new Error(`No input trigger for ${name}`);
  const target=d.connections[trigger.name];
  const triggers=d.nodes.filter(n=>n.type.endsWith('.manualTrigger')||n.type.endsWith('.executeWorkflowTrigger'));
  d.nodes=d.nodes.filter(n=>!triggers.includes(n));for(const t of triggers)delete d.connections[t.name];
  d.id=id;d.name=id;d.nodes.push({id:'test-start',name:'Baseline Start',type:'n8n-nodes-base.manualTrigger',typeVersion:1,position:[-400,0],parameters:{}},{id:'test-input',name:'Baseline Fixture',type:'n8n-nodes-base.code',typeVersion:2,position:[-200,0],parameters:{jsCode:`return [{json:${JSON.stringify(input)}}];`}});
  d.connections['Baseline Start']={main:[[{node:'Baseline Fixture',type:'main',index:0}]]};d.connections['Baseline Fixture']=target;
  writeFileSync(join(dir,'case.json'),JSON.stringify(d));
  compose(['exec','-T','n8n','n8n','import:workflow','--input=/test/case.json']);
  let output;try{output=compose(['exec','-T','n8n','n8n','execute',`--id=${id}`,'--rawOutput']);}catch(e){writeFileSync(join(dir,`case-${serial}-error.log`),String(e.stdout??'')+String(e.stderr??''));throw new Error(`Recovered workflow ${name} failed; inspect ${dir}/case-${serial}-error.log`);}
  writeFileSync(join(dir,`case-${serial}.log`),output);
 }
 try{
  compose(['up','-d','--wait','db','n8n']);
  for(const file of ['001-core.sql','002-scoring-outbox.sql'])sql(readFileSync(join(root,'database',file),'utf8'));
  for(const file of ['001_core_schema_smoke_test.sql','002_core_constraints_test.sql','003_scoring_outbox_smoke_test.sql']){sql(readFileSync(join(root,'database/tests',file),'utf8'));checks.push({name:file,status:'passed',mode:'synthetic'});}
  compose(['exec','-T','n8n','n8n','import:credentials','--input=/test/credentials.json']);
  compose(['exec','-T','n8n','n8n','import:workflow','--separate','--input=/test/workflows']);
  writeFileSync(join(dir,'bridge.json'),readFileSync(join(root,'workflows/30-qualify-existing-lead.json')));compose(['exec','-T','n8n','n8n','import:workflow','--input=/test/bridge.json']);checks.push({name:'qualification-bridge-import',status:'passed',mode:'synthetic-definition-only'});
  compose(['exec','-d','n8n','node','/test/model-mock.cjs']);
  const fixture=JSON.parse(readFileSync(join(root,'fixtures/valid-lead.json'))),lead={...fixture,submission_id:randomUUID()};
  execute('01-intake',lead);assert.equal(sql(`SELECT processing_status FROM lead_crm.lead_submissions WHERE submission_id='${lead.submission_id}'`),'AI_PENDING');checks.push({name:'valid-intake',status:'passed',mode:'synthetic'});
  execute('01-intake',lead);assert.equal(sql(`SELECT count(*) FROM lead_crm.lead_submissions WHERE submission_id='${lead.submission_id}'`),'1');checks.push({name:'idempotent-intake',status:'passed',mode:'synthetic'});
  execute('01-intake',{...lead,message:lead.message+' changed'});assert.equal(sql(`SELECT processing_status FROM lead_crm.lead_submissions WHERE submission_id='${lead.submission_id}'`),'REVIEW_REQUIRED');checks.push({name:'conflict-review',status:'passed',mode:'synthetic'});
  const invalid={...lead,submission_id:randomUUID(),consent:false};execute('01-intake',invalid);assert.equal(sql(`SELECT processing_status FROM lead_crm.lead_submissions WHERE submission_id='${invalid.submission_id}'`),'INVALID');checks.push({name:'consent-rejection',status:'passed',mode:'synthetic'});
  for(const [name,flags,expected] of [['valid-extraction',{},'SCORING'],['repair-extraction',{force_invalid_first_attempt:true},'SCORING'],['review-extraction',{force_invalid_all_attempts:true},'REVIEW_REQUIRED']]){
   const p={...lead,submission_id:randomUUID()};execute('01-intake',p);const record=JSON.parse(sql(`SELECT row_to_json(x) FROM (SELECT id AS submission_record_id,correlation_id,processing_status FROM lead_crm.lead_submissions WHERE submission_id='${p.submission_id}') x`));
   execute('02-extraction',{...p,...record,...flags});assert.equal(sql(`SELECT processing_status FROM lead_crm.lead_submissions WHERE id='${record.submission_record_id}'`),expected);checks.push({name,status:'passed',mode:'synthetic-model'});
   if(name==='valid-extraction'){execute('03-scoring',record);assert.equal(sql(`SELECT processing_status FROM lead_crm.lead_submissions WHERE id='${record.submission_record_id}'`),'CRM_SYNC_PENDING');assert.ok(Number(sql(`SELECT lead_score FROM lead_crm.lead_submissions WHERE id='${record.submission_record_id}'`))>=70);checks.push({name:'deterministic-scoring',status:'passed',mode:'synthetic'});}
  }
  assert.ok(checks.length>=10);const report={projectName,assets:{workflows:assets.workflowCount,migrations:assets.migrationCount,fixtures:assets.fixtureCount},checks,externalIntegrations:'not exercised',model:'stub only'};const evidencePath=join(dir,'evidence.json');writeFileSync(evidencePath,JSON.stringify(report,null,2));return {...report,evidencePath};
 }finally{compose(['down']);}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){try{const r=runCrmBaseline();console.log(JSON.stringify(r,null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
