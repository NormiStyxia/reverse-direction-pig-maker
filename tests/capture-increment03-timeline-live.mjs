// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Exports exact frozen scene; start chapter1-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/increment03/timeline-live');
await fs.mkdir(root,{recursive:true});
const profile=await fs.mkdtemp(path.join(root,'capture-profile-'));
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
  '--headless','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-first-run','--no-default-browser-check',
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
  ws.onclose=()=>{for(const p of pending.values())p.reject(Error('Dedicated export socket closed'));pending.clear();};
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await send('Emulation.setDeviceMetricsOverride',{width:1280,height:720,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:'http://127.0.0.1:8795/index.html'});
  let ready=false;
  for(let i=0;i<600;i++){
    await pause(100);
    const state=await evaluate('({ready:!!window.__timeline,error:window.exportError})');
    if(state.error)throw Error(state.error);
    if(state.ready){ready=true;break;}
  }
  if(!ready)throw Error('Chapter1 export timed out');
  await evaluate(`(()=>{const T=window.__timeline;window.__proto.title.active=false;document.getElementById('title-screen')?.remove();T.dropCurrent();for(const id of ['2312','2338','echo1','1447','echo2','0958','echo3','0815','echo4'])T.progress.unlock(id);T.timeline.show({dest:'2312',onPick:()=>{}});})()`);
  await pause(6000);
  const data=await evaluate(`(()=>{const t=window.__timeline.timeline;const lights=[];t.scene.traverseVisible(o=>{if(o.isLight)lights.push({type:o.type,color:o.color.toArray(),intensity:o.intensity,ground:o.groundColor?.toArray(),position:o.position.toArray(),target:o.target?.position.toArray(),shadow:o.castShadow,group:o.parent===t.g?'timeline':'world'})});return {lights,camera:{position:t.camera.position.toArray(),fov:t.camera.fov},time:t.t,selected:t.si,post:t.post.settings,titleIds:[...document.querySelectorAll('[id]')].map(x=>x.id).filter(x=>x.includes('title'))}})()`);
  const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
  await fs.writeFile(path.join(root,'h5-timeline-live.png'),Buffer.from(shot.data,'base64'));
  await fs.writeFile(path.join(root,'source-light-state.json'),JSON.stringify(data,null,2));
  console.log(JSON.stringify(data));

}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true});
}
