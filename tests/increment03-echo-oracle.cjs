// Runs methods extracted unchanged from the frozen JS, with render/audio stubs.
const fs=require('fs'),vm=require('vm');
const source=fs.readFileSync('reference/increment03/h5-source/src/rewind-levels.js','utf8');
const timeline=source.slice(source.indexOf('class Timeline {'),source.indexOf('\nlet shellMats'));
const klass=source.slice(source.indexOf('export class RewindLevels')).replace('export class','class');
const plateStart=source.indexOf('    // 圆板 → 门');
const plateEnd=source.indexOf('    if (live && !this.rewinding) this.watchDead',plateStart);
const doorStart=source.indexOf('    const D = this.L.door, pressed',plateEnd);
const doorEnd=source.indexOf('    // 第 4 层：出口的板压上了',doorStart);
const context=vm.createContext({console,Math,Set,Map,THREE:{MathUtils:{clamp:(v,a,b)=>Math.max(a,Math.min(b,v))},Vector3:class {constructor(x,y,z){Object.assign(this,{x,y,z})}}}});
vm.runInContext([
 'const CAB_HALF=.4,CAB_H=2.4,BOX=.45,SLIDE=7,PIG={radius:.5};',
 "const DIRS={'+x':[1,0],'-x':[-1,0],'+z':[0,1],'-z':[0,-1]},DIR_KEYS=Object.keys(DIRS);",
 'const overlap=(a,b)=>a.x0<b.x1&&a.x1>b.x0&&a.z0<b.z1&&a.z1>b.z0;',
 'const shrink=(o,k)=>({x0:o.x0+k,x1:o.x1-k,z0:o.z0+k,z1:o.z1-k});',
 timeline,klass,
 'globalThis.Timeline=Timeline;globalThis.RewindLevels=RewindLevels;',
 'RewindLevels.prototype.updatePlatesAndDoor=function(dt){const R=this.room,P={pos:{x:0,z:0}},live=false;'+source.slice(plateStart,plateEnd)+source.slice(doorStart,doorEnd)+'};'
].join('\n'),context);
const cases=JSON.parse(fs.readFileSync(0,'utf8'));
const results=[];
const noop=()=>{};
function crate(c){const kind=c.kind||(c.gold?'gold':'card'),holo=kind==='tonight'||kind==='bag';return {...c,kind,holo,gold:!!c.gold||holo||kind==='now',vx:0,vz:0,moving:false,mesh:{scale:{setScalar:noop}}}}
function snap(e){return {...(e.pig?{pig:{pos:{...e.pig.pos},vel:{x:e.pig.vel.x,y:e.pig.vel.y,z:e.pig.vel.z},charge:e.pig.charge,hits:e.pig.chargeHits.size},stuckT:e.stuckT}:{}),powerOff:!!e.room.powerOff,crates:e.room.crates.map(c=>({x:c.x,z:c.z,vx:c.vx,vz:c.vz,kind:c.kind,gold:c.gold,holo:c.holo,moving:c.moving,origin:c.origin||null,phased:!!c.phased,gone:!!c.gone,slid:!!c.slid})),cabinets:e.room.cabinets.map(k=>({a:k.a,w:k.w,ph:k.ph,dir:k.dir,tm:k.tm})),plates:e.room.plates.map(p=>p.pressed),door:e.room.doorOpen,hold:e.room.doorTimer,merged:e.room.merged,frames:e.timeline.h.length,total:e.timeline.total,blocked:!!e.timeline.blocked,exit:e.exitOn()}}
for(const fixture of cases){
 const e=Object.create(context.RewindLevels.prototype);
 Object.assign(e,{levels:[fixture.level],index:0,theme:fixture.theme,t:0,playAt:0,flags:new Set(),seen:new Set(),events:[],audio:{tone:noop},hooks:{shake:noop,hitstop:noop,flash:noop},puff:noop,caption:noop,say:noop,line:()=>null,later:noop,makeTag:noop,onCrateStop:noop,onCabDown:noop});
 e.stuckT=0;e.rewinding=false;e.ui={hint:noop};
 function setPig(data){e.pig=JSON.parse(JSON.stringify(data));e.pig.chargeHits=new Set();e.pig.vel.multiplyScalar=function(k){this.x*=k;this.y*=k;this.z*=k;return this};}
 if(fixture.pig)setPig(fixture.pig);
 e.room=fixture.room;e.room.crates=e.room.crates.map(crate);e.room.makeCrate=crate;e.room.fading=[];
 e.rwCrates=e.room.crates.filter(c=>!c.gold);
 e.timeline=new context.Timeline(()=>[...e.rwCrates.flatMap(c=>[c.x,c.z]),...e.room.cabinets.flatMap(k=>[k.a,k.w,k.ph,k.dir,k.tm])],s=>{let i=0;for(const c of e.rwCrates){if(!c.gone){c.x=s[i];c.z=s[i+1];c.vx=c.vz=0;c.moving=false}i+=2}for(const k of e.room.cabinets)for(const field of ['a','w','ph','dir','tm'])k[field]=s[i++];});
 const out=[];
 for(const op of fixture.ops){
  if(op.pig)setPig(op.pig);
  if(op.contact)e.hitTest(op.contact);
  if(op.collide)e.collidePig(e.pig.pos);
  if(op.push!==undefined){const c=e.room.crates[op.push];if(c){const d={'+x':[1,0],'-x':[-1,0],'+z':[0,1],'-z':[0,-1]}[op.dir];c.vx=d[0]*7;c.vz=d[1]*7;c.moving=true;c.pushed=true}}
  if(op.tip!==undefined)e.tipCabinet(e.room.cabinets[op.tip],op.dir);
  if(op.move!==undefined){const c=e.room.crates[op.move];c.x=op.x;c.z=op.z;c.vx=c.vz=0;c.moving=false}
  if(op.dt){e.t+=op.dt;if(op.rewind){e.timeline.rewind(op.dt*1.15,s=>e.rewindOk(s));e.simulate(op.dt,true)}else{e.simulate(op.dt,false);e.timeline.record(op.dt)}e.updatePlatesAndDoor(op.dt)}
  out.push(snap(e));
 }
 results.push(out);
}
process.stdout.write(JSON.stringify(results));
