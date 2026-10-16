// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Captures frozen DOM only; not a game dependency. Start panel-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/panels');
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
  const reports=[];
  const count=JSON.parse(await fs.readFile(path.join(root,'fixtures.json'),'utf8')).length;
  for(let fixture=1;fixture<=count;fixture++){
    await send('Page.navigate',{url:'http://127.0.0.1:8776/?fixture='+fixture});
    let ready=false;
    for(let i=0;i<100;i++){await pause(50);try{ready=await evaluate('window.panelReference?.fixture==='+fixture);}catch{}if(ready)break;}
    if(!ready)throw Error('Reference fixture did not load: '+fixture);
    await evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
    const report=await evaluate('({fixture:panelReference.fixture,name:panelReference.name,width:innerWidth,height:innerHeight,dpr:devicePixelRatio,fonts:[...document.fonts].map(f=>({family:f.family,status:f.status})),metrics:panelReference.metrics()})');
    const screenshot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    const name='h5-fixture-'+fixture+'.png';
    await fs.writeFile(path.join(root,name),Buffer.from(screenshot.data,'base64'));
    reports.push({...report,screenshot:name});
  }
  await fs.writeFile(path.join(root,'h5-metrics.json'),JSON.stringify(reports,null,2)+'\n');
  console.log('PASS: captured '+count+' frozen DOM fixtures at 1920 x 1080, DPR 1; metrics saved');
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true});
}
