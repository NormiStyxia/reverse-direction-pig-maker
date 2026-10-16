// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Exports exact frozen scene; start store-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/store');
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
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
  await send('Emulation.setDeviceMetricsOverride',{width:1920,height:1080,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:'http://127.0.0.1:8777/'});
  let ready=false;
  for(let i=0;i<600;i++){
    await pause(100);
    const state=await evaluate('({ready:window.exportReady,error:window.exportError})');
    if(state.error)throw Error(state.error);
    if(state.ready){ready=true;break;}
  }
  if(!ready)throw Error('Store export timed out');
  if(process.argv.includes('--sprite-geometry-only')){
    const file=path.join(root,'source-scene.json');
    const data=JSON.parse(await fs.readFile(file,'utf8'));
    const geometries=await evaluate('window.storeExport.geometries');
    const sprites=new Set(data.nodes.filter(n=>n.type==='Sprite').map(n=>n.geometry));
    if(geometries.length!==data.geometries.length)throw Error('Geometry inventory changed');
    const changes=[];
    for(let i=0;i<geometries.length;i++){
      if(JSON.stringify(geometries[i])===JSON.stringify(data.geometries[i]))continue;
      if(!sprites.has(geometries[i].id))throw Error('Unexpected non-sprite geometry change '+geometries[i].id);
      changes.push(geometries[i].id);data.geometries[i]=geometries[i];
    }
    await fs.writeFile(file,JSON.stringify(data));
    console.log('Source Sprite attributes deinterleaved through Three getters: '+JSON.stringify(changes));
  }else if(process.argv.includes('--shadow-diagnostic')){
    const cases=[];
    for(const diagnostic of ['disabled','zero-bias']){
      cases.push(await evaluate('window.storeShadowReference("both",'+JSON.stringify(diagnostic)+')'));
      const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
      await fs.writeFile(path.join(root,'h5-shadow-'+diagnostic+'.png'),Buffer.from(shot.data,'base64'));
    }
    await fs.writeFile(path.join(root,'h5-shadow-diagnostic.json'),JSON.stringify(cases,null,2));
    console.log('Frozen store shadow diagnostic: '+cases.length+' cases');
  }else if(process.argv.includes('--shadows-only')){
    const cases=[];
    for(const mode of ['none','roof','leaves','both']){
      cases.push(await evaluate('window.storeShadowReference('+JSON.stringify(mode)+')'));
      const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
      await fs.writeFile(path.join(root,'h5-shadow-'+mode+'.png'),Buffer.from(shot.data,'base64'));
    }
    await fs.writeFile(path.join(root,'h5-shadow-cases.json'),JSON.stringify(cases,null,2));
    console.log('Frozen store production-shadow reference: '+cases.length+' cases');
  }else if(process.argv.includes('--dynamics-only')){
    const fixtures=await evaluate('window.sampleStoreDynamics()');
    await fs.writeFile(path.join(root,'source-dynamics.json'),JSON.stringify(fixtures));
    console.log('Frozen store.update/fold fixtures: '+fixtures.frames.length+' frames');
  }else{
  const data=await evaluate('window.storeExport');
  data.referenceCamera=await evaluate('window.referenceCamera');
  await fs.writeFile(path.join(root,'source-scene.json'),JSON.stringify(data));
  const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
  await fs.writeFile(path.join(root,'h5-raw.png'),Buffer.from(shot.data,'base64'));
  console.log(JSON.stringify({nodes:data.nodes.length,geometries:data.geometries.length,materials:data.materials.length,textures:data.textures.length,instances:data.nodes.reduce((n,x)=>n+(x.instances?.length||0),0)}));
  }
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:300});
}
