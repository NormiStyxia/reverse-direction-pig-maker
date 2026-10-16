// Isolated Chrome evaluates the unmodified frozen buildLevel/markPresent.
// Read-only local export servers must already be running on 8778 and 8780.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/blue');await fs.mkdir(root,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'oracle-profile-'));
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
 '--headless','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check',
 '--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));let ws;
try {
 let port;for(let i=0;i<100;i++){try{port=Number((await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);break}catch{await pause(100)}}
 if(!port)throw Error('Dedicated Chrome did not start');
 const pages=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();
 ws=new WebSocket(pages.find(p=>p.type==='page').webSocketDebuggerUrl);await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject});
 let id=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result)}};
 const send=(method,params={})=>new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});ws.send(JSON.stringify({id,method,params}))});
 const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value};
 const results=[];
 for(const [port,answer] of [[8778,null],...[ 'same','late','done'].map(a=>[8780,a])]){
  await send('Page.navigate',{url:'http://127.0.0.1:'+port+'/?answer='+(answer||'same')});
  let ready=false;for(let i=0;i<600;i++){await pause(100);const s=await evaluate('({ready:window.exportReady,error:window.exportError})');if(s.error)throw Error(s.error);if(s.ready){ready=true;break}}
  if(!ready)throw Error('Frozen source export timeout');
  const rows=await evaluate('window.echoExport.map(d=>({theme:d.theme,answer:d.answer,index:d.index,ids:d.nodes.filter(n=>n.geometry&&(n.sourceLayers&4)).map(n=>n.id)}))');
  results.push(...rows);console.log('selected',port,answer,rows.length);
 }
 await fs.writeFile(path.join(root,'present-source.json'),JSON.stringify(results,null,2)+'\n');
}finally{ws?.close();chrome.kill('SIGTERM');if(chrome.exitCode===null)await new Promise(r=>chrome.once('exit',r));await fs.rm(profile,{recursive:true,force:true})}
