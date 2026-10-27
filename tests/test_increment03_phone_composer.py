"""Real night-state sends + recorded native compositor; no GPU/device claim."""
import re
from pathlib import Path
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
font=TTFont('assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
def measure(c,text,size):return sum(font['hmtx'].metrics[cmap.get(ord(ch),'.notdef')][0]for ch in text)*size/font['head'].unitsPerEm
for p in Path('scripts/render').glob('*.lua'):
 for name in set(re.findall(r'\bnvg\w+',p.read_text())):lua.globals()[name]=lambda *a:None
for k,v in [('NVG_ALIGN_LEFT',1),('NVG_ALIGN_TOP',8),('NVG_ALIGN_CENTER',2)]:lua.globals()[k]=v
lua.globals().nvgRGBA=lambda *a:lua.table_from(a)
def req(name):
 v=lua.eval("require('"+name+"')");return v[0]if isinstance(v,tuple)else v
C=req('render.StoryOverlay');E=req('render.PhoneExtras');S=req('game.NightOfficeState')
make=lua.eval('function(C,s,w,h,dpr) return setmetatable({story=s,w=w,h=h,dpr=dpr,vg=1,fontReady=true,font=1,images={},metrics={},channel="phone",placement={layoutSide="right",frostEdge=.5},actorLeft=.2,actorRight=.4,scroll={phone=0,browse=0},scrollBottom=true,maxScroll=0,elapsed=10,arrivals={},browseArrivals={},lastDraft="",typeFrom=0,lastCount=0,lastBrowseCount=-1,hits={}},C) end')
checks=0
for w,h in [(1920,1080),(1280,720),(1200,540),(800,360)]:
 for side in ['left','right']:
  for dpr in [1,2,3]:
   s=S.new(lua.table_from({'wake':False}));s.t=10;s.phase='play'
   s.phone.open=True;s.phone.k=1;s.phone.view='chat';s.phone.elapsed=10
   s.phone.buttons=lua.table_from([lua.table_from(dict(id='pick',text='收到，我来改'))])
   c=make(C,s,w,h,dpr);c.measure=measure;c.fontSize=lambda *_:None;c.text=lambda *_:None;c.image=lambda *_:None
   c.placement.layoutSide=side;c.stickerTab='tw'
   C.update(c,0);E.action(c,'stickers');C.render(c)
   assert c.thread.h>=43 and c.thread.y+c.thread.h<=c.composer.y
   assert c.composer.y>c.panel.y+c.panel.headerH
   sticker_hits=[b for b in c.hits.values()if b.id.startswith('sticker:')]
   assert sticker_hits
   for b in c.hits.values():
    if b.id.startswith(('sticker:','stab:')):
     assert b.y>=c.composer.y-1e-6 and b.y+b.h<=c.composer.y+c.composer.h+1e-6
   # Wheel/drag scroll only the composer; release must not select an item.
   before=len(s.phone.msgs);old_thread=c.scroll.phone
   if c.composerMaxScroll>0:
    b=sticker_hits[0];x=(b.x+b.w/2)*dpr;y=(b.y+b.h/2)*dpr
    assert C.pointerDown(c,x,y,'touch-2');C.pointerMove(c,x,y-50*dpr,'touch-2');C.pointerUp(c,x,y-50*dpr,'touch-2')
    assert len(s.phone.msgs)==before and c.composerScroll>0 and c.scroll.phone==old_thread
    C.wheel(c,-100,(c.composer.x+10)*dpr,(c.composer.y+10)*dpr);C.render(c)
    assert abs(c.composerScroll-c.composerMaxScroll)<1e-6
    assert any(b.id=='stickers'for b in c.hits.values()) # bottom input remains reachable
   C.dispatch(c,'sticker:tw-wanan');assert len(s.phone.msgs)==before+1
   assert s.phone.msgs[len(s.phone.msgs)].sticker=='tw-wanan' and not c.stickersOpen and c.scrollBottom
   C.render(c);assert c.composerScroll==0
   # Closing animation must neither accept a send nor retain its picker.
   E.action(c,'stickers');s.phone.open=False;s.phone.k=.4;C.update(c,.05)
   C.dispatch(c,'sticker:pig-ok');assert len(s.phone.msgs)==before+1 and not c.stickersOpen
   # Channel changes release the captured gesture and all auxiliary panels.
   c.pointerId='touch-3';c.press=lua.table_from(dict(message=False));s.phone.k=0;C.update(c,.05)
   assert not c.channel and not c.pointerId and not c.reactFor
   checks+=1
print(f'PASS: {checks} phone layouts; picker clipping/scroll/drag, real sticker send, close animation and channel cleanup')
