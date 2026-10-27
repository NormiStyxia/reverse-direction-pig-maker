-- Native NVG projection labels and input over the actual 3D shards.
local Overlay={}
local BLUE={1,64,196,255};local PAPER={251,252,255,255};local PALE={79,105,179,255};local SKY={53,121,241,255}
local function rect(c,x,y,w,h,color)
 local vg=c.vg;nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,nvgRGBA(table.unpack(color)));nvgFill(vg)
end
local function normalHeight(size)return math.floor(size*.928+.5)+math.floor(size*.256+.5)end
local function trackedWidth(c,text,size,spacing,mono)
 return (mono and (utf8.len(text)or 0)*size*.6 or c:measure(text,size))+(utf8.len(text)or 0)*(spacing or 0)
end
local function ink(c,text,x,y,size,color,spacing,bold,mono)
 local function glyph(t,xx)
  c:text(t,xx,y,size,color)
  -- Keep a single coverage pass: repeated fills darken NVG antialiasing,
  -- even with zero offset. Use the original shipped WenKai glyphs.
 end
 if not spacing and not mono then glyph(text,x);return end
 -- Canvas:text resets NVG spacing. Explicit advances also keep deployment
 -- independent of the workstation's proprietary Menlo font.
 for _,cp in utf8.codes(text)do local ch=utf8.char(cp);glyph(ch,x);x=x+(mono and size*.6 or c:measure(ch,size))+(spacing or 0)end
end
local function outline(c,text,x,y,size,fg,bg,r,spacing,bold,mono)
 for _,p in ipairs({{-r,0},{r,0},{0,-r},{0,r},{-r,-r},{r,r},{-r,r},{r,-r}})do ink(c,text,x+p[1],y+p[2],size,bg,spacing,bold,mono)end
 ink(c,text,x,y,size,fg,spacing,bold,mono)
end
local function border(c,x,y,w,h,color,width)
 local vg=c.vg;nvgBeginPath(vg);nvgRect(vg,x+width/2,y+width/2,w-width,h-width);nvgStrokeWidth(vg,width);nvgStrokeColor(vg,nvgRGBA(table.unpack(color)));nvgStroke(vg)
end
local function overlap(a,b)return a.x<b.x+b.w+6 and a.x+a.w>b.x-6 and a.y<b.y+b.h+6 and a.y+a.h>b.y-6 end
function Overlay.attach(c,view,story)
 local s={canvas=c,view=view,story=story,hits={},press=false};c.timeline=s
 c.sceneActions=false
 c.cancelPointer=function()s.press=false end
 c.pointerDown=function(_,x,y,id)if type(id)=='number'then c.touchUI=true end;if s.press then return true end;s.press={x=x/c.dpr,y=y/c.dpr,id=id};return true end
 c.pointerMove=function(_,x,y,id)if id=='mouse'then story:pointer(x/c.dpr/c.w*2-1,y/c.dpr/c.h*2-1)end;return true end
 c.pointerUp=function(_,x,y,id)
  local p=s.press;if not p or p.id~=id then return true end;s.press=false;x=x/c.dpr;y=y/c.dpr;local dx,dy=x-p.x,y-p.y
  if math.abs(dx)>50 and math.abs(dx)>math.abs(dy)then story:step(dx<0 and 1 or -1);return true end
  if math.abs(dy)>50 then story:pickFloor(dy<0 and 1 or -1);return true end
  for i=#s.hits,1,-1 do local b=s.hits[i];if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then b.action();return true end end
  if story.busy then return true end;local i=view:hitShard(x/c.w,y/c.h);if i then if i==story.si then story:confirm()else story:pick(i)end end;return true
 end
 c.sceneHUD=function(canvas)Overlay.draw(s,canvas)end
end
function Overlay.draw(state,c)
 local s,v=state.story,state.view;local vg=c.vg;state.hits={};if not v.ready then c:text('正在加载…',20,20,16,BLUE);return end
 local wide=c.w/c.h>=2;local compact=wide or(c.touchUI and c.h<=600 and c.w>c.h);local small=c.h<=520;local mobile=c.touchUI;local reserved={}
 local function hit(x,y,w,h,action)if s.ui.op<=.5 then return end;state.hits[#state.hits+1]={x=x,y=y,w=w,h=h,action=action}end
 local buttonSize=wide and 12 or compact and 13 or small and 16 or 20
 local function button(label,x,y,w,h,action,primary)
  local spacing=buttonSize*(primary and .2 or .06)
  rect(c,x,y,w,h,primary and BLUE or {251,252,255,230});border(c,x,y,w,h,BLUE,2)
  ink(c,label,x+(w-trackedWidth(c,label,buttonSize,spacing))/2,y+(h-normalHeight(buttonSize))/2,buttonSize,primary and PAPER or BLUE,spacing,true)
  hit(x,y,w,h,action);reserved[#reserved+1]={x=x,y=y,w=w,h=h}
 end
 nvgSave(vg);nvgGlobalAlpha(vg,s.ui.op)
 local hy=math.max(12,c.h*.04);local hx=wide and 64 or mobile and 68 or math.max(16,c.w*.035)
 outline(c,'‹',mobile and 24 or 12,hy+7,30,BLUE,PAPER,2);hit(mobile and 12 or 8,hy,mobile and 44 or 28,44,function()s:back()end);reserved[#reserved+1]={x=mobile and 12 or 8,y=hy,w=mobile and 44 or 28,h=44}
 local hs=wide and 10 or small and 11 or 18;local cs=wide and 11 or small and 12 or 20
 outline(c,'TIME REWIND',hx,hy,hs,BLUE,PAPER,2,hs*.3,false,true)
 local lineY=hy+normalHeight(hs)+10;rect(c,hx-2,lineY-2,30,6,PAPER);rect(c,hx,lineY,26,2,BLUE)
 outline(c,'时间回溯',hx,lineY+10,cs,BLUE,PAPER,2,cs*.4)
 reserved[#reserved+1]={x=hx,y=hy,w=trackedWidth(c,'TIME REWIND',hs,hs*.3,true),h=lineY+10+normalHeight(cs)-hy}
 if mobile then
  local n=s.nodes[s.si];local items={{'‹',function()s:step(-1)end}};if n.floors then items[#items+1]={'▼',function()s:pickFloor(-1)end}end
  items[#items+1]={'回到那一刻',function()s:confirm()end,true};if n.floors then items[#items+1]={'▲',function()s:pickFloor(1)end}end;items[#items+1]={'›',function()s:step(1)end}
  local gap=compact and 8 or 10;local total=-gap;local px=small and 11 or 16
  local bh=math.max(44,normalHeight(buttonSize)+(small and 12 or 16)+4)
  for _,b in ipairs(items)do b.w=math.max(small and 42 or 52,trackedWidth(c,b[1],buttonSize,buttonSize*(b[3]and .2 or .06))+px*2+4);total=total+b.w+gap end
  local x=c.w-(compact and 12 or math.max(12,c.w*.025))-total;local y=c.h-(compact and 10 or math.max(10,c.h*.03))-bh
  for _,b in ipairs(items)do button(b[1],x,y,b.w,bh,b[2],b[3]);x=x+b.w+gap end

 else
  local sz=wide and 12 or 15;local gap=wide and 12 or 18;local groups={{{'A','D'},'换一块'},{{'W','S'},'选层'},{{'F'},'回到那一刻'}};local total=-gap
  for _,g in ipairs(groups)do g.w=#g[1]*23+trackedWidth(c,g[2],sz,sz*.1);total=total+g.w+gap end
  local x=c.w-math.max(16,c.w*.03)-total
  for _,g in ipairs(groups)do
   for _,key in ipairs(g[1])do rect(c,x,hy,18,18,PAPER);border(c,x,hy,18,18,BLUE,1);ink(c,key,x+(18-trackedWidth(c,key,11,1.1,true))/2,hy+(18-normalHeight(11))/2,11,BLUE,1.1,false,true);x=x+23 end
   outline(c,g[2],x,hy+(18-normalHeight(sz))/2,sz,BLUE,PAPER,2,sz*.1);x=x+trackedWidth(c,g[2],sz,sz*.1)+gap
  end
 end
 nvgRestore(vg)
 local labels={}
 for i,n in ipairs(s.nodes)do local sh=s.H.shards[i];local q=sh.st;local x,y=v:project(q.x,q.y-sh.h*q.s*.55-.18,q.z);x=x*c.w;y=y*c.h
  local big=i==s.si;local rank=s:rank(i);local near=rank==1 or rank==#s.nodes-1;local on=s.unlocked[n.id]
  local size=wide and(big and 18 or near and on and 12 or 10)or small and(big and 30 or near and on and 15 or 13)or(big and 46 or near and(on and 22 or 18)or(on and 19 or 17))
  if compact and not wide and big then size=20 end
  local text=on and n.time or '--:--';local sub=(on and(big or near)or not on and near)and(on and n.place or n.lock)or '';local subsize=size*.66
  local tw=c:measure(text,size);local pad=size*.2;local w=tw+(sub~=''and trackedWidth(c,sub,subsize,subsize*.1)+subsize*.5 or 0)+pad*2;local h=size*1.4
  local chip=compact and 32 or size*.46*1.15;local chipGap=compact and 6 or size*.22;local cw=n.floors and big and on and(n.floors*(chip+chipGap)-chipGap)or 0
  if cw>0 then if compact then h=h+chip+6;w=math.max(w,cw+pad*2)else w=w+cw+size*.7 end end
  x=math.floor(x*10+.5)/10-w/2;y=math.floor(y*10+.5)/10
  if compact and big then x=16;y=c.h-(mobile and 72 or 32)-h end
  labels[#labels+1]={i=i,x=x,y=y,w=w,h=h,size=size,big=big,on=on,text=text,sub=sub,subsize=subsize,tw=tw,chip=chip,chipGap=chipGap,cw=cw,pad=pad,angle=compact and big and 0 or(i%2==0 and 1.5 or -1.5)*math.pi/180}

 end
 if compact then
  reserved[#reserved+1]=labels[s.si]
  local order={};for _,b in ipairs(labels)do if not b.big then order[#order+1]=b end end;table.sort(order,function(a,b)return a.y<b.y end)
  for _,b in ipairs(order)do
   b.x=math.max(8,math.min(c.w-b.w-8,b.x));local candidates={0,8-b.y,c.h-8-b.y-b.h};for _,r in ipairs(reserved)do candidates[#candidates+1]=r.y-b.y-b.h-7;candidates[#candidates+1]=r.y+r.h-b.y+7 end
   table.sort(candidates,function(a,b)return math.abs(a)<math.abs(b)end);local found=false
   for _,dy in ipairs(candidates)do local test={x=b.x,y=b.y+dy,w=b.w,h=b.h};local ok=test.y>=8 and test.y+test.h<=c.h-8;for _,r in ipairs(reserved)do if overlap(test,r)then ok=false;break end end;if ok then b.y=test.y;found=true;break end end
   b.hidden=not found;if found then reserved[#reserved+1]=b end
  end
 end
 state.labelBoxes=labels
 if s.backLabel then outline(c,s.backLabel,58,hy+15,12,BLUE,PAPER,2)end
 nvgSave(vg);nvgGlobalAlpha(vg,s.lab.op)
 -- Frozen .big has z-index:2. Draw/hit its chips above every other label.
 local paintOrder={};for _,b in ipairs(labels)do if not b.big then paintOrder[#paintOrder+1]=b end end
 paintOrder[#paintOrder+1]=labels[s.si]
 for _,b in ipairs(paintOrder)do if not b.hidden then
  local n=s.nodes[b.i];local fg=b.big and PAPER or b.on and BLUE or PALE
  nvgSave(vg);nvgTranslate(vg,b.x+b.w/2,b.y+b.h/2);nvgRotate(vg,b.angle);nvgTranslate(vg,-b.w/2,-b.h/2)
  local tx=b.pad;local ty=b.size*.1+(b.size*1.2-normalHeight(b.size))/2
  if b.big then outline(c,b.text,tx,ty,b.size,fg,PAPER,compact and 2 or 6,nil,true);outline(c,b.text,tx,ty,b.size,fg,BLUE,compact and 1 or 3,nil,true)
  else outline(c,b.text,tx,ty,b.size,fg,PAPER,4,nil,true)end
  if b.sub~=''then
   local sx=tx+b.tw+b.subsize*.5;local sy=ty+math.floor(b.size*.928+.5)-math.floor(b.subsize*.928+.5)
   outline(c,b.sub,sx,sy,b.subsize,fg,PAPER,b.big and not compact and 6 or 4,b.subsize*.1,true)
   if b.big then outline(c,b.sub,sx,sy,b.subsize,fg,BLUE,compact and 1 or 3,b.subsize*.1,true)end
  end
  if s.lab.op>.5 then hit(b.x,b.y,b.w,b.h,function()if b.i==s.si then s:confirm()else s:pick(b.i)end end)end
  if b.cw>0 then
   local x=compact and b.pad or b.w-b.pad-b.cw;local y=compact and b.size*1.3+6 or b.size*.1+(b.size*1.2-b.chip)/2;local passed=s.passed[n.id]or 0
   for k=0,n.floors-1 do local color=k<passed and BLUE or k==passed and SKY or PAPER;local xk=x+k*(b.chip+b.chipGap)
    nvgSave(vg);if k>passed then nvgGlobalAlpha(vg,s.lab.op*.4)end
    if k==s.floor[n.id]then border(c,xk-5,y-5,b.chip+10,b.chip+10,SKY,3)end
    rect(c,xk,y,b.chip,b.chip,color);border(c,xk,y,b.chip,b.chip,k==passed and SKY or BLUE,2)
    local fs=compact and 12 or b.size*.46
    ink(c,tostring(k+1),xk+(b.chip-trackedWidth(c,tostring(k+1),fs,0,true))/2,y+(b.chip-normalHeight(fs))/2,fs,k<=passed and PAPER or BLUE,0,true,true)
    nvgRestore(vg)
    if k<=passed and s.lab.op>.5 then
     local dx,dy=xk+b.chip/2-b.w/2,y+b.chip/2-b.h/2;local cx=b.x+b.w/2+dx*math.cos(b.angle)-dy*math.sin(b.angle);local cy=b.y+b.h/2+dx*math.sin(b.angle)+dy*math.cos(b.angle)
     hit(cx-b.chip/2,cy-b.chip/2,b.chip,b.chip,function()s:pickFloor(0,k)end)
    end
   end
  end
  nvgRestore(vg)

 end end
 nvgRestore(vg)
 if s.sw.fl>.001 then nvgSave(vg);nvgGlobalAlpha(vg,s.sw.fl);rect(c,0,0,c.w,c.h,PAPER);nvgRestore(vg)end
 if s.sw.ro>.001 and s.sw.rg>0 then
  nvgSave(vg);nvgGlobalAlpha(vg,s.sw.ro);nvgBeginPath(vg);nvgCircle(vg,c.w/2,c.h/2,math.max(0,100-20/math.max(1,s.sw.rg*.6))*s.sw.rg)
  nvgStrokeWidth(vg,40/math.max(1,s.sw.rg*.6)*s.sw.rg);nvgStrokeColor(vg,nvgRGBA(table.unpack(BLUE)));nvgStroke(vg);nvgRestore(vg)
 end
 -- Frozen portal uses the node's source image only during transition, not for the 3D page.
 if s.portalAt then local k=require('game.TitlePresentation').bezier(math.min(1,(s.t-s.portalAt)/.8),.6,0,.3,1);local sh=s.H.shards[s.si];local x,y=v:project(sh.home.x,sh.home.y,0);local r=math.sqrt(c.w^2+c.h^2)*k;nvgSave(vg);nvgBeginPath(vg);nvgCircle(vg,x*c.w,y*c.h,r);local path='timeline/'..s.nodes[s.si].id..'.jpg';local im=c.images[path]
  c:image(path,-10000,-10000,1,1);im=c.images[path];if im and im.id>0 then local scale=math.max(c.w/im.w,c.h/im.h);nvgBeginPath(vg);nvgCircle(vg,x*c.w,y*c.h,r);nvgFillPaint(vg,nvgImagePattern(vg,(c.w-im.w*scale)/2,(c.h-im.h*scale)/2,im.w*scale,im.h*scale,0,im.id,1));nvgFill(vg)end;nvgRestore(vg)
 end
end
return Overlay
