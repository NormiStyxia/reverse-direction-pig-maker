"""Physical touch routing and non-overlap at common landscape phone sizes."""
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont
l=LuaRuntime(unpack_returned_tuples=True);l.execute("package.path='scripts/?.lua;'..package.path")
f=TTFont('assets/fonts/LXGWWenKai-subset.ttf');cm=f.getBestCmap()
def measure(_,text,size):return sum(f['hmtx'].metrics[cm.get(ord(c),'.notdef')][0]for c in text)*size/f['head'].unitsPerEm
Controls=l.eval("require('render.PlayerControls')")[0]
checks=0
for w,h in [(800,360),(780,360),(844,390),(915,412),(667,375),(640,360)]:
 for dpr in [1,2,3]:
  c=l.table_from(dict(w=w,h=h,dpr=dpr,touchUI=True,measure=measure))
  state=l.table_from(dict(echo=True,movable=True,hasCard=True));actions=[]
  ctl=Controls.new(l.eval('function(s)return function()return s end end')(state),actions.append)
  rows,_=ctl.layout(ctl,c);rows=list(rows.values())
  for a in rows:
   assert a.x>=0 and a.y>=0 and a.x+a.w<=w and a.y+a.h<=h,(w,h,a.id)
   for b in rows:
    if a.id!=b.id:assert min(a.x+a.w,b.x+b.w)<=max(a.x,b.x)or min(a.y+a.h,b.y+b.h)<=max(a.y,b.y),(w,h,a.id,b.id)
   if a.id in ['mechanism','topview','restart','pause']:
    x,y=(a.x+a.w/2)*dpr,(a.y+a.h/2)*dpr
    ctl.down(ctl,c,x,y,11);ctl.up(ctl,c,x,y,11);assert actions[-1]==a.id;checks+=1
  state.card=True
  ctl.down(ctl,c,w*dpr/2,h*dpr/2,12);ctl.up(ctl,c,w*dpr/2,h*dpr/2,12)
  assert actions[-1]=='cardClose';checks+=1
  state.card=False
  ctl.cancel(ctl);assert not ctl.spin and ctl.x==0 and ctl.y==0
print('PASS:',checks,'physical-coordinate tap checks; 18 phone/DPR layouts; no tool-button overlap; card close consumes touch')
