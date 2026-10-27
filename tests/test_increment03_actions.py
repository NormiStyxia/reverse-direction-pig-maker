"""Current frozen CSS oracle, plus native hit testing in physical coordinates."""
import json
from pathlib import Path
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
module=lua.eval("require('render.SceneActions')")[0]
font=TTFont(ROOT/'assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
def measure(canvas,text,size):return sum(font['hmtx'].metrics[cmap[ord(ch)]][0]for ch in text)*size/font['head'].unitsPerEm
def table(v):
 if isinstance(v,dict):return lua.table_from({k:table(x)for k,x in v.items()})
 if isinstance(v,list):return lua.table_from([table(x)for x in v])
 return v
lua.execute('''
function makeStory(options,mode)
 return {mode=mode,options=options,interactionId='seat',t=10,interactionAt=-99,normi={busy=function()return false end},phone={open=false,k=0},browse={open=false,k=0},
 nearbyInteractions=function(self)return self.options end,interact=function(self,id)self.action=id end,
 togglePhone=function(self)self.phone.open=not self.phone.open end,
 cycleInteraction=function(self)self.interactionId=self.options[2].id end}
end
function getter(s)return function()return s end end
''')
checks=0;errors=[];max_error=0
fixtures=json.loads((ROOT/'validation/increment03/scene-actions/h5-metrics.json').read_text())
for f in fixtures:
 c=table(dict(w=f['width'],h=f['height'],dpr=1,fontReady=True,touchUI=f['touch']));c.measure=measure
 options=[dict(zip(['id','object','text'],o))for o in f['options']];s=lua.globals().makeStory(table(options),f['mode']);a=module.new(c,lua.globals().getter(s),True)
 buttons,hint=a.layout(a)
 for actual in buttons.values():
  if actual.id=='cycle':continue # Required touch-only "切物件" control is a deliberate extension.
  if actual.id=='phone':expected=next(e['rect']for e in f['elements']if e['id']=='phoneBtn')
  elif f['mode']=='night':
   if f['touch'] and f['count']>1:
    assert actual.textSize==12 and actual.h>=44;continue
   expected=next(e['rect']for e in f['elements']if e['id']=='store-interaction')
   # The desktop hint is a sibling: compare the combined prompt below instead.
   if f['count']>1:expected=None
  else:expected=next(e['rect']for e in f['elements']if e['action']==actual.id)
  if expected:
   for key,field in [('x','x'),('y','y'),('width','w'),('height','h')]:
    err=abs(expected[key]-actual[field]);max_error=max(max_error,err);checks+=1
    if err>.15:errors.append((f['width'],f['touch'],f['mode'],f['count'],actual.id,key,expected[key],actual[field]))
 if f['mode']=='night'and not f['touch']and f['count']>1:
  b=buttons[1];end=buttons[2];expected=next(e['rect']for e in f['elements']if e['id']=='store-interaction')
  for key,value in [('x',b.x),('y',b.y),('width',end.x+end.w-b.x),('height',b.h)]:
   err=abs(value-expected[key]);max_error=max(max_error,err);checks+=1
   if err>.15:errors.append((f['width'],False,'night',f['count'],'group',key,expected[key],value))
 for dpr in [1,2,3]:
  c.dpr=dpr;b=buttons[1];x=(b.x+b.w/2)*dpr;y=(b.y+b.h/2)*dpr;s.action=False
  assert a.down(a,x,y,11);assert not a.down(a,x,y,12);assert not a.up(a,x,y,12)
  a.move(a,x+9*dpr,y,11);a.up(a,x,y,11);assert not s.action
  a.down(a,x,y,13);a.cancel(a);assert not a.up(a,x,y,13)
  a.down(a,x,y,14);a.up(a,x,y,14);assert s.action=='seat'
  s.interactionAt=s.t;assert not a.down(a,x,y,15);s.interactionAt=-99
  if f['touch']and f['mode']=='night'and f['count']>1:
   cycle=buttons[2];cx=(cycle.x+cycle.w/2)*dpr;cy=(cycle.y+cycle.h/2)*dpr
   a.down(a,cx,cy,16);a.up(a,cx,cy,16);assert s.interactionId=='window';s.interactionId='seat'
  if f['width']/f['height']>=2:
   s.phone.k=1;rows,_=a.layout(a);assert len(rows)==0;s.phone.k=0
  checks+=9
if errors:
 print(json.dumps({'result':'FAIL','errors':errors,'maxPixelError':max_error},ensure_ascii=False,indent=2));raise SystemExit(1)
# Real state shapes matter: the earlier synthetic fixture incorrectly added
# browse to meeting/morning, hiding the wide-only nil dereference.
real_states=0
for name,mode in [('Chapter1State','meeting'),('Chapter1State','morning'),('DreamState','dream'),('NightOfficeState','night'),('DormState','dorm')]:
 loaded=lua.eval("require('game."+name+"')");State=loaded[0] if isinstance(loaded,tuple) else loaded
 s=State.new(table({'mode':mode}))
 for w,h in [(1280,720),(1200,540)]:
  c=table(dict(w=w,h=h,dpr=1,fontReady=True,touchUI=False));c.measure=measure
  a=module.new(c,lua.globals().getter(s),s.browse is not None)
  a.layout(a);s.phone.k=1
  buttons,_=a.layout(a)
  if w/h>=2:assert len(buttons)==0,(name,mode)
  s.phone.k=0;real_states+=1
report={'result':'PASS','frozenLayouts':len(fixtures),'checks':checks,'maxPixelError':max_error,'dprs':[1,2,3],'touchOnlyExtension':'Night prompt retains a separate 44px object-cycle target; frozen coarse CSS hides Tab.', 'notCovered':['GPU text rasterization','hardware touchscreen']}
report['realStateLayouts']=real_states
(ROOT/'docs/migration/increment03-actions-test.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10));print(json.dumps(report,ensure_ascii=False,indent=2))
