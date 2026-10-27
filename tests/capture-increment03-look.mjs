// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Captures frozen DOM only; not a game dependency. Start panel-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/increment03/look-card');
await fs.mkdir(root,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'capture-profile-'));
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
  '--headless','--disable-gpu','--no-first-run','--no-default-browser-check',
  '--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'
],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));
let ws;
try {
  let port;
  for(let i=0;i<100;i++){try{port=Number((await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);break;}catch{await pause(100);}}
  if(!port)throw Error('Dedicated Chrome did not start');
  const targets=await (await fetch('http://127.0.0.1:'+port+'/json/list')).json();
  ws=new WebSocket(targets.find(x=>x.type==='page').webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject;});
  let seq=0;const pending=new Map();
  ws.onmessage=e=>{const m=JSON.parse(e.data);const p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}};
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await send('Page.navigate',{url:'http://127.0.0.1:8795/style.css'});
  await pause(200);
  const html='<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/style.css"><script type="importmap">{"imports":{"three":"/vendor/three.module.js"}}</script>';
  const frame=(await send('Page.getFrameTree')).frameTree.frame.id;
  await send('Page.setDocumentContent',{frameId:frame,html});
  await evaluate('document.fonts.load('+JSON.stringify('18px "LXGW WenKai"')+')');
  await evaluate('(async()=>{const {LookCard}=await import("/src/look-card.js");const {OFFICE_LOOKS}=await import("/src/prologue-office.js");window.card=new LookCard();window.looks=OFFICE_LOOKS})()');
  const reports=[];
  for(const [width,height,touch] of [[1280,720,false],[1920,1080,false],[1200,540,false],[1200,540,true],[800,360,true]])for(const id of ['monitor','notes','window','box']){
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:touch});
    await send('Emulation.setTouchEmulationEnabled',{enabled:touch});
    const data=await evaluate('(async()=>{const id='+JSON.stringify(id)+';const k=window.looks[id];const d={img:"./assets/ch1/looks/"+(k.img||id)+".png",title:k.title,rows:k.rows};window.card.show(d);window.card.update(1,{x:innerWidth*.65,y:innerHeight*.52});await document.fonts.ready;await window.card.el.img.decode();return d})()');
    await pause(500);
    const layout=await evaluate('(()=>{const el=window.card.el.card;const s=getComputedStyle(el);return {x:el.offsetLeft,y:el.offsetTop,w:el.offsetWidth,h:el.offsetHeight,cssLeft:s.left,cssTop:s.top,cssWidth:s.width,cssHeight:s.height,items:[...el.querySelectorAll("img,strong,.look-row,.look-row small,.look-row span")].map(e=>{const s=getComputedStyle(e);return{tag:e.tagName,text:e.textContent,fontSize:s.fontSize,lineHeight:s.lineHeight,w:e.offsetWidth,h:e.offsetHeight}})}})()');
    const name='h5-look-'+width+'-'+touch+'-'+id+'.png';
    if(id==='notes'){const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await fs.writeFile(path.join(root,name),Buffer.from(shot.data,'base64'));}
    reports.push({width,height,touch,id,data,layout,screenshot:id==='notes'?name:null});
  }
  await fs.writeFile(path.join(root,'h5-metrics.json'),JSON.stringify(reports,null,2));
  console.log('PASS: '+reports.length+' frozen object-card layouts');
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:300});
}
