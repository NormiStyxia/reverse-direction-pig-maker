"""Differential checks against the actual frozen JS, not a rewritten oracle.
Run: python3 tests/test_migration.py (requires lupa and Node.js).
These are pure-logic checks, not UrhoX gameplay or visual acceptance.
"""
import json
import math
from pathlib import Path
import random
import subprocess
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)

def compare(expected, actual, at='root'):
    if isinstance(expected, dict):
        assert set(expected) == set(actual.keys()), at
        for key, value in expected.items():
            compare(value, actual[key], f'{at}.{key}')
    elif isinstance(expected, list):
        assert len(expected) == len(actual), at
        for i, value in enumerate(expected, 1):
            compare(value, actual[i], f'{at}[{i}]')
    elif isinstance(expected, (int, float)) and not isinstance(expected, bool):
        assert math.isclose(expected, actual, abs_tol=1e-9), (at, expected, actual)
    else:
        assert expected == actual, (at, expected, actual)

levels = lua.execute((ROOT/'scripts/game/data/Levels.lua').read_text())
compare(json.loads((ROOT/'reference/levels.json').read_text()), levels)
tuning = lua.execute((ROOT/'scripts/game/data/Tuning.lua').read_text())
for k in ('store', 'ch1'):
    compare(json.loads((ROOT/f'reference/h5-source/config/{k}-tuning.json').read_text()), tuning[k])
assert tuning.ch1.paper is False

ops = [{'op':'record','dt':1/60,'state':[0,0]} for _ in range(100)]
# Fill beyond the 90-second history cap, then exercise blocked and partial rewinds.
ops += [{'op':'record','dt':.1,'state':[i,i*.31]} for i in range(1000)]
ops += [{'op':'rewind','dt':.13,'allow':False}, {'op':'rewind','dt':.13,'allow':True}]
rng = random.Random(20261016)
for i in range(1500):
    if rng.random() < .45:
        ops.append({'op':'rewind','dt':rng.choice([.001,.017,.13,2]),'allow':rng.random()>.2})
    else:
        ops.append({'op':'record','dt':rng.choice([.001,.017,.13,2]),'state':[rng.randrange(10),rng.randrange(10)]})
ops += [{'op':'rewind','dt':200,'allow':True}, {'op':'rewind','dt':1,'allow':True}]
js = r'''
const fs=require('fs'), vm=require('vm');
const source=fs.readFileSync('reference/h5-source/src/rewind-levels.js','utf8');
const start=source.indexOf('class Timeline {'), end=source.indexOf('\nlet shellMats',start);
const Timeline=vm.runInNewContext(source.slice(start,end)+'; Timeline');
let state=[0,0], applied=0;
const t=new Timeline(()=>state.slice(),s=>{state=s.slice();applied++});
const result=[];
for(const op of JSON.parse(fs.readFileSync(0,'utf8'))){
 let changed=null;
 if(op.op==='record'){state=op.state.slice();t.record(op.dt)}
 else changed=t.rewind(op.dt,()=>op.allow);
 result.push({length:t.h.length,total:t.total,blocked:!!t.blocked,changed,applied,state:state.slice()});
}
console.log(JSON.stringify(result));
'''
expected = json.loads(subprocess.check_output(['node','-e',js], input=json.dumps(ops).encode(),cwd=ROOT))
Timeline = lua.execute((ROOT/'scripts/game/Timeline.lua').read_text())
state, applied = [0,0], 0

def get(): return lua.table_from(state)
def set_state(value):
    global state, applied
    state = [value[i] for i in range(1,len(value)+1)]
    applied += 1

t = Timeline.new(get,set_state)
blocked_steps = 0
for i, (op, exp) in enumerate(zip(ops, expected)):
    changed = None
    if op['op'] == 'record':
        state = op['state'][:]
        t.record(t,op['dt'])
    else:
        changed = t.rewind(t,op['dt'],lambda _: op['allow'])
    actual = {'length':len(t.h),'total':t.total,'blocked':bool(t.blocked),
              'changed':changed,'applied':applied,'state':state}
    assert actual.keys() == exp.keys()
    for key in actual:
        if key == 'total': assert math.isclose(actual[key],exp[key],abs_tol=1e-9),(i,key,actual,exp)
        else: assert actual[key] == exp[key],(i,key,actual,exp)
    blocked_steps += bool(t.blocked)
assert blocked_steps > 0
report = {'result':'PASS','luaRuntime':lua.lua_implementation,'frozenLevelsCompared':11,
          'tuningConfigsCompared':2,'timelineDifferentialSteps':len(ops),'blockedSteps':blocked_steps,
          'covers':['idle compression','90-second history cap','partial rewind','blocked rewind','empty history'],
          'notCovered':['UrhoX runtime','scene rendering','full gameplay','visual similarity','input and save integration']}
(ROOT/'docs/migration/logic-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
