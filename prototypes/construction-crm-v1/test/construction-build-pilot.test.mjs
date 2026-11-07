import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {runBuildPilot,syntheticPilotRuntime} from '../scripts/pilot-construction-build.mjs';
test('CRM pilot requires corrected check evidence and an explicit concrete owner decision',async()=>{const workspace=mkdtempSync(join(tmpdir(),'construction-pilot-'));try{let reviewed=false;const result=await runBuildPilot({workspace,runtimeFactory:syntheticPilotRuntime,recordOnly:false,ownerDecision:async review=>{assert.equal(review.initialCheckPassed,false);assert.equal(review.correctedCheckPassed,true);assert.equal(review.milestoneCompleted,false);assert.match(review.diff,/Email is required/);reviewed=true;return true;}});assert.equal(reviewed,true);assert.equal(result.outcome,'completed');assert.equal(result.replayMatches,true);assert.equal(result.usageKnown,false);}finally{rmSync(workspace,{recursive:true,force:true});}});
test('record-only pilot never invents an owner release',async()=>{const workspace=mkdtempSync(join(tmpdir(),'construction-pilot-'));try{const result=await runBuildPilot({workspace,runtimeFactory:syntheticPilotRuntime,recordOnly:true});assert.equal(result.outcome,'awaiting_owner_review');assert.equal(result.scene.milestones.foundation,undefined);}finally{rmSync(workspace,{recursive:true,force:true});}});
