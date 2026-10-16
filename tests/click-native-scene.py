"""Post a mouse click only to the verified live Maker window, then capture it.
Usage: python3 tests/click-native-scene.py NAME X Y
Coordinates are native content pixels; no resizing; foreground and hit window verified before OS input.
"""
import json, re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CLI=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
name,x,y=sys.argv[1],float(sys.argv[2]),float(sys.argv[3])
assert name.replace('-','').replace('_','').isalnum()
state=json.loads(subprocess.check_output(['node',str(CLI),'preview','status','--target-dir',str(ROOT),'--json'],text=True))
assert state['process_alive'] and state['state']=='running'
assert state['preparation']['entry'] in ('main.lua','preview/title.lua','preview/diagnostics.lua')
pid=state['runtime_pid']
log=max((Path(state['executable']).parent/'logs/game').glob('*'),key=lambda p:p.stat().st_mtime)
dimensions=re.findall(r'Graphics (?:mode|resized): (\d+)x(\d+) \(logic=(\d+)x(\d+), dpr=([\d.]+)\)',log.read_text())
assert dimensions,'Current runtime has no graphics dimensions'
w,h,lw,lh,dpr=map(float,dimensions[-1])
assert 0<=x<w and 0<=y<h

source='''import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
let pid:pid_t=TARGET_PID
NSRunningApplication(processIdentifier:pid)?.activate(options:[])
Thread.sleep(forTimeInterval:0.3)
precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier==pid,"Runtime must own keyboard focus")
let windows=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
let matches=windows.filter { w in
 guard (w[kCGWindowOwnerPID as String] as? Int)==Int(pid),
 let b=w[kCGWindowBounds as String] as? [String:CGFloat] else {return false}
 return b["Height",default:0]>400 && b["Width",default:0]==LOGICAL_W
}
precondition(matches.count==1,"Expected one matching runtime window")
let w=matches[0];let b=w[kCGWindowBounds as String] as! [String:CGFloat]
let window=(w[kCGWindowNumber as String] as! NSNumber).int64Value
let chrome=b["Height"]!-LOGICAL_H
precondition(chrome>=0 && chrome<=80)
let p=CGPoint(x:b["X"]!+CLICK_X,y:b["Y"]!+chrome+CLICK_Y)
var element:AXUIElement?
let hit=AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(),Float(p.x),Float(p.y),&element)
var owner:pid_t=0
if let e=element {AXUIElementGetPid(e,&owner)}
guard hit == .success && owner==pid else {print("Click not sent: accessibility hit target is not this runtime");exit(2)}
for t:CGEventType in [.mouseMoved,.leftMouseDown,.leftMouseUp] {
 let e=CGEvent(mouseEventSource:nil,mouseType:t,mouseCursorPosition:p,mouseButton:.left)!
 e.setIntegerValueField(.mouseEventWindowUnderMousePointer,value:window)
 e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,value:window)
 e.setIntegerValueField(.mouseEventClickState,value:1)
 e.post(tap:.cghidEventTap);Thread.sleep(forTimeInterval:0.12)
}
print("Posted native mouse click to PID \(pid), window \(window)")
'''
source=source.replace('TARGET_PID',str(pid)).replace('CLICK_X',str(x/dpr)).replace('CLICK_Y',str(y/dpr)).replace('LOGICAL_W',str(lw)).replace('LOGICAL_H',str(lh))
subprocess.run(['swift','-e',source],check=True)
subprocess.run([sys.executable,str(ROOT/'tests/capture-native-store.py'),name,'wait:1'],check=True)
out=ROOT/'validation/store'/f'{name}.json'
receipt=json.loads(out.read_text());receipt['nativeMouseClick']={'x':x,'y':y,'targetPid':pid,'dpr':dpr,'physicalSize':[w,h]}
assert receipt['runtimePid']==pid,'Runtime changed during click test'
out.write_text(json.dumps(receipt,indent=2)+'\n')
