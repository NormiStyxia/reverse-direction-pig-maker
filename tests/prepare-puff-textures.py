"""Keep frozen canvas originals; prepare linear RGB mip inputs without changing alpha."""
from pathlib import Path
import hashlib,json,numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1];out=root/'assets/effects';out.mkdir(parents=True,exist_ok=True)
report={}
for kind in ['puff','burst']:
 src=root/'validation/puffs/source'/f'{kind}.png';raw=src.read_bytes();(out/f'{kind}.png').write_bytes(raw)
 p=np.array(Image.open(src).convert('RGBA'));c=p[:,:,:3].astype(float)/255
 c=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
 p[:,:,:3]=np.floor(c*255+.5).astype('uint8');dest=out/f'{kind}-linear.png';Image.fromarray(p).save(dest)
 report[kind]={'frozenCanvasSHA256':hashlib.sha256(raw).hexdigest(),'linearMipInputSHA256':hashlib.sha256(dest.read_bytes()).hexdigest(),'size':list(Image.open(src).size)}
(root/'docs/migration/puff-textures.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report))
