import fs from 'node:fs';
import {catalog,hashes} from './ch1-reference.mjs';
function lua(v) {
  if(v==null)return 'false';if(typeof v==='string')return JSON.stringify(v).replace(/\\u([0-9a-f]{4})/g,'\\u{$1}');
  if(typeof v!=='object')return String(v);if(Array.isArray(v))return '{'+v.map(lua).join(',')+'}';
  return '{'+Object.entries(v).map(([k,x])=>'['+lua(k)+']='+lua(x)).join(',')+'}';
}
const data=catalog();
fs.writeFileSync('scripts/game/data/Chapter1Data.lua','-- Generated from frozen latest source by tests/export-ch1.mjs; preserved tuning overrides defaults.\nreturn '+lua(data)+'\n');
const report={sourceHashes:hashes,answers:data.answers.map(x=>x.key),paper:data.tune.paper,meetingObstacles:data.meetingObstacles.length,officeObstacles:data.officeObstacles.length};
fs.writeFileSync('docs/migration/chapter1-data-report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
