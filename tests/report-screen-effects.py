"""Measure live native event effects, freeze stability and encoded final flash mix."""
from pathlib import Path
from PIL import Image,ImageCms
import io,json,re,numpy as np
root=Path(__file__).resolve().parents[1];base=root/'validation/effects'
receipt=json.loads((base/'native/receipt.json').read_text());names=list(receipt['samples'])
def rgb(name):
 im=Image.open(base/'native'/f'{name}.png')
 if im.info.get('icc_profile'):
  im=ImageCms.profileToProfile(im,ImageCms.ImageCmsProfile(io.BytesIO(im.info['icc_profile'])),ImageCms.createProfile('sRGB'),outputMode='RGB')
 return np.array(im.convert('RGB'))
rows=[];images={}
for case in ['idle','flash','shake','settled']:
 selected=[n for n in names if f'_{case}_' in n];assert len(selected)==2
 selected.sort(key=lambda n:int(n.split('_')[-1]));a,b=map(rgb,selected);images[case]=a
 changed=int(np.any(a!=b,axis=2).sum());assert changed==0,(case,changed)
 rows.append({'case':case,'size':[a.shape[1],a.shape[0]],'firstVs24PausedFramesChangedPixels':changed})
a=images['idle'].astype(float);b=images['flash'].astype(float)
f=.6*.0005**(1/60)
expected=a*(1-f)+np.array([.98,.95,.9])*255*f
delta=abs(b-expected)
shake=int(np.any(images['idle']!=images['shake'],axis=2).sum());assert shake>100
settledDelta=abs(images['idle'].astype(float)-images['settled'])
report={'result':'PASS','sessionId':receipt['sessionId'],'reloadId':receipt['reloadId'],'runtimePid':receipt['runtimePid'],
 'rows':rows,'shakeChangedPixelsVsIdle':shake,'settledVsIdleMaxDelta255':float(settledDelta.max()),
 'flashAmountAfterOne60HzFrame':f,'flashMathMAE255':float(delta.mean()),'flashMathP99Delta255':float(np.percentile(delta,99)),
 'comparisonSpace':'sRGB after screenshot ICC conversion; no resizing',
 'scope':'Native event fixture stability and single-pass flash arithmetic; source full-scene image parity, live event timing and gameplay route checked separately; NOT 95% visual acceptance.'}
(root/'docs/migration/screen-effects-native-report.json').write_text(json.dumps(report,indent=2)+chr(10))
print(json.dumps(report,indent=2))
