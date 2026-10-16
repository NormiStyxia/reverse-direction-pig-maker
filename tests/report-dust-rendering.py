"""Compare exact-size native/source dust fixtures; exclude black background inflation."""
from pathlib import Path
from PIL import Image,ImageCms,ImageDraw
from scipy.ndimage import label,center_of_mass
import json,io,numpy as np
root=Path(__file__).resolve().parents[1];base=root/'validation/dust'
receipt=json.loads((base/'native/receipt.json').read_text());names=list(receipt['samples'])
def rgb(p):
 im=Image.open(p)
 if im.info.get('icc_profile'):
  im=ImageCms.profileToProfile(im,ImageCms.ImageCmsProfile(io.BytesIO(im.info['icc_profile'])),ImageCms.createProfile('sRGB'),outputMode='RGB')
 return np.array(im.convert('RGB'))
rows=[];crops=[]
for i in range(1,6):
 a=rgb(base/f'source/source-{i}.png');b=rgb(base/'native'/f'{names[i-1]}.png');assert a.shape==b.shape
 am=a.max(2)>10;bm=b.max(2)>10;union=am|bm;both=am&bm
 la,na=label(am);lb,nb=label(bm)
 centersA=np.array(center_of_mass(am,la,range(1,na+1)));centersB=np.array(center_of_mass(bm,lb,range(1,nb+1)))
 centersError=np.sqrt(((centersA[:,None,:]-centersB[None,:,:])**2).sum(2)).min(1)
 rows.append({'sample':i,'size':[a.shape[1],a.shape[0]],'sourcePixels':int(am.sum()),'nativePixels':int(bm.sum()),
  'coverageIoU':float(both.sum()/union.sum()),'unionPixelMAE255':float(abs(a.astype(float)-b)[union].mean()),
  'sourceComponents':na,'nativeComponents':nb,'maxNearestCenterDistancePx':float(centersError.max())})
 # Exact pixel crops enlarged for inspection, separate from original evidence.
 if i in [1,2,3,4]:
  canvas=Image.new('RGB',(480,190),'#303030');draw=ImageDraw.Draw(canvas);draw.text((5,4),f'{i}: source / native, 4x nearest pixel crops',fill='white')
  for j,(y,x) in enumerate(centersA[:4]):
   x,y=int(x),int(y);box=(max(0,x-12),max(0,y-12),min(a.shape[1],x+12),min(a.shape[0],y+12))
   for row,im in enumerate([a,b]):
    crop=Image.fromarray(im).crop(box);crop=crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST)
    canvas.paste(crop,(j*120,22+row*80))
  crops.append(canvas)
a=rgb(base/'native'/f'{names[3]}.png');b=rgb(base/'native'/f'{names[4]}.png')
report={'sessionId':receipt['sessionId'],'reloadId':receipt['reloadId'],'runtimePid':receipt['runtimePid'],'rows':rows,
 'movedFirstFrameVsStableChangedPixels':int(np.any(a!=b,axis=2).sum()),
 'nearAlphaUniqueValues':np.unique(rgb(base/'native'/f'{names[0]}.png')[:,:,0]).tolist(),
 'originalDotMatchesFrozenCanvas':bool(np.array_equal(np.array(Image.open(base/'source/paintDot.png')),np.array(Image.open(root/'assets/store/generated/a28d7137a25d50ce6d784d96.png')))),
 'scope':'Isolated dust only. Source unmodified buildDust/paintDot/Three; native app-owned geometry/SurfaceShader. ICC converted to sRGB where present. No rescaling for metrics. NOT game visual acceptance.'}
(root/'docs/migration/dust-rendering-report.json').write_text(json.dumps(report,indent=2)+'\n')
sheet=Image.new('RGB',(480,len(crops)*190));[sheet.paste(im,(0,i*190)) for i,im in enumerate(crops)];sheet.save(base/'particle-crops.png')
print(json.dumps(report,indent=2))
