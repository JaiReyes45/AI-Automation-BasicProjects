import {loadSecretFiles} from './config.mjs';
import pg from 'pg';
import {randomUUID} from 'node:crypto';
import {OperationsStore} from './store.mjs';
import {OwnerAuth} from './auth.mjs';
import {createJobQueue} from './queue.mjs';
import {startWorker,createStagePolicyReader} from './worker.mjs';
import {HubSpotProvider,syncLead,applyConfirmedBookingStage} from './hubspot.mjs';
import {createGhlReader} from './bookings.mjs';
import {createWorkflowQualifier} from './internal.mjs';
loadSecretFiles();
const pool=new pg.Pool({connectionString:process.env.WORKER_DATABASE_URL}),store=new OperationsStore(pool),secrets=new OwnerAuth({store,encryptionKey:Buffer.from(process.env.OPERATIONS_ENCRYPTION_KEY??'','hex')}),queue=createJobQueue({store}),abort=new AbortController();
const qualifier=process.env.QUALIFICATION_WORKFLOW_URL?createWorkflowQualifier({url:process.env.QUALIFICATION_WORKFLOW_URL,token:process.env.QUALIFICATION_WORKFLOW_TOKEN}):undefined;
const hubspot=async(job,{signal,reconcileOnly})=>{const connection=(await pool.query("SELECT * FROM lead_crm.integration_connections WHERE provider='HUBSPOT'")).rows[0];if(connection?.state!=='VERIFIED')return {kind:'review',reason:'HUBSPOT_UNVERIFIED'};const {token}=secrets.decrypt(connection.encrypted_credentials);const context={store,provider:new HubSpotProvider({token}),config:{...connection.config,verified:true},signal,reconcileOnly};return job.payload?.action==='confirmed_booking_stage'?applyConfirmedBookingStage(job,context):syncLead({submissionId:job.submission_id},context);};
const bookingReader=async id=>{const c=(await pool.query("SELECT * FROM lead_crm.integration_connections WHERE provider='GHL' AND state='VERIFIED'")).rows[0];if(!c)throw Object.assign(new Error('Booking provider unverified'),{kind:'review'});const {token}=secrets.decrypt(c.encrypted_credentials);return createGhlReader({token,...c.config})(id);};
process.once('SIGTERM',()=>abort.abort());process.once('SIGINT',()=>abort.abort());try{await startWorker({queue,store,workerId:randomUUID(),qualifier,hubspot,bookingReader,stagePolicy:createStagePolicyReader({store})},{signal:abort.signal});}finally{await pool.end();}
