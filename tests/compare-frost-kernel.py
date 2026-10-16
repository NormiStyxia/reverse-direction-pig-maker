"""Frozen post.js blur math on native base. NOT an H5 scene similarity score."""
import json,re
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
R=Path(__file__).resolve().parents[1]
a=np.array(Image.open(R/'validation/store/native-frost-manual-off.png').convert('RGB'),dtype=np.float64)/255
native=np.array(Image.open(R/'validation/store/native-frost-manual-on.png').convert('RGB'),dtype=np.float64)/255
assert a.shape==native.shape
h,w=a.shape[:2];qw,qh=int(w/4+.5),int(h/4+.5)
y=np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)
A=2.43*y-2.51;B=.59*y-.03;C=.14*y
linear=(-B-np.sqrt(B*B-4*A*C))/(2*A)
source=(R/'reference/h5-source/src/post.js').read_text()
frag=source.split('const BLUR =')[1].split(chr(96))[1]
center=float(re.search(r'rgb \* ([\d.]+)',frag)[1]);samples=[(0,center)]
for sign,offset,weight in re.findall(r'vUv ([+-]) dir \* ([\d.]+)\)\.rgb \* ([\d.]+)',frag):samples.append((float(offset)*(1 if sign=='+' else -1),float(weight)))
assert len(samples)==5
def sample(im,x,y):
 coords=np.array(np.broadcast_arrays(y,x))
 return np.stack([map_coordinates(im[:,:,c],coords,order=1,mode='nearest',prefilter=False) for c in range(3)],axis=2)
x=(np.arange(qw)[None,:]+.5)/qw;y=(np.arange(qh)[:,None]+.5)/qh
result=linear
for scale in [1.2,2.4]:
 for axis in [0,1]:
  ih,iw=result.shape[:2];out=np.zeros((qh,qw,3))
  for offset,weight in samples:
   u=x+(offset*scale/qw if axis==0 else 0);v=y+(offset*scale/qh if axis==1 else 0)
   out+=weight*sample(result,u*iw-.5,v*ih-.5)
  result=out.astype(np.float16).astype(float)
x=(np.arange(w)[None,:]+.5)/w;y=(np.arange(h)[:,None]+.5)/h
blur=sample(result,x*qw-.5,y*qh-.5)
f=np.clip((x-.48)/.08,0,1);mask=(f*f*(3-2*f))[:,:,None]
c=linear*(1-mask)+blur*mask
c=np.clip(c*(2.51*c+.03)/(c*(2.43*c+.59)+.14),0,1)
pred=np.where(c<=.0031308,c*12.92,1.055*c**(1/2.4)-.055)
Image.fromarray(np.uint8(np.clip(pred*255+.5,0,255))).save(R/'validation/post/cpu-frost-from-native.png')
regions={'clear_left':[200,400,1000,1250],'actor':[1000,650,1230,1100],'blur_wall_no_ui':[2600,350,2780,850],'blur_counter_no_ui':[2100,1100,2550,1250]};metrics={}
for name,(x0,y0,x1,y1) in regions.items():
 d=np.abs(pred[y0:y1,x0:x1]-native[y0:y1,x0:x1])*255
 metrics[name]={'rect':[x0,y0,x1,y1],'mae255':float(d.mean()),'p99':float(np.percentile(d,99))}
report={'scope':'frozen H5 blur math on reconstructed native input, NOT full source scene comparison','size':[w,h],'quarterSize':[qw,qh],'samples':samples,'regions':metrics,'limitations':['8-bit input quantization and unknown HDR at clipped highlights','native base differences across render paths','UI excluded by manually chosen ROIs; reference is not an H5 scene screenshot'],'visualAcceptance':False}
(R/'docs/migration/frost-kernel-comparison.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
