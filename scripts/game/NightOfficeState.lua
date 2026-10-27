-- Increment 03 prologue-office.js. Native timers, actor, phone and object cards.
local Human=require('game.Chapter1State')
local Source=require('game.data.Story03Data')
local Scene=require('game.data.Chapter03NightScene')
local Browser=require('game.BrowseState')
local Group=require('game.GroupChat')
local State=setmetatable({},{__index=Human});State.__index=State
local L,K=Source.OFFICE_LINES,Source.OFFICE_LOOKS
local SHIFT=15.825;local DX=2.625;local X1=8.175
local function vec(x,y,z) return {x=x,y=y,z=z} end
local function mix(a,b,k) return a+(b-a)*k end
local function smooth(t,a,b) local k=math.max(0,math.min(1,(t-a)/(b-a)));return k*k*(3-2*k) end
function State.new(options)
    options=options or {};Group.reset();local s=setmetatable({},State)
    s.mode='night';s.t=0;s.clock=0;s.clockMin=1392;s.clockShow=false;s.later={};s.fired={};s.events={};s.random=options.random or math.random
    s.normi=require('game.NormiController').new(Scene.normiLayout,s.random);s.normi.obstacles=Scene.obstacles;s.normi.bounds=Scene.bounds
    s.normi:setPosition(table.unpack(Scene.start));s.normi.side=-1;s.standPhone=s.normi:frameIndex('stand-phone')
    s.phase='wait';s.look=false;s.lead=0;s.typeT=0;s.waking=options.wake~=false;s.looked={};s.people={};s.lamps={};s.carrying=false;s.sent=false;s.pending=false;s.msgs={};s.msgSeq=0
    s.interactionAt=-99;s.interactionId=false;s.wideFrame=16/9;s.tune=require('game.data.Tuning').ch1
    s.fx={desat=0,vignette=.15,kFar=14,kNear=19,grade={.95,.98,1.06},exposure=1.05,haze=0};s.result=false
    s.phone={open=false,k=0,elapsed=0,view='lock',time='23:12',battery=23,draft='',msgs={},recallable={},buttons={},history={},contact=L.group,subtitle=L.groupSub,lockLabel='23:12 · 工位',preview='收到～',previewName='小周',previewAvatar='./assets/ch1/avatar-zhou.jpg',reacts={},stickers=true}
    for _,h in ipairs(L.history) do s.phone.history[#s.phone.history+1]={me=h.me or false,stamp=h.stamp,text=h.text,name=h.from.name,avatar=h.from.avatar} end
    s.browse=Browser.new();s.browse.onThought=function(text)s:think(text)end;s.panelClosable=true
    for _,p in ipairs(Scene.handles.people) do s.people[p.who]={home=p.home,phase=p.phase,walkTo=p.walkTo,standing=false} end
    for _,l in ipairs(Scene.handles.lamps) do s.lamps[l.who]=1 end
    s:begin();return s
end
function State:faceFrame() return false end
function State:controlEnabled() return (self.phase=='play' or self.phase=='go') and not self.phone.open and not self.look end
function State:walkEnabled() return self:controlEnabled() or self.phase=='out' end
function State:cam()
    local r=self.cameraRequest;if not r then return false end
    -- Frozen main.js adds the actor offset to cam.look (not cam.target).
    local n=self.normi.pos;return {target=vec(r.target.x+n.x*.12,r.target.y,r.target.z+n.z*.08),dist=r.dist,pitch=r.pitch,snap=self.t<.3}
end
function State:begin()
    if self.phase~='wait' then return end
    self.phase='intro';self.t=0
    if self.waking then
        self.lead=2;self.normi.visible=false;self.asleep=true
        self:after(1.55,function()self.asleepY=.05;self:sound('tap');self:emit('shake',{amount=.05})end)
        self:after(1.67,function()self.asleepY=0 end)
        self:after(1.8,function()self:think(L.wake)end);self:after(3,function()self:think(L.remnant)end)
        self:after(3.6,function()self.asleep=false;self.normi.visible=true;self.normi:doTouch('hesitate');self.chairSlide=0;self:sound('slide')end)
        self:after(4.3,function()self:think(L.stretch)end)
    else self:after(1.2,function()self.normi:doTouch('hesitate');self:think(L.stretch)end) end
    self:after(self.waking and 5 or 3,function()self.phase='play';self:emit('hint',{text=L.hint,duration=6})end)
end
function State:zones()
    local z={{id='monitor',object='显示器',text='看看',x0=DX-1.6,x1=DX+1.6,z0=1.4,z1=3.4},{id='notes',object='便利贴',text='看看',x0=DX-1.6,x1=DX+1.6,z0=1.4,z1=3.4},
        {id='window',object='落地窗',text='看看',x0=-8.175,x1=-5.175,z0=-5.2,z1=3.9},{id='door',object=L.door[1],text=L.door[2],x0=X1-1.6,x1=X1+.5,z0=.4,z1=3.4}}
    if self.people['coworker-glasses'].leaveT then z[#z+1]={id='empty',object='空工位',text='看看',x0=-8.175,x1=-4.775,z0=-3.4,z1=.4} end
    if not self.carrying then table.insert(z,3,{id='box',object='档案盒',text=self.phase=='go' and '拿上' or '看看',x0=DX-1.6,x1=DX+1.6,z0=1.4,z1=3.4}) end
    return z
end
function State:nearbyInteractions()
    if not self:controlEnabled() then return {} end
    local p=self.normi.pos;local out={}
    for _,z in ipairs(self:zones()) do if p.x>=z.x0 and p.x<=z.x1 and p.z>=z.z0 and p.z<=z.z1 then z.distance=math.sqrt((p.x-(z.x0+z.x1)/2)^2+(p.z-(z.z0+z.z1)/2)^2);out[#out+1]=z end end
    table.sort(out,function(a,b)return a.distance<b.distance end);return out
end
function State:updatePrompt()
    local options=self:nearbyInteractions();local found=false
    for _,o in ipairs(options) do if o.id==self.interactionId then found=true end end
    if not found then self.interactionId=options[1] and options[1].id or false;for _,o in ipairs(options) do if o.id==(self.phase=='go' and (self.carrying and 'door' or 'box')) then self.interactionId=o.id end end end
end
function State:cycleInteraction()
    local opts=self:nearbyInteractions();for i,o in ipairs(opts) do if o.id==self.interactionId then self.interactionId=opts[i%#opts+1].id;return end end
    self.interactionId=opts[1] and opts[1].id or false
end
function State:interact(id)
    if self.look then if self.look.t>.5 then self:endLook() end;return end
    id=id or self.interactionId;local found=false;for _,o in ipairs(self:nearbyInteractions())do if o.id==id then found=true end end
    if not found or self.normi:busy() or self.t-self.interactionAt<.8 then return end
    self.interactionAt=self.t;self:sound('tap')
    if id=='door' then if not self.carrying then self:say(L.noBox);return end;self:leave()
    else self:startLook(id=='box' and self.phase=='go' and 'take' or id) end
end
function State:aim(id)
    local a=Scene.nodes[Scene.handles.screen].position;local S=vec(a[1]+SHIFT,a[2],a[3]);local target,look,dist,pitch
    if id=='monitor' then target=S;look=vec(S.x-1.25,S.y-.05,S.z);dist=.3;pitch=.12
    elseif id=='notes' then target=vec(S.x-.62,S.y+.3,S.z+.05);look=vec(target.x-1.05,target.y-.25,target.z);dist=.26;pitch=.12
    elseif id=='box' or id=='take' then a=Scene.nodes[Scene.handles.archive].position;target=vec(a[1]+SHIFT,a[2]+.25,a[3]);look=vec(target.x-1,target.y+.2,target.z);dist=.26;pitch=.2
    elseif id=='window' then target=vec(-8.175+3.8,3.3,-6.3);look=vec(target.x-.8,2.9,-3.8);dist=.36;pitch=.03
    else a=self.people['coworker-glasses'].home;target=vec(a[1]+SHIFT,1.55,a[3]);look=vec(target.x-.45,target.y+.1,target.z+.3);dist=.32;pitch=.14 end
    return target,{target=look,dist=dist,pitch=pitch}
end
function State:startLook(id)
    local k=K[id];if not k then return end
    if id~='take' then self.looked[id]=true end
    local target,cam=self:aim(id);local look={id=id,t=0,target=target};self.look=look;self.cameraRequest=cam;self.normi:face(target.x-self.normi.pos.x);self.normi:release();self:sound('slide')
    self:after(.35,function()if self.look==look then
        self.browse:show(k.title,self:hm());self.browse.presentation='look'
        self.browse.lookCard={img='ch1/looks/'..(k.img or id)..'.png',title=k.title,rows=k.rows or {},target=target,at=self.t}
    end end)
    local at=.6;for _,text in ipairs(k.say or (self.waking and k.dream or k.noDream)) do
        self:after(at,function()if self.look==look then self:think(text);self.dialog.face=k.face or 'puzzled' end end)
        local n=utf8.len(text);at=at+n*.055+math.max(2.2,1.3+n*.13)-.3
    end
end
function State:endLook()
    local look=self.look;if not look then return end
    self.look=false;self.cameraRequest=false;self.fx.focus=false;self.browse:hide();self.dialog=false;self.interactionAt=self.t
    local count=0;for _ in pairs(self.looked)do count=count+1 end;if count>=2 then self.hurryAt=self.t+2 end
    if look.id=='take' then self.carrying=true;self.interactionId=false end
end
function State:onBrowse(id) if id=='close' or id=='choice:0' then self:endLook() end end
function State:onPanel(id) if self.look then self:onBrowse(id) else self:onPhone(id) end end
function State:togglePhone()
    if self.phase~='play' and self.phase~='go' then return end;self:endLook();self:sound('tap')
    if self.phone.open then self:closePhone();return end
    self.phone.view=self.pending and 'chat' or 'lock';self.phone.open=true;self.normi.override=self.standPhone;self.normi:release();self:refreshButtons()
    if self.pending then self:after(.8,function()self:seeMessage()end) end
end
function State:saveChat()
    Group.mine={};for _,m in ipairs(self.msgs)do if not m.them then Group.mine[#Group.mine+1]={id=m.id,text=m.text,sticker=m.sticker}end end
    Group.reacts={};for id,rs in pairs(self.phone.reacts)do local a={};for i,r in ipairs(rs)do a[i]=r end;Group.reacts[id]=a end
end
function State:closePhone()self.phone.open=false;self.normi.override=false;self:saveChat()end
function State:refreshButtons()
    local close={id='close',text='收起',quiet=true}
    self.phone.buttons=self.phone.view=='lock' and {{id='chat',text='打开群聊'},close} or self.pending and {{id='pick',text=L.reply},close} or {close}
end
function State:onPhone(id)
    self:sound('tap')
    if id=='close' then self:closePhone()
    elseif id=='chat' then self.phone.view='chat';self:refreshButtons();self:after(.8,function()self:seeMessage()end)
    elseif id=='pick' and self.pending then self.phone.draft=L.reply;self.draft=true
    elseif id=='clear' then self.phone.draft='';self.draft=false
    elseif id=='send' and self.draft then self:sendReply()
    elseif id:sub(1,8)=='sticker:' then self:sendReply(id:sub(9))
    elseif id:sub(1,9)=='react:w1:' and self.pending then self:answered() end
    self:saveChat()
end
function State:seeMessage()if self.dejaVu and self.pending then self.dejaVu=false;self:think(L.deja)end end
function State:receive()
    self:endLook();self.msgs[#self.msgs+1]={id='w1',them=true,name=L.msg.from.name,avatar=L.msg.from.avatar,text=L.msg.text,time='23:20',minute=8,status='sent'}
    self.phone.msgs=self.msgs;self.phone.previewName=L.msg.from.name;self.phone.previewAvatar=L.msg.from.avatar;self.phone.preview=L.msg.text;self.pending=true;self.dejaVu=self.waking;self:sound('buzz')
    if not self.phone.open then self.normi:flinch(.3)end
    self:after(.8,function()self:think(L.msgArrive)end);if self.phone.open and self.phone.view=='chat' then self:after(2.6,function()self:seeMessage()end)end;self:refreshButtons()
end
function State:sendReply(sticker)
    local answer=self.pending;self.msgSeq=self.msgSeq+1;local m={id='m'..self.msgSeq,text=sticker and '['..Group.label(sticker)..']' or L.reply,sticker=sticker,time=answer and '23:21' or self:hm(),minute=answer and 9 or self.clock,status='sending'}
    self.msgs[#self.msgs+1]=m;self.phone.msgs=self.msgs;self.draft=false;self:sound('send');self:after(.7,function()m.status='sent'end)
    if answer then self:answered()end;self:saveChat()
end
function State:answered()
    self.draft=false;self.phone.draft='';self.pending=false;self.sent=true;self:after(1.6,function()self:think(L.hungry)end)
    self:after(2.8,function()self:closePhone();self.phase='go';self:emit('hint',{text=L.go,duration=6.5});self.interactionId=false end);self:refreshButtons()
end
function State:leave()
    self:endLook();self:closePhone();self.phase='out';self.outT=0;self:think(L.out)
    self.cameraRequest={target=vec(DX-2,2.3,-.4),dist=1.2,pitch=math.rad(19)};self.normi:moveStick(vec(X1+1.2,0,1.9));self:sound('slide')
end
function State:canSkip()return self.phase~='out' and self.phase~='done'end
function State:skip()self.later={};self:endLook();self:closePhone();self.normi.visible=true;self.asleep=false;self.carrying=true;self:leave()end
function State:update(dt,ctx)
    ctx=ctx or {};self.t=self.t+dt
    for i=#self.later,1,-1 do local a=self.later[i];a.t=a.t-dt;if a.t<=0 then table.remove(self.later,i);a.fn()end end
    local n,T=self.normi,self.t-self.lead;n:update(dt,ctx.camYaw or 0,self:walkEnabled(),0);self:updatePrompt()
    local p=self.phone;p.elapsed=p.elapsed+dt;p.time=self:hm();local to=p.open and 1 or 0;p.k=p.k+(to-p.k)*(1-math.exp(-dt*(p.open and 7 or 9)));if math.abs(p.k-to)<.002 then p.k=to end
    self.browse:update(dt);self.phoneButtonHidden=self.phase~='play' and self.phase~='go'
    if self.look then self.look.t=self.look.t+dt;local a=ctx.cameraPosition or vec(0,8,22);local b=self.look.target;self.fx.focus={dist=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2),k=smooth(self.look.t,0,.6)};if ctx.moving and self.look.t>.6 then self:endLook()end end
    if self.phase=='intro' then
        self.fx.audioFade=1-smooth(self.t,.6,2)
        local t=self.t;local k=smooth(t,self.waking and 3.4 or .8,self.waking and 5 or 3)
        self.cameraRequest={target=vec(DX+mix(self.waking and .9 or 0,self.waking and 1.6 or .6,k),mix(self.waking and 1.45 or 1.95,2.05,k),mix(self.waking and 1.35 or .45,1,k)),dist=mix(self.waking and .4 or .3,.62,k),pitch=math.rad(mix(self.waking and 9 or 7,14,k))}
        self.fx.veil={k=1-smooth(t,.45,1.3),r=mix(-.2,1.9,smooth(t,.25,1.25)),cx=.5,cy=.5}
    elseif self.phase~='out' then self.fx.veil=false;if self.phase=='play' and T>3.6 and not self.look then self.cameraRequest=false end end
    if self.hurryAt and self.t>=self.hurryAt then
        self.hurryAt=false;for _,l in ipairs(L.leave)do if not self.fired['say-'..l.who] then if self.phase=='play' and not self.look then self.lead=self.lead-math.max(0,l.at+3-math.max(T,(self.lastSayT or -9)+(self.sayGap or 3)-self.lead))end;break end end
    end
    if self.phase~='intro' then self.clock=math.min(9,(T-3)/19*8);self.clockMin=1392+math.floor(self.clock) end
    if self.phase=='play' or self.phase=='go' or self.phase=='shot' then
        for _,l in ipairs(L.leave)do local person=self.people[l.who]
            if T>=l.at+3 then self:once('say-'..l.who,function()
                local replies=type(l.reply)=='table' and l.reply or l.reply and {l.reply} or {};self.lastSayT=self.t;self.sayGap=math.max(3,2.2+#replies*1.5)
                local count=0;for _ in pairs(self.looked)do count=count+1 end;if count>=2 then self.hurryAt=self.t+self.sayGap end
                person.standing=true;self:sound('slide');self:after(.35,function()self:talk(l.who,l.say)end)
                for i,text in ipairs(replies)do self:after(2+(i-1)*1.5,function()self:think(text)end)end
            end)end
            if T>=l.at+4.2 and not person.leaveT then person.leaveT=0 end
        end
        local allGone=true;for _,v in pairs(self.people)do if (v.goneT or 0)<=.3 then allGone=false end end
        if allGone and self.phase=='play' then self:once('alone',function()
            self:endLook();self:closePhone();self.phase='shot';self.cameraRequest={target=vec(-.6,2.2,-1.2),dist=1.42,pitch=math.rad(13)}
            self:after(.7,function()self:think(L.lightsOut)end);self:after(2.5,function()self:think(L.alone)end)
            self:after(4,function()self.cameraRequest=false;self.phase='play';self:after(.8,function()self:once('msg',function()self:receive()end)end)end)
        end)end
        if T>=31 and self.phase~='shot' then self:once('msg',function()self:receive()end)end
    end
    for _,v in pairs(self.people)do if v.leaveT then v.leaveT=v.leaveT+dt;local dur=math.abs(v.walkTo-v.home[1])/4.2;if v.leaveT>=dur+.8 then v.goneT=(v.goneT or 0)+dt end end end
    for who,k in pairs(self.lamps)do local v=self.people[who];local target=v and v.leaveT and v.leaveT>1.4 and 0 or 1;self.lamps[who]=k+(target-k)*math.min(1,dt*5)end
    local typing=0;for _,v in pairs(self.people)do if not v.leaveT then typing=typing+1 end end
    self.typeT=self.typeT-dt
    if typing>0 and self.typeT<=0 then self.typeT=(.08+self.random()*.25)*(4/typing);self:emit('tone',{frequency=2400+self.random()*900,dur=.018,gain=.005+self.random()*.005,wave='square'})end
    if self.chairSlide then self.chairSlide=math.min(1,self.chairSlide+dt*1.8)end
    if self.phase=='out' then self.outT=self.outT+dt;self.fx.veil={k=smooth(self.outT,0,.6),r=mix(1.9,-.2,smooth(self.outT,.3,1.9)),pivot=vec(DX,1.85,1.25)};self.fx.audioFade=smooth(self.outT,.3,1.9)
        if self.outT>2.1 then self.phase='done';self.result={toStore=true};self:emit('finish',{result=self.result})end
    end
end
return State
