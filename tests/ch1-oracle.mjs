import fs from 'node:fs';
import {createReference} from './ch1-reference.mjs';
import * as THREE from '../reference/h5-source/vendor/three.core.js';
const input=JSON.parse(fs.readFileSync(0,'utf8'));
let seed=12345,randomCalls=0;
const random=()=>{randomCalls++;seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
const ref=createReference({...input,random});seed=12345;randomCalls=0;
const p=ref.p,n=p.normi,b=p.phone;
const vec=v=>({x:v.x,y:v.y,z:v.z});
const scalar=['phase','t','playAt','clockMin','clockDusk','clockBack','talkT','idleT','typeT','officeTalkT','duskK','duskTo','interactionId','interactionAt','panelClosable','choiceMode','waitPanel','answer','carrying','replied','doorOpened','noBoxAt','frozen','foldT','fxK','focusK'];
function snapshot(){return {
  ...Object.fromEntries(scalar.filter(k=>p[k]!==undefined).map(k=>[k,p[k]])),
  randomCalls,expr:n.expr,exprId:p.exprId||0,result:ref.finished,pigReady:ref.pigReady,
  captions:[...ref.captions],hints:[...ref.hints],seen:[...p.seen].sort(),fired:[...p.fired].sort(),
  autoWalk:p.autoWalk?vec(p.autoWalk):false,cam:p.cam?{...p.cam,target:vec(p.cam.target)}:false,
  actor:{pos:vec(n.pos),vel:vec(n.vel),stickTarget:vec(n.stickTarget),stickTop:vec(n.stickTop),side:n.side,flip:n.flip,pose:n.pose,walking:n.walking,tense:n.tense,sway:n.sway,walkRock:n.walkRock,walkPhase:n.walkPhase,override:n.override,visible:n.mesh.visible,act:n.act,bounds:n.bounds,obstacles:n.obstacles},
  phone:{open:b.open,k:b.k,elapsed:b.elapsed,nextAt:b.nextAt,queue:b.queue,entries:b.entries,choices:b.choices,title:b.el.title.textContent||'',sub:b.el.sub.textContent||'',choicesWaiting:b.choicesWaiting||false},
  doorK:p.meeting.officeDoor.k,boxVisible:p.box?.visible??true,deskBoxVisible:p.deskBox?.visible??false,tonightVisible:p.tonight?.visible??false,
  pig:{visible:p.tablePig?.mesh.visible??false,...(p.tablePig?.mesh.visible?{spinT:p.tablePig.spinT,scale:p.tablePig.mesh.scale.x}:{})},
  people:p.meeting.people.map(x=>({kind:x.kind,y:x.flat.position.y,rz:x.flat.rotation.z,visible:x.flat.visible,leaveT:x.leaveT??false})),
  fx:{desat:p.fx.desat,grade:p.fx.grade,exposure:p.fx.exposure,kFar:p.fx.kFar,kNear:p.fx.kNear,sat:p.fx.sat,haze:p.fx.haze,focus:p.fx.focus,
    veil:p.fx.veil?{k:p.fx.veil.k,r:p.fx.veil.r}:false},
  interactions:p.nearbyInteractions(),later:p.later.map(l=>l.t)
}}
const out=[];
for(const op of input.ops){
  if(op.pos)n.setPosition(...op.pos);
  if(op.target)n.moveStick(new THREE.Vector3(...op.target));
  if(op.release)n.release();
  if(op.toggle)p.togglePhone();
  if(op.panel)p.onPanel(op.panel);
  if(op.cycle)p.cycleInteraction();
  if(op.interact)p.interact(op.interact);
  p.update(op.dt,{camYaw:op.camYaw||0,time:p.t});
  const state=input.compact?{phase:p.phase,t:p.t,actor:{pos:vec(n.pos)},answer:p.answer||false,carrying:!!p.carrying,doorK:p.meeting.officeDoor.k,result:ref.finished}:snapshot();
  out.push(JSON.parse(JSON.stringify(state)));ref.captions.length=0;ref.hints.length=0;
}
process.stdout.write(JSON.stringify(out));
