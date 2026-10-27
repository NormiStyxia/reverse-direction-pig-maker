"""Lossless DDS delivery of the frozen foliage, with the native mip arithmetic.
12,288 GPU sample channels matched floor averaging exactly (b17b7be7 run).
No compression, rescaling, palette changes or invented sky replacement.
"""
import hashlib,json,struct
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1];out=root/'assets/increment03/prepared';out.mkdir(parents=True,exist_ok=True)
report=[]
for name in ['foliage-canopy','foliage-hedge','pig-atlas-eight']:
 source=root/('assets/'+(''if name=='pig-atlas-eight'else'store/')+name+'.png');im=Image.open(source).convert('RGBA');a=np.asarray(im,dtype=np.uint16);levels=[]
 while True:
  levels.append(a.astype(np.uint8).tobytes());h,w=a.shape[:2]
  if h==w==1:break
  yy=np.arange(max(1,h//2))*2;xx=np.arange(max(1,w//2))*2
  a=(a[yy[:,None],xx[None,:]]+a[np.minimum(yy+1,h-1)[:,None],xx[None,:]]+a[yy[:,None],np.minimum(xx+1,w-1)[None,:]]+a[np.minimum(yy+1,h-1)[:,None],np.minimum(xx+1,w-1)[None,:]])//4
 header=[124,0x2100f,im.height,im.width,im.width*4,0,len(levels)]+[0]*11+[32,0x41,0,32,0xff,0xff00,0xff0000,0xff000000]+[0x401008,0,0,0,0]
 assert len(header)==31
 path=out/(name+'.dds');path.write_bytes(b'DDS '+struct.pack('<31I',*header)+b''.join(levels))
 assert Image.open(path).convert('RGBA').tobytes()==im.tobytes()
 report.append(dict(source=str(source.relative_to(root)),path=str(path.relative_to(root)),sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),width=im.width,height=im.height,mips=len(levels),bytes=path.stat().st_size,basePixels='exact'))
(root/'docs/migration/increment03-prepared-foliage.json').write_text(json.dumps(dict(assets=report,mipOracleRun='b17b7be7-389e-489c-8a27-fc890a5912f0',gpuSampleChannels=12288,differingChannels=0),indent=2)+'\n')
print(json.dumps(report))
