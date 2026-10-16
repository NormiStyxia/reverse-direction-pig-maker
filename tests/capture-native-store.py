"""Capture only the verified Maker runtime window; optionally post explicit test keys.
Usage: python3 tests/capture-native-store.py NAME [KEYCODE[:HOLD_SECONDS] ...]
Keys are macOS virtual codes (F6=97, J=38, Return=36, W=13, A=0, S=1, D=2).
No global keyboard events and no connection to a personal browser.
"""
import json,re,subprocess,sys,time
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
CLI=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
kind='echo' if '--echo' in sys.argv else 'store'
if '--echo' in sys.argv:sys.argv.remove('--echo')
if '--chapter1' in sys.argv:kind='chapter1';sys.argv.remove('--chapter1')
out=ROOT/'validation'/kind;out.mkdir(parents=True,exist_ok=True)
name=sys.argv[1] if len(sys.argv)>1 else 'native-store'
assert name.replace('-','').replace('_','').isalnum()
status=json.loads(subprocess.check_output(['node',str(CLI),'preview','status','--target-dir',str(ROOT),'--json'],text=True))
assert status['process_alive'] and status['preparation']['entry'] in ('main.lua','preview/title.lua','preview/diagnostics.lua')
pid=status['runtime_pid']
for arg in sys.argv[2:]:
    parts=arg.split(':')
    if parts[0]=='wait':
        delay=float(parts[1]);assert 0<=delay<=15;time.sleep(delay);continue
    key=int(parts[0]);hold=float(parts[1]) if len(parts)>1 else .05
    assert 0<=key<128 and 0<=hold<=15
    code='import CoreGraphics; import Foundation; let down=CGEvent(keyboardEventSource:nil,virtualKey:KEY,keyDown:true)!; down.flags=[]; down.postToPid(TARGET); Thread.sleep(forTimeInterval:HOLD); let up=CGEvent(keyboardEventSource:nil,virtualKey:KEY,keyDown:false)!; up.flags=[]; up.postToPid(TARGET)'
    subprocess.run(['swift','-e',code.replace('KEY',str(key)).replace('TARGET',str(pid)).replace('HOLD',str(hold))],check=True)
    time.sleep(.5)
swift='''import CoreGraphics
import Foundation
let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows where (w[kCGWindowOwnerPID as String] as? Int) == TARGET_PID {
 if let b=w[kCGWindowBounds as String] as? [String:Any], (b["Height"] as? Int ?? 0)>400, (b["Width"] as? Int ?? 0)>600 { print(w[kCGWindowNumber as String]!) }
}'''.replace('TARGET_PID',str(pid))
window=subprocess.check_output(['swift','-e',swift],text=True).strip();assert window.isdigit()
# macOS can attach an input-method badge outside the game window. Exclude
# attached windows instead of silently cropping/scaling a wider capture.
raw=out/(name+'-window.png');subprocess.run(['screencapture','-x','-o','-a','-l',window,str(raw)],check=True)
im=Image.open(raw)
# Keep real resolution; a resized/fullscreen window must never be rescaled into
# a supposedly identical 1920x1080 reference capture. Derive content size from
# this verified runtime's latest graphics event, then remove only window chrome.
logdir=Path(status['executable']).parent/'logs/game'
log=max(logdir.glob('*'),key=lambda p:p.stat().st_mtime)
sizes=re.findall(r'Graphics (?:mode|resized): ([0-9]+)x([0-9]+)',log.read_text())
assert sizes,'No current runtime graphics dimensions'
w,h=map(int,sizes[-1]);top=im.height-h
assert im.width==w and 0<=top<=160,(im.size,(w,h),'Unexpected capture geometry')
rect=(0,top,w,im.height);im.crop(rect).save(out/(name+'.png'))
(out/(name+'.json')).write_text(json.dumps({'sessionId':status['session_id'],'reloadId':status['reload_id'],'runtimePid':pid,'window':int(window),
    'keys':sys.argv[2:],'cropRect':rect,'contentSize':[w,h],'graphicsLog':str(log),'scope':'native '+kind+' integration, NOT visual acceptance'},indent=2)+'\n')
print(name+': runtime '+str(pid)+', reload '+str(status['reload_id']))
