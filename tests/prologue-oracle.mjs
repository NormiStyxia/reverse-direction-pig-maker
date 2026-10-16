// Run frozen JS classes, including the real THREE-vector actor update.
// Only DOM painting, GPU materials and audio terminate in inert adapters.
import fs from 'node:fs';
import vm from 'node:vm';
import * as THREE from '../reference/h5-source/vendor/three.core.js';
const input=JSON.parse(fs.readFileSync(0,'utf8'));
const source=f=>fs.readFileSync('reference/h5-source/src/'+f,'utf8').replace(/^import .*;$/gm,'').replaceAll('export ','');
const M=Object.create(Math);M.random=()=>.37;
function element(){return {hidden:false,dataset:{},style:{setProperty(){}},classList:{add(){},remove(){},toggle(){}},setAttribute(){},addEventListener(){},append(){},appendChild(){},replaceChildren(){},querySelector(){return element()},remove(){},scrollTo(){}}}
const context=vm.createContext({THREE,Math:M,document:{createElement:element,body:element()},requestAnimationFrame(){},paintSurface(){return new THREE.Texture()},nightU:{uNight:{value:0}},setShadowStep(){}});
vm.runInContext('(function(){'+source('normi.js')+';globalThis.Normi=Normi;})();',context);
vm.runInContext('(function(){'+source('browse.js')+';globalThis.BrowseOverlay=BrowseOverlay;})();',context);
vm.runInContext('(function(){'+source('store-chapter.js')+';Object.assign(globalThis,{StoreChapter,clockText,card,line,think,pic});})();',context);
vm.runInContext('(function(){'+source('store-prologue.js')+';globalThis.PrologueStore=PrologueStore;})();',context);
const layout=JSON.parse(fs.readFileSync('assets/c0/normi-motion-atlas.json','utf8'));
const dataContext=vm.createContext({});
const storeSource=source('store.js');
const part=(a,b)=>storeSource.slice(storeSource.indexOf(a),storeSource.indexOf(b));
vm.runInContext([part('const STORE =','const gradient ='),storeSource.match(/const T = \{ x: -2.0[^;]+;/)[0],storeSource.match(/const door = \{ x0: 3.1[^;]+;/)[0],part('  const obstacles =','  const isFree ='),part('  const zones =','  // ---- 路人'),'globalThis.data={bounds:STORE,table:T,door,zones,obstacles};'].join('\n'),dataContext);
const data=dataContext.data;
const scene=new THREE.Scene();scene.fog=new THREE.Fog(0,0,100);
const normi=new context.Normi(scene,{},layout);normi.obstacles=data.obstacles;normi.bounds=data.bounds;
const captions=[],hints=[];let finished=null,pigReady=0;
const store={...data,clerk:{head:new THREE.Vector3()},archive:{visible:false},power:1,flickBoost:0,weatherK:0,
  door:{...data.door,open:0},seatAnchor:new THREE.Object3D(),setClock(){},update(){},setSun(){},setDoodle(){},fold(k){this.foldK=k},spawn(kind,path,{onStep}){this.onRiderStep=onStep}};
const phone={target:0,k:0,elapsed:0,screen:{view:'lock',recallable:[]},cfg:{},buttons:[],
  get open(){return this.target>0},config(c){Object.assign(this.cfg,c)},set(p){Object.assign(this.screen,p)},setButtons(b){this.buttons=b},show(){this.target=1},hide(){this.target=0;this.buttons=[]},
  update(dt){this.elapsed+=dt;this.k+=(this.target-this.k)*(1-Math.exp(-dt*(this.target?7:9)));if(Math.abs(this.k-this.target)<.002)this.k=this.target}};
const audio=new Proxy({powerK:1},{get(o,k){return k in o?o[k]:()=>{}}});
const pig=()=>({mesh:new THREE.Object3D(),mat:{},spinT:0,setFrame(){}});
const p=new context.PrologueStore({deferIntro:true,scene,normi,store,phone,audio,tablePig:pig(),glassPig:pig(),camera:new THREE.PerspectiveCamera(),
  world:{lights:{sun:new THREE.DirectionalLight(),hemi:new THREE.HemisphereLight()}},
  hooks:{puff(){},shake(){},flash(){}},ui:{hint(text,duration){hints.push({text,duration})}},
  caption(who,text,style){captions.push({speaker:who.pos===store.clerk.head?'clerk':who.pos===store.riderHead?'rider':'normi',text,style})},clearCaptions(){},
  onPigReady(){pigReady++},onFinish(r){finished=JSON.parse(JSON.stringify(r))},startStress:input.startStress||0});
p.tune=JSON.parse(fs.readFileSync('assets/config/store-tuning.json','utf8'));
p.updateGlassPig=()=>{};p.applyStorm=()=>{};
const b=p.browse;b.entries=[];b.choices=[];
const show=b.show.bind(b),hide=b.hide.bind(b),push=b.push.bind(b);
b.show=(...a)=>{show(...a);b.entries=[];b.choices=[]};b.hide=()=>{hide();b.choices=[]};b.push=(...a)=>{push(...a);b.choices=[]};
b.render=e=>b.entries.push(e);b.setChoices=c=>b.choices=c;
if(input.begin!==false)p.begin();
const vec=v=>({x:v.x,y:v.y,z:v.z});
const scalar=['phase','t','clock','stress','sv','sentN','workI','offline','sitting','standT','lastDoor','idleT','interactionAt','interactionId','msgSeq'];
function snapshot(){return {
  ...Object.fromEntries(scalar.map(k=>[k,p[k]])),darkT:p.darkT||0,foldT:p.foldT||0,doodleK:p.doodleK||0,doodleGone:!!p.doodleGone,pigK:p.pigK||0,saidFail:!!p.saidFail,
  msgs:p.msgs,mem:p.mem,draft:p.draft,pending:p.pending?.text||null,unread:p.unread,
  captions:[...captions],hints:[...hints],pigReady,finished,
  actor:{pos:vec(normi.pos),vel:vec(normi.vel),stickTarget:vec(normi.stickTarget),stickTop:vec(normi.stickTop),side:normi.side,flip:normi.flip,pose:normi.pose,walking:normi.walking,tense:normi.tense,sway:normi.sway,walkRock:normi.walkRock,walkPhase:normi.walkPhase,override:normi.override,visible:normi.mesh.visible,act:normi.act},
  phone:{open:phone.open,k:phone.k,view:phone.screen.view,time:phone.screen.time,draft:phone.screen.draft,buttons:phone.buttons,msgs:phone.screen.msgs,recallable:phone.screen.recallable},
  browse:{open:b.open,k:b.k,elapsed:b.elapsed,nextAt:b.nextAt,queue:b.queue,entries:b.entries,choices:b.choices,title:b.el.title.textContent||'',sub:b.el.sub.textContent||'',closeLabel:b.el.close.title||''},
  power:store.power,flickBoost:store.flickBoost,archiveVisible:store.archive.visible,
  tablePig:{visible:p.tablePig.mesh.visible,spinT:p.tablePig.spinT,scale:p.tablePig.mesh.visible?p.tablePig.mesh.scale.x:.42,light:p.pigLight.intensity},
  fx:{haze:p.fx.haze||0,fold:store.foldK||0,veil:p.fx.veil?{k:p.fx.veil.k,r:p.fx.veil.r}:{k:0,r:1.9}},
  interactions:p.nearbyInteractions(),later:p.later.map(l=>l.t),
}}
const out=[];
for(const op of input.ops){
  if(op.pos)normi.setPosition(...op.pos);
  if(op.target)normi.moveStick(new THREE.Vector3(...op.target));
  if(op.release)normi.release();
  if(op.toggle)p.togglePhone();
  if(op.phone)p.onPhone(op.phone);
  if(op.browse)p.onBrowse(op.browse);
  if(op.startBrowse)p.startBrowse(op.startBrowse);
  if(op.cycle)p.cycleInteraction();
  if(op.interact)p.interact(op.interact);
  if(op.riderStep!==undefined){store.riderHead=new THREE.Vector3();store.onRiderStep?.({head:store.riderHead},op.riderStep)}
  p.update(op.dt,{camYaw:op.camYaw||0,moving:!!op.moving,time:p.t});
  const state=input.compact?{phase:p.phase,t:p.t,clock:p.clock,actor:{pos:vec(normi.pos)},finished}:snapshot();
  out.push(JSON.parse(JSON.stringify(state)));captions.length=0;hints.length=0;
}
process.stdout.write(JSON.stringify(out));
