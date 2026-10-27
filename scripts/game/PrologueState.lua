-- Native story model of frozen store-prologue.js + its StoreChapter behavior.
-- No DOM/engine objects. Renderer/audio consume events and continuous state.
-- Coordinates, pose/choice indices and timer ordering retain the source conventions.
---@type PrologueCatalog
local Data=require('game.data.PrologueData')
local Actor=require('game.NormiController')
local Browser=require('game.BrowseState')
local Story={}
Story.__index=Story
---@type table
local Source=require('game.data.Story03Data')
local Group=require('game.GroupChat')
local L=Source.STORE_LINES
local BROWSE=Source.STORE_BROWSE
local function copy(t)
    if type(t)~='table' then return t end
    local out={};for k,v in pairs(t) do out[k]=copy(v) end;return out
end
local function smooth(t,a,b) local x=math.max(0,math.min(1,(t-a)/(b-a)));return x*x*(3-2*x) end
local function dist(x,z) return math.sqrt(x*x+z*z) end
function Story.new(options)
    local self=setmetatable({},Story);self:init(options or {});return self
end
function Story:init(options)
    self.random=options.random or math.random
    self.normi=options.normi or Actor.new(Data.normiLayout,self.random)
    self.normi.obstacles=Data.obstacles;self.normi.bounds=Data.bounds
    self.phase='intro';self.t=0;self.clock=0;self.stress=options.startStress or 0;self.sv=self.stress/100
    self.later={};self.fired={};self.events={};self.msgs={};self.msgSeq=0;self.draft=false
    self.sentN=0;self.workI=0;self.pending=false;self.unread=false;self.offline=false;self.saidFail=false
    self.sitting=false;self.standT=-99;self.lastDoor=-99;self.idleT=0;self.walkLog={}
    self.interactionAt=-99;self.interactionId=false;self.moving=false;self.introStarted=false
    self.mem={checks=0,chats=0,sent={},doorLooks=0,sat=0,interactions={},
        tone={polite=0,ask=0,silent=0,sulk=0,blame=0,retreat=0,recall=0,resend=0,erase=0}}
    self.pose={sit=self.normi:frameIndex('sit'),sitPhone=self.normi:frameIndex('sit-phone'),standPhone=self.normi:frameIndex('stand-phone'),lookUp=self.normi:frameIndex('look-up')}
    self.phone={open=false,k=0,elapsed=0,view='lock',time=self:hm(),battery=21,draft='',msgs={},recallable={},buttons={},
        history={},reacts={},stickers=true,contact=L.group,subtitle=L.groupSub,lockLabel=L.lock,previewName='领导',previewAvatar=L.history[1].from.avatar,preview=L.history[3].text,failText=L.failText}
    local others,mine={},{}
    for _,h in ipairs(L.history)do if h.me then mine[#mine+1]=h else others[#others+1]=h end end
    mine=Group.mine or mine
    local hid={h0='h0',h1='h1',w1='h2'}
    for i,m in ipairs(mine)do if m.id then hid[m.id]='h'..(#others+i-1)end end
    for _,h in ipairs(others)do self.phone.history[#self.phone.history+1]={me=false,stamp=h.stamp,text=h.text,name=h.from and h.from.name,avatar=h.from and h.from.avatar}end
    for _,h in ipairs(mine)do self.phone.history[#self.phone.history+1]={me=true,stamp=h.stamp,text=h.text,sticker=h.sticker}end
    for id,reacts in pairs(Group.reacts)do if hid[id] and #reacts>0 then self.phone.reacts[hid[id]]=copy(reacts)end end
    self.browse=Browser.new();self.browse.onThought=function(text)self:think(text)end
    self.browseIdx={};self.activity=false;self.browseNext={}
    self.browseZone=false;self.browseCloseText='';self.phoneButtonHidden=false
    self.power=1;self.flickBoost=0;self.doodleK=0;self.doodleGone=false;self.archiveVisible=false
    self.tablePig={visible=false,spinT=0,scale=.42,light=0};self.pigK=0;self.darkT=0;self.foldT=0
    self.fx={haze=0,fold=0,audioFade=0,veil={k=0,r=1.9}};self.result=false
    if not options.deferIntro then self:begin() end
end
function Story:emit(kind,data)
    local event=data or {};event.kind=kind;event.t=self.t;self.events[#self.events+1]=event
end
function Story:drainEvents() local out=self.events;self.events={};return out end
function Story:hm()
    local total=23*60+38+math.floor(self.clock+1e-6)
    return string.format('%d:%02d',math.floor(total/60)%24,total%60)
end
function Story:tier() return self.sv<.3 and 0 or (self.sv<.6 and 1 or 2) end
function Story:controlEnabled() return (self.phase=='play' or self.phase=='dark' or self.phase=='pig') and not self.phone.open and not self.browse.open end
function Story:walkEnabled() return self.phase=='intro' or self:controlEnabled() end
function Story:after(t,fn) self.later[#self.later+1]={t=t,fn=fn} end
function Story:once(key,at,time,fn)
    if time>=at and not self.fired[key] then self.fired[key]=true;fn() end
end
function Story:add(v,isEvent)
    if self.phase~='play' and self.phase~='intro' then return end
    local cap=isEvent==false and 93 or 100
    if self.stress<cap then self.stress=math.min(cap,self.stress+v) end
end
function Story:say(text,style)
    if not text or self.phase=='done' or (self.phase=='fold' and self.foldT>.6) then return end
    if style=='inner' and text~=L.buzz then self:think(text);return end
    self:emit('caption',{speaker='normi',text=text,style=self.phone.open and 'inner' or (style or 'soft')})
end
function Story:think(text)
    local n=utf8.len(text) or 0
    self.dialog={text=text,at=self.t,hold=n*.055+math.max(2.2,1.3+n*.13),stamp=self:hm()..' · 便利店',face=text:sub(1,#'……')=='……' and 'deadpan' or 'puzzled'}
end
function Story:clerk(text)
    if self.phase~='fold' and self.phase~='done' then self:emit('caption',{speaker='clerk',text=text,style='talk'}) end
end
function Story:begin()
    if self.introStarted then return end
    self.introStarted=true;local n=self.normi
    n:setPosition(4.3,0,-4.85);n.side=-1;n.override=self.pose.standPhone;n:moveStick({x=2.4,y=0,z=-2.2})
    self:emit('doorForce',{duration=2.2})
    self:after(.7,function() self:clerk(L.enter) end)
    self:after(1.5,function() self:say(L.thinkIn,'inner') end)
    self:after(2.3,function() n.override=false;n:moveStick({x=-.7,y=0,z=-2.85}) end)
    self:after(4.4,function()
        n:face(-1);n:doTouch('hesitate');self.archiveVisible=true
        self:emit('puff',{x=Data.table.x+.42,y=Data.table.y+.2,z=Data.table.z});self:say(L.putDown)
    end)
    self:after(5.6,function() self.phase='play';self:emit('hint',{text=L.hint,duration=6.5}) end)
end
function Story:togglePhone()
    if self.phase~='play' and self.phase~='dark' and self.phase~='pig' then return end
    if self.browse.open then self:closeBrowse() end
    self:emit('sound',{name='tap'})
    if self.phone.open then self:closePhone() else self:openPhone(self.unread and 'chat' or 'lock') end
end
function Story:openPhone(view)
    self.phone.view=view;self.phone.time=self:hm();self.phone.open=true
    self.normi.override=self.sitting and self.pose.sitPhone or self.pose.standPhone
    if view=='chat' then self:readUnread() end
    self:refreshButtons()
end
function Story:closePhone() self.phone.open=false;self.phone.buttons={};self.normi.override=self.sitting and self.pose.sit or false end
function Story:readUnread()
    if not self.unread then return end
    local text=self.unread;self.unread=false;self:after(1.1,function() self:say(text,'inner') end)
end
function Story:refreshButtons()
    local p=self.phone;local close={id='close',text='收起',quiet=true}
    if self.phase=='intro' or self.phase=='fold' then p.buttons={}
    elseif p.view=='lock' then p.buttons={{id='chat',text='打开群聊'},close}
    elseif not self.pending or self.phase=='pig' then p.buttons={close}
    elseif self.pending.later then p.buttons={{id='later',text=self.pending.later},close}
    else
        p.buttons={};for i,r in ipairs(self.pending.replies) do p.buttons[#p.buttons+1]={id='pick:'..(i-1),text=r,terse=r=='……'} end
        p.buttons[#p.buttons+1]=close
    end
end
function Story:onPhone(id)
    if self.phase=='intro' or self.phase=='fold' or self.phase=='done' then return end
    self:emit('sound',{name='tap'})
    if id=='close' then self:closePhone()
    elseif id=='later' then self.pending=false;self:closePhone()
    elseif id=='chat' then self.phone.view='chat';self:readUnread();self:refreshButtons()
    elseif id:sub(1,5)=='pick:' then
        local index=tonumber(id:sub(6));local replies=self.pending and self.pending.replies
        local text=index and replies and replies[index+1]
        if text then self.draft={text=text};self.phone.draft=text end
    elseif id=='clear' then self.draft=false;self.phone.draft=''
    elseif id=='send' then self:sendDraft()
    elseif id:sub(1,8)=='sticker:' then local key=id:sub(9);self:sendDraft({sticker=key,text='['..Group.label(key)..']'})
    elseif id:sub(1,6)=='react:' and self.pending and not self.offline and id:match('^react:([^:]+):')==self.pendingId then
        self.pending=false;self.draft=false;self.phone.draft=''
        self:after(1.2,function()self:say(L.sent[math.min(self.sentN+1,#L.sent)],'inner');self.sentN=self.sentN+1 end);self:refreshButtons()
    end
end
function Story:syncMessages()
    self.phone.msgs=copy(self.msgs);self.mem.sent={}
    for _,m in ipairs(self.msgs) do if not m.them and m.status~='recalled' then self.mem.sent[#self.mem.sent+1]=m.text end end
end
function Story:sendDraft(d)
    d=d or self.draft;if not d then return end
    local answer=not not self.pending
    self.msgSeq=self.msgSeq+1
    local m={id='m'..self.msgSeq,text=d.text,sticker=d.sticker,time=self:hm(),minute=self.clock,status='sending'}
    self.msgs[#self.msgs+1]=m
    if answer or not d.sticker then self.draft=false;self.pending=false;self.phone.draft=''end
    self:syncMessages();self:emit('sound',{name='send'})
    local fail=self.offline
    self:after(.7,function()
        m.status=fail and 'failed' or 'sent';self:syncMessages()
        if fail and not self.saidFail then self.saidFail=true;self:after(.5,function() self:say(L.failed,'inner') end) end
    end)
    if not fail and answer then self:after(1.2,function() self:say(L.sent[math.min(self.sentN+1,#L.sent)],'inner');self.sentN=self.sentN+1 end) end
    self:refreshButtons()
end
function Story:receive(w)
    self.msgSeq=self.msgSeq+1
    self.msgs[#self.msgs+1]={id='w'..self.msgSeq,them=true,name=w.from.name,avatar=w.from.avatar,text=w.text,time=self:hm(),minute=self.clock,status='sent'}
    self:syncMessages();self:emit('sound',{name='buzz'});self:emit('phoneWiggle')
    self.phone.previewName=w.from.name;self.phone.previewAvatar=w.from.avatar;self.phone.preview=w.text
    if w.replies or w.later then self.pending=w;self.pendingId='w'..self.msgSeq end
    if w.after then
        if self.phone.open and self.phone.view=='chat' then self:after(1.3,function() self:say(w.after,'inner') end)
        else self.unread=w.after;if not self.browse.open and not self.phone.open then self:say(L.buzz,'inner') end end
    end
    if not self.normi:busy() and not self.phone.open and not self.sitting then self.normi:flinch(.3) end
    self:refreshButtons()
end
function Story:timeline()
    while self.workI<#L.work and self.clock>=L.work[self.workI+1].at do
        self.workI=self.workI+1;self:receive(L.work[self.workI])
    end
    self:once('rider',2.2,self.clock,function() self:emit('spawnRider') end)
    self:once('yawn',9,self.clock,function() self:clerk(L.yawn) end)
end
-- Scene walker calls back with the original zero-based route step.
function Story:riderStep(index,head)
    if index==2 then self:clerk(L.rider.hi)
    elseif index==5 then self:emit('caption',{speaker=head or 'rider',style='talk',text=L.rider.mutter})
    elseif index==9 then self:after(.6,function() self:say(L.rider.watch) end) end
end
function Story:nearbyInteractions()
    if self.phase=='dark' or not self:controlEnabled() then return {} end
    local p,z=self.normi.pos,Data.zones
    local seat=z.seat
    local pig={id='pig',object='桌上的猪',text='伸手碰它',distance=0}
    local stand={id='stand',object='窗边椅子',text='起身',distance=self.phase=='pig' and 1 or 0}
    if self.phase=='pig' then
        if self.sitting then return {pig,stand} end
        return dist(p.x-Data.table.x,p.z-Data.table.z)<2.6 and {pig} or {}
    end
    if self.sitting then return {stand,{id='window',object='窗户',text='看看窗外',distance=1}} end
    local out={};local sd=dist(p.x-seat.x,p.z-seat.z)
    if sd<seat.r+.3 then out[#out+1]={id='seat',object='窗边椅子',text='坐下',distance=sd} end
    local actions={{'door','店门','看看门外'},{'shelf','货架','看看商品'},{'fridge','饮料柜','看看饮料'},{'food','熟食区','看看熟食'},{'window','窗户','看看窗外'}}
    for _,a in ipairs(actions) do
        ---@type table
        local boxes=z[a[1]]
        local distance=math.huge
        if boxes.x0 then boxes={boxes} end
        for _,b in ipairs(boxes) do
            if p.x>=b.x0-.25 and p.x<=b.x1+.25 and p.z>=b.z0-.25 and p.z<=b.z1+.25 then distance=math.min(distance,dist(p.x-(b.x0+b.x1)/2,p.z-(b.z0+b.z1)/2)) end
        end
        if distance<math.huge then out[#out+1]={id=a[1],object=a[2],text=a[3],distance=distance} end
    end
    -- Stable insertion sort matches JavaScript sort for equal distances.
    for i=2,#out do local e=out[i];local j=i-1;while j>0 and out[j].distance>e.distance do out[j+1]=out[j];j=j-1 end;out[j+1]=e end
    return out
end
function Story:updateInteractionPrompt()
    local options=self:nearbyInteractions()
    if #options==0 then self.interactionId=false;return end
    for _,o in ipairs(options) do if o.id==self.interactionId then return end end
    self.interactionId=options[1].id
end
function Story:cycleInteraction()
    local opts=self:nearbyInteractions();if #opts==0 then return end
    local index=0;for i,o in ipairs(opts) do if o.id==self.interactionId then index=i;break end end
    self.interactionId=opts[index%#opts+1].id;self:updateInteractionPrompt()
end
function Story:sitDown()
    local n,s=self.normi,Data.zones.seat;self.sitting=true;n:setPosition(s.sitX,0,s.sitZ)
    n.act=false;n.walking=false;n.sway=0;n.walkRock=0;n.lift=0;n.side=1;n.flip=1;n.override=self.pose.sit
end
function Story:standUp() self.sitting=false;self.standT=self.t;self.normi.override=false end
function Story:interact(id)
    id=id or self.interactionId
    local opts=self:nearbyInteractions();local option=false
    for _,o in ipairs(opts) do if o.id==id then option=o;break end end
    if not id then option=opts[1] end
    if not option or self.normi:busy() or self.t-self.interactionAt<1 then return end
    self.interactionAt=self.t;self.interactionId=option.id
    self.mem.interactions[option.id]=(self.mem.interactions[option.id] or 0)+1;self:emit('sound',{name='tap'})
    if option.id=='pig' then self:startFold()
    elseif option.id=='seat' then self:sitDown();self.mem.sat=self.mem.sat+1;if self.t-self.standT<8 then self:add(4) end;self:say(L.seat)
    elseif option.id=='stand' then self:standUp()
    elseif option.id=='door' then
        self:add(self.t-self.lastDoor<20 and 6 or 2);self.lastDoor=self.t;self.mem.doorLooks=self.mem.doorLooks+1
        self.normi:face(Data.door.x0-self.normi.pos.x);self:startBrowse('door')
    elseif BROWSE[option.id] then self:startBrowse(option.id)
    else self:add(1);if not self.sitting then self.normi:doTouch('hesitate') end;if option.id=='window' then self:say(L.window) end end
    self:updateInteractionPrompt()
end
function Story:startBrowse(zone,more)
    local list=BROWSE[zone];local index=self.browseIdx[zone] or 0;local act=list[index%#list+1];self.browseIdx[zone]=index+1
    self.activity=act;self.browseZone=zone;self.browseCloseText=act.closeText or '放回去'
    if more then self.browse:retitle(act.title,act.sub);self.browse:push({{kind='divider',text=act.sub}},{}) else self.browse:show(act.title,act.sub) end
    self.mem.browse=(self.mem.browse or 0)+1;self.stress=math.max(0,self.stress-({3,1.5,0})[self:tier()+1])
    if not self.sitting then self.normi.override=self.normi:frameIndex('touch') end
    self:goBrowse('start',true)
end
function Story:goBrowse(id,first)
    local node=self.activity and self.activity.nodes[id]
    if not node then self:closeBrowse();return end
    self.browseCloseText=node.closeText or self.browseCloseText;self.browse.closeLabel=self.browseCloseText
    if node.mark then self.mem[node.mark]=true end
    local show=copy(node.show)
    -- Prologue activities have no anxiety-dependent glitch text.
    if node['end'] then show[#show+1]={kind='thought',text=node['end'][self:tier()+1]} end
    local choices={};self.browseNext={}
    if node['end'] then self.browseNext={'@more',false};choices={'再看看别的',self.browseCloseText}
    else for _,c in ipairs(node.choices) do self.browseNext[#self.browseNext+1]=c[2];choices[#choices+1]=c[1] end end
    self.browse:push(show,choices)
end
function Story:onBrowse(id)
    self:emit('sound',{name='tap'})
    if id=='close' then self:closeBrowse()
    elseif id:sub(1,7)=='choice:' then
        local index=tonumber(id:sub(8));local nextId=index and self.browseNext[index+1]
        if not nextId then self:closeBrowse() elseif nextId=='@more' then self:startBrowse(self.browseZone,true) else self:goBrowse(nextId) end
    end
end
function Story:closeBrowse()
    if not self.browse.open then return end
    self.browse:hide();self.activity=false;self.normi.override=self.sitting and self.pose.sit or false
end
function Story:move(dt)
    local speed=dist(self.normi.vel.x,self.normi.vel.z)
    if self.sitting and self.moving and self:controlEnabled() then self:standUp() end
    if not self.sitting and not self.phone.open then
        self.idleT=speed<.1 and self.idleT+dt or 0
        if self.idleT>15 then self.idleT=0;self:add(2) end
    end
    self.walkLog[#self.walkLog+1]={t=self.t,d=speed*dt}
    while #self.walkLog>0 and self.walkLog[1].t<self.t-10 do table.remove(self.walkLog,1) end
    local distance=0;for _,w in ipairs(self.walkLog) do distance=distance+w.d end
    if distance>6 then self.walkLog={};self:add(4) end
end
function Story:canSkip() return self.phase=='intro' or self.phase=='play' or self.phase=='dark' end
function Story:skip()
    if not self:canSkip() then return false end
    self.later={}
    local n=self.normi
    if self.phase=='intro' then
        n:setPosition(-.7,0,-2.85);n:moveStick({x=-.7,y=0,z=-2.85});n.override=false;n:face(-1)
        self.archiveVisible=true
    end
    if self.phone.open then self:closePhone() end
    if self.browse.open then self:closeBrowse() end
    self.clock=12;self.workI=#L.work;self.pending=false
    for _,key in ipairs({'d-blink','d-cut','d-clerk','d-b','d-c','d-gone','d-pig','d-table'}) do self.fired[key]=true end
    self.flickBoost=0;self.power=0;self.offline=true;self:emit('sound',{name='powerCut'})
    self.doodleGone=true;self.doodleK=0;self.tablePig.visible=true;self.tablePig.spinT=0
    self:emit('puff',{x=Data.table.x,y=Data.table.y+.3,z=Data.table.z,count=3});self:emit('pigReady')
    self.phase='pig';self.phoneButtonHidden=true;self:emit('hint',{text=L.pig.hint,duration=6.5})
    return true
end
function Story:startReply()
    if self.phase~='play' then return end
    self.phase='dark';self.darkT=0;self:receive(L.cut);self.pending=false
end
function Story:updateDark(dt)
    self.darkT=self.darkT+dt;local t=self.darkT
    self:once('d-blink',.4,t,function() self.flickBoost=1;self:say(L.dark.blink,'inner');self:emit('tone',{frequency=2400,dur=1.6,gain=.006,wave='sawtooth'}) end)
    self:once('d-cut',1.6,t,function()
        self.flickBoost=0;self.power=0;self.offline=true;self:emit('sound',{name='powerCut'});self:emit('shake',{amount=.1})
        if self.browse.open then self:closeBrowse() end
    end)
    self:once('d-clerk',3.2,t,function() self:clerk(L.dark.clerk) end)
    self:once('d-b',5,t,function() self:say(L.dark.b,'inner') end)
    self:once('d-c',6.2,t,function() self:say(L.dark.c,'inner') end)
    if t>7 and t<8.2 then self.doodleK=math.sin(smooth(t,7,8.2)*math.pi) end
    self.fx.blue=((t>7.52 and t<7.59) or (t>8.2 and t<8.25)) and .85 or 0
    self:once('d-gone',7.6,t,function() self.doodleGone=true end)
    self:once('d-pig',8.2,t,function()
        self.doodleK=0;self.tablePig.visible=true;self.tablePig.spinT=0
        self:emit('puff',{x=Data.table.x,y=Data.table.y+.3,z=Data.table.z,count=3})
        self:emit('tone',{frequency=330,dur=.6,gain=.04,wave='sine',slide=.6})
        self:say(L.pig.gone,'inner');self:emit('pigReady')
    end)
    self:once('d-table',9.2,t,function()
        self:say(L.pig.table,'inner');self.phase='pig';if self.phone.open then self:closePhone() end
        self.phoneButtonHidden=true;self:emit('hint',{text=L.pig.hint,duration=6.5})
    end)
    self:updateTablePig(dt)
end
function Story:updateTablePig(dt)
    local p=self.tablePig;if not p.visible then return end
    local fold=self.phase=='fold'
    p.spinT=p.spinT-dt/(fold and .09/(1+self.foldT*1.5) or .09)
    p.scale=.42*(fold and 1+smooth(self.foldT,.3,3.4)*1.4 or 1)
    self.pigK=math.min(1,self.pigK+dt*.8);p.light=2.2*self.pigK*(fold and 1+self.foldT or 1)
end
function Story:startFold()
    if self.phase~='pig' then return end
    self.phase='fold';self.foldT=0;self.dialog=false;self:emit('clearCaptions');self:emit('hint',{text='……',duration=.4})
    if not self.sitting then self.normi:doTouch('hesitate') end
    self.normi:face(Data.table.x-self.normi.pos.x);self:emit('flash',{amount=.25});self:emit('sound',{name='thunder',amount=.5});self:say('……','inner')
end
function Story:updateFold(dt)
    self.foldT=self.foldT+dt;local t,f=self.foldT,self.fx
    f.blue=smooth(t,1.4,2.6)*(1-smooth(t,3.4,4.4))*.45
    f.haze=smooth(t,.4,2.2)*(1-smooth(t,4.6,5.4));f.fold=smooth(t,.9,4.3);f.audioFade=smooth(t,1,4)
    if t>1.8 and self.normi.visible then self.normi.visible=false;self:emit('puff',{x=self.normi.pos.x,y=.3,z=self.normi.pos.z}) end
    -- Veil center is the projected table pig, supplied by the renderer.
    f.veil={k=smooth(t,1.6,2.4),r=1.9+(-.18-1.9)*smooth(t,1.8,4.6)}
    if t>4.9 and self.phase~='done' then
        self.phase='done';local own={};for _,m in ipairs(self.msgs) do if not m.them then own[#own+1]=copy(m) end end
        self.result={mem=copy(self.mem),stress=self.stress,tier=self:tier(),reply='',msgs=own};self:emit('finish',{result=self.result})
    end
end
function Story:skipAhead(dt)
    self.settleT=(not self.pending and not self.unread and not self.browse.open) and (self.settleT or 0)+dt or 0
    if self.settleT<2 then return end
    self.settleT=0;local nextAt=self.workI<#L.work and L.work[self.workI+1].at or 12
    if (nextAt-self.clock)*5>2.5 then self.clock=nextAt-.1 end
end
function Story:update(dt,ctx)
    ctx=ctx or {};self.t=self.t+dt;self.moving=not not ctx.moving
    -- Reverse traversal is deliberate: new callbacks wait until the next frame.
    for i=#self.later,1,-1 do local l=self.later[i];l.t=l.t-dt;if l.t<=0 then table.remove(self.later,i);l.fn() end end
    if self.phase=='play' then
        self.clock=math.min(12,self.clock+dt/5);self:timeline()
        local floor=self.clock>=10 and 35 or (self.clock>=5 and 15 or 0)
        if self.stress<floor then self.stress=self.stress+math.min(floor-self.stress,dt*3) end
        self:add(dt*.18,false);self:move(dt);if self.clock>=12 then self:startReply() end
    end
    if self.phase=='pig' or self.phase=='fold' or self.phase=='done' then
        if self.phase=='fold' or self.phase=='done' then self:updateFold(dt) end
        self:updateTablePig(dt)
    end
    self.sv=self.sv+(self.stress/100-self.sv)*math.min(1,dt*1.5)
    local n=self.normi
    if self.sitting then n.side=1;n.flip=1;n.act=false end
    n:update(dt,ctx.camYaw or 0,self:walkEnabled() and not self.sitting,self.sv*.6)
    self:updateInteractionPrompt();self.phone.time=self:hm();self.browse.clock=self:hm()
    self.phone.elapsed=self.phone.elapsed+dt
    local target=self.phone.open and 1 or 0
    self.phone.k=self.phone.k+(target-self.phone.k)*(1-math.exp(-dt*(self.phone.open and 7 or 9)))
    if math.abs(self.phone.k-target)<.002 then self.phone.k=target end
    self.browse:update(dt)
    if self.phase=='play' then
        local still=dist(n.vel.x,n.vel.z)<.1 and not self.phone.open and not self.browse.open
        self.idleT=still and self.idleT+dt or 0
        if self.idleT>9 then self.idleT=-12;self:say(L.idle[math.floor(self.random()*#L.idle)+1],'inner') end
    end
    if self.phase=='play' then self:skipAhead(dt)end
    if self.phase=='dark' then self:updateDark(dt) end
end
return Story
