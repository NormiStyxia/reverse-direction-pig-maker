"""Compare frozen buildHotFood update and RNG stream against native Lua model."""
import json,random,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
rng=random.Random(77);steps=[];time=0
for i in range(1200):
 dt=rng.choice([0,.001,1/60,.033,.05,.2]);time+=dt
 steps.append(dict(dt=dt,time=time,amount=[0,.64,1,1.7][i//300]))
ref=json.loads(subprocess.check_output(['node','tests/steam-oracle.mjs'],input=json.dumps(steps),text=True))
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
p=lua.eval("require('game.HotFoodSteam').new()");checks=0
for frame,(s,e) in enumerate(zip(steps,ref['snapshots'])):
 p.update(p,s['dt'],s['time'],s['amount']);assert abs(p.size-e['size'])<1e-14
 for i,part in enumerate(e['parts'],1):
  for key,v in part.items():
   assert abs(p.parts[i][key]-v)<1e-12,(frame,i,key,p.parts[i][key],v);checks+=1
  for j,key in enumerate(['x','y','z']):
   assert p.points[i][key]==e['pos'][(i-1)*3+j],(frame,i,key);checks+=1
  for j,key in enumerate(['r','g','b']):
   assert p.points[i][key]==e['col'][(i-1)*3+j],(frame,i,key);checks+=1
before=[[p.points[i][k] for k in ['x','y','z','r','g','b']] for i in range(1,91)]
for _ in range(120):p.update(p,0,time,steps[-1]['amount'])
assert before==[[p.points[i][k] for k in ['x','y','z','r','g','b']] for i in range(1,91)]
report=dict(result='PASS',frames=len(steps),particles=90,scalarChecks=checks,initialRandomCalls=ref['initialRandomCalls'],finalRandomCalls=ref['finalRandomCalls'],scope='actual frozen buildHotFood RNG/respawn/drift/Float32 position/color/amount/size plus 120 paused frames; not GPU acceptance')
(root/'docs/migration/steam-model-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report))
