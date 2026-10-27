-- Native increment04 afternoon interlude; reuse shop movement and browse controls.
local Base=require('game.PrologueState')
local Source=require('game.data.Story03Data')
local L=Source.DAY_LINES
local Day=setmetatable({},{__index=Base});Day.__index=Day
local function smooth(t,a,b)local k=math.max(0,math.min(1,(t-a)/(b-a)));return k*k*(3-2*k)end
function Day.new(options)
    options=options or {};local s=setmetatable({},Day)
    s.clockMin=915;Base.init(s,{deferIntro=true,random=options.random});s.mode='store-day';s.answer=options.answer or 'same'
    s.archiveVisible=false;s.phoneButtonHidden=true;s.looks=0;s.duskK=0;s.clockShow=false;s:begin();return s
end
function Day:hm()local m=self.clockMin or 915;return string.format('%02d:%02d',math.floor(m/60),math.floor(m%60))end
function Day:add()end
function Day:togglePhone()end
function Day:controlEnabled()return self.phase=='play'and not self.browse.open end
function Day:walkEnabled()return self.phase=='intro'or self.phase=='leave'or self:controlEnabled()end
function Day:canSkip()return self.phase=='intro'or self.phase=='play'or self.phase=='dusk'end
function Day:begin()
    self.introStarted=true;local n=self.normi;n:setPosition(4.3,0,-4.85);n.side=-1;n:moveStick({x=2,y=0,z=-1.6})
    self:emit('doorForce',{duration=2.2});self:after(.7,function()self:clerk(L.enter)end)
    self:after(1,function()self.clockShow=true end)
    self:after(1.8,function()n:face(-1);n.override=self.pose.lookUp;self:say(L.thinkIn,'inner')end)
    self:after(3.6,function()n.override=false;self.phase='play';self.playAt=self.t;self:emit('hint',{text=L.hint,duration=6})end)
end
function Day:startBrowse(zone)
    local list=Source.DAY_BROWSE[zone];if not list then return end
    self.activity=list[1];self.browseZone=zone;self.browseCloseText=self.activity.closeText or '放回去'
    self.browse:show(self.activity.title,self.activity.sub);self.normi.override=self.normi:frameIndex('touch');self:goBrowse('start')
end
function Day:goBrowse(id)
    local node=self.activity and self.activity.nodes[id];if not node then self:closeBrowse();return end
    self.browseCloseText=node.closeText or self.browseCloseText;self.browse.closeLabel=self.browseCloseText
    local entries={};for _,v in ipairs(node.show)do entries[#entries+1]=v end
    local choices={};self.browseNext={}
    if node['end']then entries[#entries+1]={kind='thought',text=node['end'][1]};choices={self.browseCloseText}
    else for i,v in ipairs(node.choices)do choices[i]=v[1];self.browseNext[i]=v[2]end end
    self.browse:push(entries,choices)
end
function Day:closeBrowse()
    local was=self.browse.open and self.phase=='play';Base.closeBrowse(self)
    if was then self.looks=self.looks+1;if self.looks>=2 then self:after(1.4,function()self:toDusk()end)end end
end
function Day:toDusk()
    if self.phase~='play'then return end
    self.phase='dusk';self.duskT=0;self.duskFrom=self.clockMin;Base.closeBrowse(self);self.normi.override=false
    self:after(1,function()self:say(L.late,'inner')end)
    self:after(3.8,function()
        self:emit('sound',{name='buzz'});self.normi:flinch(.35);self.msgOpen=true;self.normi.override=self.pose.standPhone
        self.browse:show('手机',self:hm());self.browse.closeLabel=L.back
        self.browse:push({{kind='msg',name='小周',avatar='ch1/avatar-zhou.jpg',text=L.zhou},{kind='msg',name='领导',avatar='ch1/avatar-leader.png',text=L.leader[self.answer]},
            {kind='thought',text=L.panic[1]},{kind='thought',text=L.panic[2]}},{L.back})
    end)
end
function Day:onBrowse(id)
    if self.msgOpen then if id=='close'or id:sub(1,7)=='choice:'then self:leave()end else Base.onBrowse(self,id)end
end
function Day:leave(fast)
    if self.phase=='leave'or self.phase=='done'then return end
    self.phase='leave';self.leaveT=fast and 1.6 or 0;self.msgOpen=false;self.later={};self.browse:hide();self.normi.override=false
    self.normi:moveStick({x=4.3,y=0,z=-4.9});self:emit('doorForce',{duration=3})
end
function Day:skip()if self:canSkip()then self.later={};self.duskFrom=self.clockMin;self.duskT=9;self:leave(true)end end
function Day:update(dt,ctx)
    ctx=ctx or {};self.t=self.t+dt
    for i=#self.later,1,-1 do local l=self.later[i];l.t=l.t-dt;if l.t<=0 then table.remove(self.later,i);l.fn()end end
    self.normi:update(dt,ctx.camYaw or 0,self:walkEnabled(),0);self:updateInteractionPrompt();self.browse:update(dt)
    if self.phase=='intro'or self.t<1.6 then self.fx.veil=self.t<1.6 and {k=1-smooth(self.t,.3,1.3),r=-.2+2.1*smooth(self.t,0,1.2),cx=.62,cy=.42}or false end
    if self.phase=='play'then
        local n=self.normi;self.idleT=math.sqrt(n.vel.x^2+n.vel.z^2)<.1 and not self.browse.open and self.idleT+dt or 0
        if self.idleT>9 then self.idleT=-12;self:say(L.idle[math.floor(self.random()*#L.idle)+1],'inner')end
        if self.t-self.playAt>32 then self:toDusk()end
    end
    if self.phase=='play'or self.phase=='intro'then self.clockMin=math.min(935,self.clockMin+dt/3)end
    if self.duskT then self.duskT=self.duskT+dt;self.duskK=smooth(self.duskT,0,3.4);self.clockMin=math.floor(self.duskFrom+(1065-self.duskFrom)*self.duskK+.5);self.clockSpin=self.duskK>0 and self.duskK<1 end
    self.browse.clock=self:hm();self.phone.time=self:hm()
    if self.phase=='leave'then
        self.leaveT=self.leaveT+dt;local t=self.leaveT;local p=self.normi.pos
        self.fx.veil={k=smooth(t,1.4,1.9),r=1.9-2.1*smooth(t,1.5,2.6),pivot={x=p.x,y=1.6,z=p.z}}
        if t>2.7 then self.phase='done';self.result={answer=self.answer};self:emit('finish',{result=self.result})end
    end
end
return Day
