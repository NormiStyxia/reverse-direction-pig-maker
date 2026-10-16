"""Solve all six prologue echoes with controls only, no state edits or level jumps."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Run=lua.eval("require('game.EchoRun')")[0];levels=lua.eval("require('game.data.Levels')")[0]
run=Run.new(levels.prologue,'store');inputs=[];events=[];states=[]
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
    print('Solved',next_level-1 if next_level else 6,'inputs',len(inputs),flush=True)
# 1: undo the automatic falling shelf and use the open doorway.
play(1);step(210);step(180,spin=True);walk(4.35,3.4);exit_at(4.35,-3.6,2)
# 2: overshoot, then rewind the crate to the pressure plate.
walk(-4.05,1.2);charge(1,0);rewind(1,'x',2)
assert run.sim.room.plates[1].pressed
walk(4.35,2.8);exit_at(4.35,-3.6,3)
# 3: stop at the corner using rewind, push on the other axis, rewind to plate.
walk(-5.05,2.8);charge(1,0);rewind(1,'x',3)
walk(run.pig.pos.x,4.1);walk(3,4.1);walk(3,3.85);charge(0,-1);rewind(1,'z',-.6)
assert run.sim.room.plates[1].pressed
walk(-3.5,2.7);exit_at(-3.5,-3.6,4)
# 4: shelf holds plate; undo it from the approach and use delayed door closure.
walk(6.2,3.2);walk(6.05,.8);charge(-1,0)
assert run.sim.room.cabinets[1].ph==3 and run.sim.room.plates[1].pressed
walk(6.1,3.2);walk(3.6,3.2);walk(3.6,1.8)
for _ in range(600):
    if run.sim.room.cabinets[1].ph==0:break
    step(spin=True)
else:raise AssertionError('cabinet did not rewind')
exit_at(3.6,-3.6,5)
# 5: rewind the ordinary crate into a bumper; the gold crate stops on its plate.
walk(-5.55,-.3);charge(1,0);rewind(1,'x',2)
walk(run.pig.pos.x,4.3);walk(2,4.3);charge(0,-1)
assert run.sim.room.plates[1].pressed,(run.sim.room.crates[2].x,run.sim.room.crates[2].z)
walk(-4,2.6);exit_at(-4,-3.6,6)
# 6: tip a shelf as a bumper, stop the gold crate, then rewind only the shelf.
walk(-.7,3);walk(-.7,-.85);charge(-1,0)
assert run.sim.room.cabinets[1].ph==3
walk(0,3.5);walk(0,4.3);walk(-3,4.3);charge(0,-1)
assert run.sim.room.plates[1].pressed,(run.sim.room.crates[1].x,run.sim.room.crates[1].z)
step(190,spin=True)
assert run.sim.room.plates[1].pressed and run.sim.room.cabinets[1].a<.01
walk(-4.05,2);walk(-4.05,-1.3);walk(-3,-1.3);walk(-3,-3.4);exit_at(.8,-3.7,None)
report={'result':'PASS','levelsSolved':6,'inputFrames':len(inputs),'usesTeleportOrLevelJump':False,
        'events':events,'runtime':lua.lua_implementation,'notCovered':['native realtime replay of all six','story','chapter1','visual acceptance','other solution routes']}
(ROOT/'validation/echo/prologue-six-states.json').write_text(json.dumps(states,separators=(',',':')))
(ROOT/'validation/echo/prologue-six-inputs.json').write_text(json.dumps(inputs,separators=(',',':')))
(ROOT/'docs/migration/prologue-echo-route-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='events'},ensure_ascii=False,indent=2))
