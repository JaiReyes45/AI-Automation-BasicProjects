import {timingSafeEqual} from 'node:crypto';
import {tokenHash} from './auth.mjs';
import {uuid} from './intake.mjs';
import {qualifyLead} from './qualification.mjs';
export function createQualificationAdapter({store,sharedToken,provider,modelVersion,maxDailyCalls=100,evidence='direct'}){
 if(typeof sharedToken!=='string'||sharedToken.length<32)throw new Error('Private adapter credential required');const expected=tokenHash('Bearer '+sharedToken);
 return async(req,res,{url,json,body})=>{if(url.pathname!=='/internal/qualification')return false;if(req.method!=='POST'||!timingSafeEqual(Buffer.from(tokenHash(req.headers.authorization??'')),Buffer.from(expected))){json(401,{error:'Private adapter authentication required'});return true;}const input=await body();if(!uuid(input.submissionRecordId)||!uuid(input.jobId)||Object.keys(input).some(k=>!['submissionRecordId','jobId'].includes(k))){json(400,{error:'Existing lead and job identifiers required'});return true;}json(200,await qualifyLead(input,{store,provider,modelVersion,maxDailyCalls,evidence}));return true;};
}
export function createWorkflowQualifier({url,token,fetchImpl=fetch}){const endpoint=new URL(url);if(!['http:','https:'].includes(endpoint.protocol)||!token)throw new Error('Private workflow endpoint and credential required');return async input=>{const r=await fetchImpl(endpoint,{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(input),signal:AbortSignal.timeout(45000)});if(!r.ok)throw new Error('Qualification workflow unavailable');const result=await r.json();if(!['CRM_SYNC_PENDING','REVIEW_REQUIRED','INVALID','ANALYZING','CRM_SYNCED'].includes(result.processingStatus))throw new Error('Qualification workflow has no durable result');return result;};}
