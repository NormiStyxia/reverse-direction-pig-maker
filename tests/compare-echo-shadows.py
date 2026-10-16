"""Local fixed-frame shadow metrics; never a whole-game acceptance percentage."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
story=len(sys.argv)>1 and sys.argv[1]=='story'
paths={'source':'validation/transparency/h5-production-alpha-source.png',
       'rectangularZeroBias':'validation/echo/native-shadow-zero-bias.png',
       'final':'validation/echo/native-shadow-final.png'}
if story:
 paths['source']='validation/transparency/h5-story-alpha-source.png'
 paths['final']='validation/echo/native-shadow-cull-final.png'
images={k:np.array(Image.open(ROOT/p).convert('RGB')) for k,p in paths.items()}
assert all(a.shape==(1080,1920,3) for a in images.values())
regions={'pigCast':[1040,613,1140,650],'boxCast':[468,604,540,674]}
report={'scope':'Echo6 t=5, fixed camera, production source light shadow bounds and ACES/sRGB after linear blend; no full post/world/UI',
 'threshold':'RGB mean < 42/255 in explicit floor-only rectangles, excluding actor and crate bodies',
 'images':{k:{'path':p,'sha256':hashlib.sha256((ROOT/p).read_bytes()).hexdigest()} for k,p in paths.items()},'regions':{},
 'wholeGameSimilarity':None,'visualAccepted':False}
for name,rect in regions.items():
 x,y,r,b=rect;s=images['source'][y:b,x:r];sm=s.mean(2)<42
 data={'rect':rect,'sourceShadowPixels':int(sm.sum())}
 for key in ['rectangularZeroBias','final']:
  n=images[key][y:b,x:r];nm=n.mean(2)<42
  data[key]={'maskIoU':float(np.logical_and(sm,nm).sum()/np.logical_or(sm,nm).sum()),
    'mae255':float(np.abs(s.astype(float)-n).mean()),'nativeShadowPixels':int(nm.sum())}
 report['regions'][name]=data
report['entry']='full store-to-echo route, inherited StoreChapter shadow settings' if story else 'direct echo debug entry, world defaults'
report['limitations']=['Box edge mismatch remains (IoU below .95); not hidden behind pig improvement.',
 'Zero-bias baseline isolates rectangular cutout defect, not the earlier missing-floor-shadow state.',
 'Store roof/leaf and per-node receiveShadow are implemented; whole-scene shadow parity remains pending.',
 'Shadow map sampling/filter differs between engines; other levels and moving camera need verification.']
(ROOT/('docs/migration/echo-shadow-story-comparison.json' if story else 'docs/migration/echo-shadow-comparison.json')).write_text(json.dumps(report,indent=2)+chr(10))
print(json.dumps(report['regions'],indent=2))
