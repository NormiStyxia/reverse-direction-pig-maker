// Source WebAudio -> PCM stems. Chrome is a build-time tool, never a game runtime.
import fs from 'node:fs/promises';import path from 'node:path';import http from 'node:http';import {spawn} from 'node:child_process';import crypto from 'node:crypto';
const source=await fs.readFile('reference/increment03/h5-source/src/store-audio.js','utf8');
const dreamSource=await fs.readFile('reference/increment03/h5-source/src/dream.js','utf8');
const dreamMethods='export class DreamAudio { '+dreamSource.slice(dreamSource.indexOf('  startSound() {'),dreamSource.indexOf('  dispose() {'))+'}';
const dreamSpecs=[{id:'dream-burst',dream:'swell',args:[.5,.06,2400,300],seconds:.55},{id:'dream-hold',dream:'swell',args:[3.4,.09,180,4200],seconds:3.45},{id:'dream-swap',dream:'swell',args:[1,.06,1600,200],seconds:1.05},{id:'dream-unswap',dream:'swell',args:[1,.06,200,1600],seconds:1.05},{id:'dream-murmur',dream:'murmur',args:[],seconds:2.6},{id:'dream-rewind',dream:'swell',args:[2.2,.11,160,5200],seconds:2.25}];
let swellSeed=9302;for(let i=0;i<24;i++){swellSeed=(Math.imul(swellSeed,1664525)+1013904223)>>>0;const d=1.4+swellSeed/4294967296;dreamSpecs.push({id:'dream-air-'+i,dream:'swell',args:[d,1,300,2400],seconds:d+.05})}
const specs=[...dreamSpecs,...['hum','room','cic','cri','ring','rain'].map(id=>({id,node:id+'G',seconds:id==='cri'?10:2})),
 ...[110,110.7,164.4].map(f=>({id:'pad-'+f,f,seconds:10})),
 ...Array.from({length:13},(_,i)=>({id:'wind-'+(500+i*50),filter:500+i*50,seconds:2}))];
const out='assets/audio/increment03';await fs.mkdir(out,{recursive:true});
const server=http.createServer((req,res)=>{res.setHeader('Content-Type',req.url.endsWith('.js')?'text/javascript':'text/html');res.end(req.url==='/source.js'?"const nightU={uNight:{value:1}};\n"+source.replace(/^import .*;$/gm,'').replace('tremG.gain.value = 0.008','tremG.gain.value = 0'):req.url==='/dream.js'?dreamMethods:'<!doctype html><title>Frozen audio export</title>')});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;
const profile=await fs.mkdtemp('/tmp/reverse-pig-ambient-chrome-');const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));let ws;
async function installRenderer(){
 const {StoreAudio}=await import('/source.js');const {DreamAudio}=await import('/dream.js');
 window.renderStem=async spec=>{
  const rate=44100,seconds=spec.seconds,ctx=new OfflineAudioContext(1,(seconds+2)*rate,rate);
  let seed=6316;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
  const oldRandom=Math.random,oldAC=window.AudioContext;Math.random=random;window.AudioContext=function(){return ctx};
  const a=new StoreAudio();try{a.start()}finally{Math.random=oldRandom;window.AudioContext=oldAC}
  a.master.disconnect();const recorder=ctx.createGain();recorder.gain.value=.25;recorder.connect(ctx.destination);
  if(spec.dream){const d=new DreamAudio();d.audio=a;d.startSound();d.snd.pad.gain.value=0;d.snd.wind.gain.value=0;d.snd.out.gain.cancelScheduledValues(0);d.snd.out.gain.value=1;d.snd.out.disconnect();d.snd.out.connect(recorder);Math.random=random;try{d[spec.dream](...spec.args)}finally{Math.random=oldRandom}}
  else if(spec.node){const g=a[spec.node];g.disconnect();g.gain.value=1;g.connect(recorder)}
  else if(spec.f){const o=ctx.createOscillator();o.frequency.value=spec.f;o.connect(recorder);o.start()}
  else {const s=ctx.createBufferSource();s.buffer=a.noise;s.loop=true;const f=ctx.createBiquadFilter();f.type='bandpass';f.frequency.value=spec.filter;f.Q.value=.8;s.connect(f).connect(recorder);s.start()}
  const buffer=await ctx.startRendering(),data=buffer.getChannelData(0).slice((spec.f||spec.dream)?0:2*rate,(spec.f||spec.dream)?Math.floor(seconds*rate):undefined);let peak=0;for(const x of data)peak=Math.max(peak,Math.abs(x));
  const pcm=new Int16Array(data.length);for(let i=0;i<data.length;i++)pcm[i]=Math.round(Math.max(-1,Math.min(1,data[i]))*32767);
  const b=new Uint8Array(pcm.buffer);let binary='';for(let i=0;i<b.length;i+=8192)binary+=String.fromCharCode(...b.subarray(i,i+8192));
  return {base64:btoa(binary),peak,frames:data.length,rate};
 };return true;
}
try{
 let port;for(let i=0;i<100;i++){try{port=+(await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0];break}catch{await pause(100)}}
 if(!port)throw Error('Dedicated Chrome did not start');const pages=await(await fetch('http://127.0.0.1:'+port+'/json/list')).json();ws=new WebSocket(pages.find(x=>x.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
 let seq=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(p){pending.delete(m.id);m.error?p.j(Error(JSON.stringify(m.error))):p.r(m.result)}};
 const send=(method,params={})=>new Promise((r,j)=>{pending.set(++seq,{r,j});ws.send(JSON.stringify({id:seq,method,params}))});
 const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value};
 await send('Page.navigate',{url:origin});await pause(300);await evaluate('('+installRenderer.toString()+')()');
 const receipt=[];for(const spec of specs){const r=await evaluate('renderStem('+JSON.stringify(spec)+')');if(r.peak>=1||r.peak<=0)throw Error('Invalid amplitude '+spec.id);const pcm=Buffer.from(r.base64,'base64');const wav=Buffer.alloc(44+pcm.length);wav.write('RIFF');wav.writeUInt32LE(36+pcm.length,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(r.rate,24);wav.writeUInt32LE(r.rate*2,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(pcm.length,40);pcm.copy(wav,44);await fs.writeFile(path.join(out,spec.id+'.wav'),wav);receipt.push({...spec,peak:r.peak,frames:r.frames,sha256:crypto.createHash('sha256').update(wav).digest('hex')});console.log(spec.id,r.frames)}
 const hum=Buffer.from(await fs.readFile(path.join(out,'hum.wav')));for(let i=44;i<hum.length;i+=2)hum.writeInt16LE(-hum.readInt16LE(i),i);await fs.writeFile(path.join(out,'hum-negative.wav'),hum);receipt.push({id:'hum-negative',derivedFrom:'hum',operation:'PCM sign inversion',sha256:crypto.createHash('sha256').update(hum).digest('hex')});
 await fs.writeFile('docs/migration/increment03-ambient-export.json',JSON.stringify({dreamSourceSha256:crypto.createHash('sha256').update(dreamSource).digest('hex'),dreamRandomSwellPool:24,sourceSha256:crypto.createHash('sha256').update(source).digest('hex'),gain:.25,noiseSeed:6316,stems:receipt,scope:'Source filters/noise and frequencies; native gain/pitch control. Dream wind uses 50 Hz interpolation; not device acoustic parity.'},null,2)+'\n');
}finally{ws?.close();chrome.kill('SIGTERM');if(chrome.exitCode===null)await new Promise(r=>chrome.once('exit',r));server.close();await fs.rm(profile,{recursive:true,force:true})}
