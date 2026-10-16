// Execute the frozen unfold/applyRoom methods with actual THREE transforms.
// No browser, rendering mock, or copied expected transform formulas.
import fs from 'node:fs';
import vm from 'node:vm';
import * as THREE from '../reference/h5-source/vendor/three.module.js';
const text=fs.readFileSync('reference/h5-source/src/rewind-levels.js','utf8').replace(/^import .*;\n/gm,'').replaceAll('export ','');
const scope={THREE,NIGHT:true,nightU:{uNight:{value:1},uNightT:{value:0}}};vm.createContext(scope);
vm.runInContext(text+'\nglobalThis.Levels=LEVELS;globalThis.Echo=RewindLevels;',scope);
const fixtures=[];
for(let index=0;index<scope.Levels.length;index++){
 const L=scope.Levels[index],group=new THREE.Group();
 const mat=()=>({color:new THREE.Color(),opacity:1,emissiveIntensity:0});
 const room={group,crates:(L.crates||[]).map(c=>({...c,mesh:new THREE.Group(),glow:c.gold?[mat()]:[]})),
  cabinets:(L.cabinets||[]).map(c=>({...c,pivot:new THREE.Group(),body:new THREE.Group(),wob:0})),
  plates:(L.plates||[]).map(p=>({...p,type:p.gold?'gold':'plain',mat:mat()})),panes:[-1,1].map(side=>({side,g:new THREE.Group()})),
  glow:{material:mat()},signMat:mat(),exitMat:mat(),ring:new THREE.Object3D(),hands:[new THREE.Object3D(),new THREE.Object3D()],
  rainGeo:{attributes:{position:{}}},RAIN:0,fading:[]};
 const o=Object.create(scope.Echo.prototype);
 Object.assign(o,{index,levels:scope.Levels,theme:'store',room,pivot:new THREE.Vector3(L.start[0],0,L.start[1]),t:0,rwK:0,handBack:0,fx:{},audio:{},
  scene:{fog:{color:new THREE.Color()}},world:{lights:{hemi:new THREE.HemisphereLight(),sun:new THREE.DirectionalLight()}}});
 for(let i=0;i<120;i++){
  const dt=[1/60,.05,.013][i%3];o.t+=dt;o.rewinding=i%50>=20;
  const fold=Math.min(1,i/60);room.doorOpen=(i%43)/42;room.doorTimer=(L.door.hold||0)*(i%29)/29;
  for(const [j,c]of room.crates.entries()){c.x=L.crates[j].x+Math.sin(i*.13+j);c.z=L.crates[j].z+Math.cos(i*.09+j)*.7;}
  for(const [j,c]of room.cabinets.entries()){c.dir=Math.floor(i/30)%4;c.a=(i%30)/29*Math.PI/2;if(i%40===0)c.wob=.5;}
  for(const [j,p]of room.plates.entries())p.pressed=(i+j)%23<11;
  const input={dt,t:o.t,fold,rewinding:o.rewinding,doorOpen:room.doorOpen,doorTimer:room.doorTimer,
   crates:room.crates.map(c=>({x:c.x,z:c.z})),cabinets:room.cabinets.map(c=>({x:c.x,z:c.z,a:c.a,dir:c.dir,wob:c.wob})),pressed:room.plates.map(p=>p.pressed)};
  o.unfold(fold);o.applyRoom(dt,{camYaw:.13});
  const out={root:{position:group.position.toArray(),quaternion:group.quaternion.toArray(),scale:group.scale.x},
   crates:room.crates.map(c=>({position:c.mesh.position.toArray(),glow:c.glow[0]?.emissiveIntensity})),
   cabinets:room.cabinets.map(c=>({position:c.pivot.position.toArray(),body:c.body.position.toArray(),quaternion:c.pivot.quaternion.toArray()})),
   doorOffset:room.panes[1].g.position.x,doorGlow:room.glow.material.opacity,sign:room.signMat.color.r,
   plates:room.plates.map(p=>p.mat.color.toArray()),exitOn:room.ring.visible,exitAlpha:room.exitMat.opacity,ringAngle:room.ring.rotation.z,hands:room.hands.map(h=>h.rotation.z)};
  fixtures.push({level:index+1,input,out});
 }
}
fs.writeFileSync('validation/echo/source-pose.json',JSON.stringify(fixtures));console.log('Frozen unfold/applyRoom: '+fixtures.length+' presentation frames');
