import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {OperationsStore} from '../src/store.mjs';
import {OwnerAuth} from '../src/auth.mjs';
import {testPool} from './support.mjs';
test('auth: one-time bootstrap, expiry, revocation and authenticated encryption',async()=>{const pool=testPool(),store=new OperationsStore(pool);try{await store.migrate();let now=1000;const auth=new OwnerAuth({store,encryptionKey:randomBytes(32),bootstrapHash:OwnerAuth.hash('synthetic-bootstrap'),clock:()=>now});const {ownerToken,tokenId}=await auth.bootstrap('synthetic-bootstrap');assert.ok(await auth.authenticate(ownerToken));now=31*86400000;assert.equal(await auth.authenticate(ownerToken),null);now=1000;await assert.rejects(auth.bootstrap('synthetic-bootstrap'));const raw=JSON.stringify((await pool.query('SELECT * FROM lead_crm.owner_tokens')).rows);assert.equal(raw.includes(ownerToken),false);const sealed=auth.encrypt({token:'fake-provider-token'});assert.deepEqual(auth.decrypt(sealed),{token:'fake-provider-token'});await assert.rejects(async()=>auth.decrypt({...sealed,tag:randomBytes(16).toString('base64')}));await auth.revoke(tokenId);assert.equal(await auth.authenticate(ownerToken),null);assert.equal(await auth.authenticate('guess'),null);}finally{await pool.end();}});
