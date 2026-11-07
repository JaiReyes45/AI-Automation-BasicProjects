// Existing evidence must remain usable when the optional coding runtime is offline.
export async function loadWorkspaceContext({readProjects,readModels,onProjects,onModels,onModelError}){
 const modelRequest=Promise.resolve().then(readModels).then(onModels).catch(onModelError);
 const projects=await readProjects();await onProjects(projects);return {projects,modelRequest};
}
