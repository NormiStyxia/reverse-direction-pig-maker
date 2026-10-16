"""Observe a real title Enter -> store transition in an already-live main.lua.
No runtime refresh, diagnostic key, model reset, or global input injection.
"""
import json,subprocess,time
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1];out=root/'validation/blue/live-title';out.mkdir(parents=True,exist_ok=True)
cli=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
s=json.loads(subprocess.check_output(['node',str(cli),'preview','status','--target-dir',str(root),'--json'],text=True))
assert s['process_alive'] and s['preparation']['entry']=='main.lua'
pid=s['runtime_pid']
swift='''import CoreGraphics
import Foundation
let pid=pid_t(CommandLine.arguments[1])!
let down=CGEvent(keyboardEventSource:nil,virtualKey:36,keyDown:true)!
let up=CGEvent(keyboardEventSource:nil,virtualKey:36,keyDown:false)!
down.flags=[];up.flags=[];down.postToPid(pid);Thread.sleep(forTimeInterval:0.05);up.postToPid(pid)
'''
(root/'.tmp/blue-enter.swift').write_text(swift)
subprocess.run(['swiftc',str(root/'.tmp/blue-enter.swift'),'-o',str(root/'.tmp/blue-enter')],check=True)
subprocess.run(['swiftc',str(root/'tests/native-window.swift'),'-o',str(root/'.tmp/outline-window')],check=True)
row=json.loads(subprocess.check_output([str(root/'.tmp/outline-window'),str(pid)],text=True));window=str(row['window'])
assert row['title']=='反方向的猪',row
frames=[]
def capture(index,start):
    raw=out/f'{index:03d}-window.png';subprocess.run(['screencapture','-x','-o','-a','-l',window,str(raw)],check=True)
    im=Image.open(raw);dpr=im.width/row['bounds']['Width'];assert dpr in (1,2,3)
    im=im.crop((0,round(32*dpr),im.width,im.height));im.save(out/f'{index:03d}.png')
    frames.append({'index':index,'secondsAfterEnter':time.monotonic()-start,'size':list(im.size)})
start=time.monotonic();capture(0,start)
subprocess.run([str(root/'.tmp/blue-enter'),str(pid)],check=True);start=time.monotonic()
for i in range(1,37):
    delay=i*.4-(time.monotonic()-start)
    if delay>0:time.sleep(delay)
    capture(i,start)
sheet=Image.new('RGB',(1280,4*204),'#151515');draw=ImageDraw.Draw(sheet)
for j,i in enumerate([0,2,4,6,8,10,12,14,16,18,20,22,24,28,32,36]):
    im=Image.open(out/f'{i:03d}.png');im.thumbnail((320,180));x=j%4*320;y=j//4*204;sheet.paste(im,(x,y+24))
    draw.text((x+8,y+5),'before Enter' if i==0 else f'{frames[i]["secondsAfterEnter"]:.2f}s',fill='white')
sheet.save(out/'contact-sheet.png')
(out/'receipt.json').write_text(json.dumps({'session':s['session_id'],'reload':s['reload_id'],'pid':pid,'frames':frames,'scope':'real Enter transition; wall-clock sampling, not full-game or source pixel parity'},indent=2)+chr(10))
print('Captured real title Enter:',len(frames),'frames, reload',s['reload_id'])
