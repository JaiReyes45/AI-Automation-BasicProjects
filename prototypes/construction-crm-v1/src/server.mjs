import {createServer} from 'node:http';
import {timingSafeEqual} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {exportBundle,inspectFailure} from './diagnostics.mjs';
import {seedDemo} from './demo.mjs';
import {handleSiteRoute} from './site/routes.mjs';
const assets=new Map([['/',['index.html','text/html']],['/diagnostics',['diagnostics.html','text/html']],['/app.mjs',['app.mjs','text/javascript']],['/projection.mjs',['projection.mjs','text/javascript']],['/style.css',['style.css','text/css']],...['projection.mjs','renderer.mjs','controller.mjs','connection.mjs','operations-controller.mjs','main.mjs','site.css'].map(f=>['/site/'+f,['site/'+f,f.endsWith('.css')?'text/css':'text/javascript']]),...['sprites.png','sprites.json','LICENSE.txt'].map(f=>['/assets/construction/'+f,['assets/construction/'+f,f.endsWith('.png')?'image/png':f.endsWith('.json')?'application/json':'text/plain']]),...['scene-state.mjs','site-event.mjs'].map(f=>['/contracts/'+f,['../contracts/'+f,'text/javascript']])]);
export async function serve(store,{port=4317,token,runner,siteStore,approvalRegistry,scheduler,operationsClient}={}) {
 if(!token)throw new Error('Authentication token required');
 const streams=new Set();
 const server=createServer(async(req,res)=>{
  const json=(status,value)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(value));};
  const host=req.headers.host;const allowed=[`127.0.0.1:${server.address().port}`,`localhost:${server.address().port}`];
  if(!allowed.includes(host))return json(403,{error:'Invalid local Host'});
  if(req.headers.origin&&req.headers.origin!==`http://${host}`)return json(403,{error:'Invalid Origin'});
  let url;try{url=new URL(req.url,`http://${host}`);}catch{return json(400,{error:'Invalid URL'});}
  if(req.method==='GET'&&assets.has(url.pathname)){
   const [file,type]=assets.get(url.pathname);
   try{const body=readFileSync(fileURLToPath(new URL(`../public/${file}`,import.meta.url)));res.writeHead(200,{'Content-Type':`${type}; charset=utf-8`,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"});res.end(body);}catch{json(404,{error:'Dashboard asset unavailable'});}return;
  }
  const got=Buffer.from(req.headers.authorization??'');const want=Buffer.from(`Bearer ${token}`);
  if(got.length!==want.length||!timingSafeEqual(got,want))return json(401,{error:'Unauthorized'});
  const body=async()=>{let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>65536)throw new Error('Request too large');chunks.push(chunk);}return JSON.parse(Buffer.concat(chunks).toString('utf8'));};
  try{
   if(await handleSiteRoute(req,res,{url,json,body,siteStore,approvalRegistry,scheduler,operationsClient}))return;
   if(req.method==='GET'&&url.pathname==='/health')return json(200,{status:'ok',capture:'metadata-only by default',activeRuns:runner?.active?.size??0,capabilities:{launch:!!runner,inventory:!!runner,liveTools:true,desktopAttach:false,skillCausality:false}});
   if(req.method==='GET'&&url.pathname==='/models'){if(!runner?.models)return json(503,{error:'Runtime model listing unavailable'});return json(200,await runner.models());}
   if(req.method==='GET'&&url.pathname==='/inventory'){
    if(!runner)return json(503,{error:'Runtime unavailable'});
    return json(200,await runner.inventory(url.searchParams.get('workspace')));
   }
   if(req.method==='POST'&&url.pathname==='/launch'){
    if(!runner)return json(503,{error:'Runtime unavailable'});
    return json(202,await runner.launch(await body()));
   }
   if(req.method==='POST'&&url.pathname==='/demo')return json(201,seedDemo(store));
   if(req.method==='POST'&&url.pathname==='/retention'){
    const {days}=await body();if(!Number.isInteger(days)||days<1||days>3650)return json(400,{error:'Retention days must be 1ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ3650'});
    return json(200,{removed:store.purgeBefore(Date.now()-days*86400000)});
   }
   if(req.method==='GET'&&url.pathname==='/runs')return json(200,store.runs().map(r=>({...r,workspaceLabel:store.details(r.runId)?.workspaceLabel??r.runId,synthetic:store.details(r.runId)?.synthetic??false})));
   const match=url.pathname.match(/^\/runs\/([\w.:-]+)(?:\/(export|cancel|failure))?$/);
   if(match){const id=match[1];const detail={...store.project(id),events:store.events(id),details:store.details(id)};
    if(match[2]==='cancel'&&req.method==='POST'){if(!runner)return json(503,{error:'Runtime unavailable'});await runner.cancel(id);return json(200,{status:'interrupted'});}
    if(req.method==='GET'){
     if(!detail.events.length&&!detail.details)return json(404,{error:'Run not found'});
     if(match[2]==='export')return json(200,exportBundle(detail));
     if(match[2]==='failure'){const key=url.searchParams.get('eventId');return json(200,inspectFailure(detail.events,/^\d+$/.test(key??'')?Number(key):key));}
     return json(200,detail);
    }
   }
   if(req.method==='GET'&&url.pathname==='/stream'){
    let cursor=Number(req.headers['last-event-id']??url.searchParams.get('after')??0);
    if(!Number.isSafeInteger(cursor)||cursor<0)return json(400,{error:'Invalid cursor'});
    if(streams.size>=16)return json(503,{error:'Too many streams'});
    res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-store','Connection':'keep-alive'});res.flushHeaders();streams.add(res);let ticks=0,paused=false;
    const write=frame=>{if(res.write(frame))return true;paused=true;res.once('drain',()=>{paused=false;});return false;};
    const tick=()=>{if(paused||res.destroyed)return;try{for(const e of store.after(cursor,100)){cursor=e.id;if(!write(`id: ${e.id}\nevent: event\ndata: ${JSON.stringify(e)}\n\n`))break;}if(!paused&&++ticks%100===0)write(`: heartbeat ${Date.now()}\n\n`);}catch{res.destroy();}};
    tick();const timer=setInterval(tick,100);timer.unref();res.on('close',()=>{clearInterval(timer);streams.delete(res);});return;
   }
   if(req.method==='POST'&&url.pathname==='/events'){const event=store.append(await body());return json(event?201:200,{event,duplicate:!event});}
   json(404,{error:'Not found'});
  }catch(error){json(400,{error:error.message==='Request too large'?'Request too large':'Request could not be completed; check workspace, selection and runtime availability'});}
 });
 server.on('close',()=>{for(const res of streams)res.destroy();});server.requestTimeout=10000;server.headersTimeout=10000;
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});return server;
}
