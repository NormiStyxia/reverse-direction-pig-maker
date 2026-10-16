// Executes frozen story, actor and scene builders. Only drawing/assets/audio are inert.
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
import * as THREE from '../reference/h5-source/vendor/three.core.js';
const root='reference/h5-source/';
export const source=f=>fs.readFileSync(root+'src/'+f,'utf8').replace(/^import .*;$/gm,'').replaceAll('export ','');
export const hashes={};
const manifest=JSON.parse(fs.readFileSync('docs/migration/source-manifest.json','utf8'));
for(const file of ['src/ch1-scenes.js','src/meeting.js','src/ch1-office.js','src/ch1-tuning.js','src/normi.js','src/browse.js','config/ch1-tuning.json']) {
  const hash=crypto.createHash('sha256').update(fs.readFileSync(root+file)).digest('hex');
  if(hash!==(manifest.derivedChanges?.[file]?.sha256||manifest.sourceSha256[file]))throw Error('Frozen source mismatch: '+file);
  hashes[file]=hash;
}
export function createReference({mode='meeting',answer='same',random=()=>.37}={}) {
  const math=Object.create(Math);math.random=random;
  const canvas=new Proxy({}, {get:(o,k)=>k in o?o[k]:()=>({addColorStop(){}}),set:(o,k,v)=>(o[k]=v,true)});
  function element(){return {hidden:false,dataset:{},style:{setProperty(){}},classList:{add(){},remove(){},toggle(){}},getContext(){return canvas},setAttribute(){},addEventListener(){},append(){},appendChild(){},replaceChildren(){},querySelector(){return element()},remove(){},scrollTo(){}}}
  const mat=()=>new THREE.MeshBasicMaterial();
  const context=vm.createContext({THREE,Math:math,document:{createElement:element,body:element()},requestAnimationFrame(){},
    paintSurface:()=>new THREE.Texture(),paintSlide:()=>new THREE.Texture(),paintClock:()=>new THREE.Texture(),toonGradient:()=>new THREE.Texture(),storeGradient:new THREE.Texture(),
    buildCurtainWall(){},buildGlassPartition(){},buildPlant(){},glassMaterials:()=>({glass:mat(),mullion:mat(),frost:mat()}),meetingMaterials:()=>({}),
    archiveMaterials:mat,holoArchiveMaterials:mat,buildHolo:()=>({group:new THREE.Group(),tick(){}}),nightU:{uNight:{value:0}},INK:'#222'});
  for(const [file,names] of [['meeting.js','buildMeeting,MEET,DOOR_Z0,DOOR_Z1,OFFICE_X0'],['ch1-office.js','buildOffice,MY_DESK'],['ch1-tuning.js','CH1_TUNE_DEFAULTS'],['normi.js','Normi'],['browse.js','BrowseOverlay'],['ch1-scenes.js','Ch1Meeting,Ch1Morning,KEYWORDS,ANSWERS,AFTER,MORNING,FACES,LEADER_AVATAR,ZHOU_AVATAR']])
    vm.runInContext('(function(){'+source(file)+';Object.assign(globalThis,{'+names+'});})();',context);
  const scene=new THREE.Scene();scene.fog=new THREE.Fog(0,0,100);
  const layout=JSON.parse(fs.readFileSync(root+'assets/c0/normi-motion-atlas.json','utf8'));
  const normi=new context.Normi(scene,{},layout);
  const captions=[],hints=[];let finished=false,pigReady=0;
  const image={width:100,height:100};
  const art={faces:image,office:Object.fromEntries(['coworker-headphones','coworker-bun','coworker-coffee','coworker-glasses','prop-notes','prop-seal','prop-cup'].map(k=>[k,image]))};
  const camera=new THREE.PerspectiveCamera();camera.position.set(0,8,20);camera.lookAt(0,0,0);camera.updateMatrixWorld();
  const opts={scene,normi,art,answer,camera,imgs:{leader:image,colleagueA:image,colleagueB:image,colleagueC:image},
    audio:new Proxy({}, {get:()=>()=>{}}),world:{rooms:[],rocks:[],island:{},sky:{},lights:{sun:new THREE.DirectionalLight(),hemi:new THREE.HemisphereLight()}},
    tablePig:{mesh:new THREE.Object3D(),spinT:0,setFrame(){}},hooks:{puff(){},shake(){},flash(){}},
    ui:{hint(text,duration){hints.push({text,duration:duration/1000})},title(){}},
    caption(who,text,style){captions.push({text,style})},clearCaptions(){},onPigReady(){pigReady++},onFinish(r){finished=r||true}};
  if(mode!=='morning')delete opts.answer;
  else delete opts.tablePig;
  const p=new context[mode==='morning'?'Ch1Morning':'Ch1Meeting'](opts);
  p.applyTune({...context.CH1_TUNE_DEFAULTS,...JSON.parse(fs.readFileSync(root+'config/ch1-tuning.json','utf8'))});
  const b=p.phone;b.entries=[];b.choices=[];
  for(const method of ['show','hide','push']) {const original=b[method].bind(b);b[method]=(...args)=>{original(...args);b.choices=[];if(method==='show')b.entries=[]}}
  b.render=e=>b.entries.push(e);b.setChoices=c=>b.choices=c;
  return {p,context,captions,hints,get finished(){return finished},get pigReady(){return pigReady}};
}
export function catalog() {
  const {p,context:c}=createReference();
  const vec=v=>({x:v.x,y:v.y,z:v.z});
  return {keywords:c.KEYWORDS,answers:c.ANSWERS,after:c.AFTER,morning:c.MORNING,faces:c.FACES,leaderAvatar:c.LEADER_AVATAR,zhouAvatar:c.ZHOU_AVATAR,
    bounds:p.meeting.bounds,meetingObstacles:p.meeting.obstacles,officeObstacles:p.office.obstacles,baseObstacles:p.baseObs,doorObstacle:p.doorObs,
    desk:p.office.desk,pivot:vec(p.pivot),box:vec(p.box.position),boxSpots:p.office.boxSpots.map(vec),doorZ0:c.DOOR_Z0,doorZ1:c.DOOR_Z1,officeX0:c.OFFICE_X0,
    people:p.meeting.people.map(x=>({kind:x.kind,home:vec(x.home),h:x.h})),officePeople:p.office.people.map(x=>({home:vec(x.home),head:vec(x.head),phase:x.phase})),tune:p.tune};
}
