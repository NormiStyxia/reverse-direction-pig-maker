import fs from 'node:fs';
import vm from 'node:vm';
import * as THREE from '../reference/h5-source/vendor/three.core.js';
const source=fs.readFileSync('reference/h5-source/src/pig.js','utf8').replace(/^import .*;$/gm,'').replaceAll('export ','');
const input=JSON.parse(fs.readFileSync(0,'utf8'));
const M=Object.create(Math);M.random=()=>.5;
const context=vm.createContext({THREE,ROOM:{halfW:7,zMin:-4.9,zMax:4.4},Math:M});
vm.runInContext(source+';globalThis.Pig=Pig;',context);
const p=Object.create(context.Pig.prototype),v=(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z);
function mesh(){const m=new THREE.Object3D();m.material={color:new THREE.Color(),opacity:0};m.visible=false;return m}
Object.assign(p,{pos:v(0,0,2.2),vel:v(),dir:v(0,0,-1),facing:Math.PI,frame:4,charge:0,cooldown:0,ghostTimer:0,spinning:false,spinT:0,spinSpeed:0,stop:0,squash:0,bob:0,chargeDir:v(),chargeHits:new Set(),tex:{offset:new THREE.Vector2()},mesh:mesh(),ghostIndex:0,ghosts:Array.from({length:8},()=>({mesh:mesh(),tex:{offset:new THREE.Vector2()},life:0}))});
p.setFrame(4);
const vec=x=>({x:x.x,y:x.y,z:x.z});
const fields=['facing','frame','charge','cooldown','ghostTimer','spinning','spinT','spinSpeed','stop','squash','bob','ghostIndex'];
const result=[];
for(const op of input){
 if(op.charge)p.tryCharge();if(op.nudge)p.nudge();
 if(op.spinDir!==undefined)p.spinDir=op.spinDir;
 if(op.spinFrame!==undefined)p.spinFrame=op.spinFrame;
 M.random=()=>op.random;
 p.update(op.dt,op.input,op.yaw,op.enabled);
 p.updateGhosts(op.dt,op.yaw);
 result.push({...Object.fromEntries(fields.map(f=>[f,p[f]])),pos:vec(p.pos),vel:vec(p.vel),dir:vec(p.dir),chargeDir:vec(p.chargeDir),pose:{position:vec(p.mesh.position),yaw:p.mesh.rotation.y,roll:p.mesh.rotation.z,scale:vec(p.mesh.scale)},ghosts:p.ghosts.map(g=>({life:g.life,visible:g.mesh.visible,...(g.max===undefined?{}:{max:g.max,opacity:g.mesh.material.opacity,position:vec(g.mesh.position),yaw:g.mesh.rotation.y,roll:g.mesh.rotation.z,scale:vec(g.mesh.scale)})}))});
}
process.stdout.write(JSON.stringify(result));
