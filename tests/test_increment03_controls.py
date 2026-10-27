import json
from pathlib import Path
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
m=lua.eval("require('render.PlayerControls')")[0];font=TTFont('assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
def measure(c,t,s):return sum(font['hmtx'].metrics[cmap[ord(ch)]][0]for ch in t)*s/font['head'].unitsPerEm
errors=[];n=0
for f in json.loads(Path('validation/increment03/player-controls/h5-metrics.json').read_text()):
 c=lua.table_from(dict(w=f['width'],h=f['height'],dpr=1,touchUI=f['touch'],measure=measure))
 if f['mode']=='phone':c.channel='phone';c.placement=lua.table_from(dict(layoutSide='right'))
 s=lua.table_from(dict(paused=f['mode']=='pause',canSkip=f['mode']in ['skip','phone'],echo=f['mode']=='echo',movable=f['mode']in ['echo','story'],cycle=f['mode']=='story'))
 get=lua.eval('function(s)return function()return s end end')(s)
 obj=m.new(get,lua.eval('function()end'));obj.mobile=f['touch'];rows,_=obj.layout(obj,c)
 for row in rows.values():
  label=row.text.strip()
  if row.id=='home'and f['mode']!='pause' or row.id=='pause'and not f['touch']:continue
  candidates=[e for e in f['elements'] if e['rect']['width']>0 and e['rect']['height']>0 and e['text'].startswith(label) and (e['id']=='skip-story' if row.id=='skip' else e['id']!='skip-story')]
  if row.id=='stick':candidates=[e for e in candidates if e['cls']=='tc-stick']
  if not candidates:errors.append((f['width'],f['mode'],row.id,'MISSING'));continue
  e=candidates[0]
  for a,b in [('x','x'),('y','y'),('w','width'),('h','height')]:
   delta=abs(row[a]-e['rect'][b]);n+=1
   if delta>.2:errors.append((f['width'],f['mode'],f['touch'],row.id,a,row[a],e['rect'][b]))
assert not errors,errors
# Physical coordinates, simultaneous fingers, cancellation and disabled controls.
for dpr in [1,2,3]:
 c=lua.table_from(dict(w=800,h=360,dpr=dpr,touchUI=True,measure=measure))
 s=lua.table_from(dict(echo=True,movable=True));obj=m.new(lua.eval('function(s)return function()return s end end')(s),lua.eval('function()end'));obj.mobile=True
 rows,_=obj.layout(obj,c);by={r.id:r for r in rows.values()};a,b=by['stick'],by['rewind']
 ax,ay=(a.x+a.w/2)*dpr,(a.y+a.h/2)*dpr;bx,byy=(b.x+b.w/2)*dpr,(b.y+b.h/2)*dpr
 assert obj.down(obj,c,ax,ay,1);assert obj.down(obj,c,bx,byy,2)
 obj.move(obj,c,ax+a.w*.32*dpr,ay,1);assert abs(obj.x-1)<1e-8 and obj.spin
 obj.up(obj,c,bx,byy,2);assert not obj.spin and abs(obj.x-1)<1e-8
 obj.cancel(obj);assert obj.x==0 and obj.y==0 and not obj.spin
 s.movable=False;rows,_=obj.layout(obj,c);assert not any(r.id=='stick'for r in rows.values());assert not obj.hit(obj,c,bx/dpr,byy/dpr)
 s.echo=False;s.movable=True;s.cycle=True;s.moveOnly=False;rows,_=obj.layout(obj,c);assert {'interact','cycle','stick'}<={r.id for r in rows.values()}
 s.moveOnly=True;s.cycle=False;rows,_=obj.layout(obj,c);assert not any(r.id in ['interact','cycle']for r in rows.values())
report=dict(result='PASS',layouts=25,geometryChecks=n,dprs=[1,2,3],input='two pointer ownership, release/cancel, disabled gates, dream move-only',notCovered=['hardware touchscreen','GPU raster equality'])
Path('docs/migration/increment03-controls-test.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
