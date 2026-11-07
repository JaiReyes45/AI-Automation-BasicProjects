export const EVENT_TYPES=['actor.assigned','task.queued','task.started','task.verifying','task.waiting_approval','task.completed','task.failed','task.cancelled','tool.started','tool.completed','tool.failed','skill.requested','skill.observed','approval.requested','approval.decided','usage.observed','milestone.completed','lead.received','lead.qualified','lead.review_required','crm.pending','crm.synced','crm.failed','appointment.unverified','appointment.confirmed','appointment.cancelled','appointment.rescheduled','review.resolved','outbox.replayed','outbox.stopped'];
const statuses=new Set('queued running verifying waiting_approval completed failed cancelled unknown pending review_required synced unverified confirmed rescheduled'.split(' '));
const id=(value)=>typeof value==='string'&&/^[a-zA-Z0-9_.:-]{1,160}$/.test(value)&&!Object.hasOwn(Object.prototype,value)&&value!=='prototype';
export function toPublicSummary(input){const type=EVENT_TYPES.includes(input?.type)?input.type:null;if(!type)return 'Unrecognized activity';return type.replaceAll('_',' ').split('.').map((x,i)=>i===0?x[0].toUpperCase()+x.slice(1):x).join(' ');}
export function validateSiteEvent(input){
 if(!input||typeof input!=='object')throw new Error('Event required');
 const e={};for(const key of ['eventId','sourceEventId','projectId']){if(!id(input[key]))throw new Error(`Invalid ${key}`);e[key]=input[key];}
 if(!['build-runtime','build-policy','operations'].includes(input.source)||!['build','operate'].includes(input.mode))throw new Error('Invalid event source or mode');
 const operations=/^(lead|crm|appointment|review|outbox)\./.test(input.type??'');if(!EVENT_TYPES.includes(input.type)||operations!==(input.source==='operations')||(input.source==='operations')!==(input.mode==='operate'))throw new Error('Unsupported event type/source combination');
 if(!Number.isSafeInteger(input.sequence)||input.sequence<0||!statuses.has(input.status)||!['direct','correlated','unknown','synthetic'].includes(input.evidence))throw new Error('Invalid sequence, status or evidence');
 Object.assign(e,{source:input.source,mode:input.mode,sequence:input.sequence,type:input.type,status:input.status,evidence:input.evidence});
 for(const key of ['actorId','taskId','skillId','milestoneId','leadId','appointmentId','correlationId'])if(input[key]!==undefined){if(!id(input[key]))throw new Error(`Invalid ${key}`);e[key]=input[key];}
 for(const key of ['occurredAt','receivedAt'])if(input[key]!==undefined){if(!Number.isSafeInteger(input[key])||input[key]<0)throw new Error('Invalid event time');e[key]=input[key];}
 if(input.role!==undefined){if(!['architect','foreman','builder','inspector','storekeeper'].includes(input.role))throw new Error('Invalid role');e.role=input.role;}
 if(input.usage!==undefined){if(!input.usage||typeof input.usage.measured!=='boolean')throw new Error('Invalid usage');e.usage={measured:input.usage.measured};for(const key of ['inputTokens','outputTokens','cachedTokens'])if(input.usage[key]!==undefined){if(!Number.isSafeInteger(input.usage[key])||input.usage[key]<0)throw new Error('Invalid usage count');e.usage[key]=input.usage[key];}}
 e.publicSummary=toPublicSummary(e);return e;
}
