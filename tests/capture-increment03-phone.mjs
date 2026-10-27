// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Captures frozen DOM only; not a game dependency. Start panel-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/increment03/phone-layout');
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

  const frame=(await send('Page.getFrameTree')).frameTree.frame.id;
  await send('Page.setDocumentContent',{frameId:frame,html:'<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/style.css"><style>@font-face{font-family:"LXGW WenKai";src:url("/assets/fonts/LXGWWenKai-subset.ttf")}</style>'});
  await evaluate('document.fonts.load(\'18px "LXGW WenKai"\')');
  await evaluate('(async()=>{const {PhoneOverlay}=await import("/src/phone.js");window.phone=new PhoneOverlay(id=>window.lastAction=id);phone.config({contact:"玩法评审冲刺群",subtitle:"3 人",stickers:true});phone.show();phone.set({view:"chat",time:"23:21",battery:23,history:[{name:"领导",text:"第 14 页核心循环再顺一下，明早评审前发我就行",stamp:"22:47"}],msgs:[{id:"m1",text:"[好的]",sticker:"pig-haode",status:"sent",time:"23:21",minute:9}]});phone.setButtons([{id:"close",text:"收起"},{id:"pick",text:"在改了"}]);phone.k=1;phone.update(1);document.body.classList.add("phone-open")})()');
  const reports=[];
  for(const [width,height]of [[1920,1080],[1280,720],[1200,540],[800,360]])for(const side of ['left','right']){
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
    await evaluate('phone.layoutSide=null;phone.place('+ (side==='right'?'.2,.4':'.6,.8') +');phone.toggleStickers(true);phone.update(.1)');
    await evaluate('Promise.all([...document.images].map(i=>i.decode().catch(()=>{})))');
    await pause(350);
    const result=await evaluate('(()=>{const rect=e=>JSON.parse(JSON.stringify(e.getBoundingClientRect()));return {frostEdge:phone.frostEdge,panel:rect(phone.root.querySelector(".ph-panel")),composer:rect(phone.el.composer),thread:rect(phone.el.thread),picker:rect(phone.el.stickers),input:rect(phone.el.input),scrollMax:phone.el.composer.scrollHeight-phone.el.composer.clientHeight,cells:[...phone.el.stickerGrid.children].map(rect)}})()');
    const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});const filename='frozen-'+width+'-'+side+'.png';await fs.writeFile(path.join(root,filename),Buffer.from(shot.data,'base64'));
    reports.push({width,height,side,...result,screenshot:filename});
  }
  await fs.writeFile(path.join(root,'frozen-metrics.json'),JSON.stringify(reports,null,2));
  console.log('PASS: '+reports.length+' frozen phone/picker layouts');
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:300});
}
