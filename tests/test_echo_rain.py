"""Compare Lua rain with executed frozen source, including wrap RNG consumption."""
import json,math,struct
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Rain=lua.eval("require('game.EchoRain')")[0];seeds=lua.eval("require('game.data.EchoRainSeeds')")[0]
fixtures=json.loads((root/'validation/echo/source-rain-motion.json').read_text())
checks=0;calls_total=0
f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
for fixture in fixtures:
    level=fixture['level'];model=Rain.new(seeds[level]);state=731;calls=0
    original=[list(p.values()) for p in seeds[level].values()]
    def random():
        global state,calls
        state=(state*1664525+1013904223)&0xffffffff;calls+=1
        return state/4294967296
    for frame in fixture['frames']:
        model.update(model,frame['dt'],frame['k'],random)
        assert calls==frame['calls'],(level,'rng',calls,frame['calls']);checks+=1
        for sample in frame['samples']:
            p=model.drops[sample['id']]
            for i,expected in enumerate(sample['p'],1):
                assert math.isclose(p[i],expected,rel_tol=0,abs_tol=1e-9),(level,i,p[i],expected);checks+=1
            vertices=[p[1],p[2],p[3],p[1]+.04,p[2]+.4,p[3]]
            for actual,expected in zip(vertices,sample['vertices']):
                assert f32(actual)==expected,(level,actual,expected);checks+=1
    assert original==[list(p.values()) for p in seeds[level].values()],'Seeds mutated'
    calls_total+=calls
report={'result':'PASS','levels':6,'frames':1440,'dropsPerLevel':600,'scalarChecks':checks,'randomCalls':calls_total,
        'source':'Exact frozen rewind-levels.js rain update block executed in Node VM',
        'covered':['downward rain','rewind interpolation','upward rain','both boundary wraps','Float32 segment endpoints','seed immutability'],
        'notCovered':['GPU line rasterization','frame-rate visual parity','full game acceptance']}
(root/'docs/migration/echo-rain-test-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
