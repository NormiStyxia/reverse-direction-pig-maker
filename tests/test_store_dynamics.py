"""Compare native presentation with actual frozen buildStore.update/fold in Chrome."""
import json,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
fixture=json.loads((ROOT/'validation/store/source-dynamics.json').read_text())
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Dynamics=lua.eval("require('game.StoreDynamics')")[0]
state=fixture['seed'];calls=0;checks=0
def random():
    global state,calls
    state=(state*1664525+1013904223)&0xffffffff;calls+=1
    return state/4294967296
def table(v):
    if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(x) for x in v])
    return v
def compare(a,b,path):
    global checks
    if isinstance(b,dict):
        for k,v in b.items():compare(a[k],v,path+'.'+k)
    elif isinstance(b,list):
        assert len(a)==len(b),(path,len(a),len(b))
        for i,v in enumerate(b):compare(a[i+1],v,path+str(i))
    elif isinstance(b,bool):assert bool(a)==b,(path,a,b);checks+=1
    elif isinstance(b,(int,float)):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-9),(path,a,b);checks+=1
    else:assert a==b,(path,a,b);checks+=1
model=Dynamics.new(random)
for i,frame in enumerate(fixture['frames']):
    op=frame['input']
    if op['force']:model.forceDoor(model,op['force'])
    model.update(model,op['dt'],table(op))
    for k,want in frame['expected'].items():
        if k=='randomCalls':compare(calls,want,str(i)+'.randomCalls')
        elif k=='flats':
            actual={f.name:f for f in model.flats.values()}
            for f in want:compare(actual[f['name']],f,str(i)+'.flat.'+f['name'])
        else:compare(model[k],want,str(i)+'.'+k)
report={'result':'PASS','frames':len(fixture['frames']),'scalarChecks':checks,'sourceRandomCalls':calls,
        'covered':['door proximity/forced opening/closing','clerk sway','wind/leaves','empty-chair distortion',
                   'flicker and blackout tube colors','ceiling/fridge/food/bounce intensities','seven flat fold transforms'],
        'notCovered':['GPU parity','walkers','steam/rain','pig rendering','audio','full game'] }
(ROOT/'docs/migration/store-dynamics-test-report.json').write_text(json.dumps(report,indent=2)+chr(10))
print(json.dumps(report,indent=2))
