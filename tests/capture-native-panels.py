"""macOS-only capture of the active official local runtime's exported NVG fixtures.
Run immediately after a panel-probe refresh; starts on paused fixture 2.
Uses OS window capture and process-targeted F7, not unsupported Maker screenshot APIs.
"""
import json,subprocess,time
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
CLI=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
out=ROOT/'validation/panels';out.mkdir(parents=True,exist_ok=True)
def preview(command):
    r=subprocess.run(['node',str(CLI),'preview',command,'--target-dir',str(ROOT),'--json'],capture_output=True,text=True)
    data=json.loads(r.stdout);(out/('local-'+command+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');return data
status=preview('status');assert status['process_alive'] and status['preparation']['entry']=='preview/title.lua'
pid=int(status['runtime_pid'])
lua_dir=Path(status['executable']).parent/'logs/lua'
log=max(lua_dir.glob('*'),key=lambda p:p.stat().st_mtime)
lines=[json.loads(l) for l in log.read_text().splitlines()]
last_probe=[l['m'] for l in lines if 'STORY_PANEL_PROBE:' in l['m']][-1]
assert '群聊;' in last_probe,'Capture requires initial fixture 2; restore it with F7 first'
assert any('STORY_FONT_READY: digit 12.0; first message 358.0' in l['m'] for l in lines),'Frozen font metrics not ready'
swift='''import CoreGraphics
import Foundation
let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows where (w[kCGWindowOwnerPID as String] as? Int) == TARGET_PID {
 if let b=w[kCGWindowBounds as String] as? [String:Any], (b["Height"] as? Int ?? 0)>1000 {
  print(w[kCGWindowNumber as String]!)
 }
}
'''.replace('TARGET_PID',str(pid))
window=subprocess.check_output(['swift','-e',swift],text=True).strip();assert window.isdigit(),window
key='import CoreGraphics; CGEvent(keyboardEventSource:nil,virtualKey:98,keyDown:true)?.postToPid(PID); CGEvent(keyboardEventSource:nil,virtualKey:98,keyDown:false)?.postToPid(PID)'.replace('PID',str(pid))
files=[]
count=len(json.loads((out/'fixtures.json').read_text()))
for fixture in [*range(2,count+1),1]:
    time.sleep(.8)
    raw=out/f'native-fixture-{fixture}-window.png'
    subprocess.run(['screencapture','-x','-o','-l',window,str(raw)],check=True)
    im=Image.open(raw);assert im.size==(1920,1112),im.size
    crop=out/f'native-fixture-{fixture}.png';im.crop((0,32,1920,1112)).save(crop)
    files.append({'fixture':fixture,'raw':str(raw.relative_to(ROOT)),'crop':str(crop.relative_to(ROOT)),'cropRect':[0,32,1920,1112]})
    subprocess.run(['swift','-e',key],check=True,capture_output=True)
preview('logs');check=preview('check')
report={'date':'2026-10-16','sessionId':status['session_id'],'reloadId':status['reload_id'],'runtimePid':pid,
        'windowId':int(window),'viewport':[1920,1080],'files':files,'cliCheck':check['result'],
        'notAcceptance':'UI fixtures only; no actual story scene, full route or 95% claim'}
(out/'native-capture.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'Captured {len(files)} native fixtures; runtime {pid}, reload {status["reload_id"]}; official check {check["result"]}')
