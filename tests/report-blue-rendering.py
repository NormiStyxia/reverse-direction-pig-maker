"""Audit already captured native images; no resizing in numeric comparisons."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1];out=root/'validation/blue/native-final'
receipt=json.loads((out/'receipt.json').read_text());names=list(receipt['samples'])
assert len(names)==10
sizes={tuple(r['captureSize']) for r in receipt['samples'].values()};assert sizes=={(1920,1080)},sizes
images=[np.asarray(Image.open(out/(n+'.png')).convert('RGB')).astype(int) for n in names]
original,blue,masked=images[3:6]
changed=np.any(blue!=masked,axis=2);count=int(changed.sum());assert count>20000
assert np.array_equal(original[changed],masked[changed]),'Masked objects must retain their original pixels'
hidden=np.abs(images[6]-images[7]);assert not hidden.any(),'Fully occluded objects punch through the floor'
sheet=Image.new('RGB',(960,5*296),'#161616');draw=ImageDraw.Draw(sheet)
labels=['store blue','store sweep t=3.1','store original','echo original','echo blue: mask off','echo blue: mask on','occluded: mask off','occluded: mask on','chapter original','chapter blue']
for i,n in enumerate(names):
    im=Image.open(out/(n+'.png')).convert('RGB');im.thumbnail((480,270));x=i%2*480;y=i//2*296
    sheet.paste(im,(x,y+24));draw.text((x+8,y+5),labels[i],fill='white')
sheet.save(out/'contact-sheet.png')
report={'result':'PASS_SCOPED','session':receipt['sessionId'],'reload':receipt['reloadId'],'pid':receipt['runtimePid'],'contentSize':[1920,1080],
 'goldPreservedPixels':count,'maxDifferenceFromOriginalOnPreservedPixels':0,'fullyOccludedChangedPixels':0,
 'nativeScenes':['store','prologue echo 5','chapter1 echo same 1'],'sourceSelectionScenes':21,'sourceTimingFrames':8361,
 'screenshots':'validation/blue/native-final/','limits':['synthetic fixed poses, not a live full-game route','source-like 0.00002 depth tolerance: near-surface fixture retained a 188-pixel sliver; source edge parity pending','no 95% visual similarity claim','no all-device performance or adaptation acceptance']}
(root/'docs/migration/blue-rendering-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report,indent=2))
