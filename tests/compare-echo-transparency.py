"""Local feature measurements; never report a whole-game similarity percentage."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
source=root/'validation/transparency/h5-linear-alpha-source.png'
native=root/'validation/echo/native-rain-fixed.png'
a=np.asarray(Image.open(source).convert('RGB'));b=np.asarray(Image.open(native).convert('RGB'))
assert a.shape==b.shape==(1080,1920,3)
regions={'exitInterior':[820,185,890,315],'rainAgainstSky':[1050,0,1900,300]}
rows=[];sheet=Image.new('RGB',(1280,500),(24,24,24));draw=ImageDraw.Draw(sheet)
for i,(name,(x,y,X,Y)) in enumerate(regions.items()):
    u=a[y:Y,x:X];v=b[y:Y,x:X];e=np.abs(u.astype(float)-v.astype(float))
    row={'region':name,'box':[x,y,X,Y],'meanAbsoluteChannelError_0_255':float(e.mean()),'p95AbsoluteChannelError_0_255':float(np.percentile(e,95))}
    if name=='rainAgainstSky':
        m=u.min(2)>80;n=v.min(2)>80
        row.update(sourceLinePixels=int(m.sum()),nativeLinePixels=int(n.sum()),lineMaskIntersectionOverUnion=float((m&n).sum()/(m|n).sum()),maskRule='min(R,G,B)>80 within empty-sky ROI')
    rows.append(row)
    for j,(label,data) in enumerate([('H5 linear target',u),('UrhoX native',v)]):
        im=Image.fromarray(data);im.thumbnail((630,215));sheet.paste(im,(j*640,i*250+28));draw.text((j*640+4,i*250+4),name+' / '+label,fill='white')
samples=[]
for name in ['zero','source','point2','one']:
    source_im=Image.open(root/f'validation/transparency/h5-linear-alpha-{name}.png').convert('RGB')
    native_im=Image.open(root/f'validation/echo/native-alpha-{name}-before.png').convert('RGB')
    xy=(850,230);u=source_im.getpixel(xy);v=native_im.getpixel(xy)
    samples.append({'opacityCase':name,'pixel':xy,'h5Linear':u,'native':v,'maxChannelError':max(abs(c-d) for c,d in zip(u,v))})
report={'scope':'Echo 6, fixed time 5, exact camera 1920x1080; isolated linear blend and rain checks only',
        'reference':str(source.relative_to(root)),'candidate':str(native.relative_to(root)),
        'referenceCorrection':'The original direct-to-canvas ACES captures blend after tone mapping. Production H5 uses linear HalfFloat main target then post.js FINAL. Direct captures cannot validate production transparency.',
        'productionMaterialChanged':False,'opacitySamples':samples,'regions':rows,
        'wholeGameSimilarity':None,'visualAccepted':False,
        'limitations':['Source final grading, vignette, DOF, outlines and world are excluded','Lighting/shadows and background still differ','One fixed view does not establish frame-rate or all-level visual parity']}
(root/'docs/migration/echo-transparency-comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
sheet.save(root/'validation/transparency/regions.png')
print(json.dumps(report,ensure_ascii=False,indent=2))
