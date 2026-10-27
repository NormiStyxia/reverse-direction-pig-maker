// Dedicated headless Chrome, isolated profile. Never connects to a personal browser.
// Exports exact frozen scene; start chapter1-reference-server.py first.
import fs from 'node:fs/promises';
import path from 'node:path';
import {spawn} from 'node:child_process';
const root=path.resolve('validation/increment03/chapter1');
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
  await send('Page.navigate',{url:'http://127.0.0.1:8795/src/dream.js'});await pause(300);
  const paths=['ch1/avatar-leader.png','ch1/avatar-zhou.jpg','store/avatar-me.png'];
  const out=path.resolve('assets/increment03/avatars');await fs.mkdir(out,{recursive:true});
  for(const name of paths){
    const png=await evaluate('(async()=>{const i=new Image();i.src='+JSON.stringify('/assets/'+name)+';await i.decode();const c=document.createElement("canvas");c.width=i.width;c.height=i.height;const x=c.getContext("2d");x.filter="grayscale(1) sepia(1) hue-rotate(185deg) saturate(3.5) brightness(.95)";x.drawImage(i,0,0);return c.toDataURL("image/png").split(",")[1]})()');
    await fs.writeFile(path.join(out,path.basename(name).replace(/\.[^.]+$/,'.png')),Buffer.from(png,'base64'));
    console.log(name+' → frozen CSS filtered avatar');
  }
}finally{
  ws?.close();
  if(chrome.exitCode===null){chrome.kill('SIGTERM');await new Promise(r=>chrome.once('exit',r));}
  await fs.rm(profile,{recursive:true,force:true});
}
