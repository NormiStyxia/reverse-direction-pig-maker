"""Lossless runtime delivery of the frozen 4x7 motion atlas, not new artwork.
128px gutters preserve neighbouring source texels and aligned mip footprints
through level 7. Only the native upload unit changes; pose geometry is unchanged.
"""
import hashlib,json
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1]
source=root/'assets/c0/normi-motion-atlas.png'
im=Image.open(source).convert('RGBA');assert im.size==(3072,5376)
a=np.asarray(im);out=root/'assets/increment03/normi-motion';out.mkdir(parents=True,exist_ok=True)
rows=[];rebuilt=Image.new('RGBA',im.size)
for frame in range(28):
    x,y=(frame%4)*768,(frame//4)*768
    # Edge texels reproduce the source texture's CLAMP_TO_EDGE address mode.
    xx=np.clip(np.arange(x-128,x+896),0,3071);yy=np.clip(np.arange(y-128,y+896),0,5375)
    tile=Image.fromarray(a[yy[:,None],xx[None,:]]);path=out/f'{frame:02}.png';tile.save(path,optimize=True)
    restored=Image.open(path).convert('RGBA');crop=restored.crop((128,128,896,896))
    assert crop.tobytes()==im.crop((x,y,x+768,y+768)).tobytes()
    rebuilt.paste(crop,(x,y));rows.append(dict(frame=frame,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
assert rebuilt.tobytes()==im.tobytes()
report=dict(sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest(),sourceSize=list(im.size),tileSize=[1024,1024],cell=768,gutter=128,frames=rows,totalBytes=sum(r['bytes']for r in rows),pixelReconstruction='PASS',sampling='original base pixels; aligned source mip footprints through level 7; not GPU or performance evidence')
(root/'docs/migration/increment03-motion-tiles.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items()if k!='frames'}))
