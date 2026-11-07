import {execFileSync,spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import pg from '../services/operations/node_modules/pg/lib/index.js';
import {OperationsStore} from '../services/operations/src/store.mjs';
process.chdir(fileURLToPath(new URL('..',import.meta.url)));
if(process.argv.includes('--system-pilot')&&!process.argv.includes('--synthetic'))throw new Error('System pilot requires --synthetic');
if(process.env.DATABASE_URL||process.env.OPS_TEST_DATABASE_URL)throw new Error('Refusing existing database configuration');
const name='construction-ops-test-'+randomBytes(5).toString('hex'),password=randomBytes(24).toString('hex'),dir=resolve('.scratch/operations-db/'+name);mkdirSync(dir,{recursive:true});
const override=resolve(dir,'ports.yaml');writeFileSync(override,'services:\n  db:\n    ports:\n      - "127.0.0.1:0:5432"\nnetworks:\n  test:\n    internal: false\n');
const env={...process.env,CONSTRUCTION_TEST_PASSWORD:password,CONSTRUCTION_TEST_KEY:randomBytes(32).toString('hex'),CONSTRUCTION_TEST_ASSETS:dir.replaceAll('\\','/')};
const docker=(args,input)=>execFileSync('docker',args,{env,input,encoding:'utf8',stdio:['pipe','pipe','pipe'],timeout:120000,maxBuffer:8*1024*1024});
const compose=(args,input)=>docker(['compose','-f',resolve('deploy/compose.test.yaml'),'-f',override,'-p',name,...args],input);
let pool;
try{compose(['up','-d','--wait','db']);compose(['exec','-T','db','createdb','-U','construction_test','construction_ops_test']);const port=Number(compose(['port','db','5432']).trim().split(':').at(-1));if(!port)throw new Error('Missing loopback database port');const url=`postgresql://construction_test:${password}@127.0.0.1:${port}/construction_ops_test`;pool=new pg.Pool({connectionString:url});const store=new OperationsStore(pool);await store.migrate();await pool.query(readFileSync(resolve('deploy/provision-operations.sql'),'utf8'));
 const child=spawn(process.execPath,['--test','--test-concurrency=1',...process.argv.slice(2).filter(x=>!['--system-pilot','--synthetic'].includes(x)),'services/operations/test/*.test.mjs'],{env:{...env,OPS_TEST_DATABASE_URL:url},stdio:'inherit',windowsHide:true});const exit=await new Promise(r=>child.on('exit',r));if(exit!==0)throw new Error('Operations tests failed');
 // Exercise a real logical backup restored into a distinct, clean database.
 const backup=compose(['exec','-T','db','pg_dump','-U','construction_test','--no-owner','--no-privileges','construction_ops_test']);writeFileSync(resolve(dir,'backup.sql'),backup);compose(['exec','-T','db','createdb','-U','construction_test','construction_ops_test_restore']);compose(['exec','-T','db','psql','-X','-v','ON_ERROR_STOP=1','-U','construction_test','-d','construction_ops_test_restore'],backup);const restored=compose(['exec','-T','db','psql','-X','-U','construction_test','-d','construction_ops_test_restore','-At','-c',"SELECT count(*) FROM lead_crm.schema_migrations"]).trim();if(Number(restored)<3)throw new Error('Restore verification failed');
 if(process.argv.includes('--system-pilot')){compose(['exec','-T','db','createdb','-U','construction_test','construction_ops_test_system']);const systemPool=new pg.Pool({connectionString:url.replace('/construction_ops_test','/construction_ops_test_system')});try{const systemStore=new OperationsStore(systemPool);await systemStore.migrate();const {runSystemPilot}=await import('./pilot-construction-system.mjs');const report=await runSystemPilot({operationsService:{store:systemStore},leadCount:20,intervalMs:1000});console.log(JSON.stringify({systemPilot:report.artifactRef,receipts:report.receipts,p95SceneMs:report.p95SceneMs,fakeExtractionCalls:report.actualFakeExtractionCalls}));}finally{await systemPool.end();}}
 writeFileSync(resolve(dir,'evidence.json'),JSON.stringify({project:name,realPostgres:true,tests:'passed',backupRestore:'passed',externalProviders:'not exercised'},null,2));console.log('Operations PostgreSQL tests and backup/restore passed: '+dir);
}finally{await pool?.end();compose(['down','--volumes','--remove-orphans']);}
