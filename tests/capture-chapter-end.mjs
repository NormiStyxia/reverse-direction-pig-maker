// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Captures frozen DOM only; not a game dependency. Start panel-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/chapter1');
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
  await send('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:'http://127.0.0.1:8776/?fixture=1'});
  for(let i=0;i<100;i++){await pause(50);if(await evaluate('!!window.panelReference'))break;}
  await evaluate(`(async()=>{document.body.innerHTML='<div id="chapter-end" class="show"><strong>第一章 · 完</strong><span>反方向的猪 · 谢谢游玩</span><button type="button" class="end-again">再玩一次</button></div>';document.body.style.background='#000';await document.fonts.ready;return true})()`);
  await pause(2600);
  const reports=[];
  for(const [w,h,dpr]of [[1920,1080,1],[1280,720,1],[390,844,3]]){
   await send('Emulation.setDeviceMetricsOverride',{width:w,height:h,deviceScaleFactor:dpr,mobile:false});
   await evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
   reports.push(await evaluate(`({width:innerWidth,height:innerHeight,dpr:devicePixelRatio,elements:[...document.querySelector('#chapter-end').children].map(el=>{const r=el.getBoundingClientRect(),s=getComputedStyle(el);return {tag:el.tagName,text:el.textContent,x:r.x,y:r.y,w:r.width,h:r.height,font:s.font,lineHeight:s.lineHeight,spacing:s.letterSpacing,padding:s.padding}})})`));
   const screenshot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await fs.writeFile(path.join(root,'h5-end-'+w+'.png'),Buffer.from(screenshot.data,'base64'));
  }
  await fs.writeFile(path.join(root,'h5-end-metrics.json'),JSON.stringify(reports,null,2));console.log(JSON.stringify(reports));

}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true});
}
