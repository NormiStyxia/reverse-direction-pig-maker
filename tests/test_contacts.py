"""Contact regression uses original hitTest, faceKey and collidePig methods."""
import json,math,random,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Echo=lua.execute((ROOT/'scripts/game/EchoSimulation.lua').read_text())
Player=lua.execute((ROOT/'scripts/game/EchoPlayer.lua').read_text())
levels=json.loads((ROOT/'reference/levels.json').read_text())
def table(v):
    if isinstance(v,dict):return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list):return lua.table_from([table(x) for x in v])
    return v
def native(v):
    if hasattr(v,'keys'):return {k:native(x) for k,x in v.items()}
    return v
def fixture_room(e):
    r=e.room
    return {**{k:[native(x) for x in r[k].values()] for k in ('crates','cabinets','plates','statics')},'doorOpen':r.doorOpen,'doorTimer':0,'merged':0}
def snap(e,p):
    r=e.room
    return {'crates':[{**{k:c[k] for k in ('x','z','vx','vz','kind','gold','holo','moving')},'gone':bool(c.gone),'slid':bool(c.slid)} for c in r.crates.values()],
        'cabinets':[{k:c[k] for k in ('a','w','ph','dir','tm')} for c in r.cabinets.values()],
        'plates':[x.pressed for x in r.plates.values()],'door':r.doorOpen,'hold':r.doorTimer,'merged':r.merged,
        'frames':len(e.timeline.h),'total':e.timeline.total,'blocked':bool(e.timeline.blocked),'exit':e.exitOn(e),
        'pig':{'pos':native(p.pos),'vel':native(p.vel),'charge':p.charge,'hits':len(list(p.chargeHits.keys()))},'stuckT':e.stuckT or 0}
def compare(a,b,path):
    if isinstance(a,dict):
        assert a.keys()==b.keys(),(path,a.keys(),b.keys())
        for k in a:compare(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        assert len(a)==len(b),(path,len(a),len(b))
        for i,(x,y) in enumerate(zip(a,b)):compare(x,y,path+f'/{i}')
    elif isinstance(a,(int,float)) and not isinstance(a,bool):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),(path,a,b)
    else:assert a==b,(path,a,b)
def pig(x,z,dx,dz,charge):
    return {'pos':{'x':x,'y':0,'z':z},'vel':{'x':dx*3,'y':0,'z':dz*3},'charge':charge,'chargeDir':{'x':dx,'y':0,'z':dz}}
fixtures=[];rng=random.Random(1616)
for chapter,theme in [('prologue','store'),('chapter1','meeting')]:
    for index,level in enumerate(levels[chapter]):
        e=Echo.new(table(level),theme);ops=[]
        # Push towards and glance past every starting object, then random contact points.
        objects=(level.get('crates',[])+level.get('cabinets',[]))
        for c in objects:
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                for direction in [(dx,dz),(-dz,dx)]:
                    ops.append({'pig':pig(c['x']-dx*.98,c['z']-dz*.98,*direction,.2),'contact':1/60,'collide':True})
        for _ in range(100):
            ops.append({'pig':pig(rng.uniform(-8,8),rng.uniform(-6,5),rng.choice([-1,0,1]),rng.choice([-1,0,1]),rng.choice([0,.2])),
                        'contact':1/60,'collide':True})
        fixtures.append({'name':f'{chapter}-{index+1}','level':level,'theme':theme,'room':fixture_room(e),'pig':pig(0,0,0,1,0),'ops':ops})
# Walking cannot push; sustained leaning emits heavy hint, then a three-second delay.
level=levels['prologue'][1];e=Echo.new(table(level),'store')
fixtures.append({'name':'leaning-and-charge-dedup','level':level,'theme':'store','room':fixture_room(e),'pig':pig(-3.98,1.2,1,0,0),
    'ops':[{'contact':1/60} for _ in range(240)]+[{'pig':pig(-3.98,1.2,1,0,.2),'contact':1/60}]+[{'contact':1/60} for _ in range(10)]})
expected=json.loads(subprocess.check_output(['node','tests/echo-oracle.cjs'],input=json.dumps(fixtures).encode(),cwd=ROOT))
steps=0
for case,states in zip(fixtures,expected):
    e=Echo.new(table(case['level']),case['theme']);e.stuckT=0;e.rewinding=False
    p=table(case['pig']);p.chargeHits=lua.table()
    for i,(op,want) in enumerate(zip(case['ops'],states)):
        if 'pig' in op:p=table(op['pig']);p.chargeHits=lua.table()
        if op.get('contact'):Player.hitTest(e,p,op['contact'])
        if op.get('collide'):Player.collide(e,p.pos)
        compare(snap(e,p),want,f"{case['name']}/{i}")
        e.drainEvents(e);steps+=1
report={'result':'PASS','fixtures':len(fixtures),'contactSteps':steps,'source':'frozen hitTest/faceKey/collidePig',
    'covers':['all 11 level collision shapes','charge face alignment','sideways glances rejected','walking cannot push','stable target priority','cabinet tips','charge-hit dedup','room bounds'],
    'notCovered':['engine input','end-to-end playthrough']}
(ROOT/'docs/migration/contact-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
