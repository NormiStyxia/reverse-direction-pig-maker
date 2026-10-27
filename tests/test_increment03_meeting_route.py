"""Solve five chapter1 echoes with controls only, no state edits or level jumps."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Run=lua.eval("require('game.EchoRun')")[0];levels=lua.eval("require('game.data.Levels')")[0]
run=Run.new(levels.chapter1,'meeting');inputs=[];events=[];states=[]
def step(n=1,**control):
    for _ in range(n):
        inputs.append(control.copy());run.update(run,1/60,lua.table_from(control),0,lambda:.7)
        states.append({'level':run.index,'phase':run.phase,'x':run.pig.pos.x,'z':run.pig.pos.z,
                       'door':run.sim.room.doorOpen,'timeline':len(run.sim.timeline.h)})
        for e in run.drainEvents(run).values():
            if e.kind in ['loadLevel','levelPlayable','exitReached','echoFinished']:events.append({'frame':len(inputs),'kind':e.kind,'level':e.level})
def play(level):
    for _ in range(400):
        if run.phase=='play' and run.index==level:return
        step()
    raise AssertionError(('not playable',level,run.index,run.phase))
def walk(x,z,limit=1400):
    for _ in range(limit):
        if run.phase!='play':return
        dx=x-run.pig.pos.x;dz=z-run.pig.pos.z
        if abs(dx)<.05 and abs(dz)<.05:step(15);return
        step(x=max(-1,min(1,dx*3)),y=max(-1,min(1,dz*3)))
    raise AssertionError(('walk stalled',run.index,x,z,run.pig.pos.x,run.pig.pos.z))
def charge(x,z):
    step(5,x=x,y=z);step(x=x,y=z,charge=True);step(100)
def rewind(crate,axis,target):
    for _ in range(1200):
        if abs(run.sim.room.crates[crate][axis]-target)<.10:
            step(20);return
        step(spin=True)
    raise AssertionError(('rewind missed',run.index,axis,target,run.sim.room.crates[crate][axis]))
def exit_at(x,z,next_level):
    walk(x,z);assert run.phase=='out',(run.index,run.phase,run.pig.pos.x,run.pig.pos.z)
    if next_level:play(next_level)
    else:
        step(170);assert run.phase=='done'
    print('Solved',next_level-1 if next_level else 5,'inputs',len(inputs),flush=True)
# 1: collide paired archives, then cross the opened door.
play(1);walk(-5.05,3.2);charge(1,0);rewind(1,'x',3)
walk(3,4.3);charge(0,-1);assert run.sim.room.merged==1
walk(0,1);exit_at(0,-3.6,2)
# 2: projection stops against short table; rewind old archive into it.
walk(4.1,-1.1);charge(-1,0)
step(240,spin=True)
assert run.sim.room.merged==1
walk(0,.2);exit_at(0,-3.6,3)
# 3: push tray past plate before installing the projection brake.
walk(-6.05,1);charge(1,0)
walk(-6.2,4.3);walk(-.9,4.3);charge(0,-1)
step(240,spin=True)
assert run.sim.room.plates[1].pressed
walk(2.7,4.3);walk(4,4.3);charge(0,-1)
assert run.sim.room.plates[2].pressed
walk(5.5,2);walk(4,0);walk(4,-3.2);exit_at(6,-3.6,4)
# 4: new archive stops tray rewinding, holding two plates.
walk(3,3.7);charge(0,-1)
walk(-2.05,3);walk(-2.05,1);charge(1,0)
walk(-6.05,2.6);walk(-6.05,1);charge(1,0)
step(260,spin=True)
assert run.sim.room.plates[1].pressed and run.sim.room.plates[2].pressed
walk(-3.5,2.6);exit_at(-3.5,-3.6,5)
# 5: tip board north, stop projection at the combined plate, enter before rewinding.
walk(-3.35,2.65);charge(0,-1)
assert run.sim.room.cabinets[1].ph==3
walk(4.1,2.8);walk(4.1,-1.1);charge(-1,0)
assert run.sim.room.plates[1].pressed
walk(4.6,.2);walk(4.6,-3.4)
step(360,spin=True)
assert run.sim.room.plates[2].pressed and not run.sim.room.plates[1].pressed
assert run.phase=='done'
print('Solved 5 inputs',len(inputs))
report={'result':'PASS','levelsSolved':5,'inputFrames':len(inputs),'usesTeleportOrLevelJump':False,
        'events':events,'runtime':lua.lua_implementation,'notCovered':['native realtime route','visual acceptance','other solution routes']}
(ROOT/'validation/increment03/routes/meeting-states.json').write_text(json.dumps(states,separators=(',',':')))
(ROOT/'validation/increment03/routes/meeting-inputs.json').write_text(json.dumps(inputs,separators=(',',':')))
(ROOT/'docs/migration/increment03-meeting-route-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='events'},ensure_ascii=False,indent=2))
