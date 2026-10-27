"""Native Lua model progression using movement and UI actions, no teleport.
This does not certify Runtime rendering, OS input or audio."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
def table(x):return lua.table_from(x,recursive=True)
def require(name):return lua.eval('require')(name)[0]
def tick(s,ctx=None):s.update(s,1/60,ctx or table({}))
def until(s,predicate,drive=None,limit=18000):
    for _ in range(limit):
        if predicate():return
        if drive:drive()
        tick(s,table({'input':{'x':1,'y':0}}) if s.phase=='pigwalk' else None)
    raise AssertionError((s.mode,s.phase,s.t,s.normi.pos.x,s.normi.pos.z))
checks=[]
d=require('game.DreamState').new()
until(d,lambda:d.phase=='walk')
assert not d.phone.open and d.guideVisible
def right():
    if d.phase=='walk':d.normi.moveStick(d.normi,table({'x':d.normi.pos.x+2,'y':0,'z':-.45}))
until(d,lambda:d.phase=='swap',right);checks.append('dream walk to swap')
until(d,lambda:d.phase=='pigwalk');until(d,lambda:d.phase=='unswap')
assert d.gp.x>=8.2;checks.append('pig movement to unswap')
until(d,lambda:d.phase=='walk');until(d,lambda:d.phase=='voice',right)
until(d,lambda:bool(d.result));assert d.result.toNight;checks.append('voice and break to night')
n=require('game.NightOfficeState').new()
until(n,lambda:n.phase=='play');assert not n.asleep and n.normi.visible
until(n,lambda:n.pending)
assert all(v.leaveT is not None for v in n.people.values())
n.togglePhone(n);n.onPhone(n,'pick');assert n.phone.draft
n.onPhone(n,'send');until(n,lambda:n.phase=='go');assert n.sent and not n.pending
def walk(x,z):
    n.normi.moveStick(n.normi,table({'x':x,'y':0,'z':z}))
    until(n,lambda:abs(n.normi.pos.x-x)<.08 and abs(n.normi.pos.z-z)<.08)
walk(2.625,2.6);n.interact(n,'box');assert n.look.id=='take'
until(n,lambda:n.look.t>1);n.onPanel(n,'choice:0');assert n.carrying
walk(2.625,3.3);walk(7.4,3.3);walk(7.4,2.1)
n.interact(n,'door');until(n,lambda:bool(n.result))
assert n.result.toStore;checks.append('wake, departure, reply, box and elevator')
T=require('game.TimelineState')
t=T.new(table({'dest':'echo1','progress':{'nodes':['2312','2338','echo1'],'floors':{'echo1':2}}}))
until(t,lambda:not t.busy);assert t.si==3
t.pick(t,4);assert t.si==3
t.pickFloor(t,99);assert t.floor.echo1==2
t.pickFloor(t,-99);assert t.floor.echo1==0
t.step(t,1);assert t.si==1
t.step(t,-1);assert t.si==3
t.pickFloor(t,1);t.confirm(t);until(t,lambda:bool(t.result))
assert t.result.node=='echo1' and t.result.floor==1
checks.append('timeline lock, wrap, floor gate, portal result')
report={'result':'PASS','checks':checks,'usesTeleport':False,'notCovered':['native rendering','OS keyboard and touch','audio','19 puzzle solutions']}
Path('docs/migration/increment03-prologue-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
