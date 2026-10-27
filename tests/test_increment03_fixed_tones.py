"""Verify source PCM and exact routing, including delayed and dynamic tones."""
import hashlib,json,wave
from pathlib import Path
import numpy as np
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
report=json.loads((root/'docs/migration/increment03-fixed-tones-report.json').read_text())
assert report['sourceSha256']==hashlib.sha256((root/'reference/increment03/h5-source/src/store-audio.js').read_bytes()).hexdigest()
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Cues=lua.eval("require('game.AudioCues')")[0]
for c in report['clips']:
 p=root/'assets/audio/increment03/fixed'/(c['id']+'.wav')
 assert hashlib.sha256(p.read_bytes()).hexdigest()==c['sha256']
 with wave.open(str(p),'rb')as w:
  assert(w.getframerate(),w.getnchannels(),w.getsampwidth(),w.getnframes())==(44100,1,2,c['frames'])
  pcm=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2')
 original=np.fromfile(root/'validation/increment03/fixed-tones'/(c['id']+'.f32'),dtype='<f4')
 assert np.max(np.abs(pcm/32767-original))<=.5/32767+1e-10
 for duration in ['dur','duration']:
  spec={'frequency':c['hz'],duration:c['dur'],'gain':c['gain'],'wave':c['type'],'slide':c['slide'],'at':.17}
  event=lua.table_from({'kind':'tone','data':spec},recursive=True)
  cue=Cues.resolve(event,'chapter')[1]
  assert cue.clip==c['id'] and cue.delay==.17 and cue.tone is None
  event.data.gain=c['gain']*.99
  cue=Cues.resolve(event,'chapter')[1]
  assert cue.clip is None and cue.tone is not None
print('PASS: 8 original PCM waveforms; 16 exact signatures with delay; nearby dynamic gains retain synthesis')
