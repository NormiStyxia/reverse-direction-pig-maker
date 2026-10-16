"""Observe the explicitly selected live pipeline fixture; never starts or refreshes.
Run immediately after an authorized fixture refresh. Size changes reset its epoch.
"""
import json,subprocess,time
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];out=root/'validation/effects/native';out.mkdir(parents=True,exist_ok=True)
cli=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
s=json.loads(subprocess.check_output(['node',str(cli),'preview','status','--target-dir',str(root),'--json'],text=True))
assert s['process_alive'] and s['preparation']['entry']=='preview/effects-check.lua'
pid=s['runtime_pid']
subprocess.run(['swiftc',str(root/'tests/native-window.swift'),'-o',str(root/'.tmp/outline-window')],check=True)
generation=None;seen={};deadline=time.monotonic()+110
while time.monotonic()<deadline:
 row=json.loads(subprocess.check_output([str(root/'.tmp/outline-window'),str(pid)],text=True))
 name=row.get('title','')
 if name.startswith('EFFECTS_SAMPLE_') and name not in seen:
  gen=name.split('_')[2]
  if gen!=generation:seen={};generation=gen
  time.sleep(.3)
  raw=out/(name+'-window.png');subprocess.run(['screencapture','-x','-o','-a','-l',str(row['window']),str(raw)],check=True)
  current=json.loads(subprocess.check_output([str(root/'.tmp/outline-window'),str(pid)],text=True))
  assert current['title']==name,'Fixture changed during capture'
  im=Image.open(raw);dpr=im.width/row['bounds']['Width'];assert dpr in (1,2,3),dpr;top=round(32*dpr);im.crop((0,top,im.width,im.height)).save(out/(name+'.png'));row['captureSize']=[im.width,im.height-top];row['dpr']=dpr
  seen[name]=row;print(name,flush=True)
 if name=='EFFECTS_COMPLETE_'+str(generation):
  assert len(seen)==8,seen.keys()
  (out/'receipt.json').write_text(json.dumps({'sessionId':s['session_id'],'reloadId':s['reload_id'],'runtimePid':pid,'samples':seen,'source':'native window capture; no scaling'},indent=2)+chr(10));break
 time.sleep(.1)
else:raise RuntimeError('Capture timed out')
