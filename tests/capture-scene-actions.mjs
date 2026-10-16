// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Captures frozen DOM only; not a game dependency. Start panel-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/scene-actions');
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
  await send('Page.navigate',{url:'http://127.0.0.1:8776/style.css'});
  await pause(200);
  const html='<meta charset="utf-8"><link rel="stylesheet" href="/style.css"><style>@font-face{font-family:"LXGW WenKai";src:url("/assets/fonts/LXGWWenKai-subset.ttf")}</style><div id="store-interaction"></div><button id="phoneBtn"><img class="phone-icon" src="/assets/store/phone-icon.png"><span>手机</span></button>';
  const frame=(await send('Page.getFrameTree')).frameTree.frame.id;
  await send('Page.setDocumentContent',{frameId:frame,html});
  await evaluate('document.fonts.load('+JSON.stringify('18px "LXGW WenKai"')+')');
  await evaluate('Promise.all([...document.images].map(i=>i.decode()))');
  const reports=[];
  for(const width of [1920,960,390,320])for(const count of [1,2,4]){
    await send('Emulation.setDeviceMetricsOverride',{width,height:width>600?1080:844,deviceScaleFactor:1,mobile:false});
    const options=[['seat','窗边椅子','坐下'],['window','窗户','看看窗外'],['shelf','货架','看看商品'],['fridge','饮料柜','看看饮料']].slice(0,count);
    await evaluate('(()=>{const e=document.getElementById("store-interaction");e.replaceChildren();const options='+JSON.stringify(options)+';for(const [i,o] of options.entries()){const b=document.createElement("button");b.dataset.action=o[0];b.className=i===0?"selected":"";const name=document.createElement("small"),act=document.createElement("span");name.textContent=o[1];act.textContent=(i===0?"F · ":"")+o[2];b.append(name,act);e.append(b);}if(options.length>1){const h=document.createElement("small");h.className="interaction-switch";h.textContent="Tab 切换 · 点击也可交互";e.append(h);}})()');
    await evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
    const elements=await evaluate('[...document.querySelectorAll("#store-interaction,#store-interaction button,#store-interaction small,#store-interaction span,#phoneBtn,#phoneBtn img,#phoneBtn span")].map(e=>({tag:e.tagName,id:e.id,action:e.dataset.action||null,text:e.tagName==="IMG"?"":e.textContent,rect:JSON.parse(JSON.stringify(e.getBoundingClientRect()))}))');
    const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    const name='h5-actions-'+width+'-'+count+'.png';await fs.writeFile(path.join(root,name),Buffer.from(shot.data,'base64'));
    reports.push({width,height:width>600?1080:844,count,options,elements,screenshot:name});
  }
  await fs.writeFile(path.join(root,'h5-metrics.json'),JSON.stringify(reports,null,2));
  console.log('PASS: '+reports.length+' frozen CSS action layouts');
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:300});
}
