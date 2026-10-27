"""Branch/progression checks in Lua 5.4. Not a native visual or input playthrough."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
Story=lua.eval("require('game.Chapter1State')")[0]
Dorm=lua.eval("require('game.DormState')")[0]
checks=[]
def until(p,predicate,limit=5000):
    for _ in range(limit):
        if predicate():return
        p.update(p,.05)
    raise AssertionError((p.mode,p.phase,'timed out'))
def opts(**kwargs):return lua.table_from(kwargs)
for answer in ['same','late','done']:
    for i,branch in enumerate(['fix','wreck','leave']):
        p=Story.new(opts(mode='morning',answer=answer))
        until(p,lambda:len(p.phone.choices)>0)
        assert p.choiceMode=='msg' and not p.result
        p.onChoice(p,0)
        until(p,lambda:p.canFindChen)
        assert p.phase=='play' and p.zones(p)[1].id=='chen'
        p.chenTalk(p,True)
        assert len(p.phone.choices)==3 and not p.canSkip(p)
        p.onChoice(p,i)
        until(p,lambda:bool(p.result))
        assert p.result.morningBranch==branch and p.clockMin==887
        assert p.chenVisible==(branch!='leave')
        q=Story.new(opts(mode='meeting',morningBranch=branch))
        until(q,lambda:q.phase=='play');q.skip(q)
        assert len(q.phone.choices)==1
        q.onChoice(q,0);q.skip(q)
        assert q.answer==branch and q.carrying and q.tonightAnswer==branch
        # Position fixture isolates the handoff; this does not claim walked traversal.
        q.closeUp(q);until(q,lambda:q.phase=='desk');q.startFold(q)
        until(q,lambda:bool(q.result))
        assert q.result.toOfficeEcho and q.result.morningBranch==branch
        checks.append(answer+'/'+branch)
for i,choice in enumerate(['sick','pc','off']):
    p=Dorm.new(opts(skipRewind=True));until(p,lambda:len(p.phone.choices)>0)
    assert not p.canSkip(p);p.onChoice(p,i);until(p,lambda:p.phase=='desk')
    assert p.dormChoice==choice and p.parcel==(choice=='pc') and p.clockMin==(1110 if choice=='off' else 495)
    p.startFold(p);until(p,lambda:bool(p.result));assert p.result.toDormEcho and p.result.dormChoice==choice
    q=Dorm.new(opts(afterEcho=True,dormChoice=choice));until(q,lambda:bool(q.result))
    assert q.result.ended and q.boxGone and q.screenImage and not q.pig.visible
    checks.append('dorm/'+choice)
    # Skip keeps the mandatory selection and the final screen transition.
    p=Dorm.new(opts());p.skip(p);p.skip(p);assert len(p.phone.choices)==3 and not p.canSkip(p)
    p.onChoice(p,i);p.skip(p);until(p,lambda:p.phase=='desk')
    q=Dorm.new(opts(afterEcho=True,dormChoice=choice));q.skip(q);until(q,lambda:bool(q.result))
    assert q.result.ended and q.screenT>3
    checks.append('skip/'+choice)
report={'result':'PASS','scenarios':checks,'coverage':['morning 3x3 branches','required choices survive skip','second meeting to office echoes','dorm three branches','dorm echoes handoff','withdrawal and Game Jam ending','screen return result'],
        'notCovered':['native rendering','physical input','puzzle completion','dream and 23:12','timeline navigation']}
Path('docs/migration/increment03-story-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
