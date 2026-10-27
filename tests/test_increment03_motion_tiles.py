"""Verify the delivered sprite pixels, mip footprints and runtime frame binding."""
from pathlib import Path
from PIL import Image
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
source=Image.open(root/'assets/c0/normi-motion-atlas.png').convert('RGBA')
levels=[source]
for _ in range(7):
 prev=levels[-1];levels.append(prev.resize((prev.width//2,prev.height//2),Image.Resampling.BOX))
checks=0
for frame in range(28):
 tile=Image.open(root/f'assets/increment03/normi-motion/{frame:02}.png').convert('RGBA')
 for level,original in enumerate(levels):
  pad=128>>level;cell=768>>level;x=(frame%4)*cell;y=(frame//4)*cell
  assert tile.crop((pad,pad,pad+cell,pad+cell)).tobytes()==original.crop((x,y,x+cell,y+cell)).tobytes(),(frame,level)
  checks+=1
  if level<7:tile=tile.resize((tile.width//2,tile.height//2),Image.Resampling.BOX)
lua=LuaRuntime();lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local R=require('render.StoreRenderer')
Vector4=function(...)return{...}end;Variant=function(v)return v end
local function material()return{bindings={},params={},calls=0,SetSurfaceTexture=function(self,k,v)self.bindings[k]=v;self.calls=self.calls+1 end,SetShaderParameter=function(self,k,v)self.params[k]=v end}end
local base,face=material(),material();local v=setmetatable({motionTextureId=5,data={materials={{map=5,emissiveMap=5},{map=6,emissiveMap=0}}},materials={base,face},textures={}},R)
for i=0,27 do v.textures[string.format('increment03/normi-motion/%02d.png',i)]=i end
for i=0,27 do
 v:setActorFrame(1,i,4,7);assert(base.bindings.paint_map==i and base.bindings.emit_map==i)
 local uv=base.params.map_uv;assert(uv[1]==.75 and uv[2]==.75 and uv[3]==.125 and uv[4]==.125)
 local count=base.calls;v:setActorFrame(1,i,4,7);assert(base.calls==count)
end
v:setActorFrame(2,8,3,3);assert(not face.bindings.paint_map and face.params.map_uv[3]==2/3)
v:setActorFrame(1,0,4,7);assert(base.bindings.paint_map==0)
assert(not pcall(v.setActorFrame,v,1,28,4,7))
''')
print(f'PASS: {checks} exact frame/mip crops; 28 runtime frame bindings, unchanged face atlas, cached binds, invalid frame guard')
