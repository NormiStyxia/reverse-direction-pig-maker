"""Prepare paintDot in linear RGB so Runtime's CPU mip builder averages light.
Frozen CanvasTexture is sRGB, whose WebGL mip generation averages decoded RGB.
Keep original alpha and original source PNG; this is a derived runtime asset.
"""
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[1]
p=root/'assets/store/generated/a28d7137a25d50ce6d784d96.png'
a=np.array(Image.open(p).convert('RGBA'));c=a[:,:,:3]/255
linear=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
a[:,:,:3]=np.floor(linear*255+.5).astype(np.uint8)
Image.fromarray(a).save(root/'assets/store/generated/dust-linear.png')
print('paintDot: linear RGB derivative generated, alpha unchanged')
