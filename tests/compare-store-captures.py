"""Regional raw-frame diagnostics, never an aggregate game similarity score."""
import json,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
candidate=sys.argv[1] if len(sys.argv)>1 else 'native-store-lighting-final-reference'
assert candidate.replace('-','').replace('_','').isalnum()
folder=ROOT/'validation/store'
reference=Image.open(folder/'h5-raw.png').convert('RGB')
native=Image.open(folder/(candidate+'.png')).convert('RGB')
assert reference.size==native.size==(1920,1080)
regions={'actor':[1335,400,1455,665],'cold_drinks':[85,375,380,740],
         'front_shelf':[175,740,580,925],'counter_food':[1360,580,1905,870],
         'blinds_and_wall':[440,140,1200,520],'table_and_floor_shadows':[430,520,980,740],
         'lower_floor':[590,880,1330,1035],'outside_foliage':[475,385,1185,520]}
rows=[];sheet=Image.new('RGB',(960,len(regions)*200),(24,24,24));draw=ImageDraw.Draw(sheet)
for i,(name,box) in enumerate(regions.items()):
    a=reference.crop(box);b=native.crop(box)
    delta=np.abs(np.array(a,dtype=float)-np.array(b,dtype=float))
    rows.append({'region':name,'box':box,'meanAbsoluteChannelError_0_255':round(float(delta.mean()),3),
                 'rootMeanSquaredChannelError_0_255':round(float(np.sqrt((delta*delta).mean())),3),
                 'fractionPixelsAnyChannelErrorAbove32':round(float((delta.max(axis=2)>32).mean()),4)})
    heat=Image.fromarray(np.uint8(np.clip(delta*3,0,255)))
    for j,(label,im) in enumerate([('H5 raw',a),('UrhoX raw',b),('absolute error x3',heat)]):
        im.thumbnail((310,170));sheet.paste(im,(j*320,i*200+25))
        draw.text((j*320+3,i*200+5),name+' / '+label,fill=(235,235,235))
report={'reference':'validation/store/h5-raw.png','candidate':'validation/store/'+candidate+'.png',
        'scope':'Fixed raw camera/frame only; H5 final post/UI and full gameplay are NOT covered.',
        'visualAccepted':False,'similarity':None,'aggregateScore':None,
        'metricsMeaning':'8-bit pixel differences by region; not a percentage similarity or acceptance threshold.',
        'regions':rows}
(ROOT/'docs/migration/store-lighting-comparison.json').write_text(json.dumps(report,indent=2)+chr(10))
sheet.save(folder/'lighting-regions.png')
print(json.dumps(report,indent=2))
