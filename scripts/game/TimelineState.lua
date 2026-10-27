-- Native timeline.js. 3D shard transforms, source tween timing and progress gates.
local Base=require('game.DreamState')
local Nodes=require('game.data.TimelineNodes')
local Scene=require('game.data.Chapter03TimelineScene')
local T=setmetatable({},{__index=Base});T.__index=T
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function smooth(t,a,b)local k=clamp((t-a)/(b-a),0,1);return k*k*(3-2*k)end
local ease={io=function(k)return k<.5 and 4*k^3 or 1-(-2*k+2)^3/2 end,out=function(k)return 1-(1-k)^3 end,back=function(k)return 1+2.4*(k-1)^3+1.4*(k-1)^2 end}
local ASSEMBLE={['2312']={'doorL','stairsL','clockS1'},['2338']={'bridgeR','clockS2','doorS'},echo1={'clockTL','spiral'},['1447']={'clockTR','doorR','bridgeL'},echo2={'clockTL','bridgeR'},['0958']={'doorL','clockTR','spiral'},echo3={'stairsL','bridgeL','clockS2'},['0815']={'doorR','doorS','clockS1'},echo4={'spiral','bridgeR','stairsL'}}
local function mins(text)local h,m=text:match('(%d+):(%d+)');return tonumber(h)*60+tonumber(m)end
local function backTo(cur,text)return cur-((cur-mins(text))%720)end
local function fwdTo(cur,text)return cur+((mins(text)-cur)%720)end
function T.new(options)
    options=options or {};local s=setmetatable({},T);s.backLabel=options.backLabel;s.mode='timeline';s.t=0;s.phase='timeline';s.events={};s.later={};s.fired={};s.tweens={};s.transforms={};s.alphas={};s.H=copy(Scene.handles);s.nodes=Nodes;s.si=1;s.aspect=options.aspect or 16/9
    s.unlocked={};s.passed={};s.floor={};local progress=options.progress or options.save and options.save:timeline()or {nodes={'2312'},floors={}}
    for _,id in ipairs(progress.nodes)do s.unlocked[id]=true end;for id,n in pairs(progress.floors)do s.passed[id]=n end
    for i,n in ipairs(Nodes)do if n.id==options.dest and s.unlocked[n.id]then s.si=i end end
    if not s.unlocked[Nodes[s.si].id]then for i,n in ipairs(Nodes)do if s.unlocked[n.id]then s.si=i;break end end end
    for _,n in ipairs(Nodes)do if n.floors then s.floor[n.id]=math.min(n.floors-1,s.passed[n.id]or 0,n.id==options.dest and (options.floor or 0)or (s.passed[n.id]or 0))end end
    s.normi=require('game.NormiController').new(Scene.normiLayout);s.normi.visible=false
    s.phone={open=false,k=0,elapsed=0,draft='',view='lock',history={},msgs={},buttons={}};s.browse=require('game.BrowseState').new();s.phoneButtonHidden=true;s.wideFrame=0;s.dialog=false
    s.fx={blue=1,blueLo=.1,blueHi=.8,edgeK=.12,ink=0,grade={1,1,1},exposure=1,vignette=.05,kNear=18,kFar=3};s.tune=copy(require('game.data.Tuning').store);s.tune.wobble=false;s.tune.dof=false
    s.timelineSun=copy(options.timelineSun)
    s.par={x=0,y=0,tx=0,ty=0,last=-9};s:enter(options.from);return s
end
-- Data belongs to this page, not DreamState's scene.
function T:tr(id)
    if not self.transforms[id]then local n=Scene.nodes[id];self.transforms[id]={p=copy(n.position),s=copy(n.scale),r=n.rotation and copy(n.rotation) or nil,visible=n.visible}end;return self.transforms[id]
end
function T:back()self.result={back=true};self:emit('finish',{result=self.result})end
function T:canSkip()return false end
function T:controlEnabled()return false end
function T:walkEnabled()return false end
function T:cam()return false end
function T:tw(o,to,dur,options)
    options=options or {};for i=#self.tweens,1,-1 do local tw=self.tweens[i];if tw.o==o then for k in pairs(to)do if tw.to[k]~=nil then table.remove(self.tweens,i);break end end end end
    self.tweens[#self.tweens+1]={o=o,to=to,dur=math.max(dur,.001),t=-(options.delay or 0),ease=ease[options.ease or 'io'],done=options.done}
end
function T:laterAt(t,fn)self:tw({},{},.001,{delay=t,ease='out',done=fn})end
function T:stepTweens(dt)
    local list={};for i,v in ipairs(self.tweens)do list[i]=v end
    for _,tw in ipairs(list)do
        tw.t=tw.t+dt;if tw.t>=0 then
            if not tw.from then tw.from={};for k in pairs(tw.to)do tw.from[k]=tw.o[k]end end
            local k=math.min(1,tw.t/tw.dur);local v=tw.ease(k);for key,to in pairs(tw.to)do tw.o[key]=tw.from[key]+(to-tw.from[key])*v end
            if k>=1 then for i,v in ipairs(self.tweens)do if v==tw then table.remove(self.tweens,i);break end end;if tw.done then tw.done()end end
        end
    end
end
function T:rank(i)return(i-self.si+#Nodes)%#Nodes end
function T:slot(i)
    local j,s,ax=self:rank(i),self.H.shards[i],math.min(1,self.aspect/1.6)
    if j==0 then return{x=-1.85*ax,y=-1.15,z=2.1,rx=.1,ry=math.pi-.2,rz=-.05,s=3.05/s.md,fl=.35}end
    local a=math.rad(27-(j-1)*33.4);return{x=(math.cos(a)*5.7+.3)*ax,y=-math.sin(a)*3.3+.35,z=.25+math.sin(a)*.85,rx=s.wob.rx,ry=math.pi+s.wob.ry,rz=s.wob.rz,s=1.56/s.md,fl=1}
end
function T:assembleAll(all)
    local set={};for _,id in ipairs(ASSEMBLE[Nodes[self.si].id]or {})do set[id]=true end
    -- Keep JavaScript object insertion order from geometry IDs.
    local builds={};for _,s in pairs(self.H.builds)do builds[#builds+1]=s end;table.sort(builds,function(a,b)return a.grp<b.grp end)
    for i,s in ipairs(builds)do local on=all or set[s.id]or false;if ((s.a>.5)~=on)or all then self:tw(s,{a=on and 1 or 0},on and 1.3 or 1.1,{delay=(on and .1 or 0)+(i-1)*.04,ease=on and 'io'or'out'})end end
end
function T:enter(from)
    self.busy=true;self.ui={op=0};self.lab={op=0};self.camera={d=4.2,lx=0,ly=0,shake=0};self.crack={op=0};self.sw={fl=1,rg=0,ro=1}
    for _,c in ipairs(self.H.cells)do c.gap=0 end;for _,s in ipairs(self.H.shards)do s.st=copy(s.home)end;for _,s in pairs(self.H.builds)do s.a=0 end
    self:laterAt(1.1,function()self:assembleAll()end)
    local cur=Nodes[self.si];local fromTime;for _,n in ipairs(Nodes)do if n.id==from then fromTime=n.time end end
    self.clock={tm=fromTime and mins(fromTime)or mins(cur.time)+200}
    self:tw(self.sw,{fl=0},.75,{delay=.12,ease='out'});self:tw(self.sw,{rg=9,ro=0},.9,{ease='out'});self:tw(self.crack,{op=1},.22,{delay=.55})
    self:laterAt(.55,function()self.camera.shake=1;self:tw(self.camera,{shake=0},.45,{ease='out'})end)
    for _,c in ipairs(self.H.cells)do self:tw(c,{gap=1},.8,{delay=.95,ease='out'})end
    for i,s in ipairs(self.H.shards)do self:tw(s.st,self:slot(i),1,{delay=.95+self:rank(i)*.05,ease='back'})end
    self:tw(self.camera,{d=15.5},1.6,{delay=.75,ease='out'});self:tw(self.clock,{tm=backTo(self.clock.tm,cur.time)-720},1.9,{delay=.7,ease='out'});self:tw(self.lab,{op=1},.5,{delay=2})
    self:tw(self.ui,{op=1},.5,{delay=2,done=function()self.busy=false end})
end
function T:step(d)
    if self.busy then return end;local i=self.si;for _=1,#Nodes do i=(i-1+d+#Nodes)%#Nodes+1;if self.unlocked[Nodes[i].id]then break end end;self:pick(i,d>0 and -1 or 1)
end
function T:pick(i,dir)
    if self.busy or i==self.si or not Nodes[i]or not self.unlocked[Nodes[i].id]then return end
    local back=dir or(i>self.si and -1 or 1);self.si=i
    for j,s in ipairs(self.H.shards)do self:tw(s.st,self:slot(j),.62)end
    self:tw(self.clock,{tm=back<0 and backTo(self.clock.tm,Nodes[i].time)or fwdTo(self.clock.tm,Nodes[i].time)},.8);self:assembleAll()
end
function T:pickFloor(d,to)
    if self.busy then return end;local n=Nodes[self.si];if not n.floors then return end;self.floor[n.id]=clamp(to or(self.floor[n.id]+d),0,math.min(n.floors-1,self.passed[n.id]or 0))
end
function T:pointer(x,y)self.par.tx=x;self.par.ty=y;self.par.last=self.t end
function T:confirm()
    if self.busy or not self.unlocked[Nodes[self.si].id]then return end;self.busy=true;self.confirmAt=self.t
    local cur,sel=Nodes[self.si],self.H.shards[self.si];self:tw(self.ui,{op=0},.25);self:tw(self.lab,{op=0},.25)
    for i=1,#Nodes-1 do local s=self.H.shards[(self.si-1+i)%#Nodes+1];self:tw(s.st,s.home,.75,{delay=.12+(i-1)*.05})end
    self:tw(sel.st,sel.home,.8,{delay=.6});self:laterAt(.2,function()self:assembleAll(true)end)
    for _,c in ipairs(self.H.cells)do self:tw(c,{gap=0},.6,{delay=.35})end
    self:laterAt(1.38,function()self.camera.shake=.5;self:tw(self.camera,{shake=0},.3)end);self:tw(self.crack,{op=0},.4,{delay=1.45})
    self:tw(self.camera,{d=9.5,lx=sel.home.x*.5,ly=sel.home.y*.5},1.1,{delay=1.2});self:tw(self.clock,{tm=backTo(self.clock.tm,cur.time)-720},1.1,{delay=1.15})
    self:laterAt(2.15,function()self.portalAt=self.t end)
    self:laterAt(2.95,function()self.phase='done';self.result={node=cur.id,floor=cur.floors and self.floor[cur.id]or 0};self:emit('finish',{result=self.result})end)
end
function T:update(dt,ctx)
    self.t=self.t+dt;self.aspect=ctx and ctx.aspect or self.aspect;local t,P,H=self.t,self.par,self.H;self:stepTweens(dt)
    if t-P.last>2.5 then P.tx=math.sin(t*.31)*.45;P.ty=math.sin(t*.23+1)*.3 end;P.x=P.x+(P.tx-P.x)*math.min(1,dt*3);P.y=P.y+(P.ty-P.y)*math.min(1,dt*3)
    for _,c in ipairs(H.cells)do local g=c.gap;local d=math.sqrt(c.c[1]^2+c.c[2]^2);if d==0 then d=1 end;self:pos(c.m,c.c[1]+c.c[1]/d*c.push*g,c.c[2]+c.c[2]/d*c.push*g,c.z*g);self:rotate(c.m,0,0,c.rz*g)end
    for _,s in ipairs(H.shards)do local q,i=s.st,s.i;self:pos(s.grp,q.x,q.y+math.sin(t*1.1+i)*.085*q.fl,q.z);self:rotate(s.grp,q.rx+math.sin(t*.7+i)*.1*q.fl,q.ry+math.sin(t*.5+i*2)*.17*q.fl,q.rz);self:scale(s.grp,q.s)end
    self:alpha(H.crackMat,self.crack.op);self:rotate(H.hands[1],0,0,-self.clock.tm/720*math.pi*2);self:rotate(H.hands[2],0,0,-self.clock.tm/60*math.pi*2)
    for _,a in ipairs(H.arcs)do local tr=self:tr(a.m);tr.r=tr.r or{0,0,0};tr.r[3]=tr.r[3]+a.sp*dt end
    for _,s in ipairs(H.stars)do self:scale(s.m,s.s*(.55+.45*math.sin(t*2.4+s.ph)))end
    for _,s in pairs(H.builds)do for _,p in ipairs(s.pieces)do local k=smooth(1-s.a,p.lag,p.lag+.7);self:pos(p.o,p.hp[1]+p.dp[1]*k,p.hp[2]+p.dp[2]*k+math.sin(t*.6+p.ph)*.12*k,p.hp[3]+p.dp[3]*k);self:rotate(p.o,p.hr[1]+p.dr[1]*k+math.sin(t*.4+p.ph)*.1*k,p.hr[2]+p.dr[2]*k,p.hr[3]+p.dr[3]*k)end end
    for _,h in ipairs(H.handsBg)do local tr=self:tr(h.h);tr.r=tr.r or{0,0,0};tr.r[3]=tr.r[3]-h.sp*dt*.4 end
    for _,s in ipairs(H.sheets)do local tr=self:tr(s.m);tr.r=tr.r or{0,0,0};for i=1,3 do tr.r[i]=tr.r[i]+s.w[i]*dt end;tr.p[2]=s.y+math.sin(t*.4+s.ph)*.6 end
    for _,c in ipairs(H.crystals)do local tr=self:tr(c.m);tr.r=tr.r or{0,0,0};tr.r[2]=tr.r[2]+c.sp*dt;tr.p[2]=c.y+math.sin(t*c.sp+c.ph)*.3 end
end
return T
