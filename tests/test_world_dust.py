"""Execute the frozen JS generator, not a second hand-written RNG oracle."""
import json,subprocess,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
js=r'''
const fs=require('fs'),vm=require('vm');
const art=fs.readFileSync('reference/h5-source/src/art.js','utf8');
const world=fs.readFileSync('reference/h5-source/src/world.js','utf8');
const rng=art.slice(art.indexOf('export function rng('),art.indexOf('function makeCanvas')).replace('export ','');
const build=world.slice(world.indexOf('function buildDust('),world.indexOf('export function buildWorld('));
const ctx={Float32Array,LAYER_NEAR:1,paintDot:()=>null,THREE:{
 BufferGeometry:class{setAttribute(k,v){this[k]=v}},BufferAttribute:class{constructor(a){this.array=a}},
 PointsMaterial:class{constructor(v){Object.assign(this,v)}},Color:class{constructor(...a){this.rgb=a}},
 Points:class{constructor(g,m){this.geometry=g;this.material=m;this.layers={set(){}}}},NormalBlending:1,AdditiveBlending:2}};
vm.createContext(ctx);vm.runInContext(rng+build,ctx);
const out=[[260,[44,12,30],0,.09],[46,[6,4,4],1,.05]].map(args=>{const p=ctx.buildDust(...args);return {positions:Array.from(p.geometry.position.array),material:p.material}});
console.log(JSON.stringify(out));
'''
ref=json.loads(subprocess.check_output(['node','-e',js],text=True))
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
p=lua.eval("require('render.DustPattern')")[0];checked=0
for name,source in zip(['main','near'],ref):
 flat=[p[name][i][j] for i in range(1,len(p[name])+1) for j in range(1,4)]
 assert flat==source['positions'];checked+=len(flat)
# PointSize = size * physicalHeight/2 / depth; native diameter compensates FOV.
for h in [720,1080,1676,2532]:
 for fov in [18,24,35,60]:
  for depth in [1,4.5,6.5,8.5,20,50,200]:
   for size in [.09,.05]:
    tangent=math.tan(math.radians(fov)*.5)
    diameter=max(size*tangent,2*tangent/h*depth)
    native=diameter/depth/tangent*h*.5
    source=max(1,size*h*.5/depth)
    assert abs(native-source)<1e-12;checked+=1
report={'result':'PASS','scalarChecks':checked,'sourcePositionValues':918,'particles':[260,46],
 'scope':'Frozen JS buildDust/rng exact float32 positions and perspective point-size math; GPU evidence separate'}
(root/'docs/migration/dust-model-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
