"""Import build-time Three scene data into native Lua meshes + SurfaceShader materials.

No source JS, browser runtime, or screenshot is used by the game.
Coordinate conversion lives in StoreRenderer; exported data stays in source coordinates.
"""
import base64,hashlib,json,math,shutil
from collections import defaultdict
from pathlib import Path
from xml.etree.ElementTree import Element,SubElement,tostring
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'validation/store/source-scene.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def lua(v):
    if v is None:return 'nil'
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
    if isinstance(v,(int,float)):
        assert math.isfinite(v)
        return repr(v)
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items() if x is not None)+'}'
def import_scene(data=DATA, namespace='Store', texture_namespace='store', data_name='StoreScene', report_name='store-export-report'):
    s=json.loads(data.read_text());texdir=ROOT/'assets'/texture_namespace/'generated';texdir.mkdir(parents=True,exist_ok=True)
    matdir=ROOT/'assets/Materials'/namespace;matdir.mkdir(parents=True,exist_ok=True)
    texturepaths={0:texture_namespace+'/generated/white.png'}
    from PIL import Image
    Image.new('RGBA',(1,1),(255,255,255,255)).save(ROOT/'assets'/texturepaths[0])
    for t in s['textures']:
        png=base64.b64decode(t.pop('png'))
        # Use frozen original for file textures, exact canvas PNG for procedural art.
        if t['source']:
            rel=t['source'].removeprefix('/assets/');source=ROOT/'reference/h5-source/assets'/rel
            dest=ROOT/'assets'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
            if not dest.exists():shutil.copyfile(source,dest)
            assert sha(dest)==sha(source),rel
        else:
            rel=texture_namespace+'/generated/'+hashlib.sha256(png).hexdigest()[:24]+'.png'
            (ROOT/'assets'/rel).write_bytes(png)
        texturepaths[t['id']]=rel;t['path']=rel
    s['whitePath']=texturepaths[0]
    textures={t['id']:t for t in s['textures']}
    def uv(tid):
        if not tid:return [1,1,0,0]
        t=textures[tid];assert t['rotation']==0 and t['center']==[0,0]
        x,y=t['repeat'];ox,oy=t['offset']
        return [x,y,ox,1-y-oy] if t['flipY'] else [x,-y,ox,y+oy]
    receivers=defaultdict(set)
    for n in s['nodes']:
        if n['type']=='Mesh':
            for mid in n['materials']:receivers[mid].add(bool(n['receiveShadow']))
    for m in s['materials']:
        kind=m['type'];blend=m['transparent'] and m['alphaTest']==0
        unlit=kind in ['MeshBasicMaterial','SpriteMaterial','LineBasicMaterial','PointsMaterial']
        shader='Store'+('Unlit' if unlit else 'Lit')+('Add' if blend and m['blending']==2 else 'Blend' if blend else 'Cutout' if m['alphaTest']>0 else '')
        if not m['colorWrite']:shader='StoreShadowOnly'
        no_receive=not unlit and receivers[m['id']]=={False}
        e=Element('material');SubElement(e,'surfaceshader',name='Shaders/BLGL/'+shader+'.shader')
        for key,sampler in [('map','paint_map'),('alphaMap','alpha_map'),('emissiveMap','emit_map')]:
            SubElement(e,'surfacetexture',name=sampler,texture=texturepaths[m[key]])
        key=m['programKey'];night=next((i for i,k in enumerate(['sky','tree','hedge','ground'],1) if key.endswith('|night-'+k)),0)
        wind=float(key.split('|')[0].removeprefix('store-wind-')) if key.startswith('store-wind-') else 0
        params={'tint':m['color']+[m['opacity']],'map_uv':uv(m['map']),'alpha_uv':uv(m['alphaMap']),'emit_uv':uv(m['emissiveMap']),
            'map_srgb':int(bool(m['map'] and textures[m['map']]['colorSpace']=='srgb')),
            'emit_srgb':int(bool(m['emissiveMap'] and textures[m['emissiveMap']]['colorSpace']=='srgb')),
            'alpha_cutoff':m['alphaTest'],'emissive_color':[v*m['emissiveIntensity'] for v in m['emissive']],
            'is_toon':int(kind=='MeshToonMaterial'),'night_kind':night,'wind_amp':wind,
            'shadow_step':.08,'paper_figure':int(key=='paper-figure')}
        if not unlit:params['receive_shadow']=0 if no_receive else 1
        if s.get('chapter') and m['gradientMap']:
            gradient=Image.open(ROOT/'assets'/texturepaths[m['gradientMap']]).convert('RGBA')
            assert gradient.size==(3,1)
            params['toon_bands']=[gradient.getpixel((i,0))[0]/255 for i in range(3)]
        for name,value in params.items():SubElement(e,'parameter',name=name,value=' '.join(str(x) for x in value) if isinstance(value,list) else str(value))
        # DoubleSide=2; BackSide=1. Exact handedness tested separately.
        SubElement(e,'cull',value='none' if m['side']==2 else 'cw' if m['side']==1 else 'ccw')
        # Frozen Three PCF shadow map defaults to the opposite surface side.
        # This is essential for the single-sided leaf mask lit from its back.
        SubElement(e,'shadowcull',value='none' if m['side']==2 else 'ccw' if m['side']==1 else 'cw')
        (matdir/('%03d.xml'%m['id'])).write_text(tostring(e,encoding='unicode')+'\n')
        m['path']='Materials/'+namespace+'/%03d.xml'%m['id'];m.pop('customShader')
        if not unlit and receivers[m['id']]=={False,True}:
            next(p for p in e.findall('parameter') if p.get('name')=='receive_shadow').set('value','0')
            filename='%03d-no-receive.xml'%m['id']
            (matdir/filename).write_text(tostring(e,encoding='unicode')+'\n')
            m['noReceivePath']='Materials/'+namespace+'/'+filename
    # Scene geometry is deterministic; source objects with shared geometry retain sharing.
    out=ROOT/'scripts/game/data'/(data_name+'.lua')
    out.write_text('-- Generated by tests/import-store.py; frozen source coordinates.\nreturn '+lua(s)+'\n')
    report={'sourceCommit':'6a316e84907d8bc94ab59f20796685172b3535b5','sourceExportSha256':sha(data),
        'sourceFiles':{p:sha(ROOT/'reference/h5-source'/p) for p in ['src/store.js','src/rewind-levels.js','src/store-props.js','src/night.js','src/art.js','src/normi.js','src/pig.js','src/ch1-scenes.js','src/ch1-office.js','src/ch1-art.js','src/meeting.js','config/store-tuning.json','config/ch1-tuning.json']},
        'nodes':len(s['nodes']),'geometries':len(s['geometries']),'materials':len(s['materials']),'textures':len(s['textures']),
        'instances':sum(len(n.get('instances',[])) for n in s['nodes']),'seed':s['seed'],'nativeDataSha256':sha(out),
        'visualAcceptance':False,'notes':['Exact mesh attributes, instance transforms/colors, texture pixels and hierarchy exported.',
            'Source custom night/wind/material behaviors require explicit native shaders; export alone does not establish parity.']}
    (ROOT/'docs/migration'/(report_name+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['nodes','geometries','materials','textures','instances']})+' — imported')
if __name__=='__main__':import_scene()
