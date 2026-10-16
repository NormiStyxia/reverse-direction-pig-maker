-- Frozen ch1-scenes.js story in H5 coordinates. Native rendering consumes state/events.
-- Choice indices are zero-based. Reverse timer traversal intentionally matches JS.
local Data=require('game.data.Chapter1Data')
local Actor=require('game.NormiController')
local Browser=require('game.BrowseState')
local Layout=require('game.data.PrologueData').normiLayout
local Story={};Story.__index=Story
---@class Chapter1Effects
---@field veil table|false
---@field grade number[]
---@field focus table|false
---@field desat number
---@field vignette number
---@field kFar number
---@field kNear number
---@field exposure number
---@field farSpin number
---@field haze number
---@field sat number
---@field audioFade number
local function copy(t) if type(t)~='table' then return t end local r={};for k,v in pairs(t) do r[k]=copy(v) end;return r end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function smooth(t,a,b) local x=clamp((t-a)/(b-a),0,1);return x*x*(3-2*x) end
local function lerp(a,b,k) return a+(b-a)*k end
local function hypot(x,z) return math.sqrt(x*x+z*z) end
local function vec(x,y,z) return {x=x,y=y,z=z} end
local function think(text) return {kind='thought',text=text} end
local function leader(text) return {kind='msg',name='领导',avatar=Data.leaderAvatar,text=text} end
local function zhou(text) return {kind='msg',name=Data.after.from,avatar=Data.zhouAvatar,text=text} end
local function add(a,b) for _,v in ipairs(b) do a[#a+1]=v end;return a end
function Story.new(options) local self=setmetatable({},Story);self:init(options or {});return self end
function Story:init(options)
    self.mode=options.mode or 'meeting';self.random=options.random or math.random
    self.normi=options.normi or Actor.new(Layout,self.random);self.tune=copy(Data.tune)
    self.t=0;self.later={};self.fired={};self.seen={};self.events={};self.phase='intro';self.wideFrame=1.32
    self.phone=Browser.new();self.standPhone=self.normi:frameIndex('stand-phone')
    self.interactionId=false;self.interactionAt=-99;self.panelClosable=false;self.choiceMode=false;self.waitPanel=false
    self.expr='calm';self.exprId=0;self.result=false;self.answer=false;self.playAt=0
    self.clockMin=887;self.clockShow=false;self.clockSpin=false;self.clockDusk=false;self.clockBack=0
    ---@type Chapter1Effects
    self.fx={desat=0,vignette=0,kFar=self.tune.dofFar,kNear=self.tune.dofNear,grade={1,1,1},exposure=1,focus=false,farSpin=1,
        veil={k=1,r=-.2,cx=.5,cy=.5},haze=0}
    self.carrying=false;self.doorOpened=false;self.doorK=0;self.boxVisible=true;self.deskBoxVisible=false
    self.tonightVisible=false
    ---@type string|boolean
    self.tonightAnswer='same'
    self.slide=false;self.frozen=false;self.autoWalk=false
    self.pig={visible=false,spinT=0,scale=.34};self.foldT=0;self.foldK=0;self.fxK=0;self.focusK=0
    self.talkT=1.4;self.idleT=0;self.typeT=0;self.officeTalkT=2;self.duskK=0;self.duskTo=0
    self.noBoxAt=false;self.replied=false;self.people=copy(Data.people)
    for _,p in ipairs(self.people) do p.leaveT=false;p.y=0;p.rz=0;p.visible=true end
    self.baseObs=copy(Data.baseObstacles);self.doorObs=copy(Data.doorObstacle)
    local n=self.normi;n.bounds=copy(Data.bounds);n.bounds.xMin=Data.officeX0+.6;n.bounds.xMax=Data.bounds.halfW
    n.obstacles=add(copy(self.baseObs),{self.doorObs});n:setPosition(-3.9,0,1.6);n.side=1
    if self.mode=='morning' then
        self.answer=options.answer or 'same';self.fx.haze=1
        n.bounds.xMax=-8.2;n:setPosition(Data.desk.x+.9,0,Data.desk.z+2);n.side=-1
        n.obstacles=add(add(copy(Data.meetingObstacles),{{x0=-7.9,x1=-7.4,z0=-6,z1=4.6}}),Data.officeObstacles)
        for _,p in ipairs(self.people) do p.visible=false end
    else self:emit('title',{text='第一章 · 下午三点的会'}) end
end
function Story:emit(kind,data) local e=data or {};e.kind=kind;e.t=self.t;self.events[#self.events+1]=e end
function Story:drainEvents() local e=self.events;self.events={};return e end
function Story:after(t,fn) self.later[#self.later+1]={t=t,fn=fn} end
function Story:once(key,fn) if not self.fired[key] then self.fired[key]=true;fn() end end
function Story:pick(a) return a[math.floor(self.random()*#a)+1] end
function Story:hm() return string.format('%02d:%02d',math.floor(self.clockMin/60),math.floor(self.clockMin%60)) end
function Story:sound(name) self:emit('sound',{name=name}) end
function Story:say(text,style)
    if not text or self.phase=='done' then return end
    self:emit('caption',{text=text,style=self.phone.open and 'inner' or (style or 'soft'),speaker='normi'})
end
function Story:talk(who,text) self:emit('caption',{text=text,style='talk',speaker=who}) end
function Story:express(name,duration)
    if duration==nil then duration=2.6 end
    self.expr=name;self.exprId=self.exprId+1;local id=self.exprId
    if duration~=0 then self:after(duration,function() if self.exprId==id then self.expr='calm' end end) end
end
function Story:faceFrame()
    local key=tostring(self.normi.pose);return Data.faces[self.expr][key] or Data.faces.calm[key]
end
function Story:controlEnabled()
    return (self.phase=='play' or (self.mode=='meeting' and (self.phase=='walk' or self.phase=='desk'))) and not self.phone.open
end
function Story:walkEnabled() return self:controlEnabled() or (self.mode=='meeting' and not not self.autoWalk) end
function Story:inOffice() return self.normi.pos.x< -7.65 end
function Story:cam()
    local n,D=self.normi.pos,Data.desk
    if self.mode=='meeting' then
        if self.phase=='pig' then return {target=vec(Data.pivot.x,Data.pivot.y+.05,Data.pivot.z),dist=.3,pitch=math.rad(9)} end
        if self.phase=='desk' or self.phase=='fold' or self.phase=='done' then return {target=vec(D.x-.2,1.75,D.z+.4),dist=.56,pitch=math.rad(14)} end
    end
    if self.mode=='morning' or self:inOffice() then return {target=vec(clamp(n.x,-19.5,-10.5)*.98,2.05,n.z*.45-1.1)} end
    return false
end
function Story:openPanel(title,sub,entries,choices)
    self.phone:show(title,sub);self.phone:push(entries,choices or {});self.normi.override=self.standPhone
end
function Story:closePanel() self.phone:hide();self.normi.override=false end
function Story:onPanel(id)
    self:sound('tap')
    if id=='close' then if self.panelClosable then self:closePanel() end;return end
    if id:sub(1,7)=='choice:' then self:onChoice(tonumber(id:sub(8))) end
end
function Story:zones()
    local D=Data.desk
    local function desk(id,object,text,w,z) return {id=id,object=object,text=text,x0=D.x-w,x1=D.x+w,z0=D.z+.6,z1=D.z+z} end
    if self.mode=='morning' then return self.phase=='play' and {desk('box','档案盒','看看',2.4,3.2)} or {} end
    if self.phase=='desk' then return {desk('pig',Data.after.pigName,Data.after.pigVerb,2.4,3.2)} end
    if self.phase=='walk' then
        if not self.carrying then return {{id='take',object='档案盒',text='拿上',x0=-3.9,x1=-.9,z0=-.7,z1=1.5}} end
        local out={desk('put','档案盒','放下',2.2,3)}
        for _,v in ipairs({{'notes','便利贴'},{'seal','小海豹'},{'cup','保温杯'}}) do if not self.seen[v[1]] then out[#out+1]=desk(v[1],v[2],'看看',2.2,3) end end
        return out
    end
    return {{id='box',object='档案盒',text='看看',x0=-3.9,x1=-.9,z0=-.7,z1=1.5},
        {id='screen',object='投影',text='看看',x0=-.3,x1=2.9,z0=-.7,z1=1.5},
        {id='clock',object='挂钟',text='看看',x0=3.95,x1=6.8,z0=-5.2,z1=-1.2}}
end
function Story:nearbyInteractions()
    local out={};if not self:walkEnabled() or self.phone.open then return out end
    local p=self.normi.pos
    for i,z in ipairs(self:zones()) do
        if p.x>=z.x0 and p.x<=z.x1 and p.z>=z.z0 and p.z<=z.z1 then
            local o=copy(z);o.distance=hypot(p.x-(z.x0+z.x1)/2,p.z-(z.z0+z.z1)/2);o.order=i;out[#out+1]=o
        end
    end
    table.sort(out,function(a,b) if a.distance==b.distance then return a.order<b.order end;return a.distance<b.distance end)
    return out
end
function Story:cycleInteraction()
    local o=self:nearbyInteractions();if #o==0 then return end
    local i=0;for j,v in ipairs(o) do if v.id==self.interactionId then i=j end end
    self.interactionId=o[i%#o+1].id
end
function Story:interact(id)
    id=id or self.interactionId;local options=self:nearbyInteractions()
    ---@type table|false
    local option=false
    for _,v in ipairs(options) do if v.id==id then option=v end end
    if not id then option=options[1] end
    if not option or self.normi:busy() or self.t-self.interactionAt<.8 then return end
    self.interactionAt=self.t;self:sound('tap');self:onInteract(option.id)
end
function Story:updatePrompt()
    local options=self:nearbyInteractions();if #options==0 then self.interactionId=false;return end
    for _,o in ipairs(options) do if o.id==self.interactionId then return end end
    self.interactionId=options[1].id
end
function Story:onInteract(id)
    local n=self.normi;local A=Data.after
    if self.mode=='morning' then
        if id~='box' then return end
        n:doTouch('hesitate');self:say('还是空的。');self:once('msg-soon',function() self:after(2.4,function() self:message() end) end);return
    end
    if id=='pig' then self:startFold();return end
    if id=='put' then self:closeUp();return end
    n:doTouch('hesitate');local first=not self.seen[id];self.seen[id]=true
    if id=='take' then self.carrying=true;self.boxVisible=false;self:emit('puff',{pos=vec(Data.box.x,1.6,Data.box.z),count=2});if A.take~='' then self:say(A.take) end;return end
    if id=='notes' then n:face(-1);self:say(A.notes);self:express('smile',3);return end
    if id=='seal' then n:face(-1);self:say(A.seal);self:express('deadpan',3);return end
    if id=='cup' then n:face(1);self:say(A.cup);return end
    if id=='clock' then n:face(1);self:say('两点四十七。');if first then self:after(2,function() self:say('十一点四十，我还在便利店。');self:express('deadpan',2.6) end) end end
    if id=='screen' then self:say('这页今晚还得改三遍。');self:express('deadpan',3) end
    if id=='box' then
        n:face(Data.box.x-n.pos.x);self:say('……我什么时候画的。');self:express('surprised',2)
        if first then self:after(2.2,function() self:say('哦，就是现在。');self:express('smile',2.4) end);self:after(5.5,function() self:ask() end) end
    end
end
function Story:togglePhone()
    if self.mode~='meeting' or self.phase~='play' then return end
    self:sound('tap');if self.phone.open then self:closePanel();return end
    self.panelClosable=true;self:openPanel('手机',self:hm(),{{kind='card',name='日程',rows={{'周五','方案 v7'}}},think('周五。……今天就是周五。')},{'收起'});self.choiceMode='phone'
end
function Story:ask()
    if self.phase~='play' then return end
    self.phase='ask';if self.phone.open then self:closePanel() end
    self:talk('leader','诺米，方案周五前再出一版，没问题吧？');self.normi:face(Data.people[1].home.x-self.normi.pos.x)
    self:after(2.4,function()
        self.panelClosable=false;self.choiceMode='answer';local choices={};for _,a in ipairs(Data.answers) do choices[#choices+1]=a.say end
        self:openPanel('组会',self:hm(),{leader('诺米，方案周五前再出一版，没问题吧？'),think('上次我说的是……')},choices)
    end)
end
function Story:onChoice(i)
    if self.mode=='morning' then self:closePanel();return end
    if self.choiceMode=='phone' then self:closePanel();return end
    if self.choiceMode=='zhou' then
        if self.replied then return end
        self.replied=true;self:sound('send');local A=Data.after
        self.phone:push({think(A.reply),zhou(A.back),think(A.recall),think(A['then'])},{})
        self:after(1.6,function() self:express('deadpan',7) end);self.waitPanel='zhou';return
    end
    if self.choiceMode~='answer' or self.answer then return end
    local a=Data.answers[i+1];if not a then return end
    self.answer=a.key;self.phone:push(add({think(a.say)},a.reply),{})
    self:after(2.4,function() self:express('deadpan',5) end)
    if a.slide then self:after(3.2,function() self.slide=true end) end
    self.waitPanel='answer'
end
function Story:dismiss()
    self.phase='leave';self:talk('leader','散会。');self.tonightAnswer=self.answer
    local order={};for _,p in ipairs(self.people) do if p.kind~='leader' then order[#order+1]=p end end;order[#order+1]=self.people[1]
    for i,p in ipairs(order) do self:after(1.2+(i-1)*.45,function() p.leaveT=0;self:sound('leave') end) end
    self:after(1.2+#order*.45+.4,function() self.clockMin=902;self.clockDusk=true end)
    self:after(1.2+#order*.45+1.4,function() self:message() end)
end
function Story:message()
    if self.mode=='morning' then
        if self.phase~='play' then return end
        self.phase='msg';self:sound('buzz');self.normi:flinch(.35)
        self:after(.9,function() self.panelClosable=false;self.choiceMode='msg';self:openPanel('领导','09:58',{leader(Data.morning[self.answer] or Data.morning.same)},{}) end)
        self:after(4.8,function() self:say('……怎么还在上班。','inner');self:express('deadpan',0) end)
        self:after(8.6,function() self:closePanel();self.phase='done';self.result=true;self:emit('finish') end);return
    end
    self.phase='msg';self:sound('buzz');self.normi:flinch(.3)
    self:after(.8,function() self.panelClosable=false;self.choiceMode='zhou';self:openPanel(Data.after.from,self:hm(),{zhou(Data.after.msg)},{Data.after.reply}) end)
end
function Story:closeUp()
    self.phase='pig';self:emit('clearCaptions');local D=Data.desk;self.autoWalk=vec(D.x-2,0,D.z+1.6)
    self.normi:doTouch('hesitate');self.deskBoxVisible=true;self:emit('puff',{pos=Data.boxSpots[1],count=2});self:sound('tap')
    self:after(.7,function() self.pig.visible=true;self.pig.spinT=0;self:emit('puff',{pos=Data.pivot,count=3});self:sound('pig');self:emit('pigReady') end)
    self:after(1.6,function() self:say(Data.after.seePig,'inner');self:express('surprised',3.6) end)
    self:after(2.8,function() self.frozen=true;self.clockBack=1;self:sound('freeze');self:emit('shake',{amount=.08});self:after(.5,function() self:say(Data.after.freeze,'inner') end) end)
    self:after(5.6,function() self.tonightVisible=true;self:emit('flash',{amount=.35});self:emit('puff',{pos=Data.boxSpots[2],count=4});self:sound('chime') end)
    self:after(6.4,function() self:say(Data.after.tonight,'inner');self:express('surprised',2.4) end)
    self:after(8.8,function() self.phase='desk';self:emit('hint',{text=Data.after.touch,duration=6.5}) end)
end
function Story:startFold()
    if self.phase~='desk' then return end
    self.phase='fold';self.foldT=0;self:emit('clearCaptions');self.normi:doTouch('hesitate');self:emit('flash',{amount=.25});self:sound('thunder')
end
function Story:updateFold(dt)
    self.foldT=self.foldT+dt;local T=self.foldT;self.foldK=smooth(T,.9,4.3)
    self.fx.haze=smooth(T,.4,2.2)*(1-smooth(T,4.6,5.4));self.fx.audioFade=smooth(T,1,4)
    if T>1.8 and self.normi.visible then self.normi.visible=false;self:emit('puff',{pos=vec(self.normi.pos.x,.3,self.normi.pos.z)}) end
    -- Native camera supplies the projected pivot center; k/r are absolute source timing.
    self.fx.veil={k=smooth(T,1.6,2.4),r=lerp(1.9,-.18,smooth(T,1.8,4.6)),pivot=Data.pivot}
    if T>4.9 and self.phase~='done' then self.phase='done';self.result={answer=self.answer};self:emit('finish',{result=self.result}) end
end
function Story:stepMeeting(dt,ctx)
    local T,n,A=self.t,self.normi,Data.after
    if self.phase=='intro' then
        self.fx.veil={k=1-smooth(T,.6,1.6),r=lerp(-.2,1.9,smooth(T,0,1.4)),cx=.42,cy=.55}
        self:once('time',function() self:after(1,function() self.clockShow=true end) end)
        self:once('wake',function() self:after(1.8,function() self:say('……下午？','inner');self:express('surprised',2.6) end) end)
        if T>3.2 then self.phase='play';self.fx.veil=false;self.playAt=T;self:emit('hint',{text='WASD 走动 · F 看看 · J / 空格 看手机',duration=6}) end
    end
    if self.phase=='play' or self.phase=='intro' then
        self.talkT=self.talkT-dt
        if self.talkT<=0 then self.talkT=2.6+self.random()*2;local p=self:pick({self.people[2],self.people[3],self.people[4]});self:talk(p.kind,self:pick(Data.keywords)) end
    end
    if self.phase=='play' then
        self.idleT=hypot(n.vel.x,n.vel.z)<.1 and self.idleT+dt or 0
        if self.idleT>9 then self:once('idle',function() self:say('上次，我还在想晚饭吃什么。','inner') end) end
        if T-self.playAt>45 then self:ask() end
    end
    if self.waitPanel and #self.phone.queue==0 and not self.phone.choicesWaiting then
        local w=self.waitPanel;self.waitPanel=false
        if w=='answer' then self:after(2.2,function() self:closePanel();self:dismiss() end)
        else self:after(2,function() self:closePanel();self.phase='walk';self:emit('hint',{text=A.goDesk,duration=6}) end) end
    end
    for _,p in ipairs(self.people) do if p.leaveT then
        p.leaveT=p.leaveT+dt;local k=smooth(p.leaveT,0,1.1);p.y=k*k*7;p.rz=math.sin(p.leaveT*3)*.04*(1-k);if k>=1 then p.visible=false end
    end end
    local atDoor=n.pos.x< -5.4 and n.pos.z>Data.doorZ0-.8 and n.pos.z<Data.doorZ1+.8
    if self.phase=='walk' and atDoor and not self.carrying and T-(self.noBoxAt or -9)>6 then self.noBoxAt=T;self:say(A.noBox) end
    local want=self.carrying and (atDoor or self:inOffice())
    if want and not self.doorOpened then self.doorOpened=true;self:sound('slide') end
    self.doorK=self.doorK+((self.doorOpened and 1 or 0)-self.doorK)*math.min(1,dt*3)
    n.obstacles=self.doorK>.7 and self.baseObs or add(copy(self.baseObs),{self.doorObs})
    if self.doorOpened and not self.frozen then
        self.typeT=self.typeT-dt
        if self.typeT<=0 and self:inOffice() then self.typeT=.06+self.random()*.18;self:emit('tone',{frequency=2400+self.random()*900,duration=.018,gain=.006+self.random()*.006,wave='square'}) end
        self.officeTalkT=self.officeTalkT-dt
        if self.officeTalkT<=0 and self:inOffice() then self.officeTalkT=3+self.random()*2.5;local p=self:pick(Data.officePeople);self:talk(p.head,self:pick(A.chatter)) end
    end
    if self.autoWalk then
        n:moveStick(self.autoWalk)
        if hypot(n.pos.x-self.autoWalk.x,n.pos.z-self.autoWalk.z)<.15 or self.phase~='pig' then self.autoWalk=false;n:face(1) end
    end
    if self.phase=='walk' and self:inOffice() then
        for _,p in ipairs(Data.officePeople) do if math.abs(p.home.x-n.pos.x)<1.2 and p.home.z> -2.5 then self:once('pass',function() self:talk(p.head,A.passBy) end);break end end
    end
    if self.doorOpened and self:inOffice() then self.duskTo=math.max(self.duskTo,clamp((-7.6-n.pos.x)/5.2,0,1)) end
    if self.phase=='pig' or self.phase=='desk' or self.phase=='fold' or self.phase=='done' then self.duskTo=1 end
    self.duskK=self.duskK+(self.duskTo-self.duskK)*math.min(1,dt*.7)
    local tn=self.tune;local dk=smooth(math.max(self.duskK,tn.duskPreview or 0),0,1)
    self.lightDusk=dk
    if self.clockDusk then local m=math.floor(lerp(902,1078,smooth(self.duskK,0,1))+.5)-self.clockBack;self.clockSpin=m~=self.clockMin and not self.frozen;self.clockMin=m end
    self.fxK=self.fxK+((self.frozen and 1 or 0)-self.fxK)*math.min(1,dt*2)
    local r,b=lerp(tn.gradeR,tn.duskGradeR,dk),lerp(tn.gradeB,tn.duskGradeB,dk)
    self.fx.grade={lerp(r,r*.98,self.fxK),tn.gradeG,lerp(b,b*1.03,self.fxK)}
    self.fx.desat=tn.frozenDesat*self.fxK;self.fx.exposure=lerp(tn.exposure,tn.duskExposure,dk);self.fx.sat=lerp(tn.saturation,1,self.fxK*.6)
    local fk=(self.phase=='pig' or self.phase=='fold' or self.phase=='done') and 1 or (self.phase=='desk' and .7 or 0)
    self.focusK=self.focusK+(fk-self.focusK)*math.min(1,dt*3)
    local c=ctx.cameraPosition or vec(0,8,20);local p=Data.pivot
    self.fx.focus=self.focusK>.01 and {dist=math.sqrt((c.x-p.x)^2+(c.y-p.y)^2+(c.z-p.z)^2),k=self.focusK} or false
    if self.pig.visible then
        self.pig.scale=.34*(self.phase=='fold' and 1+smooth(self.foldT,.3,3.4)*1.4 or 1)
        self.pig.spinT=self.pig.spinT-dt/(self.phase=='fold' and .09/(1+self.foldT*1.5) or .09)
    end
    if self.phase=='fold' or self.phase=='done' then self:updateFold(dt) end
end
function Story:stepMorning(dt)
    local T=self.t
    if self.phase=='intro' then
        local k=smooth(T,.4,2.8);self.clockMin=math.floor(lerp(887,598,k*k)+.5);self.clockShow=true;self.clockSpin=k<1
        self.fx.haze=1-smooth(T,2.4,3.6);self.fx.veil={k=1-smooth(T,2.6,3.6),r=lerp(-.2,1.9,smooth(T,2.4,3.8)),cx=.45,cy=.55}
        if T>2.9 then self:once('tick',function() self:sound('tick') end) end
        if T>4 then self.phase='play';self.fx.veil=false;self.fx.haze=0;self.playAt=T;self:say('……早上？','inner');self:express('surprised',2.4);self:after(2.6,function() self:emit('hint',{text='WASD 走动 · F 看看',duration=4}) end) end
    end
    if self.phase=='play' and T-self.playAt>14 then self:message() end
    self.typeT=self.typeT-dt
    if self.typeT<=0 and self.phase~='intro' then self.typeT=.08+self.random()*.22;self:emit('tone',{frequency=2400+self.random()*900,duration=.018,gain=.005+self.random()*.005,wave='square'}) end
    local tn=self.tune;self.fx.grade={tn.gradeR*.99,tn.gradeG,tn.gradeB};self.fx.exposure=tn.exposure*1.02;self.fx.desat=0;self.fx.sat=tn.saturation
end
function Story:update(dt,ctx)
    ctx=ctx or {};self.t=self.t+dt
    for i=#self.later,1,-1 do local l=self.later[i];l.t=l.t-dt;if l.t<=0 then table.remove(self.later,i);l.fn() end end
    self.normi:update(dt,ctx.camYaw or 0,self:walkEnabled(),0);self:updatePrompt();self.phone:update(dt)
    if self.mode=='morning' then self:stepMorning(dt) else self:stepMeeting(dt,ctx) end
end
return Story
