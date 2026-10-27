"""Exercise callback ordering/cancellation, not GPU performance (native run required)."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local Renderer=require('render.StoreRenderer')
ADDRESS_WRAP=0;ADDRESS_CLAMP=1;ADDRESS_MIRROR=2;FILTER_NEAREST=0;FILTER_TRILINEAR=1;COORD_U=0;COORD_V=1
time={frameNumber=1};local calls={};local immediate=false
local function texture(mips)
 return {levels=mips or 2,width=32,height=32,SetAddressMode=function()end,
 SetNumLevels=function()end,SetData=function()return true end}
end
cache={GetResourceAsync=function(_,kind,path,callback)
 if immediate then callback(texture())else calls[#calls+1]={kind=kind,path=path,cb=callback}end
end}
local function fixture()
 return setmetatable({pending=5,textureInFlight=0,textureNext=1,textureQueue={'a','b','c','d','e'},
 textureSpecs={a={minFilter=1008}},textures={}},Renderer)
end
local s=fixture();s:pumpTextures();assert(#calls==2 and s.textureInFlight==2)
s:pumpTextures();assert(#calls==2,'Two probe calls in one frame exceeded request budget')
time.frameNumber=2;s:pumpTextures();assert(#calls==2,'Exceeded in-flight limit')
calls[1].cb(texture(1));assert(#calls==3 and calls[3].kind=='Image')
assert(s.pending==5,'Mipmapped texture became ready before Image upload')
calls[2].cb(texture());assert(s.pending==4 and s.textureInFlight==1)
calls[3].cb({});assert(s.pending==3 and s.textureInFlight==0)
time.frameNumber=3;s:pumpTextures();assert(#calls==5)
calls[5].cb(texture());calls[4].cb(texture());assert(s.pending==1)
time.frameNumber=4;s:pumpTextures();calls[6].cb(texture())
assert(s.pending==0 and s.textureInFlight==0 and type(s.buildTask)=='thread')
assert(s.textures.a and s.textures.e,'Missing original textures')
local old=fixture();time.frameNumber=5;old:pumpTextures();old.disposed=true
calls[7].cb(texture());calls[8].cb(texture());assert(old.pending==5 and not old.buildTask)
old:pumpTextures();assert(#calls==8,'Disposed scene queued new assets')
immediate=true;local warm=fixture();time.frameNumber=6;warm:pumpTextures()
assert(warm.pending==3 and warm.textureInFlight==0,'Warm callbacks exceeded frame budget')
time.frameNumber=7;warm:pumpTextures();assert(warm.pending==1)
time.frameNumber=8;warm:pumpTextures();assert(warm.pending==0 and warm.buildTask)
''')
files=list(Path('scripts').rglob('*.lua'))
for p in files:
    result=lua.eval('function(p)local f,e=loadfile(p);return f~=nil,e end')(str(p))
    assert result[0],(p,result[1])
print(f'PASS: cold/warm callbacks, mip upload, cancellation, per-frame/in-flight budgets; {len(files)} Lua 5.4 files parse')
