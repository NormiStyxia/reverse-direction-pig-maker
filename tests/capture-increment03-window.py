"""Capture this project's already-requested isolated validation window on macOS.
Never starts/restarts Runtime and never selects another project's window."""
import argparse, json, subprocess, time
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('label');p.add_argument('--frames',type=int,required=True)
p.add_argument('--count',type=int,default=3);p.add_argument('--interval',type=float,default=3)
a=p.parse_args()
key='afa0dcff485e9b3b31d610f753bbb7791551aab4723b4b2494f88cc3d9dceabb'
out=Path('validation/increment03/native');out.mkdir(parents=True,exist_ok=True)
deadline=time.monotonic()+120
window=None
while time.monotonic()<deadline:
    rows=subprocess.check_output(['ps','-axo','pid=,command='],text=True).splitlines()
    for row in rows:
        if '/UrhoXRuntime -game_url=' not in row or key not in row or f'-validate-frames={a.frames}' not in row or '/bin/zsh' in row:continue
        pid=int(row.strip().split(None,1)[0])
        found=subprocess.check_output(['/tmp/reverse-pig-native-window03',str(pid)],text=True).strip()
        if found:
            window=json.loads(found.splitlines()[0])['window'];print('CAPTURE_PID',pid,window,flush=True);break
    if window:break
    time.sleep(.2)
if not window:raise SystemExit('No matching live validation window found')
for i in range(a.count):
    time.sleep(a.interval)
    path=out/f'{a.label}-window-{i}.png'
    subprocess.run(['screencapture','-x','-o','-l',str(window),str(path)],check=True)
    print(path,flush=True)
