-- Frozen dream.js: native interaction/state and animated 3D transforms.
local Human=require('game.Chapter1State')
local Data=require('game.data.Story03Data')
local Scene=require('game.data.Chapter03DreamScene')
local State=setmetatable({},{__index=Human});State.__index=State
local L=Data.DREAM_LINES
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function vec(x,y,z)return{x=x or 0,y=y or 0,z=z or 0}end
local function clamp(t,a,b)return math.max(a,math.min(b,t))end
local function mix(a,b,k)return a+(b-a)*k end
local function smooth(t,a,b)local k=clamp((t-a)/(b-a),0,1);return k*k*(3-2*k)end
local function xyz(a)return vec(a[1],a[2],a[3])end
local function lerp(a,b,k)return vec(mix(a.x,b.x,k),mix(a.y,b.y,k),mix(a.z,b.z,k))end
local function len(a,b)return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)end
local STROBE={.12,.26,.38,.48,.56,.63,.69,.74,.78,.82,.86}
function State.new(options)
    options=options or {};local s=setmetatable({},State)
    s.mode='dream';s.t=options.deferIntro and -1.3 or 0;s.phase='intro';s.later={};s.fired={};s.events={};s.random=options.random or math.random;s.dialogTheme='dream'
    s.normi=require('game.NormiController').new(Scene.normiLayout,s.random);s.normi.obstacles=Scene.obstacles;s.normi.bounds=Scene.bounds;s.normi:setPosition(table.unpack(Scene.start));s.normi.side=1;s.normi.visible=false
    s.phone={open=false,k=0,elapsed=0,view='chat',time='23:12',battery=23,draft='',msgs={},history={},buttons={},contact=Data.OFFICE_LINES.group,subtitle=Data.OFFICE_LINES.groupSub,recallable={}}
    s.browse=require('game.BrowseState').new();s.phoneButtonHidden=true;s.interactionAt=-99;s.wideFrame=0;s.tune=require('game.data.Tuning').store;s.clockMin=1392;s.clockShow=false
    s.fx={desat=0,vignette=.12,kFar=9,kNear=26,grade={1,1,1},exposure=1,haze=0,blue=1,blueLo=.1,blueHi=.78,ink=0,edgeK=.12};s.near=0;s.moved=0;s.breakT=0;s.result=false
    s.H=copy(Scene.handles);s.transforms={};s.alphas={};s.guideVisible=false;s.camLook=vec(-13.4,2.5,.7);s.ringV=.05;s.layerK=0;s.layerV=0;s.pigK=0;s.garbleT=0
    s.gp={x=0,z=-.45,y=0,vx=0,vz=0,spinT=0,spinLeft=0,waitT=0,drop=-1,frame=1};s.rawHistory={}
    for _,h in ipairs(Data.OFFICE_LINES.history)do s.rawHistory[#s.rawHistory+1]={name=h.from.name,avatar=h.from.avatar,stamp=h.stamp,text=h.text}end
    local msg=Data.OFFICE_LINES.msg;s.rawHistory[#s.rawHistory+1]={name=msg.from.name,avatar=msg.from.avatar,stamp='23:20',text=msg.text}
    for _,m in ipairs({{'领导','./assets/ch1/avatar-leader.png','第 14 页那个循环图，改成闭环箭头试试'},{'小周','./assets/ch1/avatar-zhou.jpg','诺米，新手引导二期那块配表你今晚能给吗'},{'领导','./assets/ch1/avatar-leader.png','诺米，第 14 页——','23:50'}})do s.rawHistory[#s.rawHistory+1]={name=m[1],avatar=m[2],text=m[3],stamp=m[4]}end
    s.phone.history=copy(s.rawHistory)
    s:tr(s.H.heroHands[1].h).r={0,0,-1.1};s:tr(s.H.heroHands[2].h).r={0,0,.4}
    s:begin();s:assemble(0);return s
end
function State:tr(id)
    if not self.transforms[id]then local n=Scene.nodes[id];self.transforms[id]={p=copy(n.position),s=copy(n.scale),r=n.rotation and copy(n.rotation) or nil,visible=n.visible}end
    return self.transforms[id]
end
function State:rotate(id,x,y,z)self:tr(id).r={x,y,z}end
function State:pos(id,x,y,z)self:tr(id).p={x,y,z}end
function State:scale(id,x,y,z)self:tr(id).s={x,y or x,z or x}end
function State:visible(id,v)self:tr(id).visible=v end
function State:alpha(id,a)self.alphas[id]=a end
function State:mat(id)return Scene.nodes[id].materials[1]end
function State:faceFrame()return false end
function State:controlEnabled()return (self.phase=='walk' or self.phase=='pigwalk') and not self.phone.open end
function State:walkEnabled()return self.phase=='walk' and not self.phone.open end
function State:nearbyInteractions()return {}end
function State:cycleInteraction()end
function State:interact()end
function State:onBrowse()end
function State:onPanel(id)self:onPhone(id)end
function State:cam()return self.cameraRequest end
function State:say(text,face)self:think(text);self.dialog.face=face or 'puzzled';self.dialog.stamp=''end
function State:tone(f,dur,gain,wave,slide)self:emit('tone',{frequency=f,dur=dur,gain=gain,wave=wave or 'sine',slide=slide or 0})end
function State:begin()
    self.tickT=.6;self.swellT=1.2;self.tock=false
    local lead=-self.t;local function at(t,f)self:after(lead+t,f)end
    for _,t in ipairs({.7,1.7})do at(t,function()self:tr(self.H.heroHands[2].h).r[3]=self:tr(self.H.heroHands[2].h).r[3]-math.pi/30;self:tone(2600,.02,.02,'square')end)end
    at(2.4,function()self:emit('flash',{amount=.18});self:emit('shake',{amount=.06});self:tone(3400,.05,.03,'square');self:tone(900,.3,.03,'triangle',.4)end)
    at(3,function()
        self:emit('dreamSound',{name='burst'})
        self:emit('flash',{amount=.3});self:emit('shake',{amount=.16})
        for _,b in ipairs(self.H.heroBits)do local k=(1+self.random()*1.2)*(1.6-b.dist*.5);b.vel={b.dir[1]*k,b.dir[2]*k+.5,.6+self.random()*1.6}end
        for _,h in ipairs(self.H.heroHands)do h.vel={(self.random()-.5)*2,1+self.random(),1.5};h.spin=(self.random()-.5)*14 end
        for _,a in ipairs(self.H.heroArcs)do a.vel={(self.random()-.5)*1.5,(self.random()-.5)*1.5,1+self.random()}end
        for _,s in ipairs(self.H.heroStars)do local p=self:tr(s.m).p;local d=math.sqrt(p[1]^2+p[2]^2);local k=(1.5+self.random()*2)/d;s.vel={p[1]*k,p[2]*k,1+self.random()}end
    end)
    at(3.3,function()self:tone(52,1.6,.12,'triangle',.7)end)
    at(4.6,function()self:emit('dreamSound',{name='hold'})end)
    at(8.3,function()self.normi.visible=true;self.normi:flinch(.55);self:sound('tap');self:emit('shake',{amount=.05})end)
    at(9.3,function()self.normi:face(-1)end);at(9.4,function()self.normi:face(1)end)
    at(9.6,function()self:say(L.where)end);at(11,function()self:say(L.lost)end);at(12.6,function()self:openPhone()end)
end
function State:canSkip()return self.phase~='break' and self.phase~='done'end
function State:skip()if self:canSkip()then if self.phone.open then self:closePhone(true)end;self:startBreak()end end
function State:openPhone()
    if self.phone.open or self.phase=='break' or self.phase=='done' or self.phase=='voice'then return end
    if self.phase=='intro'then self.phase='phone';self:after(1,function()if self.phase=='phone'then self:say(L.garbled[1],'deadpan')end end);self:after(3.4,function()if self.phase=='phone'then self:say(L.garbled[2],'deadpan')end end);self:after(7.8,function()if self.phase=='phone'then self:closePhone()end end)end
    self.normi:release();self.normi.override=self.normi:frameIndex('stand-phone');self.phone.open=true;self.phone.buttons={{id='stow',text=L.stow}};self:sound('tap')
end
function State:closePhone(quiet)
    if not self.phone.open then return end;self.phone.open=false;self.normi.override=false
    if not quiet then self:sound('tap');if self.phase=='phone'then self:dropPig()end end
end
function State:onPhone(id)if id=='stow' or id=='close'then self:closePhone()end end
function State:togglePhone()if self.phase=='phone'then self:closePhone()elseif self.phase=='walk'then if self.phone.open then self:closePhone()else self:openPhone()end end end
local GLYPHS={'▯','▮','▒','░','■','□','◇','◆','※','#','%','&','@','0','1','2','3','4','5','6','7','8','9','锟','斤','拷','烫','屯','囗','口','丨','乚','亅','〇'}
function State:garble(text,p)
    local out={};for _,c in utf8.codes(text or '')do local ch=utf8.char(c);out[#out+1]=(ch==' ' or self.random()>p)and ch or GLYPHS[math.floor(self.random()*#GLYPHS)+1]end;return table.concat(out)
end
function State:garblePhone(dt)
    self.garbleT=self.garbleT-dt;if self.phone.k<.02 or self.garbleT>0 then return end;self.garbleT=.07
    for i,h in ipairs(self.rawHistory)do local item=self.phone.history[i];if (item.truthUntil or 0)<self.t then
        if self.random()<.025 then item.text=h.text;item.truthUntil=self.t+.26 else item.text=self:garble(h.text,.82);item.gl=self.random()<.12;if item.gl then item.gx=math.floor((self.random()-.5)*180+.5)/10;item.gt=math.floor(self.random()*40+.5)/100 end end
    end;item.name=self:garble(h.name,.82);item.stamp=self:garble(h.stamp,.82)end
    self.phone.contact=self:garble(Data.OFFICE_LINES.group,.45);self.phone.subtitle=self:garble(Data.OFFICE_LINES.groupSub,.82);self.phone.time=self:garble('23:12',.82)
    self.phone.jitter=self.random()<.08 and math.floor((self.random()-.5)*100+.5)/10 or 0
    self.phone.batteryText=self:garble(tostring(self.phone.battery)..'%',.82);self.phone.placeholder=self:garble('选一句，或者什么都不说',.82)
    self.phone.revision=(self.phone.revision or 0)+1
end
function State:dropPig()
    self.phase='pig';local p=self.gp;p.x=self.normi.pos.x+4.2;p.y=3.2;p.drop=0;self.guideVisible=true
    self:after(1,function()p.spinLeft=8 end);self:after(2.1,function()self:say(L.pig)end)
    self:after(3.6,function()if self.phase=='pig'then self.phase='walk';self.walkAt=self.t;self:emit('hint',{text=L.walk,duration=6})end end)
end
function State:startSwap()
    if self.phase~='walk'then return end;self.fired.split=true;self.normi:release();local p,n=self.gp,self.normi.pos
    p.x=n.x;p.z=clamp(n.z,-.95,.95);p.y=0;p.drop=1;p.spinLeft=0;p.waitT=0;p.face=nil;p.vx=0;p.vz=0;self:beginSwap('pig')
end
function State:startUnswap()
    if self.phase~='pigwalk'then return end;local p=self.gp;p.vx=0;p.vz=0;self.normi:setPosition(p.x,0,p.z);self.normi:release();self.normi:face(1);self:beginSwap('normi')
end
function State:beginSwap(to)
    self:emit('dreamSound',{name=to=='pig' and 'swap' or 'unswap'})
    self.phase=to=='pig' and 'swap' or 'unswap';self.swapT=0;self.swapTo=to;self.strobeI=1;self.layerTo=to=='pig'and 1 or 0;self.dolly=1
    self:emit('flash',{amount=.18});self:emit('shake',{amount=.04});self:tone(3200,.04,.03,'square')
end
function State:updateSwap(dt)
    self.swapT=self.swapT+dt;local t=self.swapT;local toPig=self.swapTo=='pig'
    local function show(pig)self.guideVisible=pig;self.normi.visible=not pig end
    if t<STROBE[1]then show(not toPig)end
    while self.strobeI<=#STROBE and t>=STROBE[self.strobeI]do local i=self.strobeI-1;self.strobeI=self.strobeI+1;show(toPig and i%2==0 or not toPig and i%2==1);self:emit('flash',{amount=.05});self:tone(1800+i*120,.02,.014,'square')end
    if t>=.9 then self:once('swap-'..self.swapTo..(self.swapN or 0),function()
        show(toPig);self:emit('flash',{amount=.22});self:emit('shake',{amount=.06});self:tone(toPig and 330 or 440,.5,.05,'triangle',toPig and .6 or 1.6)
        if not toPig then self.guideVisible=true;local p=self.gp;p.x=p.x+1.1;p.y=1.6;p.drop=.7;p.face=nil end
    end)end
    if t>=1.25 then self.swapN=(self.swapN or 0)+1;if toPig then self.phase='pigwalk';self:emit('hint',{text=L.walk,duration=3})else self.phase='walk';self.walkAt=self.t;self.moved=1;self:after(.5,function()self:say(L.swapBack)end)end end
end
function State:updateGuide(dt,ctx)
    if not self.guideVisible then return end;local p=self.gp;local moving=false
    if p.drop>=0 and p.drop<1 then p.drop=math.min(1,p.drop+dt/.45);p.y=3.2*(1-p.drop^2);if p.drop>=1 then p.y=0;self:tone(330,.25,.04,'sine',.6)end end
    if self.phase=='swap' or self.phase=='pigwalk' or self.phase=='unswap'then
        local inp=self.phase=='pigwalk' and ctx.input or {};local ix,iz=inp.x or 0,inp.y or 0;local d=math.sqrt(ix^2+iz^2);local wx,wz=d>0 and ix/d*1.6 or 0,d>0 and iz/d*1.6 or 0
        p.vx=mix(p.vx,wx,math.min(1,dt*8));p.vz=mix(p.vz,wz,math.min(1,dt*8));p.x=p.x+p.vx*dt;p.z=p.z+p.vz*dt
        if self.phase=='pigwalk'then p.x=clamp(p.x,-4.5,8.5);p.z=clamp(p.z,-.95,.95)end
        moving=math.sqrt(p.vx^2+p.vz^2)>.3
        if moving then p.spinLeft=0;p.waitT=0;p.face=math.floor(-(math.atan(p.vx,p.vz)-(ctx.camYaw or 0))/(math.pi/4)+.5)%8 else p.waitT=p.waitT+dt;if p.waitT>3.8 then p.waitT=0;p.spinLeft=8 end end
    elseif self.phase=='walk' or self.phase=='voice'then
        local goal=math.min(self.normi.pos.x+5.2,16.25);local go=p.x<goal-.3 and (self.normi.pos.x>p.x-3.4 or self.phase=='voice');p.vx=mix(p.vx,go and 3.4 or 0,math.min(1,dt*6));p.x=p.x+p.vx*dt;moving=p.vx>.4
        p.z=mix(p.z,self.phase=='voice' and -.55 or -.45,math.min(1,dt*2));p.waitT=moving and 0 or p.waitT+dt
        if p.waitT>3.8 and self.phase=='walk'then p.waitT=0;p.spinLeft=8 end;if self.phase=='voice' and p.spinLeft<=0 then p.spinLeft=8 end
    end
    if p.spinLeft>0 then p.spinT=p.spinT+dt/(self.phase=='voice' and .11 or .055);while p.spinT>=1 and p.spinLeft>0 do p.spinT=p.spinT-1;p.spinLeft=p.spinLeft-1;p.frame=(p.frame+1)%8 end
    elseif (self.phase=='swap' or self.phase=='pigwalk' or self.phase=='unswap') and p.face then p.frame=p.face
    else p.frame=math.floor(-(math.atan(moving and 1 or -1,moving and 0 or .8)-(ctx.camYaw or 0))/(math.pi/4)+.5)%8 end
    p.bob=moving and math.abs(math.sin(self.t*14))*.08 or 0
end
function State:startVoice()
    if self.phase~='walk'then return end;self.phase='voice';self.voiceT=0;self.normi:release();self.normi:face(1)
    local candidates={};for _,d in ipairs(self.H.drift)do if not d.fg and self:tr(d.m).visible then candidates[#candidates+1]=d end end
    table.sort(candidates,function(a,b)return len(xyz(self:tr(a.m).p),vec(17.2,1.6,-.35))<len(xyz(self:tr(b.m).p),vec(17.2,1.6,-.35))end)
    for i=1,math.min(16,#candidates)do local d=candidates[i];local p=self:tr(d.m).p;d.conv={r0=math.sqrt((p[1]-17.2)^2+(p[3]+.35)^2),a0=math.atan(p[3]+.35,p[1]-17.2),y0=p[2],delay=(i-1)*.1,s0=self:tr(d.m).s[1],to={17.2+(self.random()-.5)*.5,.5+self.random()*2.2,-.35}}end
    self:after(.4,function()self:emit('dreamSound',{name='murmur'})end)
    self:after(7.6,function()self:startBreak()end)
end
function State:startBreak()
    if self.phase=='break' or self.phase=='done'then return end
    self:closePhone(true);self.phase='break';self.breakT=0;self.later={};self.dialog=false;self.normi:release();self.layerTo=0
    self:emit('dreamSound',{name='rewind'});self:tone(180,2.2,.05,'sawtooth',6)
    for _,d in ipairs(self.H.drift)do d.vel={(self.random()-.5)*2,1.5+self.random()*2,3+self.random()*4};if d.conv then self:visible(d.m,true);self:tr(d.m).p=copy(d.conv.to);self:scale(d.m,d.conv.s0);d.conv=nil end end
    for _,w in ipairs(self.H.words)do w.vel={(self.random()-.5)*3,1+self.random()*2,2+self.random()*3}end
    if not self.normi.visible then self.normi:setPosition(self.gp.x,0,self.gp.z);self.normi.visible=true end
end
function State:assemble(t)
    local pre=t<3
    for _,q in ipairs(self.H.parts)do
        local fall=clamp((t-3.3-q.d)/1.3,0,1)^2;local rise=clamp((t-5-q.d2)/2.7,0,1);local s=t<5 and fall or (1-rise)^3
        self:visible(q.o,not pre);self:pos(q.o,q.p[1]+q.v[1]*s,q.p[2]+q.v[2]*s,q.p[3]+q.v[3]*s);self:rotate(q.o,q.r[1]+q.w[1]*s,q.r[2]+q.w[2]*s,q.r[3]+q.w[3]*s)
    end
    self.assembleS=pre and 1 or t<5 and clamp((t-3.3)/1.3,0,1)^2 or (1-clamp((t-5)/3,0,1))^3
    self:alpha(self:mat(self.H.backdrop),smooth(t,3,6.5));self:visible(self.H.sil,not pre and t>5);for _,g in ipairs(self.H.ghosts)do self:visible(g.m,not pre and t>5)end
end
function State:updateHero(dt,t)
    local H=self.H;if not self:tr(H.hero).visible then return end
    for _,a in ipairs(H.heroArcs)do local tr=self:tr(a.m);tr.r=tr.r or {0,0,0};tr.r[3]=tr.r[3]+a.sp*dt*(t>1.9 and -3 or 1)end
    for _,s in ipairs(H.heroStars)do self:scale(s.m,s.s*(.75+.35*math.sin(math.max(0,t)*3+s.ph)))end
    local hand=self:tr(H.heroHands[2].h)
    if t<2.4 then if t>1.9 then hand.r[3]=hand.r[3]+dt*smooth(t,1.9,2.4)*9 end;return end
    if t<3 then for _,b in ipairs(H.heroBits)do local k=smooth(t,2.4+b.dist*.22,2.48+b.dist*.22);self:pos(b.bit,b.home[1]+b.dir[1]*.05*k,b.home[2]+b.dir[2]*.05*k,-.02*k);self:rotate(b.bit,b.spin[1]*.004*k,b.spin[2]*.004*k,b.spin[3]*.006*k)end;hand.r[3]=hand.r[3]+dt*14;return end
    for _,b in ipairs(H.heroBits)do if t-3>=b.dist*.18 then local tr=self:tr(b.bit);b.vel[2]=b.vel[2]-dt*1.4;tr.r=tr.r or {0,0,0};for i=1,3 do tr.p[i]=tr.p[i]+b.vel[i]*dt;tr.r[i]=tr.r[i]+b.spin[i]*dt end end end
    for _,h in ipairs(H.heroHands)do local tr=self:tr(h.h);h.vel[2]=h.vel[2]-dt*1.4;for i=1,3 do tr.p[i]=tr.p[i]+h.vel[i]*dt end;tr.r[3]=tr.r[3]+h.spin*dt end
    for _,a in ipairs(H.heroArcs)do local tr=self:tr(a.tilt);for i=1,3 do tr.p[i]=tr.p[i]+a.vel[i]*dt end;tr.r=tr.r or {0,0,0};tr.r[1]=tr.r[1]+dt*a.sp*2;self:scale(a.tilt,1+(t-3)*.6)end
    for _,s in ipairs(H.heroStars)do local tr=self:tr(s.m);for i=1,3 do tr.p[i]=tr.p[i]+s.vel[i]*dt end end
    local fade=1-smooth(t,4,5.2);for _,m in ipairs(H.heroMats)do self:alpha(m,fade)end;if fade<=0 then self:visible(H.hero,false)end
end
function State:updateCamera(dt,ctx)
    local t,n,near=self.t,self.normi.pos,self.near;local brk=self.phase=='break' and self.breakT or 0;local pull=smooth(t,3.35,9.4);local settle=smooth(t,8.7,13.2)
    local intro={target=lerp(vec(-13.4,2.5,.7),vec(-10,3.6,-.8),pull),dist=mix(.32-smooth(t,0,2.4)*.05,1.65,pull^1.4),pitch=math.rad(mix(3,17,pull)),yaw=mix(.06,.36,pull)}
    local request
    if self.phase=='voice' or (brk>0 and self.voiceT)then
        local k=smooth(self.voiceT,0,2.6);local k2=smooth(self.voiceT,2.6,7.6);local target=lerp(vec((n.x+17.2)/2+.3,2.1,-.3),vec(17,2.2,-.15),k)
        self.camLook=lerp(self.camLook,target,math.min(1,dt*2.2));request={target=self.camLook,dist=mix(.84,.46,k)-k2*.05,pitch=math.rad(mix(7,2.5,k)),yaw=mix(-.16,-.06,k)-k2*.05}
        self.fx.focus={dist=len(ctx.cameraPosition or vec(0,8,22),vec(17.2,2,-.35)),k=k};self.fx.kFar=9
    else
        local pig=self.phase=='pigwalk' or (self.phase=='swap' and self.swapT>.9) or (self.phase=='unswap' and self.swapT<.9);self.pigK=mix(self.pigK,pig and 1 or 0,math.min(1,dt*2.5));local sk=self.pigK
        local follow=vec(n.x+2.2+near*.8-sk*.8,2.15+math.sin(t*.33)*.08-near*.15-sk*.85,n.z*.35-.6);local want=lerp(intro.target,follow,settle)
        self.camLook=settle<1 and want or lerp(self.camLook,want,math.min(1,dt*2.2))
        request={target=self.camLook,dist=mix(intro.dist,.9-near^2*.12-sk*.2,settle),pitch=mix(intro.pitch,math.rad(9-near*3-sk*4),settle),yaw=mix(intro.yaw,math.sin(t*.21)*.025-near^2*.16,settle),snap=t<.1}
        local fk=1-smooth(t,3,6);self.fx.focus=fk>0 and {dist=len(ctx.cameraPosition or vec(0,8,22),vec(-13.4,2.5,.7)),k=fk}or false;self.fx.kFar=mix(9,30,fk)
    end
    if brk>0 then local k=smooth(brk,.15,2.3);request.dist=request.dist+k*.55;request.pitch=request.pitch+math.rad(k*10);request.yaw=request.yaw+k^2*.9 end
    self.cameraRequest=request
end
function State:updateWorld(dt,ctx)
    local t,H,n,near=self.t,self.H,self.normi.pos,self.near;local brk=self.phase=='break'and self.breakT or 0;local yaw=ctx.camYaw or 0;local building=t<=8.1
    local formed=self.phase=='voice' and smooth(self.voiceT,.4,2.6)or self.phase=='break' and 1 or 0;local breath=1+math.sin(t*1.3)*.012
    self:rotate(H.sil,0,yaw,0)
    if self.phase~='break'then self:scale(H.sil,breath,1/breath,1);self:alpha(self:mat(H.sil),mix(.5,.9,formed)+math.sin(t*5.3)*(.04+(1-formed)*.06))end
    for _,gh in ipairs(H.ghosts)do local spread=(1-near*.7)*(self.phase=='break'and 2.5 or 1)*(1.6-formed);local p=self:tr(H.sil).p
        self:pos(gh.m,p[1]+gh.k*(.32+math.sin(t*.7+gh.k)*.12)*spread,p[2],-.4);self:rotate(gh.m,0,yaw,0);self:tr(gh.m).s=copy(self:tr(H.sil).s);self:alpha(self:mat(gh.m),(.22+math.sin(t*2.1+gh.k*2)*.08)*(1-smooth(brk,.8,1.8)))
    end
    self:tr(H.backdrop).p[1]=(ctx.cameraPosition and ctx.cameraPosition.x or 0)*.82;self:rotate(H.backdrop,0,0,-near^2*.05+math.sin(t*.3)*.004)
    self.ringV=mix(self.ringV,.05-near^2*.9-smooth(brk,0,1.5)*3,math.min(1,dt*1.5));local ring=self:tr(H.ring);ring.r=ring.r or {0,0,0};ring.r[3]=ring.r[3]+self.ringV*dt
    local jit=near>.35 and math.floor(t*7)or -1
    for _,tk in ipairs(H.ticks)do local off=jit>=0 and (math.floor(tk.a*100)+jit*13)%17==0 and .35*near or 0;self:pos(tk.m,math.sin(tk.a)*(tk.r+off),math.cos(tk.a)*(tk.r+off),0)end
    for _,c in ipairs(H.clocks)do for _,h in ipairs(c.hands)do local tr=self:tr(h.h);tr.r=tr.r or {0,0,0};tr.r[3]=tr.r[3]-h.sp*dt*(1-near*2.2)*(brk>0 and -6 or 1)end;local rev=c.speed*(1-near*2.2);self:rotate(c.face,0,0,near>.35 and math.sin(t*3+c.speed*5)>.92 and .12*(rev<0 and -1 or 1)or 0);local tr=self:tr(c.c);tr.p[2]=tr.p[2]+math.sin(t*.5+c.speed)*dt*.08 end
    local grow=smooth(n.x,.8-7,.8+1);self.sproutSpin=(self.sproutSpin or 0)+dt*near*.4;self:scale(H.sprout,1,math.max(.01,grow*2.6),1);self:rotate(H.sprout,0,0,-grow*.6+math.sin(t*.8)*.05*grow-self.sproutSpin)
    for _,f in ipairs(H.frags)do self:tr(f.f).p[2]=f.home[2]+math.sin(t*.4+f.k*2)*.25;self:rotate(f.f,f.rot[1],f.rot[2]+math.sin(t*.2+f.k)*.15-near*.4,f.rot[3])end
    for i,d in ipairs(H.drift)do local tr=self:tr(d.m)
        if d.conv and self.phase=='voice'then
            local c=d.conv;local k=smooth(self.voiceT,c.delay,c.delay+1.5);local a=c.a0+k*math.pi*1.6;local r=c.r0*(1-k)
            self:pos(d.m,mix(17.2+math.cos(a)*r,c.to[1],k*k),mix(c.y0,c.to[2],k),mix(-.35+math.sin(a)*r,c.to[3],k*k));self:scale(d.m,c.s0*(1-k*.85));tr.r=tr.r or {0,0,0};tr.r[1]=tr.r[1]+dt*4*k;tr.r[3]=tr.r[3]+dt*3*k;self:visible(d.m,k<.98)
        elseif brk>0 then for j=1,3 do d.vel[j]=d.vel[j]*(1+dt*1.2);tr.p[j]=tr.p[j]+d.vel[j]*dt end;tr.r=tr.r or {0,0,0};tr.r[1]=tr.r[1]+dt*(4+d.spin*6);tr.r[3]=tr.r[3]-dt*5
        else
            local sweep=d.fg and (1-smooth(t,6,11))*9 or 0;local w=t*d.sp*(1-near*2.4)+d.ph
            self:pos(d.m,d.home[1]+math.sin(w*.7)*.8+sweep,d.home[2]+math.sin(w)*.35,d.home[3]+math.cos(w*.6)*.4)
            if d.fg then tr.p[3]=tr.p[3]-13*self.layerK;tr.p[2]=tr.p[2]+2.5*self.layerK elseif d.pull~=0 then tr.p[3]=tr.p[3]+d.pull*self.layerK end
            self:rotate(d.m,math.sin(w*.5)*.6,w*.3*(d.spin<0 and -1 or 1),math.cos(w*.4)*.5+d.spin)
        end
    end
    if building then self:assemble(t);for i,d in ipairs(H.drift)do self:visible(d.m,t>=3);for j=1,3 do self:tr(d.m).p[j]=self:tr(d.m).p[j]+H.driftOff[i][j]*self.assembleS end end end
    for _,w in ipairs(H.words)do local vt=self.voiceT or 0;local on=(self.phase=='voice' or brk>0)and vt>w.at;self:visible(w.m,on)
        if on then
            local tr=self:tr(w.m)
            if brk>0 then for j=1,3 do w.vel[j]=w.vel[j]*(1+dt*1.2);tr.p[j]=tr.p[j]+w.vel[j]*dt end;self:alpha(self:mat(w.m),1-smooth(brk,.3,1.4))
            else local wt=vt-w.at;local a=w.a+wt*.32;self:pos(w.m,17.2+math.cos(a)*w.r,w.y+wt*.16+math.sin(t*1.1+w.a)*.05,-.35+math.sin(a)*w.r*.6+.4);self:rotate(w.m,0,yaw+math.sin(t*.6+w.a)*.15,math.sin(t*.8+w.a)*.06);if self.random()<.04 then tr.p[1]=tr.p[1]+(self.random()-.5)*.12 end;self:alpha(self:mat(w.m),smooth(wt,0,.7)*(.85+math.sin(t*4+w.a)*.1))end
        end
    end
end
function State:updateBreak(dt,ctx)
    self.breakT=self.breakT+dt;local t,H=self.breakT,self.H;local p=self.gp
    if self.guideVisible then p.spinLeft=99;p.spinT=p.spinT+dt/.03 end;if t>.25 then self.guideVisible=false end
    self:visible(H.doodle,t>.25 and t<.9);if t>.25 and t<.9 then self:pos(H.doodle,p.x,.75+(t-.25)*.6,p.z+.2);self:rotate(H.doodle,0,ctx.camYaw or 0,-(t-.25)*6);self:alpha(self:mat(H.doodle),1-smooth(t,.6,.9))end
    for _,sl in ipairs(H.slabs)do local d=(20.2-sl.x)/34;local k=smooth(t,.35+d*1.7,1.25+d*1.7);local tr=self:tr(sl.piv);tr.r=tr.r or {0,0,0};tr.r[1]=-k*2.6;tr.p[2]=k*k*3 end
    self:tr(H.sil).p[2]=smooth(t,1,2.1)*4;self:tr(H.sil).s[1]=1-smooth(t,1,1.9)*.9
    for _,d in ipairs(H.doors)do local tr=self:tr(d);tr.r=tr.r or {0,0,0};tr.r[2]=tr.r[2]-dt*smooth(t,.6,1.6)*4 end
    self:emit('shake',{amount=.03+smooth(t,.6,2.2)*.12});if t>.3 and t<.36 then self:emit('flash',{amount=.12})end
    self.fx.veil={k=smooth(t,1.7,2.3),r=mix(1.9,-.25,smooth(t,1.6,2.3)),cx=.5,cy=.52}
    if t>2.3 then self.normi.visible=false;self.fx.audioFade=1 end
    if t>3.1 then self.phase='done';self.result={toNight=true};self:emit('finish',{result=self.result})end
end
function State:update(dt,ctx)
    ctx=ctx or {};self.t=self.t+dt
    for i=#self.later,1,-1 do local a=self.later[i];a.t=a.t-dt;if a.t<=0 then table.remove(self.later,i);a.fn()end end
    local n=self.normi;if self.phase~='break'then self.near=clamp((n.pos.x-4.2)/10,0,1)end;n:update(dt,ctx.camYaw or 0,self:walkEnabled(),self.near^2)
    if self.phase=='walk'then self.moved=self.moved+math.sqrt(n.vel.x^2+n.vel.z^2)*dt;if self.t>self.walkAt+12 and self.moved<.5 then self:once('again',function()self:emit('hint',{text=L.walk,duration=5})end)end;if n.pos.x>=-3 and not self.fired.split then self:startSwap()end;if n.pos.x>=15 then self:startVoice()end end
    if self.phase=='swap' or self.phase=='unswap'then self:updateSwap(dt)end
    if self.phase=='pigwalk'then n:setPosition(self.gp.x,0,self.gp.z);if self.gp.x>=8.2 then self:startUnswap()end end
    if self.layerTo then self.layerV=self.layerV+((self.layerTo-self.layerK)*70-self.layerV*11)*dt;self.layerK=self.layerK+self.layerV*dt end
    if self.phase=='voice'then self.voiceT=self.voiceT+dt end
    self.dolly=math.max(0,(self.dolly or 0)-dt/1.6);self:updateCamera(dt,ctx);self:updateHero(dt,self.t);self:updateWorld(dt,ctx);self:updateGuide(dt,ctx)
    local p=self.phone;p.elapsed=p.elapsed+dt;local target=p.open and 1 or 0;p.k=mix(p.k,target,1-math.exp(-dt*(p.open and 7 or 9)));if math.abs(p.k-target)<.002 then p.k=target end;self:garblePhone(dt)
    if self.phase=='break'then self:updateBreak(dt,ctx)end
    if self.phase~='break' and self.phase~='done'then
        self.tickT=self.tickT-dt*(1+self.near*math.sin(self.t*2.3)*.8)
        if self.tickT<=0 then self.tickT=1;self.tock=not self.tock;self:tone(self.tock and 2100 or 2600,.015,.012*(.5+self.near),'square')end
        self.swellT=self.swellT-dt
        if self.swellT<=0 and self.phase~='voice'then
            self.swellT=5+self.random()*3
            self:emit('dreamSound',{name='air-'..math.min(23,math.floor(self.random()*24)),gain=.03+self.near*.04})
        end
    end
end
return State
