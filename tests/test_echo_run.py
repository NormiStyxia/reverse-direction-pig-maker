"""Headless integration via movement/charge/rewind inputs; no teleports or level jumps."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Run=lua.execute((ROOT/'scripts/game/EchoRun.lua').read_text())
levels=lua.execute((ROOT/'scripts/game/data/Levels.lua').read_text())
frames=0

def step(run,n=1,**control):
    global frames
    for _ in range(n):
        run.update(run,1/60,lua.table_from(control),0,lambda:.7)
        run.drainEvents(run)
        frames+=1

def wait_play(run):
    for _ in range(360):
        if run.phase=='play':return
        step(run)
    raise AssertionError(('not playable',run.phase))

def walk(run,x,z,max_frames=1500):
    for _ in range(max_frames):
        if run.phase!='play':return
        dx=x-run.pig.pos.x;dz=z-run.pig.pos.z
        if abs(dx)<.06 and abs(dz)<.06:
            step(run,20)
            return
        # Proportional stick slows down near destination without teleporting.
        step(run,x=max(-1,min(1,dx*3)),y=max(-1,min(1,dz*3)))
    raise AssertionError(('walk stalled',x,z,run.pig.pos.x,run.pig.pos.z))

run=Run.new(levels.prologue,'store')
wait_play(run);step(run,210)
assert run.sim.room.cabinets[1].ph==3
step(run,180,spin=True)
assert run.sim.room.cabinets[1].a<.01
walk(run,4.35,3.4);walk(run,4.35,-3.6)
assert run.phase=='out' and run.nextIndex==2
wait_play(run)
assert run.index==2
step(run,restart=True)
assert run.phase=='out' and run.nextIndex==2
wait_play(run)
assert run.index==2 and abs(run.sim.room.crates[1].x+3)<1e-8

meeting=Run.new(levels.chapter1,'meeting')
wait_play(meeting)
walk(meeting,-5.0,1.0)
step(meeting,x=1,charge=True)
step(meeting,100)
assert meeting.sim.room.merged==1
assert meeting.sim.room.plates[1].pressed
walk(meeting,0,1);walk(meeting,0,-3.6)
assert meeting.phase=='out' and meeting.nextIndex==2
wait_play(meeting)
assert meeting.index==2
report={'result':'PASS','inputFrames':frames,'runs':['prologue level 1 -> level 2 -> restart','chapter1 level 1 -> level 2'],
        'usesDebugTeleportOrLevelJump':False,'runtime':lua.lua_implementation,
        'notCovered':['remaining 9 level solutions','UrhoX runtime','full story','visuals']}
(ROOT/'docs/migration/run-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
