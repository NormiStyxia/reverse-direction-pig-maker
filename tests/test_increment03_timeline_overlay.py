"""Exercise actual NVG hit dispatch at both layouts, without pretending to render."""
from lupa.lua54 import LuaRuntime
lua=LuaRuntime();lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
for _,name in ipairs({'nvgBeginPath','nvgRect','nvgFillColor','nvgFill','nvgStrokeWidth','nvgStrokeColor','nvgStroke','nvgSave','nvgRestore','nvgGlobalAlpha','nvgTranslate','nvgRotate'})do _G[name]=function()end end
nvgRGBA=function(...)return{...}end
local Overlay=require('render.TimelineOverlay');local Nodes=require('game.data.TimelineNodes')
for _,config in ipairs({{1280,720,false,1},{1200,540,true,2},{800,450,true,3},{640,360,true,2}})do
 local w,h,touch,dpr=table.unpack(config)
 local c={vg=1,w=w,h=h,dpr=dpr,touchUI=touch,text=function()end,measure=function(_,text,size)return utf8.len(text)*size*.6 end}
 local s={nodes=Nodes,si=3,ui={op=1},lab={op=1},sw={fl=0,ro=0},H={shards={}},unlocked={},passed={},floor={},events={}}
 function s:rank(i)return(i-self.si)%#self.nodes end
 function s:pick(i)self.si=i end
 function s:pickFloor(delta,k)self.floor[self.nodes[self.si].id]=k or(self.floor[self.nodes[self.si].id]+delta)end
 function s:confirm()self.confirmed=true end
 function s:step(i)self.si=(self.si-1+i)%#self.nodes+1 end
 function s:emit(k,v)self.events[#self.events+1]=k end
 for i,n in ipairs(Nodes)do s.H.shards[i]={st={x=(i-1)/9,y=.3,z=0,s=1},h=.1};s.unlocked[n.id]=true;s.floor[n.id]=0;s.passed[n.id]=n.floors or 0 end
 local view={ready=true,project=function(_,x,y,z)return x,.3 end,hitShard=function()return nil end}
 Overlay.attach(c,view,s);Overlay.draw(c.timeline,c)
 assert(#c.timeline.labelBoxes==9)
 for _,b in ipairs(c.timeline.hits)do assert(b.w>0 and b.h>0)end
 local hits=c.timeline.hits;local floorCount=Nodes[s.si].floors
 for k=0,floorCount-1 do
  local b=hits[#hits-floorCount+1+k];local x,y=(b.x+b.w/2)*dpr,(b.y+b.h/2)*dpr
  c:pointerDown(x,y,'mouse');c:pointerUp(x,y,'mouse');assert(s.floor[Nodes[s.si].id]==k,'Rotated floor hit mismatch')
 end
 local back=hits[1];local x,y=(back.x+back.w/2)*dpr,(back.y+back.h/2)*dpr
 c:pointerDown(x,y,1);c:cancelPointer();c:pointerUp(x,y,1);assert(not s.result,'Cancelled pointer activated back')
 c:pointerDown(x,y,1);c:pointerUp(x,y,1);assert(s.result.back)
 s.ui.op=0;s.lab.op=0;Overlay.draw(c.timeline,c);assert(#c.timeline.hits==0,'Invisible UI remains clickable')
end
''')
print('PASS: desktop/wide/touch layouts; DPR 1/2/3; all floor chips; arrow, cancellation, invisible hit gating')
