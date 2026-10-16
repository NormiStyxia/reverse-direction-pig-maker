"""Check source DOM alignment and replay pointer semantics across physical DPRs."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
NVG_ALIGN_CENTER=1;NVG_ALIGN_TOP=2
function nvgRGBA(...)return {...}end
for _,k in ipairs({'BeginPath','Rect','FillColor','Fill','GlobalAlpha','TextLetterSpacing','TextAlign','Text','RoundedRect','StrokeWidth','StrokeColor','Stroke'})do _G['nvg'..k]=function(...)end end
function canvas(w,h,dpr)return {vg={},w=w,h=h,dpr=dpr,fontSize=function()end,measure=function(self,s,size)return 64 end,text=function()end}end
''')
End=lua.eval("require('render.ChapterEnd')")[0]
refs=json.loads((ROOT/'validation/chapter1/h5-end-metrics.json').read_text());checks=0
for r in refs:
    c=lua.globals().canvas(r['width'],r['height'],r['dpr']);end=End.new();end.show(end);end.update(end,2.4);end.render(end,c)
    rect=end.button;button=r['elements'][2]
    for k in ['x','y','w','h']:assert abs(rect[k]-button[k])<.01;checks+=1
    d=r['dpr'];x=(rect.x+rect.w/2)*d;y=(rect.y+rect.h/2)*d
    end.down(end,c,x,y,3);end.up(end,c,x,y,4);assert not end.replay
    end.down(end,c,x,y,3);end.up(end,c,x+9*d,y,3);assert not end.replay
    end.down(end,c,x,y,3);end.cancel(end);end.up(end,c,x,y,3);assert not end.replay
    end.down(end,c,0,0,3);end.up(end,c,x,y,3);assert not end.replay
    end.down(end,c,x,y,3);end.up(end,c,x,y,3);assert end.replay
result={'result':'PASS','viewports':len(refs),'frozenDomButtonComparisons':checks,'inputCases':15,
        'scope':'DPR hit coordinates, drag cancellation, pointer id, focus cancellation, outside presses, valid replay',
        'notCovered':['font weight and text raster parity','complete visual score']}
(ROOT/'docs/migration/chapter-end-test-report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
