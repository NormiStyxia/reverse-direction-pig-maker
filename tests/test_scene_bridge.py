"""Execute frozen updateBridge and native Lua on identical timing sequences."""
import json,random,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
source=(root/'reference/h5-source/src/main.js').read_text()
source=source[source.index('function startBridge()'):source.index('// ---------- 主循环 ----------')]
rng=random.Random(6316)
steps=[{'dt':0,'blue':0,'start':True}]
steps += [{'dt':1/60,'blue':.6} for _ in range(360)]
steps += [{'dt':rng.choice([0,.001,.016,.033,.05]),'blue':rng.random()*.6,'start':i%1000==0} for i in range(8000)]
oracle='''
const steps=JSON.parse(require('fs').readFileSync(0,'utf8'));
const THREE={MathUtils:{lerp:(a,b,k)=>a+(b-a)*k,smootherstep:(x,a,b)=>{const k=Math.max(0,Math.min(1,(x-a)/(b-a)));return k*k*k*(k*(k*6-15)+10)}}};
const bridge={on:false,t:0},post={blue:{}},rig={bridgeDist:1},store={normi:{pos:{}},fx:{blue:0}},echo=null,pig={},camera={};
const _bp={x:0,y:0,copy(){return this},setY(){return this},project(){return this}};
''' + source + '''
console.log(JSON.stringify(steps.map(s=>{store.fx.blue=s.blue;if(s.start)startBridge();updateBridge(s.dt);return {on:bridge.on,t:bridge.t,distance:rig.bridgeDist,blue:post.blue.k,sweep:post.blue.sweep}})));
'''
expected=json.loads(subprocess.check_output(['node','-e',oracle],input=json.dumps(steps),text=True))
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
b=lua.eval("require('game.SceneBridge').new()")
for i,(step,e) in enumerate(zip(steps,expected)):
    if step.get('start'):b.start(b)
    b.update(b,step['dt'],step['blue'])
    for key,want in e.items():
        got=b[key];assert got==want if isinstance(want,bool) else abs(got-want)<1e-12,(i,key,got,want)
report={'result':'PASS','frames':len(steps),'scope':'frozen main.js timing, sweep, previous-frame distance output, inactive rewind strength; not pixel parity'}
(root/'docs/migration/scene-bridge-test-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report))
