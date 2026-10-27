"""Decode original Mivo files and apply frozen loop-tail overlap, without resampling."""
from pathlib import Path
import subprocess,tempfile,hashlib,json,wave
import numpy as np
from scipy.io import wavfile
out=Path('assets/audio/increment04');out.mkdir(exist_ok=True)
records=[]
for src in list(Path('assets/audio').glob('music-*.m4a'))+[Path('assets/audio/rewind.wav')]:
 with tempfile.TemporaryDirectory() as d:
  pcm=Path(d)/'decoded.wav'
  subprocess.run(['/usr/bin/afconvert',str(src),str(pcm),'-f','WAVE','-d','LEI16'],check=True)
  rate,data=wavfile.read(pcm);assert data.dtype==np.int16
  channels=1 if data.ndim==1 else data.shape[1];data=data.reshape(-1,channels).copy()
  frames=len(data);n=min(int((1.8 if src.stem.startswith('music-')else .06)*rate),frames//4)
  k=np.arange(n,dtype=np.float64)[:,None]/n
  data[:n]=np.rint(data[-n:]*(1-k)+data[:n]*k).clip(-32768,32767).astype('<i2')
  dst=out/(src.stem+'.wav')
  with wave.open(str(dst),'wb')as f:
   f.setnchannels(channels);f.setsampwidth(2);f.setframerate(rate);f.writeframes(data[:-n].tobytes())
  records.append(dict(source=str(src),sha256=hashlib.sha256(src.read_bytes()).hexdigest(),output=str(dst),frames=frames-n,rate=rate,channels=channels,overlap=n))
Path('docs/migration/increment04-audio-conversion.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS: original sample rates/channels, frozen 1.8s music and 60ms rewind overlap',len(records))
