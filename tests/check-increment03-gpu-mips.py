"""Compare native GPU readback samples with candidate offline mip arithmetic."""
import json,sys
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1]
run=sys.argv[1];log=root/'.maker/validation-evidence'/run/'runtime.log'
rows={}
for line in log.read_text().splitlines():
 text=json.loads(line)['text'];tag='INCREMENT03_TEXTURE_MIP: '
 if tag in text:
  d=json.loads(text.split(tag,1)[1]);rows[d['path']]=d
out=root/'validation/increment03/texture-mips';out.mkdir(parents=True,exist_ok=True)
(out/(run+'.json')).write_text(json.dumps(list(rows.values()),indent=2)+'\n')
for method in ['floor','round']:
 checks=diff=0;largest=0
 for name in ['foliage-canopy','foliage-hedge','pig-atlas-eight']:
  if f'increment03-{name}-mip00.png' not in rows:continue
  a=np.asarray(Image.open(root/('assets/'+(''if name=='pig-atlas-eight'else'store/')+name+'.png')).convert('RGBA'),dtype=np.uint16)
  for level in range(12):
   d=rows[f'increment03-{name}-mip{level:02}.png'];assert a.shape[:2]==(d['height'],d['width'])
   for x,y,*value in d['pixels']:
    delta=np.abs(a[y,x].astype(int)-np.array(value));checks+=4;diff+=int(np.count_nonzero(delta));largest=max(largest,int(delta.max()))
   h,w=a.shape[:2]
   if h==w==1:break
   yy=np.arange(max(1,h//2))*2;xx=np.arange(max(1,w//2))*2
   a=(a[yy[:,None],xx[None,:]]+a[np.minimum(yy+1,h-1)[:,None],xx[None,:]]+a[yy[:,None],np.minimum(xx+1,w-1)[None,:]]+a[np.minimum(yy+1,h-1)[:,None],np.minimum(xx+1,w-1)[None,:]]+(2 if method=='round' else 0))//4
 print(json.dumps(dict(method=method,channels=checks,differing=diff,maxByteError=largest)))
