"""Check native material cutout/blend selection against every frozen scene export."""
import json
from collections import defaultdict
from lupa.lua54 import LuaRuntime
from pathlib import Path
from xml.etree import ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
scenes=[('Store','validation/store/source-scene.json')]
scenes += [(f'Echo{i}',f'validation/echo/source-level-{i}.json') for i in range(1,7)]
scenes += [('Chapter1'+s.title(),f'validation/chapter1/source-{s}.json') for s in ['meeting','morning']]
scenes += [(f'Ch1Echo{a}{i}',f'validation/ch1-echo/source-{a}-{i}.json') for a in ['same','late','done'] for i in range(1,6)]
counts={'opaque':0,'cutout':0,'blend':0,'add':0}
receiver_checks=0
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path='+json.dumps(str(ROOT/'scripts/?.lua'),ensure_ascii=False)+'..";"..package.path')
renderer=lua.eval("require('render.StoreRenderer')")[0]
select=renderer.sourceMaterial
for namespace,path in scenes:
 data=json.loads((ROOT/path).read_text());usage=defaultdict(set)
 for n in data['nodes']:
  if n['type']=='Mesh':
   for mid in n['materials']:usage[mid].add(n['receiveShadow'])
 view=lua.table_from({'materials':lua.table(),'noReceiveMaterials':lua.table()})
 for m in data['materials']:
  native=ET.parse(ROOT/'assets/Materials'/namespace/('%03d.xml'%m['id'])).getroot()
  params={p.attrib['name']:p.attrib['value'] for p in native.findall('parameter')}
  assert float(params['alpha_cutoff'])==m['alphaTest']
  assert float(params['tint'].split()[3])==m['opacity']
  unlit=m['type'] in ['MeshBasicMaterial','SpriteMaterial','LineBasicMaterial','PointsMaterial']
  category='cutout' if m['alphaTest']>0 else ('add' if m['blending']==2 else 'blend') if m['transparent'] else 'opaque'
  suffix={'cutout':'Cutout','blend':'Blend','add':'Add','opaque':''}[category]
  shader='Store'+('Unlit' if unlit else 'Lit')+suffix+'.shader'
  view.materials[m['id']]=str(ROOT/'assets/Materials'/namespace/('%03d.xml'%m['id']))
  if not unlit and usage[m['id']]=={False,True}:view.noReceiveMaterials[m['id']]=str(ROOT/'assets/Materials'/namespace/('%03d-no-receive.xml'%m['id']))
  if not m['colorWrite']:shader='StoreShadowOnly.shader'
  assert native.find('shadowcull').attrib['value']==('none' if m['side']==2 else 'ccw' if m['side']==1 else 'cw')
  assert native.find('surfaceshader').attrib['name']=='Shaders/BLGL/'+shader,(namespace,m['id'])
  text=(ROOT/'assets/Shaders/BLGL'/shader).read_text()
  if category=='cutout':
   assert 'ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;' in text and 'ALPHA=alpha;' in text
   assert 'blend_mix' not in text and 'blend_add' not in text and 'depth_draw_never' not in text
  counts[category]+=1
 for n in data['nodes']:
  if n['type']!='Mesh':continue
  for mid in n['materials']:
   m=data['materials'][mid-1]
   if m['type'] not in ['MeshToonMaterial','MeshLambertMaterial','MeshStandardMaterial']:continue
   material=ET.parse(select(view,lua.table_from(n),mid)).getroot()
   params={p.attrib['name']:p.attrib['value'] for p in material.findall('parameter')}
   assert float(params['receive_shadow'])==int(n['receiveShadow']),(namespace,n['id'],mid)
   receiver_checks+=1
report={'result':'PASS','scenes':len(scenes),'materials':sum(counts.values()),'categories':counts,'perNodeReceiverChecks':receiver_checks,'checks':['frozen opacity and alpha cutoff','shader category for every material','opaque-depth cutout separated from blended effects','actual Lua material selection versus every frozen node receiveShadow flag','Three PCF opposite-side caster culling','shadow-only material dispatch'],'notCovered':['GPU auxiliary passes','whole game visual similarity']}
(ROOT/'docs/migration/scene-material-test-report.json').write_text(json.dumps(report,indent=2)+chr(10))
print(json.dumps(report,indent=2))
