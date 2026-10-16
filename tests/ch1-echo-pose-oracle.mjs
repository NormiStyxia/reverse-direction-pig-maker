// Frozen applyRoom/merge/unfold methods, real THREE transforms, no copied expected formulas.
import fs from 'node:fs';import vm from 'node:vm';
import * as THREE from '../reference/h5-source/vendor/three.module.js';
const strip=p=>fs.readFileSync('reference/h5-source/src/'+p,'utf8').replace(/^import .*;\n/gm,'').replaceAll('export ','');
const scope={THREE,NIGHT:false,nightU:{uNight:{value:0},uNightT:{value:0}}};vm.createContext(scope);
vm.runInContext(strip('rewind-levels.js')+'\n'+strip('ch1-levels.js')+'\nglobalThis.Levels=CH1_LEVELS;globalThis.Echo=RewindLevels;',scope);
const fixtures=[];const noop=()=>{};
for(let index=0;index<scope.Levels.length;index++){
 const L=scope.Levels[index],mat=()=>({color:new THREE.Color(),opacity:1,emissiveIntensity:0,map:{offset:{x:0}}});
 const makeCrate=c=>({...c,mesh:new THREE.Group(),glow:c.kind==='now'?[mat()]:[],gold:['now','tonight','bag'].includes(c.kind),holo:['tonight','bag'].includes(c.kind)});
 const room={group:new THREE.Group(),crates:L.crates.map(makeCrate),makeCrate,fading:[],
  cabinets:(L.cabinets||[]).map(c=>({...c,pivot:new THREE.Group(),body:new THREE.Group(),dir:2,a:0,wob:0})),
  plates:L.plates.map(p=>({...p,type:p.type||'plain',mat:mat()})),panes:[],
  curtain:L.door.kind==='holo'?{material:mat(),scale:{x:1}}:null,
  glow:{material:mat()},signMat:mat(),exitMat:mat(),ring:new THREE.Object3D(),hands:[new THREE.Object3D(),new THREE.Object3D()],rainGeo:{attributes:{position:{}}},RAIN:0};
 const o=Object.create(scope.Echo.prototype);
 Object.assign(o,{index,levels:scope.Levels,theme:'meeting',room,pivot:new THREE.Vector3(L.start[0],0,L.start[1]),t:0,rwK:0,handBack:0,fx:{},audio:{tone:noop},
  hooks:{flash:noop,hitstop:noop,shake:noop},puff:noop,later:noop,makeTag:noop,line:()=>[],
  scene:{fog:{color:new THREE.Color()}},world:{lights:{hemi:new THREE.HemisphereLight(),sun:new THREE.DirectionalLight()}}});
 for(let frame=0;frame<120;frame++){
  const dt=[1/60,.05,.013][frame%3];o.t+=dt;o.rewinding=frame%50>=20;
  let merge=null;
  if(frame===35){const a=room.crates.findIndex(c=>c.kind==='past'),b=room.crates.findIndex(c=>c.kind==='tonight');if(a>=0&&b>=0){merge=[a+1,b+1];o.merge(room.crates[a],room.crates[b]);}}
  room.doorOpen=(frame%43)/42;room.doorTimer=0;for(const [j,p]of room.plates.entries())p.pressed=(frame+j)%23<11;
  const fold=Math.min(1,frame/25);const input={dt,t:o.t,fold,merge,rewinding:o.rewinding,doorOpen:room.doorOpen,pressed:room.plates.map(p=>p.pressed)};
  o.unfold(fold);o.applyRoom(dt,{camYaw:0});
  const out={crates:room.crates.map(c=>({position:c.mesh.position.toArray(),scale:c.mesh.scale.x})),
   faded:room.fading.flatMap(f=>f.list.map(c=>({position:c.mesh.position.toArray(),scale:c.mesh.scale.x,visible:c.mesh.visible}))),
   plates:room.plates.map(p=>p.mat.color.toArray()),plateAlpha:room.plates.map(p=>p.mat.opacity)};
  if(room.curtain)out.curtain={alpha:room.curtain.material.opacity,scale:room.curtain.scale.x,offset:room.curtain.material.map.offset.x};
  fixtures.push({level:index+1,input,out});
 }
}
fs.writeFileSync('validation/ch1-echo/source-pose.json',JSON.stringify(fixtures));console.log('Frozen chapter echo: '+fixtures.length+' presentation frames');
