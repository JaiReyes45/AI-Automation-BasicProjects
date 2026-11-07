import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,cpSync,readFileSync,writeFileSync,rmSync,unlinkSync,symlinkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
import {validateCrmAssets} from '../scripts/validate-crm-assets.mjs';

function copy(t){const dir=mkdtempSync(join(tmpdir(),'construction-assets-'));cpSync(resolve('integrations/lead-crm'),dir,{recursive:true});t.after(()=>rmSync(dir,{recursive:true,force:true}));return dir;}
test('CRM validator rejects an empty package instead of passing zero files',t=>{const dir=mkdtempSync(join(tmpdir(),'empty-crm-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));assert.throws(()=>validateCrmAssets(dir),/missing|required|empty/i);});
test('recovered CRM package contains nine inactive workflows, migrations and fixtures',()=>{const r=validateCrmAssets(resolve('integrations/lead-crm'));assert.equal(r.workflowCount,9);assert.ok(r.migrationCount>=2);assert.equal(r.fixtureCount,3);assert.ok(r.provenance.every(a=>a.origin==='recovered'||a.origin==='derived'));});
test('CRM validator rejects a missing required schema',t=>{const dir=copy(t);unlinkSync(join(dir,'database/001-core.sql'));assert.throws(()=>validateCrmAssets(dir),/missing|required/i);});
test('CRM validator rejects active workflows and duplicate workflow identities before checksum verification',t=>{const dir=copy(t),file=join(dir,'workflows/01-intake.json'),d=JSON.parse(readFileSync(file));d.active=true;writeFileSync(file,JSON.stringify(d));assert.throws(()=>validateCrmAssets(dir),/active/i);d.active=false;d.id=JSON.parse(readFileSync(join(dir,'workflows/00-orchestrator.json'))).id;writeFileSync(file,JSON.stringify(d));assert.throws(()=>validateCrmAssets(dir),/duplicate/i);});
test('CRM validator rejects secret values and changed source package bytes',t=>{const dir=copy(t),file=join(dir,'workflows/20-hubspot-template.json'),d=JSON.parse(readFileSync(file));d.secret={access_token:'actual-private-value'};writeFileSync(file,JSON.stringify(d));assert.throws(()=>validateCrmAssets(dir),/credential|secret/i);delete d.secret;d.name+=' altered';writeFileSync(file,JSON.stringify(d));assert.throws(()=>validateCrmAssets(dir),/hash|checksum/i);});
test('CRM validator refuses symlinked files outside the package',t=>{const dir=copy(t),file=join(dir,'database/001-core.sql');unlinkSync(file);symlinkSync(resolve('README.md'),file,'file');assert.throws(()=>validateCrmAssets(dir),/symlink|unsafe/i);});
test('checksummed recovered assets retain exact bytes across Git checkouts',()=>{assert.match(execFileSync('git',['check-attr','text','--','integrations/lead-crm/database/001-core.sql'],{encoding:'utf8'}),/text: unset/);});
