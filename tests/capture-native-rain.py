"""Capture the verified paused echo fixture running down, rewinding up, then recovering.
Requires native-rain-fixed.json from F5. Uses process-scoped keys, never global input.
The GIF is a scaled motion artifact; only raw PNGs are valid pixel evidence.
"""
import json,subprocess,time
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
CLI=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
meta=json.loads((ROOT/'validation/echo/native-rain-fixed.json').read_text())
out=ROOT/'validation/echo/rain-motion';out.mkdir(exist_ok=True)
s=json.loads(subprocess.check_output(['node',str(CLI),'preview','status','--target-dir',str(ROOT),'--json'],text=True))
assert s['process_alive'] and s['runtime_pid']==meta['runtimePid'] and s['reload_id']==meta['reloadId']
helper=out/'key.swift';binary=out/'key'
helper.write_text('''import CoreGraphics
import Foundation
let pid=pid_t(CommandLine.arguments[1])!
let key=CGKeyCode(CommandLine.arguments[2])!
let mode=CommandLine.arguments[3]
func post(_ down:Bool){let e=CGEvent(keyboardEventSource:nil,virtualKey:key,keyDown:down)!;e.flags=[];e.postToPid(pid)}
if mode=="tap" {post(true);Thread.sleep(forTimeInterval:0.03);post(false)} else {post(mode=="down")}
''')
subprocess.run(['swiftc',str(helper),'-o',str(binary)],check=True)
def key(code,mode='tap'):subprocess.run([str(binary),str(s['runtime_pid']),str(code),mode],check=True)
frames=[];rows=[];start=time.monotonic();w,h=meta['contentSize']
def capture(stage,n):
    for i in range(n):
        raw=out/f'{len(rows):03}-{stage}.png'
        subprocess.run(['screencapture','-x','-o','-l',str(meta['window']),str(raw)],check=True)
        im=Image.open(raw);assert im.width==w and im.height>=h
        im=im.crop((0,im.height-h,w,im.height));im.save(raw)
        row={'stage':stage,'seconds':time.monotonic()-start,'file':raw.name};rows.append(row)
        thumb=im.convert('RGB').resize((960,540));d=ImageDraw.Draw(thumb);d.rectangle((0,0,960,24),fill='black');d.text((8,6),stage+' / native runtime / scaled motion diagnostic',fill='white');frames.append(thumb)
        time.sleep(.08)
try:
    key(97);capture('down',12)
    key(40,'down');time.sleep(.8);capture('rewind',16)
    key(40,'up');time.sleep(.8);capture('recover',12)
finally:
    key(40,'up');key(97)
durations=[max(20,round((rows[i+1]['seconds']-row['seconds'])*1000)) if i<len(rows)-1 else 300 for i,row in enumerate(rows)]
frames[0].save(out/'native-rain-motion.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0)
(out/'capture.json').write_text(json.dumps({'reloadId':s['reload_id'],'runtimePid':s['runtime_pid'],'frames':rows,'scope':'Real keyboard K, real runtime motion; no visual acceptance claim'},indent=2)+'\n')
print('Captured',len(rows),'native rain motion frames; final runtime paused')
