"""Same-size frozen Three vs native particle; exclude empty background from metrics."""
from pathlib import Path
from PIL import Image,ImageCms,ImageDraw
import io,json,numpy as np
root=Path(__file__).resolve().parents[1];base=root/'validation/puffs'
receipt=json.loads((base/'native/receipt.json').read_text());names=list(receipt['samples'])
def rgb(p):
 im=Image.open(p)
 if im.info.get('icc_profile'):
  im=ImageCms.profileToProfile(im,ImageCms.ImageCmsProfile(io.BytesIO(im.info['icc_profile'])),ImageCms.createProfile('sRGB'),outputMode='RGB')
 return np.array(im.convert('RGB'))
rows=[];crops=[]
for i in range(1,8):
 a=rgb(base/f'source/source-{i}.png');b=rgb(base/'native'/f'{names[i-1]}.png');assert a.shape==b.shape
 am=a.max(2)>10;bm=b.max(2)>10;union=am|bm;both=am&bm
 d=abs(a.astype(float)-b)
 rows.append({'sample':i,'size':[a.shape[1],a.shape[0]],'sourcePixels':int(am.sum()),'nativePixels':int(bm.sum()),
 'coverageIoU':float(both.sum()/union.sum()) if union.any() else None,'unionRGBMAE255':float(d[union].mean()) if union.any() else 0,
 'interiorRGBMAE255':float(d[both].mean()) if both.any() else 0})
 if union.any():
  y,x=np.where(union);box=(max(0,int(x.min())-8),max(0,int(y.min())-8),int(x.max())+9,int(y.max())+9)
  images=[Image.fromarray(v).crop(box) for v in [a,b]]
  canvas=Image.new('RGB',(640,350),'#303030');draw=ImageDraw.Draw(canvas);draw.text((5,5),f'{i}: frozen source / native (display crops only)',fill='white')
  for j,im in enumerate(images):im.thumbnail((310,310));canvas.paste(im,(j*320+5,30))
  crops.append(canvas)
a=rgb(base/'native'/f'{names[3]}.png');b=rgb(base/'native'/f'{names[4]}.png')
report={'sessionId':receipt['sessionId'],'reloadId':receipt['reloadId'],'runtimePid':receipt['runtimePid'],'rows':rows,
 'movedFirstVsStableChangedPixels':int(np.any(a!=b,axis=2).sum()),
 'scope':'single opaque paper puff, source frozen paintPuff/main.js/Three vs native SurfaceShader; ICC normalized to sRGB, no rescaling for metrics, background excluded; NOT full-game similarity'}
(root/'docs/migration/puff-rendering-report.json').write_text(json.dumps(report,indent=2)+chr(10))
sheet=Image.new('RGB',(640,len(crops)*350));[sheet.paste(im,(0,i*350)) for i,im in enumerate(crops)];sheet.save(base/'comparison.png')
print(json.dumps(report,indent=2))
