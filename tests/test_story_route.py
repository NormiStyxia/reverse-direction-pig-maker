"""Walking/interaction-only routes compared frame-by-frame to frozen H5 classes."""
import json, math, subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
Route=lua.eval("require('preview.StoryRoute')")[0]
def table(v):return lua.table_from(v,recursive=True)
def py(v):
    if hasattr(v,'items'):return {k:py(x) for k,x in v.items()}
    return v
reports=[];checks=0
for kind in ['store','same','late','done']:
    seed=12345
    def random():
        global seed
        seed=(seed*1664525+1013904223)&0xffffffff
        return .37 if kind=='store' else seed/4294967296
    module='PrologueState' if kind=='store' else 'Chapter1State'
    Story=lua.eval("require('game."+module+"')")
    if isinstance(Story,tuple):Story=Story[0]
    s=Story.new(table({'random':random}));r=Route.new('store' if kind=='store' else 'meeting',kind)
    original_interact=s.interact;original_panel=s.onPanel
    op={}
    def interact(this,action):
        op['interact']=action;return original_interact(this,action)
    def panel(this,action):
        op['panel']=action;return original_panel(this,action)
    s.interact=interact
    if kind!='store':s.onPanel=panel
    ops=[];states=[];key_driven=False
    for frame in range(18000):
        op={'dt':1/60,'camYaw':0}
        control=r.control(r,s);x,z=control[:2];p=s.normi.pos;n=s.normi
        if s.controlEnabled(s) and math.hypot(x,z)>0:
            target=[p.x+x*.8,0,p.z+z*.8];op['target']=target
            n.moveStick(n,table(dict(zip(['x','y','z'],target))));key_driven=True
        elif key_driven:n.release(n);op['release']=True;key_driven=False
        op['moving']=x*x+z*z>0
        s.update(s,1/60,table(op));s.drainEvents(s)
        state={'phase':s.phase,'t':s.t,'actor':{'pos':py(n.pos)}}
        if kind=='store':state.update(clock=s.clock,finished=py(s.result))
        else:state.update(answer=s.answer or False,carrying=bool(s.carrying),doorK=s.doorK,result=py(s.result))
        ops.append(op);states.append(state)
        if s.result:break
    assert s.result,(kind,s.phase,py(n.pos),r.waypoint)
    assert not any('pos' in op for op in ops),'Route must not teleport'
    oracle='prologue' if kind=='store' else 'ch1'
    expected=json.loads(subprocess.check_output(['node',f'tests/{oracle}-oracle.mjs'],input=json.dumps({'ops':ops,'compact':True}).encode(),cwd=ROOT))
    def compare(a,b,path):
        global checks
        if isinstance(b,dict):
            for k,v in b.items():compare(a[k],v,path+'.'+k)
        elif isinstance(b,list):
            assert len(a)==len(b),(path,a,b)
            for i,v in enumerate(b):compare(a[i+1],v,path+f'[{i}]')
        elif b is None:assert a is False or a is None,(path,a,b)
        elif isinstance(b,bool):assert a==b,(path,a,b)
        elif isinstance(b,(int,float)):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),(path,a,b)
        else:assert a==b,(path,a,b)
        checks+=1
    for i,(actual,want) in enumerate(zip(states,expected)):compare(actual,want,f'{kind}/{i}')
    reports.append({'kind':kind,'frames':len(ops),'seconds':len(ops)/60,'finalPhase':s.phase,'result':'PASS'})
result={'result':'PASS','routes':reports,'checks':checks,'positionOrClockAssignments':False,'scope':'input-only story routes vs frozen H5; GPU and full native route not covered'}
(ROOT/'docs/migration/story-input-route-report.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
