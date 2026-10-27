// Build-time data import. The game ships Lua and native resources, never a JS runtime.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import vm from 'node:vm';
const pack=path.resolve(process.argv[2] || 'reference/increment04');
const source=path.join(pack,'h5-source');
const manifest=JSON.parse(fs.readFileSync(path.join(pack,'source-manifest.json')));
const expected='936230c91fa6a133958ab44c7af44e864d1f720cf747cd150124a1a9f1453517';
if(manifest.sourceTreeSha256!==expected)throw Error('Wrong frozen increment');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
for(const [name,hash] of Object.entries(manifest.sourceSha256))
  if(sha(fs.readFileSync(path.join(source,name)))!==hash)throw Error('Frozen file mismatch: '+name);
const read=name=>fs.readFileSync(path.join(source,'src',name),'utf8');
function constant(file,name){
  const s=read(file),start=s.indexOf('export const '+name+' = ');
  if(start<0)throw Error('Missing '+name);
  const end=s.indexOf('\n];'.replace('\\n','\n'),start)+3;
  if(end<3)throw Error('Missing array end '+name);
  return vm.runInNewContext(s.slice(start,end).replace('export ','')+';JSON.stringify('+name+')',{}, {timeout:1000});
}
function lua(v){
  if(v===null)return 'false';
  if(typeof v==='string')return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g,'\\u{$1}');
  if(typeof v!=='object')return String(v);
  if(Array.isArray(v))return '{'+v.map(lua).join(',')+'}';
  return '{'+Object.entries(v).map(([k,x])=>'['+lua(k)+']='+lua(x)).join(',')+'}';
}
const levels=Object.fromEntries([['prologue','rewind-levels.js','LEVELS'],['chapter1','ch1-levels.js','CH1_LEVELS'],['office','ch1-levels.js','CH1_OFFICE_LEVELS'],['dorm','ch1-levels.js','CH1_DORM_LEVELS']].map(([k,f,n])=>[k,JSON.parse(constant(f,n))]));
const tuning=Object.fromEntries(['store','ch1'].map(k=>{
  const defaults=read(k+'-tuning.js').match(/export const \w+_TUNE_DEFAULTS = (\{[\s\S]*?\n\});/)[1];
  return [k,{...vm.runInNewContext('('+defaults+')'),...JSON.parse(fs.readFileSync(path.join(source,'config',k+'-tuning.json')))}];
}));
const helpers={think:text=>({kind:'thought',text}),me:text=>({kind:'me',text}),line:text=>({kind:'line',text}),card:(name,rows)=>({kind:'card',name,rows}),
  leader:text=>({kind:'msg',name:'领导',avatar:'./assets/ch1/avatar-leader.png',text}),
  chen:text=>({kind:'msg',name:'老陈',avatar:'./assets/c0/colleague-c.png',text}),
  zhou:text=>({kind:'msg',name:'小周',avatar:'./assets/ch1/avatar-zhou.jpg',text})};
const narrative={};
const prologuePrefix=read('store-prologue.js').split('export class PrologueStore')[0].replace(/^import .*;$/gm,'').replace(/\bexport const\b/g,'const');
const store=vm.runInNewContext(prologuePrefix+';({lines:LINES,browse:BROWSE})',{
 THREE:{MathUtils:{}},...helpers,scene:(src,prop=false)=>({kind:'scene',src,prop}),
 card:(name,rows,price=null,note=null,img=null)=>({kind:'card',name,rows,price,note,img}),pic:(img,caption)=>({kind:'pic',img,caption})});
narrative.STORE_LINES=store.lines;narrative.STORE_BROWSE=store.browse;
for(const name of ['STICKERS','REACTIONS']){
 const text=read('phone.js').match(new RegExp('export const '+name+' = ([\\s\\S]*?);(?=\\n)'))[1];
 narrative[name]=vm.runInNewContext('('+text+')');
}
narrative.TONIGHT=vm.runInNewContext('('+read('ch1-art.js').match(/export const TONIGHT = (\{[\s\S]*?\n\});/)[1]+')');
for(const name of ['WAKE','REWAKE','RE_ECHO','PARK','WHY_FIRST','MEET_CHAT','ASK','ASK_THINK','ANSWERS','AFTER','MEET_BRANCH','CHEN_TALK','BRANCH_FATE','MORNING','CHEN_SEAT','CHEN_MUTTER','CHEN_ASK','MORNING_ANSWERS','DORM_REWIND','DORM_ASK','DORM_ANSWERS','DORM_FREE','DORM_JAM']){
  const match=read('ch1-scenes.js').match(new RegExp('const '+name+' = ([\\s\\S]*?);(?=\\n)'));
  if(!match)throw Error('Missing story constant '+name);
  narrative[name]=vm.runInNewContext('('+match[1]+')',helpers,{timeout:1000});
}
for(const name of ['OFFICE_LINES','OFFICE_LOOKS','DREAM_LINES']){
  const file=name.startsWith('OFFICE')?'prologue-office.js':'dream.js';
  const s=read(file),start=s.indexOf('export const '+name+' = '),end=s.indexOf('\n};',start)+3;
  narrative[name]=vm.runInNewContext(s.slice(start,end).replace('export ','')+';'+name,{LEADER:{name:'领导',avatar:'./assets/ch1/avatar-leader.png'},ZHOU:{name:'小周',avatar:'./assets/ch1/avatar-zhou.jpg'}});
}
const day=read('store-day.js').split('export class Ch1DayStore')[0].replace(/^import .*;$/gm,'').replace(/export const/g,'const');
const dayData=vm.runInNewContext(day+';({lines:DAY_LINES,browse:BROWSE})',{THREE:{MathUtils:{},Color:class{}},...helpers,card:(name,rows,price=null,note=null,img=null)=>({kind:'card',name,rows,price,note,img}),pic:(img,caption)=>({kind:'pic',img,caption})});
narrative.DAY_LINES=dayData.lines;narrative.DAY_BROWSE=dayData.browse;
const cards=vm.runInNewContext(read('mech-card.js').split('export class MechCard')[0]+';CARDS');
fs.writeFileSync('scripts/game/data/MechanismCards.lua','-- Frozen increment04 native diagram input.\nreturn '+lua(cards)+'\n');
const nodes=JSON.parse(constant('timeline.js','NODES'));
for(const [name,value] of Object.entries({Levels:levels,Tuning:tuning,TimelineNodes:nodes,Story03Data:narrative}))
  fs.writeFileSync('scripts/game/data/'+name+'.lua','-- Frozen increment 04: '+expected+'; generated by tests/import-increment04.mjs.\n-- Array indices are 1-based; plate references retain source 0-based values.\nreturn '+lua(value)+'\n');
// Keep the previous reference intact for historical reports.
fs.mkdirSync('reference/increment04',{recursive:true});
if(source!==path.resolve('reference/increment04/h5-source'))fs.cpSync(source,'reference/increment04/h5-source',{recursive:true});
if(path.join(pack,'source-manifest.json')!==path.resolve('reference/increment04/source-manifest.json'))fs.copyFileSync(path.join(pack,'source-manifest.json'),'reference/increment04/source-manifest.json');
let copied=0;
for(const name of Object.keys(manifest.sourceSha256)){
  if(!name.startsWith('assets/')&&!name.startsWith('config/'))continue;
  const dest=name.startsWith('config/')?'assets/'+name:name;
  fs.mkdirSync(path.dirname(dest),{recursive:true});
  if(!fs.existsSync(dest)||sha(fs.readFileSync(dest))!==manifest.sourceSha256[name]){fs.copyFileSync(path.join(source,name),dest);copied++;}
}
const report={sourceTreeSha256:expected,sourceFiles:Object.keys(manifest.sourceSha256).length,levels:Object.fromEntries(Object.entries(levels).map(([k,v])=>[k,v.length])),nodes:nodes.length,assetsUpdated:copied,status:'DATA_IMPORTED_NATIVE_ACCEPTANCE_PENDING'};
fs.writeFileSync('docs/migration/increment04-import.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
