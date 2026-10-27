"""Exercise the actual NVG compositor: wash < prompt < panel < ink < menus."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
font=TTFont('assets/fonts/LXGWWenKai-subset.ttf'); cmap=font.getBestCmap()
def measure(c,text,size):
 return sum(font['hmtx'].metrics[cmap[ord(ch)]][0] for ch in text)*size/font['head'].unitsPerEm
record=[]
names=['Save','Restore','BeginPath','Rect','Circle','MoveTo','LineTo','ClosePath','Fill','Stroke','FillPaint','FillColor','StrokeColor','StrokeWidth','GlobalAlpha','FontBlur','ShapeAntiAlias','BeginFrame','EndFrame']
for name in names:
 lua.globals()['nvg'+name]=lambda *args,_name=name:record.append((_name,args))
lua.globals().nvgRGBA=lambda *args:lua.table_from(args)
lua.globals().nvgLinearGradient=lambda *args:record.append(('gradient',args))or 'gradient'
D=lua.eval("require('render.DialogOverlay')")[0]
S=lua.eval("require('game.NightOfficeState')")[0]
C=lua.eval("require('render.StoryOverlay')")[0]
lua.execute("package.loaded['render.TimelinePortal']={draw=function() end};package.loaded['render.LookCard']={draw=function(c) c.marker('panel') end}")
count=0
for w,h in [(1920,1080),(1280,720),(1200,540),(800,360),(960,540)]:
 for dpr in [1,2,3]:
  for theme in ['night','dream']:
   s=S.new(lua.table_from({'wake':False}));s.t=4;s.dialogTheme=theme
   s.dialog=lua.table_from(dict(at=0,hold=10,text='……手麻了。',stamp='23:12',face='tired'))
   c=lua.table_from(dict(w=w,h=h,dpr=dpr,vg=1,fontReady=True,story=s,measure=measure))
   c.text=lambda *args:record.append(('text',args));c.image=lambda *args:record.append(('image',args))
   c.marker=lambda name:record.append((name,()))
   c.sceneBackdrop=lambda canvas:D.draw(canvas,s,'background')
   c.sceneActions=lua.table_from(dict(render=lambda *_:record.append(('prompt',()))))
   c.sceneHUD=lambda canvas:D.draw(canvas,s,'foreground')
   c.externalHUD=lambda *_:record.append(('menu',()))
   record.clear();C.render(c)
   keys=[r[0]for r in record]
   prompt=keys.index('prompt'); assert keys.index('gradient')<prompt<keys.index('image')<keys.index('menu')
   assert 'Rect'not in keys[prompt+1:] # no dark band drawn over prompt
   strips=[args for name,args in record if name=='Rect']
   dm=max(40,min(56,h*.1))if w/h>=2 else max(60,min(90,h*.2))if h<=600 else max(118,min(190,h*.24))
   assert abs(sum(a[4]for a in strips)-dm*.82)<1e-8
   alphas=[a[1]for name,a in record if name=='GlobalAlpha']
   assert any(0<a<.06 for a in alphas)and 1 in alphas
   # The same backdrop remains below object cards; menus remain above dialog ink.
   c.channel='browse';s.browse.presentation='look';s.browse.k=1
   record.clear();C.render(c);keys=[r[0]for r in record]
   assert keys.index('gradient')<keys.index('prompt')<keys.index('panel')<keys.index('image')<keys.index('menu')
   # Long text may grow the dialog grid, never the wash height.
   s.dialog.text='这是换行很长的一段测试对话。'*6;s.t=9
   record.clear();D.draw(c,s,'background')
   strips=[args for name,args in record if name=='Rect']
   assert abs(sum(a[4]for a in strips)-dm*.82)<1e-8
   count+=1
print(f'PASS: {count} dialog layouts; both themes, DPR 1/2/3, compositor ordering, fixed wash height and soft edges')
