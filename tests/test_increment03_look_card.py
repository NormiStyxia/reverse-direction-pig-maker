"""Compare native object-card layout with frozen LookCard + CSS in Chrome."""
import json
from pathlib import Path
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1];lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
m=lua.eval("require('render.LookCard')")[0];font=TTFont(root/'assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
def measure(_,t,s):return sum(font['hmtx'].metrics[cmap[ord(ch)]][0]for ch in t)*s/font['head'].unitsPerEm
fixtures=json.loads((root/'validation/increment03/look-card/h5-metrics.json').read_text());checks=0;max_error=0
for f in fixtures:
 c=lua.table_from({'w':f['width'],'h':f['height'],'touchUI':f['touch'],'measure':measure});data=lua.table_from(f['data'],recursive=True);r=m.layout(c,data)
 for field,css in [('x','cssLeft'),('y','cssTop'),('w','cssWidth'),('h','cssHeight')]:
  expected=float(f['layout'][css].removesuffix('px'));err=abs(r[field]-expected);max_error=max(max_error,err)
  assert err<.1,(f['id'],f['width'],field,r[field],expected);checks+=1
 assert r.back.h>=44 and r.back.x>=0 and r.back.y+r.back.h<=c.h;checks+=3
 c.externalHUD=True;r2=m.layout(c,data);assert r2.x>=72 and r2.y==r.y and r2.w==r.w and r2.h==r.h;checks+=4
report={'result':'PASS','source':'frozen LookCard class and current CSS in isolated Chrome','layouts':len(fixtures),'checks':checks,'maxPixelError':max_error,'nativeHomeSpace':'Only when the added home control would overlap, keep card dimensions and reserve x>=72; ordinary 16:9 desktop placement unchanged.','notCovered':['native rasterization','physical touch']}
(root/'docs/migration/increment03-look-card-test.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10));print(json.dumps(report,ensure_ascii=False,indent=2))
