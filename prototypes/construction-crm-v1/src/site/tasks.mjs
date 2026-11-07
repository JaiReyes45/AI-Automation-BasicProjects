export function assertSiteId(value){if(typeof value!=='string'||!/^[a-zA-Z0-9_.:-]{1,160}$/.test(value)||Object.hasOwn(Object.prototype,value)||value==='prototype')throw new Error('Invalid site identifier');return value;}
export function validateTaskInput(input,lookup){
 assertSiteId(input.id);assertSiteId(input.projectId);const role=input.role??'builder';if(!['architect','foreman','builder','inspector','storekeeper'].includes(role))throw new Error('Invalid requested role');const dependencies=input.dependencies??[],requestedSkillIds=input.requestedSkillIds??[];
 if(!Array.isArray(dependencies)||!Array.isArray(requestedSkillIds)||dependencies.length>50||requestedSkillIds.length>20)throw new Error('Invalid task lists');
 for(const id of dependencies){assertSiteId(id);if(id===input.id)throw new Error('Dependency cycle');const task=lookup(id);if(!task||task.projectId!==input.projectId)throw new Error('Dependency must exist in this project');}
 for(const id of requestedSkillIds)assertSiteId(id);
 const criteria=input.criteria?.length?input.criteria:[{id:'owner-review',kind:'owner_acceptance'}];if(!Array.isArray(criteria)||criteria.length>20)throw new Error('Invalid criteria');
 const seen=new Set();for(const c of criteria){assertSiteId(c.id);if(seen.has(c.id)||!['runtime_check','owner_acceptance'].includes(c.kind)||Object.keys(c).some(k=>!['id','kind','command','argv','milestoneId'].includes(k)))throw new Error('Invalid criterion');seen.add(c.id);if(c.command!==undefined&&(typeof c.command!=='string'||c.command.length>1024))throw new Error('Invalid command');if(c.argv!==undefined&&(!Array.isArray(c.argv)||c.argv.length>100||c.argv.some(a=>typeof a!=='string'||a.length>4096)))throw new Error('Invalid command arguments');if(c.milestoneId!==undefined)assertSiteId(c.milestoneId);}
 return {id:input.id,projectId:input.projectId,role,label:typeof input.label==='string'?input.label.slice(0,100):input.id,dependencies:[...new Set(dependencies)],requestedSkillIds:[...new Set(requestedSkillIds)],criteria:structuredClone(criteria),state:'queued',version:0,actorId:null};
}
const transitions={queued:['running','cancelled'],running:['verifying','waiting_approval','failed','cancelled'],verifying:['completed','waiting_approval','failed','cancelled'],waiting_approval:['running','verifying','failed','cancelled'],completed:[],failed:[],cancelled:[]};
export function assertTaskTransition(task,{expectedVersion,to,evidenceIds=[]},context){
 if(task.version!==expectedVersion)throw new Error('Task version conflict');if(!transitions[task.state]?.includes(to))throw new Error('Invalid task transition');
 if(to==='running'&&task.state==='queued'&&task.dependencies.some(id=>context.lookup(id)?.state!=='completed'))throw new Error('Dependencies are not complete');
 if(to==='completed')for(const c of task.criteria){const evidence=evidenceIds.map(context.evidence).find(e=>e?.taskId===task.id&&e.criterionId===c.id&&e.kind===c.kind&&e.passed===true&&(c.kind!=='runtime_check'||e.exitCode===0));if(!evidence)throw new Error(`Missing passed criterion evidence: ${c.id}`);}
}
