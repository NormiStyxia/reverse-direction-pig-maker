-- Native projection labels and original-colour avatar, drawn after scene grading.
local Top={};Top.__index=Top
local CRATE={card={'纸箱','会倒带'},gold={'金色箱子','不倒带'},past={'下午的档案盒','会倒带'},tonight={'今晚的投影','不倒带 · 没重量'},now={'现在的档案盒','不倒带 · 有重量'},plain={'文件筐','会倒带'},bag={'外卖袋 · 投影','不倒带 · 没重量'},parcel={'闪送纸箱','会倒带 · 有重量'}}
local PLATE={plain={'光斑','要有重量才压得下'},gold={'金色光斑','只认金色的'},holo={'全息感应板','只认今晚的投影'},lock={'死锁板','压上就锁死'},power={'断电板','压着就断电'}}
local function smooth(x,a,b)local k=math.max(0,math.min(1,(x-a)/(b-a)));return k*k*(3-2*k)end
function Top.new(view,run)return setmetatable({view=view,run=run,spin=0},Top)end
function Top:project(c,x,y,z)local p=self.view.view.camera:WorldToScreenPoint(Vector3(x,y,-z));return p.x*c.w,p.y*c.h end
function Top:update(dt)
 local p=self.run.pig
 self.spin=p.spinning and self.spin+dt*p.spinSpeed*9*(p.spinDir or 1)or self.spin*math.max(0,1-dt*8)
end
function Top:render(c)
 local k=self.view.topK or 0;if k<.36 then return end
 local r=self.run;local vg=c.vg;local show=smooth(k,.35,.65);local p=r.pig;local x,y=self:project(c,p.pos.x,1.6,p.pos.z)
 -- A sprite spans the camera plane, not the foreshortened world-Y axis.
 local camera=self.view.view.camera;local depth=self.view.view.cameraNode:WorldToLocal(Vector3(p.pos.x,1.6,-p.pos.z)).z
 local size=1.45*c.h/(2*math.max(.01,depth)*math.tan(math.rad(camera.fov)/2))*show*(1+(p.charge>0 and .12 or 0))*(1+math.max(0,p.squash or 0)*.08)
 nvgSave(vg);nvgTranslate(vg,x,y);nvgRotate(vg,self.spin);c:image('increment04/pig-top-avatar.png',-size/2,-size/2,size,size);nvgRestore(vg)
 local dir=p.dir;local ax,ay=self:project(c,p.pos.x+dir.x*.95,.12,p.pos.z+dir.z*.95);local bx,by=self:project(c,p.pos.x,0,p.pos.z)
 local a=math.atan(ay-by,ax-bx);nvgSave(vg);nvgTranslate(vg,ax,ay);nvgRotate(vg,a);nvgBeginPath(vg);nvgMoveTo(vg,8,0);nvgLineTo(vg,-5,-5);nvgLineTo(vg,-5,5);nvgClosePath(vg);nvgFillColor(vg,nvgRGBA(255,203,79,220));nvgFill(vg);nvgRestore(vg)
 local alpha=smooth(k,.55,.95);if alpha<=.01 then return end
 local items={};local room=r.sim.room;local level=r.levels[r.index]
 local function add(obj,name,rule,height,on)local x,y=self:project(c,obj.x,height or .9,obj.z);items[#items+1]={x=x,y=y,name=name,rule=rule,on=on}end
 for _,v in ipairs(room.crates)do if not v.gone then local q=CRATE[v.kind]or CRATE[v.gold and 'gold'or 'card'];add(v,q[1]..(v.origin=='b'and ' B'or r.theme=='office'and v.origin=='a'and ' A'or ''),v.phased and '断电 · 可穿过'or q[2])end end
 for _,v in ipairs(room.cabinets)do add(v,({store='高货架',dorm='衣帽架'})[r.theme]or '白板',v.a>.8 and '倒下了 · 会倒带'or v.auto and '会自己倒 · 会倒带'or '撞倒它 · 会倒带',1.2)end
 local function contains(list,i)for _,v in ipairs(list or {})do if v==i then return true end end end
 local groups={}
 for i,v in ipairs(room.plates)do
  local role=contains(level.door.plates,i-1)and '开门'or contains(level.exitPlates,i-1)and '亮出口'or contains(level.door.lockPlates,i-1)and '锁门'or contains(level.exitLockPlates,i-1)and '锁出口'or ''
  local group;for _,g in ipairs(groups)do if (g.pos.x-v.x)^2+(g.pos.z-v.z)^2<.09 then group=g end end
  if not group then group={pos=v,parts={},roles={},on=true};groups[#groups+1]=group end
  group.parts[#group.parts+1]=v;group.roles[role]=role~='';group.on=group.on and v.pressed
 end
 for _,g in ipairs(groups)do
  local v=g.parts[1];local q=PLATE[v.type]or PLATE.plain;local name,rule=q[1],q[2]
  if v.type=='gold'and r.theme~='store'then rule='只认「现在」的'end
  if #g.parts>1 then name='全息环 + 金芯';rule='外圈认今晚的投影 · 中间认「现在」的'end
  local roles={};for name,on in pairs(g.roles)do if on then roles[#roles+1]=name end end;table.sort(roles)
  add(g.pos,name..(#roles>0 and ' → '..table.concat(roles,' / ')or ''),rule,.1,g.on)
 end
 if #(level.door.plates or {})>0 then add({x=level.door.x,z=level.partition},level.door.kind=='holo'and '光幕门'or '门',room.doorOpen>.5 and '开着'or '关着',1.2,room.doorOpen>.5)end
 add({x=level.exit[1],z=level.exit[2]},'出口',r.sim:exitOn()and '亮了 · 走进去'or '还没亮',.2,r.sim:exitOn())
 local x0,x1=math.huge,-math.huge
 for _,p in ipairs({{-8,-6},{8,-6},{-8,5},{8,5}})do local x=self:project(c,p[1],0,p[2]);x0=math.min(x0,x);x1=math.max(x1,x)end
 local wide=c.w/c.h>=2;local fs=wide and 11 or 12;local mid=(x0+x1)/2;local Layout=require('game.StoryPanelLayout')
 nvgSave(vg);nvgGlobalAlpha(vg,alpha)
 for _,side in ipairs({-1,1})do
  local list={};for _,it in ipairs(items)do if (it.x<mid and -1 or 1)==side then list[#list+1]=it end end
  table.sort(list,function(a,b)return a.y<b.y end)
  local maxW=math.max(110,math.min(wide and 180 or 210,c.w*.23));local top=64
  for _,it in ipairs(list)do
   it.lines=Layout.wrap(it.rule,maxW-12,fs,function(t,z)return c:measure(t,z)end);it.names=Layout.wrap(it.name,maxW-12,fs,function(t,z)return c:measure(t,z)end)
   it.h=(#it.lines+#it.names)*(fs+3)+10;it.ty=math.max(top,it.y-it.h/2);top=it.ty+it.h+6
  end
  local bottom=c.h-(c.touchUI and 92 or 44)
  for i=#list,1,-1 do local it=list[i];it.ty=math.min(it.ty,bottom-it.h);bottom=it.ty-6 end
  -- Dense mobile rows keep the UI readable: use available height instead of overlap.
  for _,it in ipairs(list)do
   local lx=side<0 and math.max(8,x0-22-maxW)or math.min(c.w-8-maxW,x1+22);local edge=side<0 and lx+maxW or lx;local cy=it.ty+it.h/2
   nvgBeginPath(vg);nvgMoveTo(vg,it.x,it.y);nvgLineTo(vg,edge-side*16,cy);nvgLineTo(vg,edge,cy);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(240,230,202,220));nvgStroke(vg)
   nvgBeginPath(vg);nvgCircle(vg,it.x,it.y,3);nvgFillColor(vg,nvgRGBA(255,220,140,255));nvgFill(vg)
   nvgBeginPath(vg);nvgRoundedRect(vg,lx,it.ty,maxW,it.h,4);nvgFillColor(vg,nvgRGBA(249,244,228,235));nvgFill(vg)
   local y=it.ty+5;for _,t in ipairs(it.names)do c:text(t,lx+6,y,fs,it.on and {137,92,16,255}or {43,33,29,255});y=y+fs+3 end
   for _,t in ipairs(it.lines)do c:text(t,lx+6,y,fs,{94,80,62,255});y=y+fs+3 end
  end
 end
 nvgRestore(vg)
end
return Top
