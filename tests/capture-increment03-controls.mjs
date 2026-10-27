// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Captures frozen DOM only; not a game dependency. Start panel-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/increment03/player-controls');
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
  const html='<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/style.css"><style>@font-face{font-family:"LXGW WenKai";src:url("/assets/fonts/LXGWWenKai-subset.ttf")}</style><button id="skip-story">跳过 <b>Esc</b></button><div class="ph-layer" data-side="right"></div><div id="pause-card" hidden><strong>暂停</strong><div class="pause-actions"><button>继续 <b>Esc</b></button><button>返回主界面 <b>Enter</b></button></div></div>';
  const frame=(await send('Page.getFrameTree')).frameTree.frame.id;
  await send('Page.setDocumentContent',{frameId:frame,html});
  await evaluate('document.fonts.load('+JSON.stringify('18px "LXGW WenKai"')+')');
  await evaluate('Promise.all([...document.images].map(i=>i.decode()))');
  const reports=[];
  await evaluate('(async()=>{const {TouchControls}=await import("/src/touch-controls.js");window.tc=new TouchControls(new Set())})()');
  for(const [width,height,touch] of [[1920,1080,false],[1280,720,false],[1200,540,false],[1200,540,true],[800,360,true]])for(const mode of ['skip','phone','pause','echo','story']){
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:touch});
    await send('Emulation.setTouchEmulationEnabled',{enabled:touch});
    await evaluate('(()=>{document.body.className='+JSON.stringify(mode==='phone'?'phone-open':'')+';document.querySelector("#skip-story").hidden='+JSON.stringify(mode!=='skip'&&mode!=='phone')+';document.querySelector("#pause-card").hidden='+JSON.stringify(mode!=='pause')+';window.tc.update({visible:'+JSON.stringify(mode==='echo'||mode==='story')+',enabled:true,echo:'+JSON.stringify(mode==='echo')+',cycle:'+JSON.stringify(mode==='story')+',tap:false,moveOnly:false})})()');
    await evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
    const elements=await evaluate('[...document.querySelectorAll("#skip-story,#skip-story b,#pause-card strong,#pause-card button,#pause-card b,#touch-controls button,.tc-stick,.tc-knob")].map(e=>{const s=getComputedStyle(e);return {text:e.textContent,id:e.id,cls:e.className,rect:JSON.parse(JSON.stringify(e.getBoundingClientRect())),style:Object.fromEntries(["fontSize","letterSpacing","lineHeight","display","backgroundColor","borderRadius","padding","color"].map(k=>[k,s[k]]))}})');
    const name='h5-'+mode+'-'+width+'-'+touch+'.png';
    const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});await fs.writeFile(path.join(root,name),Buffer.from(shot.data,'base64'));
    reports.push({width,height,touch,mode,elements,screenshot:name});
  }
  await fs.writeFile(path.join(root,'h5-metrics.json'),JSON.stringify(reports,null,2));
  console.log('PASS: '+reports.length+' frozen CSS controls layouts');
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:300});
}
