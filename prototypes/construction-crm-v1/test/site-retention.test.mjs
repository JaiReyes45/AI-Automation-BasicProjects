import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Store} from '../src/store.mjs';
import {SiteStore} from '../src/site/store.mjs';
import {tmpdir} from 'node:os';
test('retained event gaps preserve the authoritative scene checkpoint',()=>{const raw=new Store(':memory:');try{const site=new SiteStore(raw.db);site.createProject({id:'p',workspace:tmpdir()});site.createTask({id:'t',projectId:'p'});site.assignActor({taskId:'t'});const before=site.snapshot('p');site.retainEvents('p',0);const after=site.snapshot('p');assert.deepEqual(after,before);assert.equal(site.eventsAfter(0,'p').length,0);assert.equal(site.retainedCursor('p'),before.cursor);}finally{raw.close();}});
