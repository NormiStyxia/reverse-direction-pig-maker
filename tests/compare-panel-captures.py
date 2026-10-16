"""Registered UI-only comparisons; deliberately no full-frame similarity score."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageChops,ImageDraw
ROOT=Path(__file__).resolve().parents[1];folder=ROOT/'validation/panels'
regions={'header':(1000,60,1895,135),'content':(1000,145,1895,895),'composer':(1000,905,1895,990)}
reports=[]
for fixture in range(1,7):
    source=Image.open(folder/f'h5-fixture-{fixture}.png').convert('RGB')
    native=Image.open(folder/f'native-fixture-{fixture}.png').convert('RGB')
    assert source.size==native.size==(1920,1080)
    panel=(995,55,1900,990);w,h=panel[2]-panel[0],panel[3]-panel[1]
    canvas=Image.new('RGB',(w*3,h+24),'#302e37');draw=ImageDraw.Draw(canvas)
    diff=ImageChops.difference(source,native).point(lambda v:min(255,v*4))
    for i,(label,im) in enumerate([('Frozen H5',source),('Native UrhoX NVG',native),('Absolute RGB difference x4',diff)]):
        draw.text((i*w+8,5),label,fill='white');canvas.paste(im.crop(panel),(i*w,24))
    canvas.save(folder/f'comparison-{fixture}.png')
    values={}
    for name,rect in regions.items():
        a=np.asarray(source.crop(rect),dtype=float);b=np.asarray(native.crop(rect),dtype=float)
        delta=np.abs(a-b)
        values[name]={'rect':rect,'meanAbsoluteChannelError0To255':round(float(delta.mean()),4),
                      'pixelsWithChannelDifferenceOver24':int(np.sum(np.max(delta,axis=2)>24)),
                      'pixelCount':int(delta.shape[0]*delta.shape[1])}
    reports.append({'fixture':fixture,'comparison':f'validation/panels/comparison-{fixture}.png','regions':values})
report={'date':'2026-10-16','method':'Aligned raw RGB absolute differences; no registration, rescale, blur or tolerance alignment; screenshot title bar cropped only',
        'scope':'Six isolated UI fixtures on a solid backdrop, 1920x1080 DPR1; not actual story rendering',
        'accepted':False,'similarityPercentage':None,
        'limitations':['Solid empty background cannot be used to claim 95% parity','Text weight and baseline differ','Avatars still alias under strong minification','Lock clock differs in baseline and tracking','Scene frost, animated integration and full gameplay not tested'],
        'fixtures':reports}
(ROOT/'docs/migration/story-panel-comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Created 6 three-column UI comparisons and per-region difference records; visual acceptance NOT ACCEPTED')
