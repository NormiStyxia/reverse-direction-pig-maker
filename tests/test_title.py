"""Title animation differential against frozen JS, plus menu contract checks."""
import json,math,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
Title=lua.execute((ROOT/'scripts/game/TitleState.lua').read_text())
frames=0
stages=set()
def compare(a,b,path):
    if isinstance(b,dict):
        for k,v in b.items():compare(a[k],v,path+'.'+k)
    elif isinstance(b,bool):assert a==b,(path,a,b)
    elif isinstance(b,(float,int)):assert math.isclose(a,b,abs_tol=1e-9,rel_tol=1e-10),(path,a,b)
    elif b is None:assert a is False or a is None,(path,a,b)
    else:assert a==b,(path,a,b)
for scenario in ['intro-auto','held-options','skip-leave']:
    ops=[]
    for i in range(5000 if scenario!='skip-leave' else 240):
        op={'dt':[1/60,.007,1/30,.05][i%4]}
        if scenario=='held-options':
            if i%600==220:op['holding']=True
            if i%600==470:op['holding']=False
            if i%770==0:op['opts']={'motion':i%1540==0,'parallax':i%2310==0}
            op['pointer']={'x':math.sin(i*.17),'y':math.cos(i*.13)}
        if scenario=='skip-leave':
            if i==0:op['skip']=True
            if i==100:op['leave']=True
        ops.append(op)
    expected=json.loads(subprocess.check_output(['node','tests/title-oracle.mjs'],input=json.dumps({'random':.37,'ops':ops}).encode(),cwd=ROOT))
    t=Title.new(0,lambda:.37)
    for i,(op,want) in enumerate(zip(ops,expected)):
        if op.get('skip'):t.skipIntro(t)
        if 'holding' in op:t.st.holding=op['holding']
        if 'pointer' in op:t.pointer(t,op['pointer']['x'],op['pointer']['y'])
        for k,v in op.get('opts',{}).items():t.opts[k]=v
        if op.get('leave'):t.leave(t,lua.table_from({'kind':'new'}))
        t.update(t,op['dt']);compare(t.st,want,scenario+f'/{i}')
        stages.add(t.st.auto.stage);frames+=1
    if scenario=='skip-leave':
        events=list(t.drainEvents(t).values());assert [e.kind for e in events]==['start','dispose']
        assert not t.active and not t.covering
assert stages=={'wait','glitch','draft','glitchBack'}
# Skip consumes first Enter; repeated activation/hold keys are ignored.
t=Title.new(0,lambda:.5);t.keyDown(t,'Enter',False);t.update(t,1/60)
assert t.st.phase=='idle'
t.keyDown(t,'ArrowDown',False);assert t.sel==2
t.keyDown(t,'Enter',False);assert t.panel=='chapters'
t.keyDown(t,'ArrowDown',False);assert t.sel==0
for i in range(1,7):t.activate(t,i);assert t.st.phase=='idle'
t.keyDown(t,'Escape',False);assert t.sel==2 and not t.panel
t.keyDown(t,'ArrowDown',False);t.keyDown(t,'Enter',False);assert t.panel=='options'
for i,key in enumerate(['motion','parallax','muted']):
    before=t.opts[key];t.activate(t,i);assert t.opts[key]!=before and t.sel==i
t.activate(t,3);assert not t.panel and t.sel==3
t.keyDown(t,'K',True);assert not t.st.holding
t.keyDown(t,'K',False);assert t.st.holding
t.blur(t);assert not t.st.holding
t.st.auto.t=4.2;t.keyDown(t,'ArrowDown',False);assert t.st.auto.t==4.2
for reached in range(1,7):
    t=Title.new(reached,lambda:.5);t.skipIntro(t);t.update(t,.01)
    t.keyDown(t,'ArrowDown',False);t.activate(t);assert t.st.choice.level==reached-1
    t=Title.new(reached,lambda:.5);t.skipIntro(t);t.update(t,.01);t.openPanel(t,'chapters')
    t.select(t,reached);t.activate(t);assert t.st.choice.level==reached-1
for w,h in [(1280,720),(2560,1152),(720,1280),(3440,1440),(640,360)]:
    f=Title.layout(w,h);assert f.x>=0 and f.y>=0 and math.isclose(f.width/f.height,20/9)
report={'result':'PASS','differentialFrames':frames,'source':'frozen src/title-screen.js update executed verbatim','autoStages':sorted(stages),'covers':['intro flash/reveal/camera','automatic hard cuts and random waits','K hold/release and stopped world','pig independent orbit/spin','motion/parallax settings','leave/start/dispose timing','menu locks and zero-based choices','skip consumes input','activity does not reset auto timer','five viewport layouts'],'notCovered':['UrhoX shader compilation','rendered pixels','native UI/input','full playthrough']}
(ROOT/'docs/migration/title-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
