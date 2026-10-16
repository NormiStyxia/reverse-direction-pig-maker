"""Actual NVG layout/dispatch under mocked drawing API, no physical-device claim."""
import runpy,json,contextlib,io
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
with contextlib.redirect_stdout(io.StringIO()):
 titleEnv=runpy.run_path(str(ROOT/'tests/test_title_nvg.py'))
 storyEnv=runpy.run_path(str(ROOT/'tests/test_story_nvg.py'))
Title,Canvas=titleEnv['Title'],titleEnv['Canvas']
count=0
for w,h in [(844,390),(667,375),(390,844),(320,568)]:
 for dpr in [1,2,3]:
  for panel in ['levelmode','chapters','options']:
   t=Title.new(6,lambda:.5);t.skipIntro(t);t.update(t,.01);t.openPanel(t,panel)
   c=Canvas.new(t);c.touchMode=True;c.resize(c,w*dpr,h*dpr,dpr);c.update(c);c.render(c)
   seen=set()
   c.touchRows(c)
   for scroll in [0,c.touchScrollMax]:
    c.touchScroll=scroll;c.render(c)
    for r in c.touchRows(c).values():
     assert r.x>=0 and r.x+r.w<=w and r.h>=44
     if r.index is not None and (r.y<108 or r.y+r.h>h-12):continue
     assert r.y>=0 and r.y+r.h<=h
     px,py=(r.x+r.w/2)*dpr,(r.y+r.h/2)*dpr
     x,y=c.designPoint(c,px,py);hit=c.hitTest(c,x,y)
     assert (hit[0] if isinstance(hit,tuple) else hit)==r.id
     seen.add(r.id);count+=1
   assert len(seen)==t.count(t)+1,(w,h,panel,seen)
   if c.touchScrollMax>0:
    c.touchScroll=0;c.render(c)
    c.pointerDown(c,40*dpr,140*dpr,0)
    c.pointerMove(c,40*dpr,110*dpr,1)
    assert c.touchScroll==0, 'second finger stole scroll'
    c.pointerMove(c,40*dpr,110*dpr,0)
    assert c.touchScroll>0 and c.touchDrag
    c.pointerUp(c,40*dpr,110*dpr,0)
    assert t.panel==panel and not t.st.started, 'drag activated a level'
   c.dispose(c)
lua=storyEnv['lua'];req=storyEnv['require'];Story=req('game.Chapter1State');Panels=req('game.Chapter1Panels');Canvas=storyEnv['Canvas']
branches=[]
for w,h in [(844,390),(667,375),(390,844),(320,568)]:
 for dpr in [1,2,3]:
  for index,answer in enumerate(['same','late','done']):
   s=Story.new();s.phase='play';s.skip(s);s.phone.k=1
   c=Canvas.new(Panels.new(s));c.touchUI=True;c.resize(c,w*dpr,h*dpr,dpr);c.update(c,1);c.render(c)
   choices=[r for r in c.hits.values() if r.id.startswith('choice:')]
   assert len(choices)==3
   for r in choices:
    assert r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,(w,h,r.text,r.x,r.y,r.w,r.h)
    assert r.h>=44
   r=next(r for r in choices if r.id=='choice:'+str(index))
   x,y=(r.x+r.w/2)*dpr,(r.y+r.h/2)*dpr
   c.pointerDown(c,x,y,0);c.pointerUp(c,x,y,1);assert not s.answer
   c.pointerUp(c,x,y,0);assert s.answer==answer
   branches.append([w,h,dpr,answer]);c.dispose(c)
report={'result':'PASS','titleRows':count,'branchTaps':len(branches),'logicalSizes':[[844,390],[667,375],[390,844],[320,568]],'dprs':[1,2,3],
 'checks':['all three required answers via real NVG dispatch','44px touch targets','multi-finger ownership','title rows visible and hit-test aligned'],
 'notCovered':['physical mobile browser/device','native font rendering','whole game visuals']}
(ROOT/'docs/migration/increment-02-mobile-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
