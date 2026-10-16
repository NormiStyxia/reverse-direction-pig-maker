"""Compare isolated source/native shadow-only caster contributions, no aggregate score."""
import json
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'validation/store'
def read(prefix,mode):return np.array(Image.open(folder/(prefix+mode+'.png')).convert('RGB')).astype(float)
regions={'leaf_left_wall':[235,145,435,375],'leaf_floor':[585,740,815,860],
         'roof_right_wall':[1710,145,1910,490],'left_wall_mismatch':[0,145,210,740]}
source={m:read('h5-shadow-',m) for m in ['none','roof','leaves','both']}
native={m:read('native-shadow-',m) for m in ['none','roof','leaves','both']}
assert all(a.shape==(1080,1920,3) for a in [*source.values(),*native.values()])
assert np.array_equal(native['both'],read('native-shadow-','restored')),'Diagnostic round trip changed the frozen frame'
report={'source':'linear target + source FINAL ACES/sRGB; world bounds and StoreChapter shadow overrides',
 'candidate':'native reload44, projection-based shadow-only SurfaceShader and frozen opposite caster side',
 'visualAccepted':False,'wholeGameSimilarity':None,'exactRoundTrip':True,'regions':{},'casterChangedPixels':{}}
for mode in ['roof','leaves']:
 s=np.abs(source[mode]-source['none']).max(2)>8;n=np.abs(native[mode]-native['none']).max(2)>8
 report['casterChangedPixels'][mode]={'source':int(s.sum()),'native':int(n.sum())}
for name,rect in regions.items():
 x,y,r,b=rect;mode='leaves' if name.startswith('leaf_') else 'roof'
 sm=(np.abs(source[mode]-source['none']).max(2)>8)[y:b,x:r]
 nm=(np.abs(native[mode]-native['none']).max(2)>8)[y:b,x:r]
 union=np.logical_or(sm,nm).sum()
 report['regions'][name]={'rect':rect,'caster':mode,'contributionMaskIoU':float(np.logical_and(sm,nm).sum()/union) if union else None,
 'finalPixelMAE255':float(np.abs(source['both'][y:b,x:r]-native['both'][y:b,x:r]).mean())}
report['limitations']=['Mask metrics compare isolated caster contribution, not all shading or complete scenes.',
 'Side wall shadow boundary, texture filtering and outside grading remain different.',
 'No full post-processing or gameplay acceptance; no average similarity number.']
(ROOT/'docs/migration/store-shadow-comparison.json').write_text(json.dumps(report,indent=2)+chr(10))
sheet=Image.new('RGB',(960,4*210),(24,24,24));draw=ImageDraw.Draw(sheet)
for i,(name,rect) in enumerate(regions.items()):
 for j,(label,a) in enumerate([('source',source['both']),('native',native['both'])]):
  x,y,r,b=rect;im=Image.fromarray(a[y:b,x:r].astype('uint8'));im.thumbnail((460,180));sheet.paste(im,(j*480,i*210+25));draw.text((j*480+3,i*210+5),name+' / '+label,fill=(240,240,240))
sheet.save(folder/'shadow-regions.png');print(json.dumps(report,indent=2))
