"""Exercise native loading lifecycle and probe gates; no GPU timing claim."""
from lupa.lua54 import LuaRuntime
lua=LuaRuntime();lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local L=require('render.CaptionOverlay')
local c={fontReady=false,loadingAlpha=1}
for i=1,20 do assert(L.loadStep(c,.05,true)and c.loadingAlpha==1)end
c.fontReady=true
for i=1,20 do assert(L.loadStep(c,.05,false)and c.loadingFrames==0)end
assert(L.loadStep(c,.05,true)and c.loadingAlpha==1)
assert(L.loadStep(c,.05,true)and c.loadingAlpha==1)
assert(L.loadStep(c,10,true)and math.abs(c.loadingAlpha-.8)<1e-9)
local previous=c.loadingAlpha;L.loadStep(c,-1,true);assert(c.loadingAlpha==previous)
for i=1,6 do L.loadStep(c,.05,true)end
assert(not c.loading and c.loadingAlpha==0)
-- A newly unready room must be fully opaque again, even after a completed fade.
assert(L.loadStep(c,.05,false)and c.loadingAlpha==1 and c.loadingFrames==0)
-- Font-independent opaque drawing exists before any text can be rendered.
local fills=0
for _,name in ipairs({'nvgSave','nvgGlobalAlpha','nvgBeginPath','nvgRect','nvgFillColor','nvgStrokeColor','nvgStrokeWidth','nvgMoveTo','nvgLineTo','nvgStroke','nvgRestore'})do _G[name]=function()end end
nvgRGBA=function(...)return{...}end;nvgFill=function()fills=fills+1 end
L.drawLoading({fontReady=false,w=1200,h=540,vg=1,loadingAlpha=1});assert(fills==1)

-- Real Probe:update methods must not advance story/simulation while loading.
local function noop()end
local function forbidden()error('simulation/input advanced while covered')end
for _,module in ipairs({'preview.Chapter1Probe','preview.StoreProbe','preview.EchoProbe'})do
 local P=require(module);local ready=false;local cancels=0
 local screen={loading=true,loadingAlpha=1,fontReady=false,ending={active=false},
  update=noop,place=noop,cancelPointer=function()cancels=cancels+1 end}
 local mesh={ready=false,pumpBuild=noop}
 local view={view=mesh,ready=false,pumpBuild=noop,update=function(_,dt)assert(dt==0)end,actorScreen=function()return .2,.4 end,loadId=1,pose={}}
 local post={updateGame=function(_,a,b,dt)assert(dt==0)end,view=mesh}
 local p=setmetatable({view=view,screen=screen,post=post,story={update=forbidden},run={loadId=1,update=forbidden},bridge={},
  updatePost=function(_,dt)assert(dt==0)end},P)
 p:update(.05);assert(screen.loading and screen.loadingAlpha==1)
 mesh.ready=true;view.ready=true
 for i=1,4 do p:update(.05);assert(screen.loading and screen.loadingAlpha==1)end
 screen.fontReady=true
 for i=1,9 do if screen.loading then p:update(.05)end end
 assert(not screen.loading and screen.loadingAlpha==0)
 if module=='preview.EchoProbe'then
  post.dispose=noop
  package.loaded['render.ScenePost']={new=function(v)return{view=v,setEnabled=noop}end}
  view.load=function(self,run)self.loadId=run.loadId;self.view={ready=false,pumpBuild=noop}end
  p.run.loadId=2;p.charge=true;p.restart=true
  assert(not p:syncScene());assert(cancels==1 and not p.charge and not p.restart and screen.loadingAlpha==1)
 end
end
-- Pointer gate consumes taps without forwarding them into covered scene UI.
local Controls=require('render.PlayerControls')
local fired=0;local state={covered=true}
local controls=Controls.new(function()return state end,function()fired=fired+1 end)
local canvas={w=1200,h=540,dpr=2}
assert(controls:down(canvas,100,100,1));assert(controls:up(canvas,100,100,1));assert(fired==0)
''')
print('PASS: resource/font wait, ready-frame delay, clamped fade, room reset/cancel, 3 real probe simulation gates, covered pointer input')
