// Observation never depends on CRM delivery reaching a terminal state.
export function createReceiptObserver({readReceipt,onUpdate,onError=()=>{},onPaused=()=>{},now=Date.now,setTimer=setTimeout,clearTimer=clearTimeout,pollMs=10000,maxObservationMs=30*60000}){
 let generation=0,timer,abort,started=0,failures=0;
 const stop=()=>{generation++;clearTimer(timer);timer=undefined;abort?.abort();};
 async function start(){stop();const current=generation;started=now();failures=0;abort=new AbortController();
  const poll=async()=>{if(current!==generation)return;if(now()-started>=maxObservationMs){onPaused('Automatic checks paused. Check status to continue.');return;}
   let delay=pollMs;try{const receipt=await readReceipt({signal:abort.signal});if(current!==generation)return;failures=0;onUpdate(receipt);}
   catch(error){if(current!==generation)return;if(error.status===404){onPaused('This receipt has expired. Your enquiry may still be processing.');return;}failures++;delay=error.status===429?Math.min(60000,Math.max(1000,Number(error.retryAfterMs)||15000)):Math.min(60000,pollMs*2**Math.min(failures,3));onError('Status is temporarily unavailable. Checking again shortly.');}
   if(current===generation)timer=setTimer(poll,Math.min(delay,Math.max(1,maxObservationMs-(now()-started))));
  };await poll();
 }
 return {start,stop};
}
