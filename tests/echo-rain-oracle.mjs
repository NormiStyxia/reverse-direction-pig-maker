// Execute the exact frozen rain update block, not a reimplementation of expected math.
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync('reference/h5-source/src/rewind-levels.js','utf8');
const start=source.indexOf('    const fall = dt * lerp(12, -7, K);');
const end=source.indexOf('    R.rainGeo.attributes.position.needsUpdate = true;',start);
if(start<0||end<0)throw Error('Frozen rain block missing');
const run=new vm.Script('{'+source.slice(start,end)+'}');
const seeds=JSON.parse(fs.readFileSync('validation/transparency/source-rain-seeds.json'));
const fixtures=[];
for(const [level,initial] of seeds.entries()){
 let state=731,calls=0;
 const math=Object.create(Math);math.random=()=>{calls++;state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296};
 const R={rainSeed:initial.map(p=>p.slice()),RAIN:initial.length,rainPos:new Float32Array(initial.length*6)};
 const context=vm.createContext({R,Math:math,lerp:(a,b,k)=>a+(b-a)*k,dt:0,K:0});
 const frames=[];
 for(let f=0;f<240;f++){
  context.dt=[0,1/60,.05,.013][f%4];context.K=[0,.1,.5,1][Math.floor(f/60)];run.runInContext(context);
  // All drops at phase boundaries; mixed sampled drops on every other frame.
  const ids=f%30===0||f===239?Array.from({length:600},(_,i)=>i):[0,1,19,59,179,299,419,599];
  frames.push({dt:context.dt,k:context.K,calls,samples:ids.map(i=>({id:i+1,p:R.rainSeed[i].slice(),vertices:Array.from(R.rainPos.slice(i*6,i*6+6))}))});
 }
 fixtures.push({level:level+1,frames});
}
fs.writeFileSync('validation/echo/source-rain-motion.json',JSON.stringify(fixtures));
console.log('Frozen rain oracle: 6 levels × 240 frames; normal, slowing, reversing and boundary wraps');
