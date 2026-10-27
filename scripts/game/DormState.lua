-- Frozen increment 03 Ch1Dorm state machine; native scene owns all drawing.
local Human=require('game.Chapter1State')
local Data=require('game.data.Story03Data')
local Dorm=setmetatable({},{__index=Human});Dorm.__index=Dorm
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function smooth(x,a,b) local k=clamp((x-a)/(b-a),0,1);return k*k*(3-2*k) end
local function mix(a,b,k) return a+(b-a)*k end
local function vec(x,y,z) return {x=x,y=y,z=z} end
local D={x=2.2,z=-1.2,y=1.25}
local pivot=vec(2.35,1.59,-1.02)
local screen=vec(2.35,1.57,-1.33)
function Dorm.new(options)
    options=options or {};options.mode='dorm'
    local s=Human.new(options);setmetatable(s,Dorm)
    local n=s.normi
    n.bounds={halfW=4.1,xMin=-4.1,xMax=4.1,zMin=-2.6,zMax=2.7}
    n.obstacles={{x0=-4.45,x1=-2.35,z0=-3,z1=.1},{x0=1.05,x1=3.35,z0=-1.75,z1=-.65},
        {x0=1.55,x1=2.45,z0=-.35,z1=.45},{x0=3.5,x1=4.5,z0=-3,z1=-1.8},
        {x0=-2.45,x1=-1.45,z0=-3,z1=-2.15},{x0=-.65,x1=1.35,z0=-3,z1=-2.15},
        {x0=3.55,x1=4.5,z0=1.6,z1=2.4}}
    n:setPosition(-1.6,0,.6);n.side=1;n.visible=true
    s.phase=options.skipRewind and 'intro' or 'rewind';s.introT=0;s.introFrom=options.skipRewind and 495 or 598
    s.clockMin=options.skipRewind and 495 or 887;s.fx.haze=1;s.parcel=false;s.dormChoice=false
    s.pig.position=vec(pivot.x,pivot.y,pivot.z)
    if options.afterEcho then
        s.dormChoice=options.dormChoice or 'sick';s.phase='after';s.afterT=0;s.clockMin=s.dormChoice=='off' and 1110 or 496
        s.duskK=s.dormChoice=='off' and 1 or 0;s.duskTo=s.duskK;s.parcel=s.dormChoice=='pc'
        n:setPosition(D.x-1.9,0,D.z+1.7);n:face(1);s:showDeskPig(true);s.fx.haze=0
        if options.assemble then s.assembled=true;s.assembleT=0;s.afterT=-2.2;s.fx.veil=false;s.fx.blue=.92 end
    end
    return s
end
function Dorm:atDesk() return ({pig=true,desk=true,fold=true,after=true,jam=true,screen=true,done=true})[self.phase] or false end
function Dorm:controlEnabled() return (self.phase=='play' or self.phase=='desk') and not self.phone.open end
function Dorm:walkEnabled() return self:controlEnabled() or not not self.autoWalk end
function Dorm:cam()
    if self.screenT then local k=smooth(self.screenT,0,2.4);return {target=vec(mix(D.x-.3,screen.x,k),mix(1.7,screen.y,k),mix(D.z+.2,screen.z,k)),dist=mix(.42,.05,k),pitch=mix(math.rad(13),.22,k)} end
    if self:atDesk() then return {target=vec(D.x-.3,1.7,D.z+.2),dist=.42,pitch=math.rad(13)} end
    local n=self.normi.pos;return {target=vec(n.x*.25,1.9,-.4+n.z*.1),dist=.66}
end
function Dorm:zones()
    if self.phase=='desk' then return {{id='pig',object='小猪',text='碰它',x0=D.x-3.4,x1=D.x+1.6,z0=D.z+.5,z1=D.z+3.4}} end
    if self.phase=='play' then return {{id='phone',object='手机',text='看手机',x0=D.x-1.9,x1=D.x+1.6,z0=D.z+.5,z1=D.z+3.4}} end
    return {}
end
function Dorm:onInteract(id)
    if id=='phone' then self.normi:doTouch('hesitate');self:openDorm() elseif id=='pig' then self:startFold() end
end
function Dorm:togglePhone() if self.phase=='play' then self:openDorm() end end
function Dorm:canSkip() return ({rewind=true,intro=true,play=true,pig=true,after=true,jam=true})[self.phase] or (self.phase=='dorm' and not not self.dormChoice) end
function Dorm:skip()
    if not self:canSkip() then return false end
    self.later={}
    if self.phase=='rewind' or self.phase=='intro' then self:closePanel();self:toPlay()
    elseif self.phase=='play' then self:openDorm(true)
    elseif self.phase=='after' or self.phase=='jam' then if self.assembleT then self.assembleT=9;self.fx.blue=0 end;self.phoneThen=false;self.fx.veil=false;self:closePanel();self:emit('clearCaptions');self:boxOut(true);self:screenOn(true);self:startScreen()
    else
        self.waitPanel=false;self:closePanel()
        if self.dormChoice=='pc' then self:dropParcel() end
        if self.dormChoice=='off' then self.clockMin=1110;self.duskTo=1 end
        if self.phase=='pig' then self.pig.visible=true;self.tonightVisible=true;self.phase='desk' else self:finale(true) end
    end
    return true
end
function Dorm:onChoice(i)
    if self.choiceMode=='rewind' then if self.phase=='rewind' then self:closePanel();self.phase='intro';self.introT=0 end;return end
    if self.choiceMode~='dorm' or self.dormChoice then return end
    local a=Data.DORM_ANSWERS[i+1];if not a then return end
    self.dormChoice=a.key;self:sound('send');self.phone:push(a.reply,{})
    if a.key=='off' then self:after(1.2,function() self.clockMin=1110;self.duskTo=1;self.clockSpin=true;self:after(.6,function() self.clockSpin=false end) end) end
    if a.key=='pc' then self:after(3.1,function() self:dropParcel() end) end
    self:after(3,function() self:express('deadpan',6) end);self.waitPanel='dorm'
end
function Dorm:toPlay()
    if self.phase=='play' or self.phase=='dorm' then return end
    self.phase='play';self.playAt=self.t;self.clockMin=495;self.clockSpin=false;self.fx.veil=false;self.fx.haze=0
    self:say('……八点十五。还没出门。','inner');self:express('surprised',2.4)
end
function Dorm:openDorm(now)
    if self.phase~='play' then return end
    self.phase='dorm';self.interactionId=false;self:sound('buzz');self.normi:flinch(.3);self.panelClosable=false;self.choiceMode='dorm'
    local choices={};for _,a in ipairs(Data.DORM_ANSWERS) do choices[#choices+1]=a.say end
    self:openPanel('08:15 · 宿舍','周五早上',{Data.DORM_ASK},choices);if now then self.phone:flush() end
end
function Dorm:dropParcel()
    if self.parcel then return end
    self.parcel=true;self:emit('puff',{pos=vec(3.6,.8,1.6),count=3});self:sound('tap');self:sound('chime')
end
function Dorm:showDeskPig(now)
    self.tonightAnswer=self.dormChoice or 'sick';self.tonightVisible=now or false
    if now then self.pig.visible=true;self.pig.spinT=0;return end
    self:after(.5,function() self.pig.visible=true;self.pig.spinT=0;self:emit('puff',{pos=pivot,count=3});self:sound('pig');self:emit('pigReady') end)
    self:after(.9,function() self.tonightVisible=true;self:emit('flash',{amount=.3});self:emit('puff',{pos=vec(1.5,1.6,-1.25),count=4});self:sound('chime') end)
end
function Dorm:finale(now)
    if self:atDesk() then return end
    self.phase='pig';self.interactionId=false;self:emit('clearCaptions');self.autoWalk=vec(D.x-1.9,0,D.z+1.7)
    self:showDeskPig(now);if now then self:emit('pigReady') end
    self:after(now and .3 or 2.4,function() self.phase='desk';self:emit('hint',{text='书桌上的小猪 · F 碰它',duration=6.5}) end)
end
function Dorm:updateFold(dt)
    self.foldT=self.foldT+dt;local t=self.foldT;self.foldK=smooth(t,.9,4.3)
    self.fx.haze=smooth(t,.4,2.2)*(1-smooth(t,4.6,5.4));self.fx.audioFade=smooth(t,1,4)
    if t>1.8 and self.normi.visible then self.normi.visible=false;self:emit('puff',{pos=self.normi.pos}) end
    self.fx.veil={k=smooth(t,1.6,2.4),r=mix(1.9,-.18,smooth(t,1.8,4.6)),pivot=pivot}
    if t>4.9 and self.phase~='done' then self.phase='done';self.result={dormChoice=self.dormChoice,toDormEcho=true};self:emit('finish',{result=self.result}) end
end
function Dorm:boxOut(now)
    if self.boxGone then return end
    self.boxGone=true
    local function gone() self.tonightVisible=false;self:emit('puff',{pos=vec(1.5,1.6,-1.25),count=4}) end
    if now then gone();return end
    self:emit('tone',{frequency=220,duration=.35,gain=.05,wave='triangle',slide=.5})
    for i,t in ipairs({.12,.22,.4,.5}) do self:after(t,function() self.tonightVisible=i%2==0 end) end
    self:after(.75,gone)
end
function Dorm:screenOn(now)
    if self.screenLit then return end
    self.screenLit=true;self.phase='jam'
    local function lit() self.pig.visible=false;self.screenImage=true end
    if now then lit();return end
    self.pigDive=0;self:emit('tone',{frequency=880,duration=.3,gain=.04,wave='triangle',slide=1.6})
    self:after(.7,function() lit();self:emit('flash',{amount=.3});self:emit('puff',{pos=screen,count=3});self:sound('chime');self.autoWalk=false;self.normi:face(1);self:express('surprised',2.4) end)
    self:after(1.7,function()
        self.panelClosable=false;self.choiceMode=false;self:openPanel('Game Jam','初赛结果',Data.DORM_JAM)
        self.phoneThen=function() self:closePanel();self:express('smile',4);self.autoWalk=vec(D.x-.9,0,D.z+.8);self:after(1.6,function() self:startScreen() end) end
    end)
end
function Dorm:startScreen()
    if self.screenT or self.phase=='done' then return end
    self.phase='screen';self.screenT=0;self.interactionId=false;self:emit('clearCaptions')
end
function Dorm:updateAfter(dt)
    if self.assembleT then
        self.assembleT=self.assembleT+dt;self.fx.blue=.92*(1-smooth(self.assembleT,.6,2.6))
        if self.assembleT>1.6 and not self.landed then self.landed=true;self:sound('tap')end
    end
    self.afterT=self.afterT+dt;local t=self.afterT
    if t<0 then return end
    self.fx.veil=not self.assembled and t<2.2 and {k=1-smooth(t,1,2),r=mix(-.2,1.9,smooth(t,0,1.8)),pivot=pivot} or false
    self:once('free-box',function() self:after(1.6,function() self:boxOut() end) end)
    self:once('free-msg',function() self:after(3.4,function()
        self:sound('buzz');self.normi:flinch(.3);self.panelClosable=false;self.choiceMode=false;self:openPanel('手机',self:hm(),Data.DORM_FREE);self:express('surprised',3.2)
        self.phoneThen=function()
            self:closePanel();self:express('smile',3.4);self:after(1.4,function() self.autoWalk=vec(D.x-2.4,0,D.z+1.9) end)
            self:after(3.4,function() self:screenOn() end)
        end
    end) end)
end
function Dorm:update(dt,ctx)
    ctx=ctx or {};self.t=self.t+dt
    for i=#self.later,1,-1 do local a=self.later[i];a.t=a.t-dt;if a.t<=0 then table.remove(self.later,i);a.fn() end end
    self.normi:update(dt,ctx.camYaw or 0,self:walkEnabled(),0);self:updatePrompt();self.phone:update(dt)
    local t=self.t;self.clockShow=true
    if self.phase=='rewind' then
        local k=smooth(t,.3,2.2);self.clockMin=math.floor(mix(887,598,k*k)+.5);self.clockSpin=k<1
        if t>2.5 then self:once('rewind',function() self:sound('tick');self.panelClosable=false;self.choiceMode='rewind';self:openPanel('时间回溯','09:58',Data.DORM_REWIND,{'再往前拨：08:15 · 还没出门的宿舍'}) end) end
    end
    if self.phase=='intro' then
        self.introT=self.introT+dt;local i=self.introT;local k=smooth(i,0,1.6);self.clockMin=math.floor(mix(self.introFrom,495,k)+.5);self.clockSpin=k<1
        self.fx.haze=1-smooth(i,1,2.2);self.fx.veil={k=1-smooth(i,1.2,2.2),r=mix(-.2,1.9,smooth(i,1,2.4)),cx=.45,cy=.55}
        if i>2.4 then self:toPlay() end
    end
    if self.phase=='play' and t-self.playAt>2.5 then self:openDorm() end
    if self.phase=='after' then self:updateAfter(dt) end
    if self.screenT then
        self.screenT=self.screenT+dt;self.fx.audioFade=smooth(self.screenT,.4,2.8)
        if self.screenT>3 and self.phase~='done' then self.phase='done';self.result={dormChoice=self.dormChoice,ended=true};self:emit('finish',{result=self.result}) end
    end
    if self.phoneThen and #self.phone.queue==0 and not self.phone.choicesWaiting then local f=self.phoneThen;self.phoneThen=false;self:after(1.6,f) end
    if self.phase=='fold' then self:updateFold(dt) end
    if self.waitPanel and #self.phone.queue==0 and not self.phone.choicesWaiting then self.waitPanel=false;self:after(2,function() self:closePanel();self:finale() end) end
    if self.autoWalk then
        self.normi:moveStick(self.autoWalk);local n=self.normi.pos;local a=self.autoWalk
        if math.sqrt((n.x-a.x)^2+(n.z-a.z)^2)<.15 then self.autoWalk=false;self.normi:face(1) end
    end
    self.duskK=self.duskK+(self.duskTo-self.duskK)*math.min(1,dt*.8);local dk=smooth(self.duskK,0,1)
    self.fx.grade={mix(1,1.03,dk),1,mix(1.03,.98,dk)};self.fx.exposure=self.tune.exposure*mix(1,.82,dk);self.fx.sat=self.tune.saturation*mix(.95,.8,dk);self.fx.desat=0
    self.focusK=self.focusK+((self:atDesk() and 1 or 0)-self.focusK)*math.min(1,dt*3)
    local c=ctx.cameraPosition or vec(0,8,20);local p=self.screenT and screen or pivot
    self.fx.focus=self.focusK>.01 and {dist=math.sqrt((c.x-p.x)^2+(c.y-p.y)^2+(c.z-p.z)^2),k=self.focusK} or false
    if self.pig.visible then
        local fold=self.phase=='fold';local grow=fold and 1+smooth(self.foldT,.3,3.4)*1.4 or 1
        if self.pigDive then self.pigDive=self.pigDive+dt end
        local k=self.pigDive and smooth(self.pigDive,0,.7) or 0
        self.pig.spinT=self.pig.spinT-dt/(fold and .09/(1+self.foldT*1.5) or .09/(1+k*4));self.pig.scale=.34*grow*(1-k*.85)
        self.pig.position=vec(mix(pivot.x,screen.x,k),mix(pivot.y,screen.y,k),mix(pivot.z,screen.z,k))
    end
end
return Dorm
