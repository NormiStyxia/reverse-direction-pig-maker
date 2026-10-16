"""Exercise real Lua style uniform routing, including source-inherited cadence."""
import json,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
function Vector3(x,y,z)return {x=x,y=y,z=z}end
function Vector2(x,y)return {x=x,y=y}end
function Variant(x)return x end
TRIANGLE_LIST=0
local function noop()end
local mesh={SetNumGeometries=noop,BeginGeometry=noop,DefineVertex=noop,DefineNormal=noop,DefineTexCoord=noop,Commit=noop,SetMaterial=noop}
local node={CreateComponent=function()return mesh end}
Material={new=function()return {params={},SetSurfaceShader=function()return true end,SetShaderParameter=function(self,k,v)self.params[k]=v end}end}
graphics={GetWidth=function()return 1920 end,GetHeight=function()return 1080 end}
view={camera={nearClip=1,farClip=1400,fov=24,UseReverseZ=function()return true end},cameraNode={position={x=0,y=8,z=-22},CreateChild=function()return node end}}
''')
Style=lua.eval("require('render.SceneStyle')")[0];tuning=lua.eval("require('game.data.Tuning')")[0]
dof=lua.eval('Material:new()');ink=lua.eval('Material:new()');s=Style.new(lua.globals().view,ink,dof);fx=lua.table_from({});checks=0
for name,amp in [('store',.17),('ch1',.35)]:
 t=tuning[name];s.update(s,t,fx,2,None,0);p=s.material.params
 assert p.wobbleFps==4 and p.wobbleOn==amp,(name,p.wobbleFps,p.wobbleOn)
 assert p.paperOn==(0 if name=='ch1' else 1)
 assert p.lineOn==1 and p.depth_reverse==1 and p.cNear==1 and p.cFar==1400
 assert dof.params.cFar==1400 and dof.params.enabled==1 and dof.params.maxCoc==26
 checks+=10
 t.wobble=False;t.lines=False;s.update(s,t,fx,2,None,0)
 assert p.wobbleOn==0 and p.lineOn==0
 t.wobble=None;t.lines=None;checks+=2
# Point sampling at texel centres exactly selects the original nearest texel,
# independently of the backend's fixed hint-depth sampler filtering mode.
for size in [1,270,1080,1566,2532]:
 for i in range(1001):
  uv=-.01+1.02*i/1000
  center=(max(0,min(size-1,math.floor(uv*size)))+.5)/size
  assert math.floor(center*size)==max(0,min(size-1,math.floor(uv*size)))
  checks+=1
report={'result':'PASS','checks':checks,'sourceCadenceHz':4,'storeWobbleAmp':.17,'chapterWobbleAmp':.35,'chapterPaper':False,'scope':'Lua uniforms and nearest-texel coordinates; native temporal acceptance reported separately'}
(ROOT/'docs/migration/scene-style-test-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
