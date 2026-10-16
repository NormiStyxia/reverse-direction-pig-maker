"""Increment 02 contracts: real menu/controller/application routing, mocked GPU/save I/O."""
import json, runpy
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local Title=require('game.TitleState')
for reached=0,6 do
 for i=0,10 do
  local t=Title.new(reached);t:skipIntro();t:update(.01);assert(t:count()==5)
  t:activate(2);assert(t.panel=='levelmode' and t:count()==11 and not t:disabled(i))
  t:activate(i);local c=t.st.choice
  assert(c.kind=='levels' and c.set==(i<6 and 'prologue' or 'ch1') and c.level==(i<6 and i or i-6))
 end
end
local C=require('render.PlayerControls')
local context={echo=true,movable=true,paused=false};local actions={}
local c={w=844,h=390,dpr=3};local ctl=C.new(function()return context end,function(id)actions[#actions+1]=id end)
ctl.mobile=true
local function row(id)for _,r in ipairs(ctl:layout(c))do if r.id==id then return r end end end
local function point(r)return (r.x+r.w/2)*c.dpr,(r.y+r.h/2)*c.dpr end
local r=row('stick');local x,y=point(r);assert(ctl:down(c,x,y,1));ctl:move(c,x+120,y,1);assert(ctl.x>.8)
r=row('rewind');local rx,ry=point(r);assert(ctl:down(c,rx,ry,2) and ctl.spin)
ctl:up(c,rx,ry,3);assert(ctl.spin and ctl.x>.8)
ctl:up(c,rx,ry,2);assert(not ctl.spin and ctl.x>.8)
ctl:up(c,x,y,1);assert(ctl.x==0 and ctl.y==0)
for _,size in ipairs({{844,390},{667,375},{390,844},{320,568}}) do
 for _,dpr in ipairs({1,2,3}) do
  c.w=size[1];c.h=size[2];c.dpr=dpr
  for _,paused in ipairs({false,true}) do
   context.paused=paused
   for _,r in ipairs(ctl:layout(c))do
    assert(r.x>=0 and r.y>=0 and r.x+r.w<=c.w and r.y+r.h<=c.h and r.h>=44)
    for _,other in ipairs(ctl:layout(c))do
     if other.id~=r.id then assert(r.x+r.w<=other.x or other.x+other.w<=r.x or r.y+r.h<=other.y or other.y+other.h<=r.y,'overlapping touch targets') end
    end
   end
  end
 end
end
ctl:cancel();context.paused=true;assert(ctl:down(c,0,0,1))
local r=row('home');local x,y=point(r);ctl:down(c,x,y,1);ctl:up(c,x,y,1);assert(actions[#actions]=='home')
''')
# Execute the real application with replaceable graphics/lifecycle boundaries.
lua.execute('''
KEY_ESCAPE=27;KEY_RETURN=13;KEY_M=77;SOUND_MASTER=0;MM_ABSOLUTE=0
for i=1,12 do _G['KEY_F'..i]=300+i end
KEY_K=75;KEY_SHIFT=16;KEY_LSHIFT=160;KEY_RSHIFT=161;KEY_UP=38;KEY_DOWN=40;KEY_W=87;KEY_S=83;KEY_SPACE=32;KEY_F=70;KEY_BACKSPACE=8
local function noop()end
local function screen()return {vg={},resize=noop,cancelPointer=noop,dispose=noop,update=noop,pointerDown=noop,pointerMove=noop,pointerUp=noop,render=noop,ending={active=false,show=function(self)self.active=true end}}end
local function view()return {ready=true,viewport={},update=noop,resize=noop,dispose=noop,activate=noop,view={ready=true},look={}}end
local data={reached=2,answer='late',writes=0}
TEST_SAVE=data
package.loaded['game.NativeSave']={open=function()return {reached=function()return data.reached end,answer=function()return data.answer end,
 echoLoaded=function(_,i)data.reached=i;data.writes=data.writes+1 end,echoFinished=function()data.writes=data.writes+1 end,meetingFinished=function()data.writes=data.writes+1 end}end}
package.loaded['game.AudioPlayback']={get=function()return {reset=noop,update=noop,dispose=noop,clock=0}end}
package.loaded['game.ScreenEffects']={shared={reset=noop}}
package.loaded['game.SpriteParticles']={shared={reset=noop}}
package.loaded['render.TitleRenderer']={new=view}
package.loaded['render.TitleOverlay']={new=screen}
package.loaded['preview.StoreProbe']={new=function()local d={screen=screen(),view=view(),story=require('game.PrologueState').new(),bridge=require('game.SceneBridge').new(),events=noop,dispose=noop};d.update=function()end;TEST_STORE=d;return d end}
package.loaded['preview.Chapter1Probe']={new=function(mode)TEST_CHAPTER=mode;return {screen=screen(),view=view(),story={mode=mode},focus=noop,update=noop,post={setEnabled=noop},ending={}}end}
package.loaded['preview.EchoProbe']={new=function(look,theme,answer,level,progress)
 local d={run={theme=theme,answer=answer,index=level or 1,phase='play'},screen=screen(),view=view(),bridge=require('game.SceneBridge').new(),focus=noop,update=noop,dispose=noop,suppressed={},onProgress=progress}
 d.key=function(self)self.keyCount=(self.keyCount or 0)+1 end
 d.setPaused=function(self,on)self.paused=on;self.playerPaused=on end
 TEST_ECHO=d;if progress then progress({kind='loadLevel',level=level or 1})end;return d
end}
graphics={GetWidth=function()return 1600 end,GetHeight=function()return 900 end,GetDPR=function()return 1 end}
audio={SetMasterGain=noop};input={};renderer={SetViewport=noop};SubscribeToEvent=noop
require('game.Application');Start()
local function upvalue(fn,name)for i=1,100 do local n,v=debug.getupvalue(fn,i);if n==name then return v end;if not n then break end end end
local event={GetFloat=function()return .05 end}
local function tick()TitlePreviewUpdate(nil,event)end
local function key(k)TitlePreviewKeyDown(nil,{GetInt=function()return k end,GetBool=function()return false end})end
local title=upvalue(TitlePreviewUpdate,'title')
title:skipIntro();title:update(.01);title:activate(2);title:activate(5)
for i=1,60 do tick()end
assert(TEST_ECHO.run.theme=='store' and TEST_ECHO.run.index==6 and data.writes==0)
TEST_ECHO.bridge.on=false;key(KEY_ESCAPE);assert(TEST_ECHO.paused)
local count=TEST_ECHO.keyCount;key(KEY_M);key(KEY_SPACE);assert(TEST_ECHO.keyCount==count)
key(KEY_ESCAPE);assert(not TEST_ECHO.paused)
TEST_ECHO.run.phase='done';if TEST_ECHO.onProgress then TEST_ECHO.onProgress({kind='echoFinished'})end;tick()
assert(TEST_ECHO.run.theme=='meeting' and TEST_ECHO.run.index==1 and TEST_ECHO.run.answer=='late')
assert(TEST_CHAPTER==nil and data.writes==0)
TEST_ECHO.run.phase='done';tick();assert(TEST_ECHO.screen.ending.active and TEST_CHAPTER==nil and data.writes==0)
TEST_ECHO.screen.ending.replay=true;tick()
-- Direct first-chapter entry, every selectable floor, no story save writes.
for index=6,10 do
 title=upvalue(TitlePreviewUpdate,'title');title:skipIntro();title:update(.01);title:activate(2);title:activate(index)
 for i=1,60 do tick()end
 assert(TEST_ECHO.run.theme=='meeting' and TEST_ECHO.run.index==index-5 and data.writes==0)
 TEST_ECHO.bridge.on=false;key(KEY_ESCAPE);assert(TEST_ECHO.paused);key(KEY_RETURN)
end
-- Returning to story mode restores persistence.
title=upvalue(TitlePreviewUpdate,'title');title:skipIntro();title:update(.01);title:activate(1)
for i=1,60 do tick()end
assert(TEST_ECHO.run.theme=='store' and TEST_ECHO.run.index==2 and data.writes==1)
''')
report={'result':'PASS','scope':'real menu + application routing with mocked GPU/probes/storage; real multi-touch controls',
        'checks':['77 unlocked level selections','store 6 to meeting 1 without story','meeting completion card','saved answer fallback path','no level-mode save writes','pause keyboard isolation and return to title','story persistence restored','12 touch viewport/DPR layouts','independent movement and held-rewind fingers'],
        'notCovered':['GPU rendering','physical mobile device','actual full level playthrough']}
(ROOT/'docs/migration/increment-02-contract-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
