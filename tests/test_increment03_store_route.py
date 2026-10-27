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
# Increment03: source puzzles, controls only.
play(1);step(210);step(180,spin=True);walk(4.35,3.4);exit_at(4.35,-3.6,2)
walk(-4.05,1.2);charge(1,0);rewind(1,'x',2)
assert run.sim.room.plates[1].pressed
walk(4.35,2.8);exit_at(4.35,-3.6,3)
walk(-5.05,2.8);charge(1,0);rewind(1,'x',3)
walk(run.pig.pos.x,4.1);walk(3,4.1);walk(3,3.85);charge(0,-1);rewind(1,'z',-.6)
assert run.sim.room.plates[1].pressed
walk(-3.5,2.7);exit_at(-3.5,-3.6,4)
# Shelf holds entry plate; send crate past exit plate; enter before rewinding.
walk(-5,3.5);walk(4.15,3.5);walk(4.15,2.2);charge(-1,0)
assert run.sim.room.cabinets[1].ph==3 and run.sim.room.plates[1].pressed
walk(4.4,.6);walk(-6.05,.6);walk(-6.05,-1.1);charge(1,0)
walk(0,.3);walk(0,-3.6)
for _ in range(1200):
    if run.phase=='out':break
    step(spin=True)
assert run.phase=='out';play(5);print('Solved 4 inputs',len(inputs))
walk(-5.55,-.3);charge(1,0);rewind(1,'x',2)
walk(run.pig.pos.x,4.3);walk(2,4.3);charge(0,-1)
assert run.sim.room.plates[1].pressed
walk(-4,2.6);exit_at(-4,-3.6,6)
walk(-.7,3);walk(-.7,-.85);charge(-1,0)
assert run.sim.room.cabinets[1].ph==3
walk(0,3.5);walk(0,4.3);walk(-3,4.3);charge(0,-1)
assert run.sim.room.plates[1].pressed
step(190,spin=True)
assert run.sim.room.plates[1].pressed and run.sim.room.cabinets[1].a<.01
walk(-4.05,2);walk(-4.05,-1.3);walk(-3,-1.3);walk(-3,-3.4);exit_at(.8,-3.7,None)
report={'result':'PASS','theme':'store','levelsSolved':6,'inputFrames':len(inputs),'usesTeleportOrLevelJump':False,'events':events,'notCovered':['native replay','visual acceptance']}
root=ROOT/'validation/increment03/routes';root.mkdir(exist_ok=True,parents=True)
(root/'store-inputs.json').write_text(json.dumps(inputs,separators=(',',':')))
(root/'store-states.json').write_text(json.dumps(states,separators=(',',':')))
(ROOT/'docs/migration/increment03-store-route-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='events'},ensure_ascii=False))
