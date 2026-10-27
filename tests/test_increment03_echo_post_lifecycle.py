"""Every floor/restart must own a live Post targeting the current native room."""
from lupa.lua54 import LuaRuntime
lua=LuaRuntime();lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local operations={};local made=0
package.loaded['render.ScenePost']={new=function(view)
 made=made+1;operations[#operations+1]='post-new'
 return {view=view,setEnabled=function(self,on)assert(on);self.enabled=on end,dispose=function(self)assert(not self.disposed);self.disposed=true;operations[#operations+1]='post-dispose' end}
end}
local P=require('preview.EchoProbe')
local function mesh(ready)return{ready=ready,pumpBuild=function()end}end
local v={loadId=1,view=mesh(true),load=function(self,run)
 operations[#operations+1]='room-load';self.view.disposed=true;self.loadId=run.loadId;self.view=mesh(false)
end}
local p=setmetatable({run={loadId=1},view=v,screen={cancelPointer=function()end}},P)
assert(p:syncScene()and p.post.view==v.view and made==1)
local first=p.post;p:syncScene();assert(made==1)
for level=2,19 do
 operations={};p.run.loadId=level
 assert(not p:syncScene());assert(operations[1]=='post-dispose'and operations[2]=='room-load'and operations[3]=='post-new')
 assert(p.post.view==v.view and not p.post.view.disposed and p.screen.loading)
 v.view.ready=true;assert(p:syncScene());assert(made==level)
end
assert(first.disposed)
-- Restart increments loadId even though the floor index need not change.
p.run.loadId=20;p:syncScene();assert(made==20 and p.post.view==v.view)
-- A diagnostic renderer replacement is recovered as well.
local previous=p.post;v.view=mesh(true);p:syncScene();assert(previous.disposed and made==21 and p.post.view==v.view)
''')
print('PASS: 19 rooms, same-floor restart, disposed-view recovery; Post disposed before room; no redundant rebuild')
