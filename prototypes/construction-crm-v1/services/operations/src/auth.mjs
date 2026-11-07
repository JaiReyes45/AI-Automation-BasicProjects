import {randomBytes,randomUUID,createHash,timingSafeEqual,createCipheriv,createDecipheriv} from 'node:crypto';
export const tokenHash=value=>createHash('sha256').update(value).digest('hex');
const same=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
export class OwnerAuth{
 static hash=tokenHash;
 constructor({store,encryptionKey,bootstrapHash,clock=Date.now,tokenTtlMs=30*86400000}){if(!Buffer.isBuffer(encryptionKey)||encryptionKey.length!==32)throw new Error('A stable deployment-managed 32-byte key is required');this.store=store;this.key=encryptionKey;this.bootstrapHash=bootstrapHash;this.clock=clock;this.ttl=tokenTtlMs;}
 async bootstrap(secret){if(typeof secret!=='string'||!same(tokenHash(secret),this.bootstrapHash))throw new Error('Bootstrap rejected');const ownerToken=randomBytes(32).toString('base64url'),tokenId=randomUUID();await this.store.transaction(async tx=>{await tx.query('INSERT INTO lead_crm.owner_bootstrap(singleton) VALUES(TRUE)');await tx.query('INSERT INTO lead_crm.owner_tokens(id,token_hash,expires_at) VALUES($1,$2,$3)',[tokenId,tokenHash(ownerToken),new Date(this.clock()+this.ttl)]);});return {ownerToken,tokenId,expiresAt:this.clock()+this.ttl};}
 async authenticate(raw){if(typeof raw!=='string'||raw.length>256)return null;return (await this.store.pool.query('SELECT id,expires_at FROM lead_crm.owner_tokens WHERE token_hash=$1 AND revoked_at IS NULL AND expires_at>$2',[tokenHash(raw),new Date(this.clock())])).rows[0]??null;}
 async revoke(id){await this.store.pool.query('UPDATE lead_crm.owner_tokens SET revoked_at=$2 WHERE id=$1',[id,new Date(this.clock())]);}
 encrypt(data){const iv=randomBytes(12),c=createCipheriv('aes-256-gcm',this.key,iv);c.setAAD(Buffer.from('construction-crm:provider:v1'));const encrypted=Buffer.concat([c.update(JSON.stringify(data),'utf8'),c.final()]);return {v:1,iv:iv.toString('base64'),tag:c.getAuthTag().toString('base64'),data:encrypted.toString('base64')};}
 decrypt(data){if(data?.v!==1)throw new Error('Unsupported encrypted envelope');const c=createDecipheriv('aes-256-gcm',this.key,Buffer.from(data.iv,'base64'));c.setAAD(Buffer.from('construction-crm:provider:v1'));c.setAuthTag(Buffer.from(data.tag,'base64'));return JSON.parse(Buffer.concat([c.update(Buffer.from(data.data,'base64')),c.final()]).toString('utf8'));}
}
