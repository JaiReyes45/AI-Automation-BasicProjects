window.careerProfile = async function(method, path, body) {
 const r = await fetch(path, {method, headers: {'Content-Type':'application/json','X-CareerFlow':'local-profile'}, ...(body ? {body} : {})});
 const data = await r.json(); if (!r.ok) throw new Error(data.error || 'Storage unavailable'); return JSON.stringify(data);
};
window.careerUpload = function(category) {
 return new Promise((resolve,reject) => {
 const input=document.createElement('input'); input.type='file'; input.accept='.pdf,.docx,.png,.jpg,.jpeg';
 input.addEventListener('cancel',()=>resolve('cancelled'));
 input.onchange=async()=>{try {const f=input.files[0]; if(!f){resolve('cancelled');return;} if(f.size>8388608) throw new Error('Maximum file size is 8 MB.');
 const reader=new FileReader(); reader.onerror=()=>reject(new Error('Could not read file'));
 reader.onload=async()=>{try {await window.careerProfile('POST','/api/documents',JSON.stringify({category,name:f.name,content:reader.result.split(',')[1]}));resolve('uploaded');}catch(e){reject(e);}};reader.readAsDataURL(f);
 }catch(e){reject(e);}}; input.click();
 });
};
window.careerOpen = function(url) { const u=new URL(url,location.origin); if(u.protocol==='https:' || (u.origin===location.origin && u.pathname.startsWith('/api/files/'))) window.open(u.href,'_blank','noopener,noreferrer'); };
