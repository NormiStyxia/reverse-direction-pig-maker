// Dedicated disposable Chrome; never connects to the user's browser.
import fs from 'node:fs/promises';import path from 'node:path';import {spawn} from 'node:child_process';
const out=path.resolve('validation/puffs/source');await fs.mkdir(out,{recursive:true});
const receipt=JSON.parse(await fs.readFile('validation/puffs/native/receipt.json','utf8'));
const sample=Object.values(receipt.samples)[0];const [w,h]=sample.captureSize;
const profile=await fs.mkdtemp(path.join(out,'chrome-'));
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
 '--headless','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));let ws;
try{
 let port;for(let i=0;i<100;i++){try{port=+(await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break}catch{await pause(100)}}
 if(!port)throw Error('Dedicated Chrome did not start');
 const pages=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();
 ws=new WebSocket(pages.find(x=>x.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
 let id=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.j(Error(JSON.stringify(m.error))):p.r(m.result)}};
 const send=(method,params={})=>new Promise((r,j)=>{pending.set(++id,{r,j});ws.send(JSON.stringify({id,method,params}))});
 for(let mode=1;mode<=7;mode++){
  await send('Page.navigate',{url:'http://127.0.0.1:8782/tests/puffs-reference.html?w='+w+'&h='+h+'&mode='+mode});
  let d;
  for(let i=0;i<300;i++){
   await pause(100);const r=await send('Runtime.evaluate',{expression:'({data:window.puffsReference,error:window.exportError})',returnByValue:true});
   const v=r.result?.value;if(v?.error)throw Error(v.error);if(v?.data){d=v.data;break}
  }
  if(!d)throw Error('Source timeout');
  await fs.writeFile(path.join(out,'source-'+mode+'.png'),Buffer.from(d.png.split(',')[1],'base64'));
  console.log('source',mode,w,h);
 }
 await fs.writeFile(path.join(out,'receipt.json'),JSON.stringify({width:w,height:h,frozen:'chapter1 6a316e84907d8bc94ab59f20796685172b3535b5',scope:'frozen main.js spawnSprite/puff/updateSprites native comparison, not full game'},null,2)+'\n');
}finally{ws?.close();chrome.kill('SIGTERM');if(chrome.exitCode===null)await new Promise(r=>chrome.once('exit',r));await fs.rm(profile,{recursive:true,force:true})}
