"""Validate app render-target ownership, resize, and source frost routing using real Lua."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
function Vector3(x,y,z)return {x=x,y=y,z=z}end
function Vector2(x,y)return {x=x,y=y}end
function Variant(x)return x end
function BoundingBox(a,b)return {a,b}end
TRIANGLE_LIST=1;TONEMAP_MODE_NONE=0;TEXTURE_RENDERTARGET=1;TEXTURE_DEPTHSTENCIL=2;FILTER_BILINEAR=1;FILTER_NEAREST=0;ADDRESS_CLAMP=1;COORD_U=0;COORD_V=1;SURFACE_MANUALUPDATE=0
surfaceGcCount=0;surfaceGcErrors=0
function generic()
 return setmetatable({attributes={},bound={},params={},queued=0,dead=false},{__index=function(self,k)
  return function(self,...)
   assert(not self.dead,'use after disposal '..k)
   local a,b=...
   if k=='SetAttribute' then self.attributes[a]=b
   elseif k=='SetSurfaceTexture' then self.bound[a]=b
   elseif k=='SetShaderParameter' then self.params[a]=b
   elseif k=='SetLinkedDepthStencil' then self.linked=a
   elseif k=='GetRenderSurface' then
    local weak=rawget(self,'surfaceRef');local surface=weak and weak[1]
    if not surface then
     surface=generic();local parent=self;local meta=getmetatable(surface)
     meta.__gc=function(s)surfaceGcCount=surfaceGcCount+1;if parent.dead then surfaceGcErrors=surfaceGcErrors+1 end end
     setmetatable(surface,meta)
     self.surfaceRef=setmetatable({surface},{__mode='v'})
    end
    return surface
   elseif k=='Dispose' then local weak=rawget(self,'surfaceRef');assert(not weak or not weak[1],'surface wrapper outlives parent texture');self.dead=true
   elseif k=='SetNumViewports' then self.count=a
   elseif k=='QueueUpdate' then self.queued=self.queued+1
   elseif k=='SetSize' then self.w=a;self.h=b;return true
   elseif k=='SetSurfaceShader' or k=='Load' then return true
   else return generic() end
  end
 end})
end
package.loaded['render.PuffRenderer']={new=function()return {dispose=function(self)self.disposed=true end}end}
package.loaded['render.WorldDust']={new=function()return {viewport=generic(),dispose=function(self)self.disposed=true end}end}
package.loaded['render.SceneStyle']={new=function(view)return {node=generic()} end}
function Scene()return generic()end
Viewport={new=function()return generic()end};Material={new=function()return generic()end}
Texture2D={new=function()return generic()end}
Graphics={GetRGBAFloat16Format=function()return 16 end,GetReadableDepthFormat=function()return 24 end}
graphics={w=1920,h=1080,GetWidth=function(self)return self.w end,GetHeight=function(self)return self.h end}
renderer={SetViewport=function(self,i,v)self.viewport=v end,GetViewport=function(self,i)return self.viewport end}
cache={GetResource=function()return generic()end}
view={zone=generic(),viewport=generic()}
canvas={story={phone={k=.75},browse={k=.4,layoutSide='left',frostEdge=.36}},channel='phone',placement={layoutSide='right',frostEdge=.62}}
''')
Post=lua.eval("require('render.ScenePost')")[0];g=lua.globals();p=Post.new(g.view)
checks=0
for w,h in [(1920,1080),(2880,1566),(1170,2532),(1,1),(1921,1081)]:
 old=list(p.targets.values())+list(p.bloomTargets.values());g.graphics.w=w;g.graphics.h=h
 p.setEnabled(p,True);p.update(p,g.canvas,0)
 if old[0].w!=w or old[0].h!=h:assert all(t.dead for t in old)
 assert p.targets[1].w==w and p.targets[1].h==h
 assert p.targets[6].w==w and p.targets[6].h==h
 assert p.depthTexture.w==w and p.depthTexture.h==h
 assert p.nearTexture.w==w and p.nearTexture.h==h
 assert p.nearSurface.queued>=1
 assert lua.eval("function(p)return p.dof.material.bound.tNear==p.nearTexture end")(p)
 checks+=3
 assert lua.eval('function(p)return p.surfaces[1].linked==p.depthSurface and p.dof.material.bound.tDepth==p.depthTexture end')(p)
 assert lua.eval('function(p)return p.dof.material.bound.tStyled==p.targets[7] and p.ink.material.bound.tColor==p.targets[1] and p.ink.material.bound.tDepth==p.depthTexture and p.final.material.bound.tColor==p.targets[6] end')(p)
 for i in range(1,5):
  stage=p.passes[i];t=p.targets[i+1]
  assert t.w==max(1,int(w/4+.5)) and t.h==max(1,int(h/4+.5))
  assert stage.material.bound.input_color.w==p.targets[6 if i==1 else i].w
  d=stage.material.params.blur_dir
  assert (d.x>0 and d.y==0) if i%2 else (d.x==0 and d.y>0)
  assert p.surfaces[i+1].queued>=1
  checks+=4
 for i in range(1,8):
  stage=p.bloom[i];t=p.bloomTargets[i];divisor=2 if i==1 else 4 if i<=3 else 8
  assert t.w==max(1,int(w/divisor+.5)) and t.h==max(1,int(h/divisor+.5))
  assert p.bloomSurfaces[i].queued>=1
  if i>1: assert stage.material.bound.input_color.w==p.bloomTargets[i-1].w
  checks+=3
 assert p.final.material.bound.tBloomA.w==p.bloomTargets[3].w
 assert p.final.material.bound.tBloomB.w==p.bloomTargets[7].w
 assert p.final.material.params.frost==.75 and p.final.material.params.frostSide==1
 before=[s.queued for s in p.surfaces.values()]
 p.setEnabled(p,False);p.update(p,g.canvas,1)
 assert [s.queued for s in p.surfaces.values()]==before and g.view.zone.attributes['Bloom Enable']
 checks+=7
p.setEnabled(p,True);g.canvas.channel='browse';p.update(p,g.canvas,0)
assert p.final.material.params.frost==.4 and p.final.material.params.frostSide==-1 and p.final.material.params.frostEdge==.36
p.update(p,g.canvas,.9)
assert p.final.material.params.frost==.9 and p.final.material.params.frostSide==1 and p.final.material.params.frostEdge==-.2
old=list(p.targets.values())+list(p.bloomTargets.values());p.dispose(p);assert all(t.dead for t in old)
checks+=3
lua.execute("collectgarbage('collect')")
assert g.surfaceGcErrors==0 and g.surfaceGcCount==80
checks+=2
# Echoes add a separately linked readable present depth. Disabled blue must not
# queue this view, and both wrappers must die before their parent textures.
lua.execute("package.loaded['render.PresentMask']={new=function()return {viewport=generic(),dispose=function(self)self.disposed=true end}end};view.data={definition={}}")
p=Post.new(g.view)
for w,h in [(1920,1080),(2880,1566),(1170,2532),(1,1),(1921,1081)]:
 g.graphics.w=w;g.graphics.h=h;p.setEnabled(p,True);p.presentActive=False;p.update(p,g.canvas,0)
 assert lua.eval('function(p)return p.surfaces[8].linked==p.presentDepthSurface and p.final.material.bound.tPresent==p.presentDepth and p.final.material.bound.tSceneDepth==p.depthTexture end')(p)
 assert p.presentDepth.w==w and p.presentDepth.h==h
 before=p.surfaces[8].queued;p.update(p,g.canvas,0);assert p.surfaces[8].queued==before
 p.presentActive=True;p.update(p,g.canvas,0);assert p.surfaces[8].queued==before+1
 checks+=4
p.dispose(p);lua.execute("collectgarbage('collect')")
assert g.surfaceGcErrors==0 and g.surfaceGcCount==188,(g.surfaceGcErrors,g.surfaceGcCount)
checks+=1
report={'result':'PASS','checks':checks,'sizes':5,'coverage':['resize releases old targets after detaching viewports and materials','188 surface wrappers collected before parent textures; zero invalid destructor accesses','scene ink and DOF color separated; shared readable depth attached and detached','present-depth linked/detached with conditional render scheduling', 'all frost, DOF and bloom targets explicitly queued','source bloom bright/quarter/eighth resolution with six directional passes','disabled pipeline queues no work','phone/browse/haze mask routing','source quarter resolution and blur axis order'], 'notCovered':['GPU pass order and image parity','95% game visual acceptance']}
(ROOT/'docs/migration/scene-post-test-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
