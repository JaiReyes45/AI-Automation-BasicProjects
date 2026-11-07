import {createInterface} from 'node:readline';
const send=m=>{const line=JSON.stringify(m)+'\n';process.stdout.write(line.slice(0,4));setTimeout(()=>process.stdout.write(line.slice(4)),1);};
createInterface({input:process.stdin}).on('line',line=>{const m=JSON.parse(line);
 if(m.method==='initialize')send({id:m.id,result:{}});
 if(m.method==='echo')send({id:m.id,result:m.params});
 if(m.method==='ask'){globalThis.askId=m.id;send({id:999,method:'item/commandExecution/requestApproval',params:m.params.approval??{}});}
 if(m.id===999)send({id:globalThis.askId,result:{denied:m.result?.decision==='decline'}});
 if(m.method==='exit')process.exit(0);
});
