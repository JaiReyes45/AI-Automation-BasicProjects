export {projectScene} from '../../contracts/scene-state.mjs';
export function usageLabel(scene){return scene.usage.known?`${scene.usage.inputTokens.toLocaleString()} input · ${scene.usage.outputTokens.toLocaleString()} output tokens`:'Token usage unknown · start limit still enforced';}
