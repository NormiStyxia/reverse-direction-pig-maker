"""Retained rooms survive scene disposal and hide rain without hiding instance meshes."""
from lupa.lua54 import LuaRuntime
l=LuaRuntime();l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
local Node={};Node.__index=Node
local function node(name,parent)local n=setmetatable({name=name,children={},enabled=true,position={x=0,y=0,z=0}},Node);if parent then n:SetParent(parent)end;return n end
function Node:GetChildren()return self.children end
function Node:GetChild(i)return self.children[i+1]end
function Node:GetParent()return self.parent end
function Node:RemoveComponents(t)assert(t=='Light');self.light=false end
function Node:SetParent(parent)
 if self.parent then for i,c in ipairs(self.parent.children)do if c==self then table.remove(self.parent.children,i);break end end end
 self.parent=parent;parent.children[#parent.children+1]=self
end
-- Clone without mutating the original children array while iterating.
function Node:Clone()
 local function copy(n,p)local c=node(n.name,p);c.position={x=n.position.x,y=n.position.y,z=n.position.z};for _,v in ipairs(n.children)do copy(v,c)end;return c end
 return copy(self,self.parent)
end
function Node:Remove()self.removed=true;if self.parent then for i,c in ipairs(self.parent.children)do if c==self then table.remove(self.parent.children,i);break end end end;self.parent=nil end
function Node:Dispose()self.disposed=true;for _,c in ipairs(self.children)do c.removed=true end end
function Scene()return node('scene')end
Vector3=setmetatable({UP={}},{__call=function(_,x,y,z)return{x=x,y=y,z=z}end})
function Quaternion(y,axis)return{yaw=y}end
local History=require('render.EchoHistory');local h=History.new()
local scene=Scene();local root=node('root',scene);local products=node('products',root)
local instance=node('native instance',products);local rain=node('rain',products);local crate=node('crate',root);crate.position.x=4.75
local view={view={nodes={[1]=root,[2]=products,[3]=rain,[4]=crate}},data={handles={root=1,rain=3},nodes={{id=1,parent=0},{id=2,parent=1},{id=3,parent=2},{id=4,parent=1}}}}
local run={theme='store',index=1,phase='out',answer='same',loadId=1}
h:capture(view,run);local r=h.rooms[0]
assert(r.completed and r.node.children[2].position.x==4.75)
assert(r.node.children[1].children[1].enabled and not r.node.children[1].children[2].enabled)
crate.position.x=9;assert(r.node.children[2].position.x==4.75)
h:place(scene,1);assert(r.node.enabled and r.node.parent==scene and r.node.position.y==-5.5)
h:park();scene:Dispose();assert(not r.node.removed and r.node.parent==h.storage)
local nextScene=Scene();h:place(nextScene,1);assert(r.node.enabled and h:complete(1)and not h:complete(2))
h:clear();assert(r.node.removed and next(h.rooms)==nil)
h:dispose();assert(h.storage.disposed)
''')
print('PASS: true end transforms retained, native instance indices, rain-only hiding, park/dispose/reparent, history cleanup (model test)')
