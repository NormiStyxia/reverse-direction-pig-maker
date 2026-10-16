"""Regression checks for errors observed in official runtime logs.

Mocks enforce CustomGeometry material-slot and first-frame buffer contracts.
This is not an engine rendering test.
"""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path='+json.dumps(str(ROOT/'scripts/?.lua'),ensure_ascii=False)+'..";"..package.path')
lua.execute('''
TRIANGLE_LIST=0;TONEMAP_MODE_NONE=0
function Vector2(x,y)return {x=x,y=y} end
function Vector3(x,y,z)return {x=x,y=y,z=z} end
function Color(...)return {...} end
function BoundingBox(...)return {...} end
function Variant(v)return v end
graphics={GetWidth=function()return 1280 end,GetHeight=function()return 720 end}
local function material(path)
 return {path=path,params={},Clone=function(s)return material(s.path) end,
  SetShaderParameter=function(s,k,v)s.params[k]=v end}
end
cache={GetResource=function(_,kind,path)
 if kind=='Material' then return material(path) end
 if kind=='Texture2D' then return {width=700,height=500} end
 if kind=='XMLFile' then return {path=path} end
 error('unknown resource type')
end}
meshes={}
local function geometry()
 local g={slots=0,vertices={},enabled=true,committed=false}
 function g:SetNumGeometries(n)self.slots=n end
 function g:SetMaterial(m)assert(self.slots>0,'material assigned before slot creation');self.material=m end
 function g:BeginGeometry(index,kind)assert(index<self.slots);self.vertices={} end
 function g:DefineVertex(v)self.vertices[#self.vertices+1]=v end
 function g:DefineNormal(v)assert(v.z==-1) end
 function g:DefineTexCoord(v)assert(v.x and v.y) end
 function g:Commit()assert(#self.vertices==6);self.committed=true end
 meshes[#meshes+1]=g;return g
end
local function node()
 return {CreateComponent=function(_,kind)
  if kind=='CustomGeometry' then return geometry() end
  if kind=='Camera' then return {} end
  error('unexpected node component')
 end}
end
function Scene()
 return {CreateComponent=function(_,kind)
  if kind=='Octree' then return {} end
  if kind=='Zone' then return {SetAttribute=function()end} end
  error('unexpected scene component')
 end,CreateChild=function()return node() end,Dispose=function(s)s.disposed=true end}
end
local function renderPath()
 return {Clone=function()return renderPath() end,Load=function(s,file)s.file=file;return true end}
end
Viewport={new=function(_,scene,camera)
 return {scene=scene,camera=camera,path=renderPath(),
  GetRenderPath=function(s)return s.path end,SetRenderPath=function(s,p)s.path=p end}
end}
renderer={SetViewport=function(s,i,v)assert(i==0);s.viewport=v end}
function checkDrawables()
 for _,m in ipairs(meshes) do
  if m.enabled then assert(m.committed and #m.vertices==6 and m.material,'empty or unbound drawable') end
 end
end
''')
Title=lua.eval('require("game.TitleState")')[0]
Renderer=lua.eval('require("render.TitleRenderer")')[0]
title=Title.new(0,lambda:.5);view=Renderer.new()
lua.globals().checkDrawables()
assert len(lua.globals().meshes)==12
assert view.viewport.path.file.path=='RenderPaths/Forward.xml'
for _ in range(120):
    title.update(title,1/60);view.update(view,title);lua.globals().checkDrawables()
title.opts.motion=False;view.update(view,title)
assert all(not view.sprites[i].geometry.enabled for i in range(1,11))
assert view.sprites[11].geometry.enabled
view.resize(view,0,0);assert view.camera.orthoSize>0
view.dispose(view);assert view.scene.disposed
report={'result':'PASS','frames':120,'drawables':12,
 'checks':['forward render path selected','material slots allocated before assignment',
 'first-frame drawables committed before enable','moving quads have six vertices',
 'motion setting preserves pig','zero-sized viewport remains finite'],
 'notCovered':['GPU/shader execution','native CustomGeometry implementation','runtime warning resolution','visual parity']}
(ROOT/'docs/migration/title-renderer-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
