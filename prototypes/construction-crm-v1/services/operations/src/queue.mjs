import {randomUUID} from 'node:crypto';
import {appendOperationEvent} from './intake.mjs';
export function createJobQueue({store,clock=Date.now,random=Math.random,evidence='direct'}){
 async function publishState(tx,job,status){
  if(job.job_type==='CRM_SYNC'&&job.submission_id&&job.payload?.action!=='confirmed_booking_stage'){
   const sent=status==='SENT',pending=['PENDING','RETRY','PROCESSING'].includes(status);
   await tx.query('UPDATE lead_crm.lead_submissions SET processing_status=$2 WHERE id=$1',[job.submission_id,sent?'CRM_SYNCED':pending?'CRM_SYNC_PENDING':'SYNC_FAILED']);
   await appendOperationEvent(store,tx,{type:sent?'crm.synced':pending?'crm.pending':'crm.failed',status:sent?'synced':pending?'pending':'failed',leadId:job.submission_id,evidence});
  }
  if(['DEAD_LETTER','REVIEW_REQUIRED'].includes(status))await appendOperationEvent(store,tx,{type:'outbox.stopped',status:'failed',leadId:job.submission_id??undefined,evidence});
 }
 async function claimJob({workerId,leaseMs=60000}){
  if(typeof workerId!=='string'||!workerId||leaseMs!==60000)throw new Error('Use a named worker and the 60-second lease');
  return store.transaction(async tx=>{
   const expired=(await tx.query("UPDATE lead_crm.outbox_jobs SET status='DEAD_LETTER',version=version+1,needs_reconciliation=TRUE,lease_token=NULL,lease_until=NULL WHERE status='PROCESSING' AND lease_until<=$1 AND attempt_count>=max_attempts RETURNING *",[new Date(clock())])).rows;
   for(const job of expired)await publishState(tx,job,'DEAD_LETTER');
   const job=(await tx.query("SELECT * FROM lead_crm.outbox_jobs WHERE ((status IN('PENDING','RETRY') AND available_at<=$1) OR (status='PROCESSING' AND lease_until<=$1)) AND attempt_count<max_attempts ORDER BY available_at,created_at,id FOR UPDATE SKIP LOCKED LIMIT 1",[new Date(clock())])).rows[0];if(!job)return null;
   const token=randomUUID(),row=(await tx.query("UPDATE lead_crm.outbox_jobs SET status='PROCESSING',attempt_count=attempt_count+1,version=version+1,needs_reconciliation=needs_reconciliation OR status='PROCESSING',worker_id=$2,lease_token=$3,lease_until=$4,locked_at=$5 WHERE id=$1 RETURNING *",[job.id,workerId,token,new Date(clock()+leaseMs),new Date(clock())])).rows[0];return {...row,leaseToken:token,needsReconciliation:row.needs_reconciliation};
  });
 }
 async function heartbeatJob({jobId,leaseToken}){const r=await store.pool.query("UPDATE lead_crm.outbox_jobs SET lease_until=$3 WHERE id=$1 AND lease_token=$2 AND status='PROCESSING' AND lease_until>$4 RETURNING id",[jobId,leaseToken,new Date(clock()+60000),new Date(clock())]);if(!r.rowCount)throw new Error('Lease expired or replaced');return true;}
 async function finishJob({jobId,leaseToken,outcome}){
  if(!['delivered','retry','review','unknown'].includes(outcome?.kind))throw new Error('Explicit delivery outcome required');
  return store.transaction(async tx=>{
   const job=(await tx.query("SELECT * FROM lead_crm.outbox_jobs WHERE id=$1 AND lease_token=$2 AND status='PROCESSING' AND lease_until>$3 FOR UPDATE",[jobId,leaseToken,new Date(clock())])).rows[0];if(!job)throw new Error('Lease expired or replaced');
   if(outcome.kind==='delivered'&&(!outcome.externalIds||!Object.values(outcome.externalIds).length||Object.values(outcome.externalIds).some(id=>typeof id!=='string'||!id)))throw new Error('Confirmed external references required');
   const retry=['retry','unknown'].includes(outcome.kind),status=outcome.kind==='delivered'?'SENT':outcome.kind==='review'?'REVIEW_REQUIRED':job.attempt_count>=job.max_attempts?'DEAD_LETTER':'RETRY',delay=Math.min(86400000,Math.max(1000,Number.isFinite(outcome.retryAfterMs)?outcome.retryAfterMs:1000*2**job.attempt_count+Math.floor(random()*1000))),reason=/^[A-Z0-9_]{1,80}$/.test(outcome.reason??'')?outcome.reason:outcome.kind.toUpperCase();
   await tx.query('UPDATE lead_crm.outbox_jobs SET status=$2,available_at=$3,lease_token=NULL,lease_until=NULL,version=version+1,needs_reconciliation=$4,last_error=$5,external_reference=$6,sent_at=$7 WHERE id=$1',[job.id,status,new Date(clock()+(retry?delay:0)),outcome.kind==='unknown'||(job.needs_reconciliation&&outcome.kind!=='delivered'),outcome.kind==='delivered'?null:reason,outcome.kind==='delivered'?JSON.stringify(outcome.externalIds):null,outcome.kind==='delivered'?new Date(clock()):null]);
   if(status==='REVIEW_REQUIRED')await tx.query("INSERT INTO lead_crm.review_queue(submission_id,job_id,reason_code,reason_detail) VALUES($1,$2,$3,$4) ON CONFLICT(job_id) WHERE status='OPEN' AND job_id IS NOT NULL DO UPDATE SET reason_code=excluded.reason_code,reason_detail=excluded.reason_detail,version=lead_crm.review_queue.version+1",[job.submission_id,job.id,reason,{jobVersion:job.version+1}]);
   await publishState(tx,job,status);return {status,version:job.version+1};
  });
 }
 async function replayDeadLetter({id,version,ownerId}){return store.transaction(async tx=>{const job=(await tx.query("UPDATE lead_crm.outbox_jobs SET status='RETRY',attempt_count=0,available_at=$3,version=version+1,needs_reconciliation=TRUE WHERE id=$1 AND version=$2 AND status='DEAD_LETTER' RETURNING *",[id,version,new Date(clock())])).rows[0];if(!job)throw new Error('Replay version/state conflict');await tx.query("INSERT INTO lead_crm.policy_decisions(submission_id,kind,data) VALUES($1,'DEAD_LETTER_REPLAY',$2)",[job.submission_id,{ownerId,jobId:id,version}]);await appendOperationEvent(store,tx,{type:'outbox.replayed',status:'pending',leadId:job.submission_id??undefined,evidence});return {id,version:job.version};});}
 async function resumeReviewedJob({jobId,version,ownerId},tx){const work=async tx=>{const job=(await tx.query("UPDATE lead_crm.outbox_jobs SET status='RETRY',attempt_count=0,available_at=$3,version=version+1,needs_reconciliation=TRUE WHERE id=$1 AND version=$2 AND status='REVIEW_REQUIRED' RETURNING *",[jobId,version,new Date(clock())])).rows[0];if(!job)throw new Error('Reviewed job version/state conflict');await tx.query("INSERT INTO lead_crm.policy_decisions(submission_id,kind,data) VALUES($1,'REVIEWED_JOB_RETRY',$2)",[job.submission_id,{ownerId,jobId,version}]);await appendOperationEvent(store,tx,{type:'outbox.replayed',status:'pending',leadId:job.submission_id??undefined,evidence});return {id:job.id,version:job.version};};return tx?work(tx):store.transaction(work);}
 return {claimJob,heartbeatJob,finishJob,replayDeadLetter,resumeReviewedJob};
}
