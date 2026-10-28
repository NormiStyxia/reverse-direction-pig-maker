"""Rebuilding older rooms must retain the active post-composite viewport."""
from lupa.lua54 import LuaRuntime
l=LuaRuntime();l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
local final,raw,background={name='composite'},{name='active-room'},{name='history-room'}
renderer={viewport=final,GetViewport=function(self,i)return self.viewport end,SetViewport=function(self,i,v)self.viewport=v end}
function Scene()return {}end
package.loaded['game.LevelCatalog']={at=function(j)return {levels={},theme='store',answer='same'},j end}
package.loaded['game.EchoRun']={new=function()return {load=function()end,drainEvents=function()end}end}
local built,disposed,captured=false,false,false
package.loaded['render.EchoRenderer']={new=function()
 renderer:SetViewport(0,background) -- actual room constructors activate their viewport
 return {view={ready=false,pumpBuild=function(self)self.ready=built end},update=function()end,dispose=function()disposed=true end}
end}
local History=require('render.EchoHistory');local h=History.new()
local active={view={scene={}},activate=function()renderer:SetViewport(0,raw)end}
local run={theme='store',index=2}
function h:capture(view,r)captured=true;self.rooms[0]={}end
function h:place(scene,at)assert(scene==active.view.scene);self.at=at end
h:fill(active,run,{})
assert(h.pending and renderer:GetViewport(0)==final,'history allocation replaced final composite')
h:fill(active,run,{})
assert(h.pending and renderer:GetViewport(0)==final,'pending build replaced final composite')
built=true;h:fill(active,run,{})
assert(not h.pending and captured and disposed and h.at==1 and renderer:GetViewport(0)==final,'completed history replaced final composite')
h:fill(active,run,{})
assert(renderer:GetViewport(0)==final,'already complete history changed viewport')
''')
print('PASS: history allocation, pending build, capture/disposal and completion preserve the active composite viewport')
