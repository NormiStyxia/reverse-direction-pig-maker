"""Aligned isolated chapter panels; never turn a mostly empty frame into a similarity %."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageChops,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
cases=[(8,'question'),(11,'done-answer'),(13,'zhou-recall'),(16,'morning-done')]
reports=[];panel=(995,55,1900,990)
regions={'header':(1000,60,1895,135),'content':(1000,145,1895,895),'composer':(1000,905,1895,990)}
for fixture,name in cases:
    source=Image.open(ROOT/f'validation/panels/h5-fixture-{fixture}.png').convert('RGB')
    native=Image.open(ROOT/f'validation/chapter1/native-{name}.png').convert('RGB')
    assert source.size==native.size==(1920,1080)
    w,h=panel[2]-panel[0],panel[3]-panel[1]
    diff=ImageChops.difference(source,native).point(lambda v:min(255,v*4))
    canvas=Image.new('RGB',(w*3,h+24),'#302e37');draw=ImageDraw.Draw(canvas)
    for i,(label,im) in enumerate([('Frozen H5',source),('Native UrhoX NVG',native),('Absolute RGB difference x4',diff)]):
        draw.text((i*w+8,5),label,fill='white');canvas.paste(im.crop(panel),(i*w,24))
    path=f'validation/chapter1/comparison-{name}.png';canvas.save(ROOT/path)
    values={}
    for key,rect in regions.items():
        delta=np.abs(np.asarray(source.crop(rect),dtype=float)-np.asarray(native.crop(rect),dtype=float))
        values[key]={'rect':rect,'meanAbsoluteChannelError0To255':round(float(delta.mean()),4),
                     'pixelsWithChannelDifferenceOver24':int(np.sum(np.max(delta,axis=2)>24)),'pixelCount':int(delta.shape[0]*delta.shape[1])}
    reports.append({'fixture':fixture,'name':name,'comparison':path,'regions':values})
report={'date':'2026-10-16','scope':'Four isolated chapter1 NVG panels; actual model snapshots, not native story scenes',
        'method':'Same viewport/DPR, only window chrome cropped; no alignment, scaling or blur',
        'accepted':False,'similarityPercentage':None,'fixtures':reports,
        'knownDifferences':['Font weight/baseline','Avatar minification aliasing'],
        'notCovered':['Scene frost blur','Native meeting/office scene','Timing of live rendered story','Whole-game 95% acceptance']}
(ROOT/'docs/migration/chapter1-panel-comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Recorded 4 chapter1 panel comparisons; visual acceptance NOT ACCEPTED')
