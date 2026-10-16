// Evaluate only frozen data declarations. Never import the historical c0 route.
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
const root='reference/h5-source/src/';
const manifest=JSON.parse(fs.readFileSync('docs/migration/source-manifest.json','utf8'));
for(const file of ['src/store-prologue.js','src/store-chapter.js','src/store.js','assets/c0/normi-motion-atlas.json','config/ch1-tuning.json']) {
  const hash=crypto.createHash('sha256').update(fs.readFileSync('reference/h5-source/'+file)).digest('hex');
  if(hash!==(manifest.derivedChanges?.[file]?.sha256||manifest.sourceSha256[file]))throw new Error('Frozen source mismatch: '+file);
}
const parent=fs.readFileSync(root+'store-chapter.js','utf8');
const source=fs.readFileSync(root+'store-prologue.js','utf8');
const store=fs.readFileSync(root+'store.js','utf8');
const slice=(s,a,b)=>s.slice(s.indexOf(a),s.indexOf(b));
const context=vm.createContext({});
vm.runInContext([
  slice(parent,'export const card =','const BROWSE =').replaceAll('export ',''),
  slice(source,'const BASE =','export class PrologueStore').replaceAll('export ',''),
  slice(store,'export const STORE =','const gradient =').replaceAll('export ',''),
  store.match(/const T = \{ x: -2.0[^;]+;/)[0],
  store.match(/const door = \{ x0: 3.1[^;]+;/)[0],
  slice(store,'  const obstacles =','  const isFree ='),
  slice(store,'  const zones =','  // ---- 路人'),
  'globalThis.data={lines:LINES,browse:BROWSE,bounds:STORE,table:T,door,zones,obstacles};',
].join('\n'),context);
function lua(v) {
  if(v==null)return 'false';
  if(typeof v==='string')return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g,'\\u{$1}');
  if(typeof v!=='object')return String(v);
  if(Array.isArray(v))return '{'+v.map(lua).join(',')+'}';
  const reserved=new Set(['end','repeat','until','function','local','if','else','elseif','then','do','while','for','in','return','and','or','not','true','false','nil','break','goto']);
  return '{'+Object.entries(v).map(([k,x])=>(/^[a-zA-Z_]\w*$/.test(k)&&!reserved.has(k)?k:'['+lua(k)+']')+'='+lua(x)).join(',')+'}';
}
const data=JSON.parse(JSON.stringify(context.data));
data.normiLayout=JSON.parse(fs.readFileSync('reference/h5-source/assets/c0/normi-motion-atlas.json','utf8'));
const out='scripts/game/data/PrologueData.lua';
const schema='---@class PrologueCatalog\n---@field lines table<string, any>\n---@field browse table<string, table[]>\n---@field bounds {halfW:number,zMin:number,zMax:number}\n---@field table {x:number,y:number,z:number}\n---@field door {x0:number,x1:number,h:number}\n---@field zones table<string, any>\n---@field obstacles {x0:number,x1:number,z0:number,z1:number}[]\n---@field normiLayout table\n';
fs.writeFileSync(out,'-- Generated from the frozen latest source by tests/export-prologue.mjs.\n-- Choice numbers remain zero-based; false is a terminal branch.\n'+schema+'local catalog='+lua(data)+'\nreturn catalog\n');
const report={source:'frozen chapter1 6a316e84907d8bc94ab59f20796685172b3535b5 + preserved tuning',output:out,
  hashes:Object.fromEntries(['store-prologue.js','store-chapter.js','store.js'].map(f=>[f,crypto.createHash('sha256').update(fs.readFileSync(root+f)).digest('hex')])),
  activities:Object.values(data.browse).flat().length,nodes:Object.values(data.browse).flat().reduce((n,a)=>n+Object.keys(a.nodes).length,0),workMessages:data.lines.work.length};
fs.writeFileSync('docs/migration/prologue-data-report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
