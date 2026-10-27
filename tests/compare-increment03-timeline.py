"""Whole-frame numeric comparison; not a substitute for visual/interaction review."""
import json
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1];folder=root/'validation/increment03/timeline-aligned'
def average(a):
 p=np.pad(a,((1,0),(1,0),(0,0))).cumsum(0).cumsum(1)
 return(p[7:,7:]-p[:-7,7:]-p[7:,:-7]+p[:-7,:-7])/49
rows=[]
for name,width,height,run in [('timeline-aligned03',1280,720,'b8986d85-8476-4d04-80ba-042d9d94211f'),('timeline-wide01',1200,540,'25912732-2cc8-4f86-9a60-6eaa3f8f6b94')]:
 image=Image.open(root/f'validation/increment03/native/{name}-window-1.png').convert('RGB')
 assert image.size==(width,height+32),'Unexpected native window chrome; do not silently resize'
 image=image.crop((0,32,width,height+32));image.save(folder/f'{name}-client.png')
 a=np.asarray(Image.open(folder/f'h5-{width}-{height}.png').convert('RGB'),float);b=np.asarray(image,float)
 u,v=average(a),average(b);aa=(average(a*a)-u*u)*49/48;bb=(average(b*b)-v*v)*49/48;ab=(average(a*b)-u*v)*49/48
 metric=((2*u*v+6.5025)*(2*ab+58.5225)/((u*u+v*v+6.5025)*(aa+bb+58.5225))).mean()
 rows.append(dict(run=run,width=width,height=height,ssim=float(metric),meanAbsoluteRgbError=float(np.abs(a-b).mean()),source=str((folder/f'h5-{width}-{height}.png').relative_to(root)),native=str((folder/f'{name}-client.png').relative_to(root))))
report=dict(method='7x7 uniform valid window; sample covariance 49/48; RGB mean; data range 255',time=10,rows=rows,verdict='NOT_ACCEPTED',limitations=['Snapshots precede final label paint-order and mobile button correction','Not all scenes; not a perceptual percentage','Frozen page fixture explicitly unlocks nodes, not natural gameplay'])
(root/'docs/migration/increment03-timeline-visual-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
