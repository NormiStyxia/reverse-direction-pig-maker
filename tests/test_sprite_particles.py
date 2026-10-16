"""Execute the exact frozen particle functions with inert Three objects vs real Lua."""
import json,subprocess,random
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1];src=(root/'reference/h5-source/src/main.js').read_text()
code=src[src.index('function spawnSprite('):src.index('// ---------- 交互：')]
rng=random.Random(6316);steps=[]
for i in range(5000):
 step={'dt':rng.choice([0,.001,1/60,.033,.05]),'kind':'idle'}
 if i%19==0:step.update(kind='puff',count=rng.randrange(1,9),pos={'x':rng.random()*10,'y':rng.random()*3,'z':rng.random()*10})
 elif i%37==0:step.update(kind='burst',pos={'x':rng.random()*10,'y':rng.random()*3,'z':rng.random()*10})
 steps.append(step)
steps += [{'dt':1/60,'kind':'idle'} for _ in range(60)]
js='''const steps=JSON.parse(require('fs').readFileSync(0,'utf8'));
let seed=6316;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296};
class V {constructor(x=0,y=0,z=0){Object.assign(this,{x,y,z})}copy(v){Object.assign(this,v);return this}clone(){return new V(this.x,this.y,this.z)}add(v){this.x+=v.x;this.y+=v.y;this.z+=v.z;return this}addScaledVector(v,s){this.x+=v.x*s;this.y+=v.y*s;this.z+=v.z*s;return this}}
const THREE={Vector3:V,Color:class{},DoubleSide:2,PlaneGeometry:class{constructor(s){this.size=s}dispose(){}},MeshBasicMaterial:class{constructor(d){this.map=d.map}dispose(){}},Mesh:class{constructor(g,m){this.geometry=g;this.material=m;this.position=new V();this.angle=0;this.sc=1;this.quaternion={copy:()=>{this.angle=0}};this.scale={setScalar:s=>{this.sc=s}}}rotateZ(a){this.angle+=a}}};
const scene={add(){},remove(){}},sprites=[],burstTex='burst',puffTex='puff',camera={quaternion:{}};
'''+code+'''
console.log(JSON.stringify(steps.map(s=>{if(s.kind==='puff')puff(new V().copy(s.pos),s.count);if(s.kind==='burst')burst(new V().copy(s.pos));updateSprites(s.dt);return sprites.map(p=>({kind:p.m.material.map,x:p.m.position.x,y:p.m.position.y,z:p.m.position.z,size:p.m.geometry.size,life:p.life,max:p.max,vx:p.vel.x,vy:p.vel.y,vz:p.vel.z,spin:p.spin,grow:p.grow,angle:p.m.angle,scale:p.m.sc}))})));'''
expected=json.loads(subprocess.check_output(['node','-e',js],input=json.dumps(steps),text=True))
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
p=lua.eval("function()local s=6316;return require('game.SpriteParticles').new(function()s=(s*1664525+1013904223)&0xffffffff;return s/4294967296 end)end")();checks=0
for i,(step,ref) in enumerate(zip(steps,expected)):
 if step['kind']=='puff':p.puff(p,lua.table_from(step['pos']),step['count'])
 elif step['kind']=='burst':p.burst(p,lua.table_from(step['pos']))
 p.update(p,step['dt']);assert len(p.list)==len(ref),(i,len(p.list),len(ref))
 for j,e in enumerate(ref,1):
  for k,v in e.items():
   got=p.list[j][k];assert (got==v if isinstance(v,str) else abs(got-v)<1e-12),(i,j,k,got,v);checks+=1
assert len(p.list)==0
# Pause holds the last rendered pose and lifetime exactly, with no fresh randoms.
p.puff(p,lua.table_from({'x':0,'y':0,'z':0}),3);p.update(p,.1)
a=[[p.list[i][k] for k in ['x','y','z','life','angle','scale']] for i in range(1,4)]
for _ in range(120):p.update(p,0)
assert a==[[p.list[i][k] for k in ['x','y','z','life','angle','scale']] for i in range(1,4)]
report={'result':'PASS','sourceFrames':len(steps),'scalarChecks':checks,'scope':'frozen spawnSprite/puff/burst/updateSprites random order, position, rotation, shrink/lifetime, paused stability; no GPU claim'}
(root/'docs/migration/sprite-particles-model-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report))
