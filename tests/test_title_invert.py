"""Increment 01 differential: execute frozen patched JS update, never reimplement oracle."""
import hashlib,json,math,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
INC=ROOT/'reference/increment-01-title-invert'
manifest=json.loads((INC/'manifest.json').read_text())
for name,expected in manifest['files'].items():
    if (INC/name).is_file(): assert hashlib.sha256((INC/name).read_bytes()).hexdigest()==expected,name
lua=LuaRuntime(unpack_returned_tuples=True)
Title=lua.execute((ROOT/'scripts/game/TitleState.lua').read_text())
def compare(actual,expected,path):
    if isinstance(expected,dict):
        for key,value in expected.items():compare(actual[key],value,path+'.'+key)
    elif isinstance(expected,bool):assert actual==expected,(path,actual,expected)
    elif isinstance(expected,(int,float)):assert math.isclose(actual,expected,abs_tol=1e-9,rel_tol=1e-10),(path,actual,expected)
    elif expected is None:assert actual is False or actual is None,(path,actual,expected)
    else:assert actual==expected,(path,actual,expected)
frames=0;seen=set()
for look in ['invert','sketch']:
    for random in [.03,.37,.98]:
        ops=[]
        for i in range(4000):
            op={'dt':[1/60,.007,1/30,.05][i%4]}
            # Irregular holds cross entry/exit boundaries and reverse mid-sweep.
            if i%131==0:op['holding']=True
            if i%131==49:op['holding']=False
            if i%311==0:op['opts']={'motion':i%622==0,'parallax':i%933==0}
            op['pointer']={'x':math.sin(i*.17),'y':math.cos(i*.13)}
            if i==3850:op['leave']=True
            ops.append(op)
        wants=json.loads(subprocess.check_output(['node','tests/title-oracle.mjs'],input=json.dumps({'random':random,'increment':True,'look':look,'ops':ops}).encode(),cwd=ROOT))
        title=Title.new(0,lambda:random,look)
        for i,(op,want) in enumerate(zip(ops,wants)):
            if 'holding' in op:title.st.holding=op['holding']
            title.pointer(title,op['pointer']['x'],op['pointer']['y'])
            for k,v in op.get('opts',{}).items():title.opts[k]=v
            if op.get('leave'):title.leave(title,lua.table_from({'kind':'new'}))
            title.update(title,op['dt']);compare(title.st,want,f'{look}/{random}/{i}')
            if look=='invert' and title.st.phase=='idle':
                seen.add((title.st.auto.stage,title.st.holding,title.st.inv>0,title.st.inv<1))
                assert title.view.alt==(title.st.inv>.5 and title.st.prog<.5)
            frames+=1
# Explicit hard-cut and held-boundary expectations, including the one-frame source stop rule.
def idle():
    t=Title.new(0,lambda:.5);t.skipIntro(t);t.update(t,.01);return t
for held in [False,True]:
    t=idle();t.st.auto.stage='glitch';t.st.auto.t=.75;t.st.holding=held;t.update(t,.01)
    assert t.st.auto.stage=='draft' and t.st.prog==0 and t.st.inv==(0 if held else 1)
t=idle();t.st.auto.stage='draft';t.st.inv=1;t.st.prog=0;t.keyDown(t,'K',False)
world=t.st.world;t.update(t,.05)
assert t.st.inv==1-.05*.95 and not t.view.atStart and t.st.world<world
for _ in range(22):t.update(t,.05)
assert t.st.inv==0 and t.view.atStart
t.keyUp(t,'K');t.update(t,.05);assert math.isclose(t.st.inv,.035)
t.st.auto.stage='glitchBack';t.st.auto.t=.5;t.st.holding=True;t.st.inv=.4;t.update(t,.01)
assert t.st.inv==0 and t.st.prog==0 and t.st.auto.stage=='wait'
t.keyUp(t,'K');t.update(t,.05);assert math.isclose(t.st.prog,.035) and t.st.inv==0
assert any(stage=='draft' and held and positive and partial for stage,held,positive,partial in seen)
report={'result':'PASS','differentialFrames':frames,'oracle':'increment-01 frozen title-screen.js update executed verbatim','looks':['invert (native default)','sketch (legacy comparison)'],'randomWaitValues':[.03,.37,.98], 'checks':['automatic hard cut with/without K','inverse hold/release speed','hold across inverted interval end','rewinding and stopped-world hint timing','intro/leave/world/clock/pig parity','alt threshold'],'notCovered':['GPU execution','rendered pixel similarity','native touch']}
(ROOT/'docs/migration/title-invert-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
