// Replay the same complete route through unmodified frozen Pig/RewindLevels methods.
// Artwork and audio are stubbed; movement, collisions, timeline and level flow are source code.
import fs from 'node:fs';import vm from 'node:vm';
import * as THREE from '../reference/h5-source/vendor/three.module.js';
const strip=p=>fs.readFileSync('reference/h5-source/src/'+p,'utf8').replace(/^import .*;\n/gm,'').replaceAll('export ','');
const noop=()=>{};const scope={THREE,console,ROOM:{halfW:7,zMin:-4.9,zMax:4.4},
 paintSurface:()=>null,paintClock:()=>null,paintStripes:()=>null,buildShelves:noop,buildFridge:noop,storeGradient:null,markPresent:noop};
vm.createContext(scope);vm.runInContext(strip('pig.js')+'\n'+strip('rewind-levels.js')+'\nglobalThis.Pig=Pig;globalThis.Echo=RewindLevels;globalThis.Levels=LEVELS;',scope);
const scene=new THREE.Scene(),pig=new scope.Pig(scene,{}),e=Object.create(scope.Echo.prototype);let hitstop=0,finished=false;
Object.assign(e,{scene,pig,levels:scope.Levels,theme:'store',seen:new Set(),world:{},camera:new THREE.PerspectiveCamera(),cam:{kFar:7},fx:{},
 audio:new Proxy({},{get:()=>noop}),ui:{hint:noop,title:noop},caption:noop,puff:noop,onFinish:()=>{finished=true;},
 hooks:{shake:noop,flash:noop,hitstop:v=>{hitstop=Math.max(hitstop,v);}},
 applyRoom:noop,unfold:noop,later:noop,watchDead:noop,rewindPuffs:noop});
pig.spinDir=-1;pig.spinFrame=.05;e.load(0);
const inputs=JSON.parse(fs.readFileSync('validation/echo/prologue-six-inputs.json','utf8'));
const expected=JSON.parse(fs.readFileSync('validation/echo/prologue-six-states.json','utf8'));
let checks=0;const exits=[];
for(let i=0;i<inputs.length;i++){
 if(e.phase!=='done'){
  let dt=1/60;if(hitstop>0){hitstop-=dt;dt*=.05;}
  const input={x:0,y:0,spin:false,...inputs[i]};
  if(input.restart)e.restart();
  if(input.charge&&e.controlEnabled)pig.tryCharge();
  pig.update(dt,e.controlEnabled?input:{x:0,y:0,spin:false},0,e.controlEnabled);
  const before=e.index;e.update(dt,{camYaw:0,reveal:false});
  if(e.index!==before||e.phase==='done')exits.push({frame:i+1,from:before+1,to:e.phase==='done'?'done':e.index+1});
 }
 const got={level:e.index+1,phase:e.phase,x:pig.pos.x,z:pig.pos.z,door:e.room.doorOpen,timeline:e.timeline.h.length};
 for(const [key,value]of Object.entries(expected[i])){
  if(typeof value==='number'?Math.abs(value-got[key])>1e-8:value!==got[key])throw Error(JSON.stringify({frame:i+1,key,expected:value,source:got[key],got}));
  checks++;
 }
}
if(!finished)throw Error('Source did not finish all six rooms');
const report={result:'PASS',frames:inputs.length,scalarChecks:checks,levelsSolved:6,exits,
 source:'frozen Pig.update + RewindLevels.update and their original collision/timeline/load methods',
 stubs:['procedural artwork','audio/captions','presentation','deferred UI hints','dead-end hints'],visualAcceptance:false};
fs.writeFileSync('docs/migration/prologue-echo-source-route-report.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
