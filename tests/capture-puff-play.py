"""Capture two explicitly selected actual gameplay events; never starts a runtime."""
import json,subprocess,time
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];out=root/'validation/puffs/play';out.mkdir(parents=True,exist_ok=True)
cli=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
s=json.loads(subprocess.check_output(['node',str(cli),'preview','status','--target-dir',str(root),'--json'],text=True))
assert s['process_alive'] and s['preparation']['entry']=='preview/puffs-play-check.lua';pid=s['runtime_pid']
seen={};deadline=time.monotonic()+120
while time.monotonic()<deadline:
 row=json.loads(subprocess.check_output([str(root/'.tmp/outline-window'),str(pid)],text=True));name=row.get('title','')
 if name in ['PUFF_PLAY_cabinetDown','PUFF_PLAY_merge'] and name not in seen:
  raw=out/(name+'-window.png');subprocess.run(['screencapture','-x','-o','-a','-l',str(row['window']),str(raw)],check=True)
  im=Image.open(raw);dpr=im.width/row['bounds']['Width'];assert dpr in (1,2,3)
  im.crop((0,round(32*dpr),im.width,im.height)).save(out/(name+'.png'));seen[name]=row;print(name,flush=True)
 if name=='PUFF_PLAY_COMPLETE':
  assert len(seen)==2
  (out/'receipt.json').write_text(json.dumps({'sessionId':s['session_id'],'reloadId':s['reload_id'],'runtimePid':pid,'samples':seen,'scope':'isolated native echo starts; source input replay; event capture, not full-game route'},indent=2)+chr(10));break
 time.sleep(.1)
else:raise TimeoutError('Native gameplay particle capture timed out')
