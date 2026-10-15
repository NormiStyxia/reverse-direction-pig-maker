"""Source differential tests; low-level simulation, not a user-input playthrough."""
import json, math, random, subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
Echo=lua.execute((ROOT/'scripts/game/EchoSimulation.lua').read_text())
levels=json.loads((ROOT/'reference/levels.json').read_text())
def to_lua(x):
    if isinstance(x,dict): return lua.table_from({k:to_lua(v) for k,v in x.items()})
    if isinstance(x,list): return lua.table_from([to_lua(v) for v in x])
    return x
def from_lua(x):
    if hasattr(x,'keys'):
        keys=list(x.keys())
        if keys and all(isinstance(k,int) for k in keys):return [from_lua(x[i]) for i in range(1,len(x)+1)]
        return {k:from_lua(x[k]) for k in keys}
    return x
def room_fixture(e):
    R=e.room
    return {'crates':[from_lua(c) for c in R.crates.values()], 'cabinets':[from_lua(c) for c in R.cabinets.values()],
        'statics':[from_lua(s) for s in R.statics.values()],'plates':[from_lua(p) for p in R.plates.values()],
        'doorOpen':R.doorOpen,'doorTimer':0,'merged':0}
def snapshot(e):
    R=e.room
    crates=[]
    for c in R.crates.values():
        d={k:c[k] for k in ['x','z','vx','vz','kind','gold','holo','moving']}
        d.update(gone=bool(c.gone),slid=bool(c.slid));crates.append(d)
    return {'crates':crates,'cabinets':[{k:c[k] for k in ['a','w','ph','dir','tm']} for c in R.cabinets.values()],
        'plates':[p.pressed for p in R.plates.values()],'door':R.doorOpen,'hold':R.doorTimer,'merged':R.merged,
        'frames':len(e.timeline.h),'total':e.timeline.total,'blocked':bool(e.timeline.blocked),'exit':e.exitOn(e)}
def compare(a,b,path='root'):
    if isinstance(a,dict):
        assert a.keys()==b.keys(),path
        for k in a:compare(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        assert len(a)==len(b),(path,len(a),len(b))
        for i,(x,y) in enumerate(zip(a,b)): compare(x,y,path+f'[{i}]')
    elif isinstance(a,(float,int)) and not isinstance(a,bool):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),(path,a,b)
    else:assert a==b,(path,a,b)
fixtures=[]
for chapter,theme in [('prologue','store'),('chapter1','meeting')]:
    for index,level in enumerate(levels[chapter]):
        e=Echo.new(to_lua(level),theme)
        ops=[]
        rng=random.Random(400+index)
        for frame in range(480):
            op={'dt':1/60,'rewind':180<=frame<260 or 390<=frame<430}
            if frame in (0,120,280,340) and len(e.room.crates):op.update(push=frame//120%len(e.room.crates),dir=rng.choice(['+x','-x','+z','-z']))
            if frame==60 and len(e.room.cabinets):op.update(tip=0,dir='+z')
            ops.append(op)
        fixtures.append({'name':f'{chapter}-{index+1}','theme':theme,'level':level,'room':room_fixture(e),'ops':ops})
# Targeted fixture: same-origin collision, stationary merge position, irreversibility.
level={'start':[0,0],'partition':-2,'door':{'x':0,'plates':[0]},'exit':[0,-3.6],
       'crates':[{'x':-2,'z':1,'kind':'past','origin':'a'},{'x':2,'z':1,'kind':'tonight','origin':'a'}],
       'plates':[{'x':2,'z':1,'type':'gold'}]}
e=Echo.new(to_lua(level),'meeting')
ops=[{'push':0,'dir':'+x','dt':1/60}]+[{'dt':1/60} for _ in range(90)]+[{'dt':1/60,'rewind':True} for _ in range(100)]
fixtures.append({'name':'forward-merge','theme':'meeting','level':level,'room':room_fixture(e),'ops':ops})
# Return the afternoon box through its own projection, or an unrelated hologram.
for same in (True,False):
    level2=json.loads(json.dumps(level));level2['crates'][1]['origin']='a' if same else 'other'
    e=Echo.new(to_lua(level2),'meeting')
    ops=[{'push':0,'dir':'+z','dt':1/60}]+[{'dt':1/60} for _ in range(40)]
    ops += [{'move':1,'x':-2,'z':1}]+[{'dt':1/60,'rewind':True} for _ in range(100)]
    fixtures.append({'name':'rewind-merge' if same else 'rewind-block','theme':'meeting','level':level2,'room':room_fixture(e),'ops':ops})
expected=json.loads(subprocess.check_output(['node','tests/echo-oracle.cjs'],input=json.dumps(fixtures).encode(),cwd=ROOT))
steps=0
for fixture,states in zip(fixtures,expected):
    e=Echo.new(to_lua(fixture['level']),fixture['theme'])
    for i,(op,state) in enumerate(zip(fixture['ops'],states)):
        if 'push' in op:
            c=e.room.crates[op['push']+1]
            if c:e.push(e,c,op['dir'])
        if 'tip' in op:e.tipCabinet(e,e.room.cabinets[op['tip']+1],op['dir'])
        if 'move' in op:
            c=e.room.crates[op['move']+1];c.x=op['x'];c.z=op['z'];c.vx=0;c.vz=0;c.moving=False
        if 'dt' in op:e.step(e,op['dt'],op.get('rewind',False))
        compare(snapshot(e),state,f"{fixture['name']}/{i}")
        e.drainEvents(e)
        steps+=1
    if fixture['name'] in ('forward-merge','rewind-merge'):
        assert e.room.merged==1 and len(e.room.crates)==1 and e.room.crates[1].kind=='now'
    if fixture['name']=='rewind-block':assert e.timeline.blocked and e.room.merged==0
report={'result':'PASS','fixtures':len(fixtures),'differentialSteps':steps,'source':'frozen src/rewind-levels.js methods',
        'covers':['all 11 level physics','crate slide and transfer','cabinet falling','automatic slide','forward merge',
                  'rewind merge','unrelated hologram blocking','merge irreversibility','plates and doors','gold objects during rewind'],
        'notCovered':['player input','dead-end hints','scene transitions','rendering','full playthrough']}
(ROOT/'docs/migration/echo-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
