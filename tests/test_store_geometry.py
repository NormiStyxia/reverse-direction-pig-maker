"""Validate every native triangle stream against frozen browser-exported source data.
Mocks capture actual StoreRenderer:model() output; no screenshot-similarity claims.
"""
import hashlib,json,math,sys
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
arg=sys.argv[1] if len(sys.argv)>1 else None
chapter=arg if arg in ['meeting','morning'] else None
ch1echo=arg.removeprefix('ch1-') if arg and arg.startswith('ch1-') else None
level=int(arg) if arg and not chapter and not ch1echo else None
prefix=f'ch1-echo-{ch1echo}' if ch1echo else f'chapter1-{chapter}' if chapter else (f'echo-{level}' if level else 'store')
source_path=f'validation/ch1-echo/source-{ch1echo}.json' if ch1echo else f'validation/chapter1/source-{chapter}.json' if chapter else (f'validation/echo/source-level-{level}.json' if level else 'validation/store/source-scene.json')
source=json.loads((ROOT/source_path).read_text())
report=json.loads((ROOT/'docs/migration'/(prefix+'-export-report.json')).read_text())
for path,digest in report['sourceFiles'].items():
    assert hashlib.sha256((ROOT/'reference/h5-source'/path).read_bytes()).hexdigest()==digest,path
assert report['sourceFiles']['config/ch1-tuning.json']=='1dae5f70540d5606ba113498d202bf45175721f817c8ef983669adf0ef8101a9'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path='+json.dumps(str(ROOT/'scripts/?.lua'),ensure_ascii=False)+'..";"..package.path')
lua.execute('''
TRIANGLE_LIST=0
function Vector2(x,y)return {x,y} end
function Vector3(x,y,z)return {x,y,z} end
function Color(r,g,b,a)return {r,g,b,a} end
function Model()return {} end
local function geometry()
 local g={slots={},current=false}
 function g:SetNumGeometries(n)self.n=n end
 function g:BeginGeometry(slot,kind)assert(slot<self.n);self.current={};self.slots[slot]=self.current end
 function g:DefineVertex(v)local e={p=v};self.current[#self.current+1]=e;self.vertex=e end
 function g:DefineNormal(v)self.vertex.n=v end
 function g:DefineTexCoord(v)self.vertex.uv=v end
 function g:DefineColor(v)self.vertex.c=v end
 function g:Commit()assert(not self.enabled);for _,slot in pairs(self.slots)do assert(#slot%3==0)end end
 function g:FillModel(m)m.slots=self.slots;return true end
 return g
end
local scene={CreateChild=function()return {CreateComponent=function()return geometry()end,Remove=function()end}end}
local R=require('render.StoreRenderer')
view=setmetatable({scene=scene,models={}},R)
''')
view=lua.globals().view
if level:view.data=lua.execute((ROOT/f'scripts/game/data/EchoScene{level}.lua').read_text())
if chapter:view.data=lua.execute((ROOT/f'scripts/game/data/Chapter1{chapter.title()}Scene.lua').read_text())
if ch1echo:view.data=lua.execute((ROOT/f'scripts/game/data/Ch1Echo{ch1echo.replace("-","")}.lua').read_text())
keys={(n['geometry'],len(n['materials'])) for n in source['nodes'] if n['type'] in ['Mesh','Sprite']}
for gid,slots in keys:
    attributes=source['geometries'][gid-1]['attributes']
    count=len(attributes['position']['array'])/3
    assert count==int(count),(gid,'position stride is not packed')
    for name,a in attributes.items():
        assert len(a['array'])==count*a['size'],(gid,name,'interleaved attribute was not unpacked')
vertices=triangles=groups=0
def tup(t):return [t[i] for i in range(1,len(t)+1)]
def close(a,b):assert len(a)==len(b) and all(abs(x-y)<1e-8 for x,y in zip(a,b)),(a,b)
for gid,slots in sorted(keys):
    model=view.model(view,gid,slots)
    g=source['geometries'][gid-1];attrs=g['attributes'];p=attrs['position']['array']
    indices=g['index'] or list(range(len(p)//3))
    srcgroups=g['groups'] if slots>1 else [{'start':0,'count':len(indices),'materialIndex':0}]
    for slot in range(slots):
        groups+=1;stream=model['slots'][slot];expected=[]
        for group in srcgroups:
            if group['materialIndex']==slot:
                chunk=indices[group['start']:group['start']+group['count']]
                assert len(chunk)%3==0
                for i in range(0,len(chunk),3):expected.extend([chunk[i],chunk[i+2],chunk[i+1]])
        assert len(stream)==len(expected)
        for out,index in enumerate(expected,1):
            e=stream[out];j=index*3;k=index*2
            close(tup(e['p']),[p[j],p[j+1],-p[j+2]])
            if 'normal' in attrs:
                n=attrs['normal']['array'];close(tup(e['n']),[n[j],n[j+1],-n[j+2]])
            if 'uv' in attrs:
                uv=attrs['uv']['array'];close(tup(e['uv']),[uv[k],1-uv[k+1]])
            assert all(math.isfinite(v) for v in tup(e['p'])+tup(e['n'])+tup(e['uv']))
            vertices+=1
        triangles+=len(expected)//3
    # Shared geometry remains shared on the native importer, not rebuilt per product.
    assert lua.eval('function(a,b)return a==b end')(model,view.model(view,gid,slots))
result={'result':'PASS','nativeModelVariants':len(keys),'materialGroups':groups,'triangles':triangles,'verticesCompared':vertices,
    'sourceNodes':len(source['nodes']),'productInstances':sum(len(n.get('instances',[])) for n in source['nodes']),
    'checks':['all mesh vertices/normals/UVs versus source','single Z reflection and reversed triangle order','multi-material slots','shared native model reuse','finite coordinates','frozen tuning hash'],
    'notCovered':['GPU winding/culling','light/shadow equivalence','95% visual acceptance','all live source scene dynamics']}
(ROOT/'docs/migration'/(prefix+'-geometry-test-report.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
