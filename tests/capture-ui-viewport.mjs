import fs from 'node:fs/promises';
import {spawn} from 'node:child_process';
const out='validation/ui-viewport';
const profile=await fs.mkdtemp('/tmp/pig-ui-chrome-');
const server=spawn('python3',['-u','tests/ui-viewport-reference.py']);
const port=await new Promise(r=>server.stdout.once('data',d=>r(Number(d.toString().trim()))));
const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
const pause=ms=>new Promise(r=>setTimeout(r,ms));let ws;
try{
 let p;for(let i=0;i<100;i++){try{p=Number((await fs.readFile(profile+'/DevToolsActivePort','utf8')).split('\n')[0]);break}catch{}await pause(100)}
 const list=await(await fetch('http://127.0.0.1:'+p+'/json/list')).json();ws=new WebSocket(list.find(x=>x.type==='page').webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
 let seq=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data);const cb=pending.get(m.id);if(cb){pending.delete(m.id);m.error?cb.j(Error(JSON.stringify(m.error))):cb.r(m.result)}};
 const send=(method,params={})=>new Promise((r,j)=>{let id=++seq;pending.set(id,{r,j});ws.send(JSON.stringify({id,method,params}))});
 const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value};
 const reports=[];
 for(const [w,h,dpr,mobile]of [[1920,1080,1,false],[1280,720,2,false],[800,360,2.4027777778,true],[844,390,3,true],[667,375,2,true]]){
  await send('Emulation.setDeviceMetricsOverride',{width:w,height:h,deviceScaleFactor:dpr,mobile});await send('Emulation.setTouchEmulationEnabled',{enabled:mobile,maxTouchPoints:5});await send('Page.navigate',{url:'http://127.0.0.1:'+port+'/ui'});
  let ready=false;for(let i=0;i<100;i++){await pause(50);try{ready=await evaluate('window.ready===true')}catch{}if(ready)break}if(!ready)throw Error('Frozen CSS fixture failed');
  await evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
  const metric=await evaluate(`(()=>{const q=s=>{const e=document.querySelector(s),c=getComputedStyle(e),b=e.getBoundingClientRect();return{x:b.x,y:b.y,w:b.width,h:b.height,fontSize:parseFloat(c.fontSize)}};return{viewport:[innerWidth,innerHeight],dpr:devicePixelRatio,coarse:matchMedia('(pointer:coarse)').matches,dialog:q('.dlg'),medal:q('.dlg-medal'),say:q('.dlg-say'),name:q('.dlg-name'),skip:q('#skip-story')}})()`);
  const stem=w+'x'+h+'-dpr'+dpr.toFixed(2);let im=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(out+'/h5-dialog-'+stem+'.png',Buffer.from(im.data,'base64'));
  await evaluate('makeTitle();new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');
  metric.title=await evaluate(`[...document.querySelectorAll('.mi')].map(e=>{const b=e.getBoundingClientRect();return{label:e.querySelector('.zh').textContent,x:b.x,y:b.y,w:b.width,h:b.height}})`);
  im=await send('Page.captureScreenshot',{format:'png'});await fs.writeFile(out+'/h5-title-'+stem+'.png',Buffer.from(im.data,'base64'));reports.push(metric);
 }
 await fs.writeFile(out+'/h5-metrics.json',JSON.stringify(reports,null,2));console.log('PASS: isolated Google Chrome; 5 frozen CSS viewports, dialog and title metrics/screenshots');
}finally{ws?.close();chrome.kill('SIGTERM');server.kill('SIGTERM');await new Promise(r=>chrome.exitCode!==null?r():chrome.once('exit',r));await fs.rm(profile,{recursive:true,force:true,maxRetries:3,retryDelay:100})}
