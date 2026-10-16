"""Original frozen Ch1Meeting/Ch1Morning/Normi/BrowseOverlay vs native Lua model.
Positions in fixtures isolate interactions; these are NOT native end-to-end playthroughs.
"""
import json,math,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
Story=lua.eval("require('game.Chapter1State')")[0]
def table(x):
    if isinstance(x,dict):return lua.table_from({k:table(v) for k,v in x.items()})
    if isinstance(x,list):return lua.table_from([table(v) for v in x])
    return x
checks=0
def compare(a,b,path):
    global checks
    if isinstance(b,dict):
        for k,v in b.items():compare(a[k],v,path+'.'+k)
    elif isinstance(b,list):
        assert len(a)==len(b),(path,'length',len(a),len(b))
        for i,v in enumerate(b):compare(a[i+1],v,path+f'[{i}]')
    elif b is None:assert a is False or a is None,(path,a,b)
    elif isinstance(b,bool):assert bool(a)==b,(path,a,b)
    elif isinstance(b,(int,float)):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),(path,a,b)
    else:assert a==b,(path,a,b)
    checks+=1
frames=0;scenarios=[];phases=set();completions=[]
def run(name,ops,mode='meeting',answer='same'):
    global frames
    expected=json.loads(subprocess.check_output(['node','tests/ch1-oracle.mjs'],input=json.dumps({'mode':mode,'answer':answer,'ops':ops}).encode(),cwd=ROOT))
    seed=12345;calls=0
    def random():
        nonlocal seed,calls
        seed=(seed*1664525+1013904223)&0xffffffff;calls+=1;return seed/4294967296
    p=Story.new(table({'mode':mode,'answer':answer,'random':random}));p.drainEvents(p);ready=0
    for i,(op,want) in enumerate(zip(ops,expected)):
        n=p.normi
        if 'pos' in op:n.setPosition(n,*op['pos'])
        if 'target' in op:n.moveStick(n,table(dict(zip(['x','y','z'],op['target']))))
        if op.get('release'):n.release(n)
        if op.get('toggle'):p.togglePhone(p)
        if op.get('panel'):p.onPanel(p,op['panel'])
        if op.get('cycle'):p.cycleInteraction(p)
        if op.get('interact'):p.interact(p,op['interact'])
        p.update(p,op['dt'],table(op));events=list(p.drainEvents(p).values());ready+=sum(e.kind=='pigReady' for e in events)
        mapping={'randomCalls':calls,'actor':n,'pigReady':ready,'cam':p.cam(p),
          'captions':table([{k:e[k] for k in ['text','style']} for e in events if e.kind=='caption']),
          'hints':table([{k:e[k] for k in ['text','duration']} for e in events if e.kind=='hint']),
          'seen':table(sorted(p.seen.keys())),'fired':table(sorted(p.fired.keys())),
          'later':table([l.t for l in p.later.values()]),'interactions':p.nearbyInteractions(p)}
        for k,v in want.items():compare(mapping.get(k,p[k]),v,f'{name}/{i}.{k}')
        frames+=1;phases.add(mode+':'+p.phase)
    if p.result:completions.append(name)
    scenarios.append({'name':name,'mode':mode,'frames':len(ops),'finalPhase':p.phase,'answer':p.answer,'randomCalls':calls})
    return p
def fixed(seconds,dt=.05):return [{'dt':dt} for _ in range(round(seconds/dt))]
def at(ops,second,**values):ops[round(second/.05)].update(values)
for answer_index,answer in enumerate(['same','late','done']):
    ops=fixed(110)
    # Inspect optional objects, phone schedule, then trigger the question by archive box.
    at(ops,4,pos=[4.8,0,-1.3],interact='clock')
    at(ops,7,pos=[.5,0,1.2],interact='screen')
    at(ops,10,toggle=True);at(ops,13,panel='choice:0')
    at(ops,14,pos=[-3.6,0,1.2],interact='box')
    at(ops,20,toggle=True);at(ops,23,panel='close') # Unclosable answer panel.
    at(ops,26,panel=f'choice:{answer_index}');at(ops,26.05,panel=f'choice:{(answer_index+1)%3}')
    at(ops,48,panel='choice:0');at(ops,48.05,panel='choice:0') # Single Zhou reply guard.
    at(ops,59,pos=[-6.8,0,1.8]);at(ops,60,target=[-10,0,1.8]) # Closed door without box.
    at(ops,66,pos=[-3.6,0,1.2],interact='take');at(ops,66.05,interact='take')
    at(ops,68,pos=[-6.8,0,1.8],target=[-10,0,2.9])
    at(ops,74,pos=[-10,0,2.9],target=[-13.2,0,2.9])
    at(ops,77,pos=[-13.2,0,2.9],cycle=True,interact='notes')
    at(ops,79,interact='seal');at(ops,81,interact='cup');at(ops,83,interact='put')
    at(ops,94,pos=[-14.8,0,2.5],interact='pig')
    p=run('meeting-'+answer,ops)
    assert p.result and p.result.answer==answer,(answer,p.phase)
    assert p.tonightAnswer==answer and p.tonightVisible and p.doorOpened and p.frozen
    assert p.slide==(answer=='done')
    assert not p.people[1].visible and p.clockBack==1
    # Every answer has both a natural morning timeout and inspecting the empty box.
    for inspect in [False,True]:
        ops=fixed(30)
        if inspect:at(ops,5,interact='box');at(ops,5.05,interact='box')
        at(ops,10,panel='close');at(ops,12,toggle=True)
        p=run('morning-'+answer+('-inspect' if inspect else '-timeout'),ops,'morning',answer)
        assert p.result and p.clockMin==598 and p.expr=='deadpan'
# Idle question must interrupt an open optional phone panel at the original 45s deadline.
ops=fixed(55);at(ops,43,toggle=True)
p=run('meeting-auto-question',ops);assert p.phase=='ask' and len(p.phone.choices)==3
# Vary frame durations/camera; repeated inspections and out-of-zone F cannot skip story.
ops=[{'dt':[.013,.033,.05,.007][i%4],'camYaw':math.sin(i*.01)} for i in range(2400)]
for i in range(200,1600,170):ops[i].update(pos=[-3.6,0,1.2],interact='box')
run('meeting-variable-delta',ops)
report={'result':'PASS','differentialFrames':frames,'stateChecks':checks,'completedModelRuns':completions,'phases':sorted(phases),'scenarios':scenarios,
        'source':'Frozen Ch1Meeting/Ch1Morning/Normi/BrowseOverlay executed directly with real THREE scene builders, inert art/audio/DOM',
        'covers':['all three answers and duplicate-answer guard','Zhou reply/recall and single reply','optional phone and unclosable required panel','archive inspections, carry, door gating, optional desk props','auto-walk, freeze, one-minute rewind, hologram, pig fold','09:58 message variants and both triggers','movement/collision, reverse timers, seeded random call order, FX numeric state'],
        'notCovered':['native scene rendering and NVG integration','player-only end-to-end route','audio playback','visual similarity','save/load']}
(ROOT/'docs/migration/chapter1-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
