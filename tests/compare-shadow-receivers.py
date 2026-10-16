"""Verify real runtime shadow-receiver switch and exact round-trip restoration."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def read(name):return np.array(Image.open(ROOT/'validation/echo'/(name+'.png')).convert('RGB')).astype(float)
on=read('native-receiver-explicit-on');off=read('native-receiver-explicit-off');restored=read('native-receiver-explicit-restored')
a=read('native-receiver-floor-on');b=read('native-receiver-floor-disabled-mode')
assert np.array_equal(on,restored),'Receiver toggle must restore the exact diagnostic frame'
assert np.array_equal(on[:320],off[:320]),'Floor toggle must not change sky or upper geometry'
assert np.array_equal(on[350:400,1200:1400],off[350:400,1200:1400]),'Wall receiver must be unchanged'
assert all(off[627,1070]-on[627,1070]>40),'Pig cast-shadow floor sample should become lit'
report={'result':'PASS','reload':40,'floorShadowSample':{'xy':[1070,627],'on':on[627,1070].tolist(),'off':off[627,1070].tolist()},
 'changedPixelsAbove3':int((np.abs(on-off).max(2)>3).sum()),'exactRoundTrip':True,'wallAndSkyUnchanged':True,
 'unsupportedModeProbe':{'reload':39,'shaderAccepted':True,'changedPixelsAbove3':int((np.abs(a-b).max(2)>3).sum()),'floorSampleUnchanged':bool(np.array_equal(a[627,1070],b[627,1070]))},
 'scope':'Receiver toggle behavior only; does not verify whole-game visual equivalence','visualAccepted':False}
(ROOT/'docs/migration/shadow-receiver-comparison.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report,indent=2))
