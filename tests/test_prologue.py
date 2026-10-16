"""Differential story/actor tests against the actual frozen JS classes, no GPU claims."""
import json,math,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
Story=lua.eval("require('game.PrologueState')")[0]
def table(value):
    if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([table(v) for v in value])
    return value
def compare(a,b,path):
    if isinstance(b,dict):
        for k,v in b.items():compare(a[k],v,path+'.'+k)
    elif isinstance(b,list):
        assert len(a)==len(b),(path,'length',len(a),len(b))
        for i,v in enumerate(b):compare(a[i+1],v,path+f'[{i}]')
    elif b is None:assert a is False or a is None,(path,a,b)
    elif isinstance(b,bool):assert bool(a)==b,(path,a,b)
    elif isinstance(b,(float,int)):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),(path,a,b)
    else:assert a==b,(path,a,b)
frames=0;scenarios=[];seen=set();finished_count=0
def run(name,ops,stress=0):
    global frames,finished_count
    expected=json.loads(subprocess.check_output(['node','tests/prologue-oracle.mjs'],input=json.dumps({'ops':ops,'startStress':stress}).encode(),cwd=ROOT))
    p=Story.new(table({'random':lambda:.37,'startStress':stress}));pig_ready=0
    # Door-open event belongs to construction, not frame 1.
    p.drainEvents(p)
    for i,(op,want) in enumerate(zip(ops,expected)):
        n=p.normi
        if 'pos' in op:n.setPosition(n,*op['pos'])
        if 'target' in op:n.moveStick(n,table(dict(zip(['x','y','z'],op['target']))))
        if op.get('release'):n.release(n)
        if op.get('toggle'):p.togglePhone(p)
        if op.get('phone'):p.onPhone(p,op['phone'])
        if op.get('browse'):p.onBrowse(p,op['browse'])
        if op.get('startBrowse'):p.startBrowse(p,op['startBrowse'])
        if op.get('cycle'):p.cycleInteraction(p)
        if op.get('interact'):p.interact(p,op['interact'])
        if 'riderStep' in op:p.riderStep(p,op['riderStep'])
        p.update(p,op['dt'],table(op))
        events=list(p.drainEvents(p).values())
        captions=[{k:e[k] for k in ['speaker','text','style']} for e in events if e.kind=='caption']
        hints=[{'text':e.text,'duration':e.duration*1000} for e in events if e.kind=='hint']
        pig_ready+=sum(e.kind=='pigReady' for e in events)
        mapping={'actor':n,'captions':table(captions),'hints':table(hints),'pigReady':pig_ready,'finished':p.result,
                 'pending':p.pending.text if p.pending else False,'interactions':p.nearbyInteractions(p),
                 'later':lua.table_from([l.t for l in p.later.values()])}
        for key,value in want.items():compare(mapping.get(key,p[key]),value,f'{name}/{i}.{key}')
        frames+=1;seen.add(p.phase)
    if p.result:finished_count+=1
    scenarios.append({'name':name,'frames':len(ops),'phase':p.phase})
    return p
def fixed(seconds,dt=.05):return [{'dt':dt} for _ in range(round(seconds/dt))]
# Complete natural timeline, pig interaction, fold, done; no clock jumps.
ops=fixed(153)
ops[2910].update(pos=[-3.35,0,-3.2],interact='pig')
run('natural-timeline-and-fold',ops)
# Phone draft survives new arrivals and blackout. Before-cut send must still succeed.
ops=fixed(151)
for i,extra in {
  400:{'toggle':True},401:{'phone':'pick:1'},402:{'phone':'send'},435:{'phone':'close'},
  800:{'toggle':True},801:{'phone':'later'},1250:{'toggle':True},1251:{'phone':'pick:0'},1252:{'phone':'clear'},
  2300:{'phone':'pick:1'},2618:{'phone':'send'},2621:{'phone':'close'},2622:{'toggle':True},2623:{'phone':'chat'},
  2910:{'phone':'close','pos':[-3.35,0,-3.2],'interact':'pig'},
}.items():ops[i].update(extra)
run('messages-drafts-and-send-before-cut',ops)
ops=fixed(152)
for i,extra in {2300:{'toggle':True},2301:{'phone':'pick:0'},2650:{'phone':'send'},2910:{'pos':[-3.35,0,-3.2],'interact':'pig'}}.items():ops[i].update(extra)
p=run('offline-draft-failure',ops)
assert any(m.status=='failed' for m in p.msgs.values())
# Every activity and every branch choice, including both sauce choices.
for zone,count in [('shelf',2),('fridge',2),('food',2)]:
    ops=fixed(9)
    for activity in range(count):
        ops.append({'dt':.05,'startBrowse':zone});ops+=fixed(4)
        if not (zone=='fridge' and activity==1):
            ops.append({'dt':.05,'browse':'choice:0'});ops+=fixed(4)
        if zone=='food' and activity==0:
            ops.append({'dt':.05,'browse':'choice:1'});ops+=fixed(4)
        ops.append({'dt':.05,'browse':'close'})
    run('browse-'+zone,ops)
# "More" preserves the accumulated entries and alternates activities; close is terminal.
ops=fixed(9)+[{'dt':.05,'startBrowse':'food'}]+fixed(3)+[{'dt':.05,'browse':'choice:0'}]+fixed(2)+[{'dt':.05,'browse':'choice:0'}]+fixed(2)+[{'dt':.05,'browse':'choice:0'}]+fixed(3)+[{'dt':.05,'browse':'choice:1'}]
run('browse-more-and-sauce-first-choice',ops,80)
# Exhaust every terminal choice path, including declining each purchase.
paths=[('shelf',0,[0,1]),('shelf',0,[1]),('shelf',1,[0,1]),('shelf',1,[1]),
       ('fridge',0,[0,1]),('fridge',0,[1]),('fridge',1,[1]),
       ('food',0,[0,0,1]),('food',0,[0,1,1]),('food',0,[1]),('food',1,[0,1]),('food',1,[1])]
for index,(zone,activity,choices) in enumerate(paths):
    ops=fixed(9)
    if activity==1:ops += [{'dt':.05,'startBrowse':zone},{'dt':.05,'browse':'close'}]
    ops += [{'dt':.05,'startBrowse':zone}]+fixed(4)
    for choice in choices:ops += [{'dt':.05,'browse':f'choice:{choice}'}]+fixed(4)
    p=run(f'browse-terminal-{index}-{zone}',ops)
    assert not p.browse.open
# Seating, cooldown, Tab, door repeat penalty, movement/obstacle/lift and rider callbacks.
ops=fixed(42)
for i,extra in {190:{'pos':[-3.35,0,-3.2],'interact':'seat'},191:{'interact':'stand'},215:{'cycle':True},216:{'interact':'stand'},240:{'interact':'seat'},265:{'moving':True},300:{'pos':[4.3,0,-4.5],'interact':'door'},325:{'interact':'door'},350:{'pos':[1,0,-.4],'interact':'shelf'},400:{'toggle':True},401:{'toggle':True},450:{'target':[-6,0,3]},520:{'release':True},550:{'target':[-4,1.8,3]},620:{'target':[4,0,-5]},650:{'riderStep':2},680:{'riderStep':5},710:{'riderStep':9}}.items():ops[i].update(extra)
for i,op in enumerate(ops):op['camYaw']=math.sin(i*.011)*.8
run('interactions-movement-rider',ops)
# Irregular delta-time preserves scheduler order and dark transition in the crossing frame.
ops=[{'dt':[.013,.033,.05,.007][i%4]} for i in range(5700)]
run('variable-frame-time',ops)
assert seen=={'intro','play','dark','pig','fold','done'},seen
assert finished_count>=2
report={'result':'PASS','source':'actual frozen StoreChapter/PrologueStore/Normi/BrowseOverlay methods executed in Node with inert rendering adapters','differentialFrames':frames,'scenarios':scenarios,'phases':sorted(seen),'finishedRuns':finished_count,'terminalBrowsePaths':len(paths),
        'covers':['6 work messages + blackout cutoff','draft/send/clear/later/read/unread and delayed captions','offline at send time','all 6 activities and 12 nodes','both sauce choices and more/close','browse reveal queue timing','character motion/collision/poses','sit/stand/door/interact cooldown','dark/pig/fold timing and handoff result','reverse callback ordering and varying delta'],
        'notCovered':['native story renderer and NVG phone/browse','GPU pixels/audio','end-to-end player playthrough','chapter1 story','save/load']}
(ROOT/'docs/migration/prologue-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
