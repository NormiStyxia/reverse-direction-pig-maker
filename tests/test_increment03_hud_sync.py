import json
from pathlib import Path
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
m=lua.eval("require('render.PlayerControls')")[0];font=TTFont('assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
def measure(c,t,s):return sum(font['hmtx'].metrics[cmap[ord(ch)]][0]for ch in t)*s/font['head'].unitsPerEm

# Invoke renderers with recorded NVG calls; this catches missing APIs/state fields.
record=[]
for name in ['nvgSave','nvgRestore','nvgBeginPath','nvgRect','nvgRoundedRect','nvgCircle','nvgEllipse','nvgMoveTo','nvgLineTo','nvgFill','nvgStroke','nvgFillColor','nvgStrokeColor','nvgStrokeWidth','nvgGlobalAlpha','nvgFontBlur']:
 lua.globals()[name]=lambda *args,_name=name:record.append((_name,args))
lua.globals().nvgRGBA=lambda *args:lua.table_from(args)
c=lua.table_from(dict(w=1200,h=540,dpr=2,vg=1,measure=measure));c.text=lambda *args:record.append(('text',args))
Cap=lua.eval("require('render.CaptionOverlay')")[0]
for mode in ['meeting','morning','dorm']:
 name='DormState' if mode=='dorm' else 'Chapter1State'
 v=lua.eval("require('game."+name+"')");S=v[0] if isinstance(v,tuple)else v
 state=S.new(lua.table_from(dict(mode=mode)));state.clockShow=True;state.t=10
 Cap.clock(c,state);state.t=11;Cap.clock(c,state)
 assert any(x[0]=='text'for x in record)
# Tag approach, leave, merge labels, and room replacement.
E=lua.eval("require('render.EchoOverlay')")[0];Run=lua.eval("require('game.EchoRun')")[0];Catalog=lua.eval("require('game.LevelCatalog')")[0]
for theme in ['meeting','office','dorm']:
 level=Catalog.find(theme)[0];run=Run.new(level.levels,theme);run.answer=level.answer
 run.phase='play';first=run.sim.room.crates[1];run.pig.pos.x=first.x;run.pig.pos.z=first.z
 screen=lua.table_from(dict(run=run,elapsed=0,w=1200,h=540,vg=1,measure=measure,text=c.text,projectTag=lambda crate:(.5,.5)))
 E.update(screen,.05);assert screen.tags[first]>.0;E.crateTags(screen)
 run.pig.pos.x=100;run.pig.pos.z=100;old=screen.tags[first];E.update(screen,.05);assert screen.tags[first]<old
 run.loadId=run.loadId+1;E.update(screen,.05);assert screen.tags[first]==0
print('PASS: clocks for meeting/morning/dorm; native tag drawing, distance fade and level reset')
