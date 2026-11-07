import {loadSecretFiles} from './config.mjs';
import {createServer} from 'node:http';
import pg from 'pg';
import {OperationsStore} from './store.mjs';
import {createQualificationAdapter} from './internal.mjs';
import {createOllamaProvider} from './ollama.mjs';
// Dedicated internal listener. Deployment must not publish this container port.
loadSecretFiles();
const pool=new pg.Pool({connectionString:process.env.WORKER_DATABASE_URL}),store=new OperationsStore(pool),model=process.env.EXTRACTION_MODEL;
const provider=process.env.OLLAMA_URL?createOllamaProvider({baseUrl:process.env.OLLAMA_URL,model,authorization:process.env.OLLAMA_AUTHORIZATION}):undefined;
const adapter=createQualificationAdapter({store,sharedToken:process.env.INTERNAL_ADAPTER_TOKEN,provider,modelVersion:model??'unconfigured',maxDailyCalls:Number(process.env.EXTRACTION_MAX_DAILY_CALLS??100)});
const server=createServer(async(req,res)=>{const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};try{const url=new URL(req.url,'http://internal');if(req.method==='GET'&&url.pathname==='/health'){try{await pool.query('SELECT 1');json(200,{status:'ok'});}catch{json(503,{status:'database_unavailable'});}return;}const body=async()=>{let size=0,s='';for await(const chunk of req){size+=chunk.length;if(size>16384)throw new Error('Too large');s+=chunk;}return JSON.parse(s);};if(!await adapter(req,res,{url,body,json}))json(404,{error:'Not found'});}catch{json(400,{error:'Internal qualification request failed'});}});server.requestTimeout=45000;server.listen(Number(process.env.INTERNAL_PORT??8090),'0.0.0.0');process.once('SIGTERM',()=>server.close(async()=>{await pool.end();process.exit();}));
