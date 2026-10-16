"""Compare event-driven effects with executable expressions from frozen main.js."""
import json, random, re, subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
src=(root/'reference/h5-source/src/main.js').read_text()
hooks='\n'.join(re.findall(r'^  (?:shock|shake|flash):.*$',src,re.M))
camera=src[src.index('  r.shake *='):src.index('  camera.lookAt(look);',src.index('  r.shake *='))]
decay='\n'.join(re.findall(r'^  fx\.(?:shock|flash) \*=.*$',src,re.M))
rng=random.Random(6316)
steps=[{'dt':1/60,'events':[]} for _ in range(180)]
steps += [{'dt':rng.choice([.001,.016,1/60,.05,.0008333333333]),'events':
           [[rng.choice(['flash','shake','shock']),rng.random()*.6]] if i%19==0 else []} for i in range(8000)]
steps += [{'dt':1/60,'events':[]} for _ in range(300)]
js='''const steps=JSON.parse(require('fs').readFileSync(0,'utf8'));
let seed=6316;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
const fx={shock:0,shockSeed:0,flash:0},rig={shake:0},r=rig;
class V {constructor(x,y,z){this.x=x;this.y=y;this.z=z}multiplyScalar(s){this.x*=s;this.y*=s;return this}}
const THREE={Vector3:V};let offset={x:0,y:0};const camera={position:{add:v=>offset=v}};
const hooks={''' + hooks + '''};
console.log(JSON.stringify(steps.map(s=>{const dt=s.dt;for(const [kind,v] of s.events)hooks[kind](v);offset={x:0,y:0};
''' + camera + decay + '''
return {...fx,shake:rig.shake,x:offset.x,y:offset.y}})));'''
expected=json.loads(subprocess.check_output(['node','-e',js],input=json.dumps(steps),text=True))
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
e=lua.eval("function()local s=6316;return require('game.ScreenEffects').new(function()s=(s*1664525+1013904223)&0xffffffff;return s/4294967296 end)end")()
checks=0
for i,(step,ref) in enumerate(zip(steps,expected)):
 for kind,v in step['events']: e.trigger(e,kind,v)
 e.camera(e,step['dt']);e.update(e,step['dt'])
 for key,want in ref.items():
  assert abs(e[key]-want)<1e-12,(i,key,e[key],want);checks+=1
# A real pause differs deliberately from calling the original dt=0 loop:
# no new randomness and no camera offset changes while the runtime is paused.
e.trigger(e,'shake',.45);e.camera(e,1/60);snapshot=[e[k] for k in ['shake','x','y','flash','shock']]
for _ in range(120):
 e.camera(e,0);e.update(e,0)
 assert [e[k] for k in ['shake','x','y','flash','shock']]==snapshot;checks+=1
# Actual production event shapes and semantic echo hooks.
for kind,data,expected_values in [('crateStop',{}, {'shake':.12}),('cabinetDown',{}, {'shake':.45}),
 ('merge',{}, {'flash':.6,'shake':.3}),('exitReached',1,{'flash':.4}),('shake',.22,{'shake':.22})]:
 e.reset(e);e.event(e,lua.table_from({'kind':kind,'data':lua.table_from(data) if isinstance(data,dict) else data}))
 for key,value in expected_values.items():assert e[key]==value;checks+=1
for kind in ['flash','shock','shake']:
 e.reset(e);e.event(e,lua.table_from({'kind':kind,'amount':.25}));assert e[kind]==.25;checks+=1
# Idle has exactly zero camera displacement, regardless of dt; no ambient jitter.
e.reset(e)
for _ in range(300):assert e.camera(e,1/60)==(0,0);checks+=1
report={'result':'PASS','sourceFrames':len(steps),'scalarChecks':checks,'scope':'Frozen JS effect hooks, camera offsets and exponential decay; paused stability and production event shapes; not full-scene visual parity'}
(root/'docs/migration/screen-effects-model-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
