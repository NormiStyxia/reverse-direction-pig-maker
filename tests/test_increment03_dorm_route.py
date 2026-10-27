"""Solve five chapter1 echoes with controls only, no state edits or level jumps."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Run=lua.eval("require('game.EchoRun')")[0];levels=lua.eval("require('game.data.Levels')")[0]
run=Run.new(levels.dorm,'dorm');inputs=[];events=[];states=[]
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
    print('Solved',next_level-1 if next_level else 4,'inputs',len(inputs),flush=True)
# Cut power, slide through the hologram, restore power without displacing the tray.
play(1);walk(-6.1,3);charge(1,0)
assert run.sim.room.powerOff
walk(-5.1,1);charge(1,0)
assert run.sim.room.plates[1].pressed
walk(5.5,2);walk(6.8,2);charge(0,1)
assert not run.sim.room.powerOff and run.sim.room.plates[2].pressed
walk(4,2);exit_at(4,-3.6,2)
# Rewind while the power is off; then restore power and merge.
step(210);step(260,spin=True)
assert run.sim.room.crates[1].z< -1.1
walk(1.9,.4);walk(1.9,2);charge(1,0)
assert not run.sim.room.powerOff
walk(4.1,.4);walk(4.1,-1.1);charge(-1,0)
assert run.sim.room.merged==1
walk(0,.3);exit_at(0,-3.6,3)
# The powerless paired archive can overlap in the corner before reappearing.
walk(-5.1,0);charge(1,0)
assert run.sim.room.powerOff
walk(-5.5,2);walk(-5.1,3.6);charge(1,0)
walk(3,1.6);walk(3,-1.05);walk(4.4,-1.05);charge(0,1)
assert not run.sim.room.powerOff and run.sim.room.merged==1
walk(-3,.4);exit_at(-3,-3.6,4)
# Coat rack stops B on the hologram plate; power cycle merges A in the corner.
walk(-6,.4);walk(-2.8,.4);walk(-2.8,2.55);walk(-1.6,2.55);charge(0,-1)
assert run.sim.room.cabinets[1].ph==3
walk(4.1,.5);walk(4.1,-1.1);charge(-1,0)
assert run.sim.room.plates[2].pressed
walk(1.1,2.5);walk(-2.8,2.5);walk(-2.8,.5);walk(-5.1,.5);walk(-5.1,2.6);charge(1,0)
assert run.sim.room.powerOff
walk(-5.2,3.6);charge(1,0)
walk(3.6,4.3);walk(4.4,3.75);charge(0,-1)
assert not run.sim.room.powerOff and run.sim.room.merged==1
walk(3.4,2.5);walk(-3,2.5);exit_at(-3,-3.6,None)
report={'result':'PASS','theme':'dorm','levelsSolved':4,'inputFrames':len(inputs),'usesTeleportOrLevelJump':False,'events':events,'notCovered':['native replay','visual acceptance']}
root=ROOT/'validation/increment03/routes';root.mkdir(exist_ok=True,parents=True)
(root/'dorm-inputs.json').write_text(json.dumps(inputs,separators=(',',':')))
(root/'dorm-states.json').write_text(json.dumps(states,separators=(',',':')))
(ROOT/'docs/migration/increment03-dorm-route-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='events'},ensure_ascii=False))
