import {test} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
test('setup: generated deployment secrets are create-only and key material remains stable',()=>{const dir=mkdtempSync(join(tmpdir(),'construction-setup-')),target=join(dir,'private'),script=fileURLToPath(new URL('../src/manage.mjs',import.meta.url));try{const out=execFileSync(process.execPath,[script,'setup','--directory',target],{encoding:'utf8'});const key=readFileSync(join(target,'operations_encryption_key'),'utf8').trim(),secret=readFileSync(join(target,'owner_bootstrap_secret'),'utf8').trim(),hash=readFileSync(join(target,'owner_bootstrap_hash'),'utf8').trim();assert.equal(Buffer.from(key,'hex').length,32);assert.equal(hash,createHash('sha256').update(secret).digest('hex'));assert.equal(out.includes(secret),false);assert.throws(()=>execFileSync(process.execPath,[script,'setup','--directory',target],{stdio:'ignore'}));assert.equal(readFileSync(join(target,'operations_encryption_key'),'utf8').trim(),key);}finally{rmSync(dir,{recursive:true,force:true});}});
