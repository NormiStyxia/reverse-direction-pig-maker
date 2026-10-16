// Render frozen audio in dedicated Chrome; no browser dependency in the game.
import fs from 'node:fs/promises';import path from 'node:path';import {spawn} from 'node:child_process';
const out=path.resolve('validation/audio/source');await fs.mkdir(out,{recursive:true});
const profile=await fs.mkdtemp(path.join(out,'chrome-'));
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',[
 '--headless','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));let ws;
try{
 let port;for(let i=0;i<100;i++){try{port=+(await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split(String.fromCharCode(10))[0];break}catch{await pause(100)}}
 if(!port)throw Error('Dedicated Chrome did not start');
 const pages=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();
 ws=new WebSocket(pages.find(x=>x.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
 let id=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.j(Error(JSON.stringify(m.error))):p.r(m.result)}};
 const send=(method,params={})=>new Promise((r,j)=>{pending.set(++id,{r,j});ws.send(JSON.stringify({id,method,params}))});
 const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result?.value};
 await send('Page.navigate',{url:'http://127.0.0.1:8782/tests/audio-export.html'});
 let count;for(let i=0;i<100;i++){await pause(100);const v=await evaluate('({count:window.audioReady,error:window.exportError})');if(v?.error)throw Error(v.error);if(v?.count){count=v.count;break}}
 if(!count)throw Error('Source audio module timeout');
 const receipt=[];for(let i=0;i<count;i++){const d=await evaluate('window.renderClip('+i+')');await fs.writeFile(path.join(out,d.id+'.f32'),Buffer.from(d.float32,'base64'));delete d.float32;receipt.push(d)}
 await fs.writeFile(path.join(out,'receipt.json'),JSON.stringify({source:'frozen StoreAudio methods; OfflineAudioContext mono 44100 Hz; master .9; deterministic noise seed 6316',clips:receipt},null,2)+String.fromCharCode(10));
 console.log('Frozen audio rendered:',count,'clips');
}finally{ws?.close();chrome.kill('SIGTERM');if(chrome.exitCode===null)await new Promise(r=>chrome.once('exit',r));await fs.rm(profile,{recursive:true,force:true})}
