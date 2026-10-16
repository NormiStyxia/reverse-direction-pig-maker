-- Native prologue scene; reference fixtures only in the explicit diagnostics entry.
local Story=require('game.PrologueState')
local Store=require('render.StoreRenderer')
local Panel=require('render.StoryOverlay')
local Dynamics=require('game.StoreDynamics')
local Diagnostics=require('game.Diagnostics')
local Probe={}
Probe.__index=Probe
function Probe.new()
    local self=setmetatable({},Probe);self:init();return self
end
function Probe:init()
    self.story=Story.new();self.view=Store.new();self.screen=Panel.new(self.story)
    self.active=true;self.paused=false;self.focused=true;self.keyDriven=false;self.caption='';self.captionUntil=0;self.hint='';self.hintUntil=0
    self.screen.sceneActions=require('render.SceneActions').new(self.screen,function() return self.story end,true)
    self.reference=false
    self.post=require('render.ScenePost').new(self.view);self.post:setEnabled(true)
    self.bridge=require('game.SceneBridge').new()
    self.finished=false
    self.diagnostic=false
    ---@type table|false
    self.route=false
    self.screen.sceneHUD=function(canvas) self:hud(canvas) end
    print('STORE_PROBE: native source geometry; WASD/arrows move, J/Space phone, F interact, Tab select; F6 pause, F8 title')
end
function Probe:update(dt)
    if not self.view.ready or self.paused or not self.focused then self.screen:update(dt);self:updatePost(0);return end
    self:events()
    dt=math.min(.05,dt)
    ---@type number
    local x=(input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT)) and 1 or 0
    x=x-((input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT)) and 1 or 0)
    ---@type number
    local z=(input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN)) and 1 or 0
    z=z-((input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP)) and 1 or 0)
    if self.route then x,z=self.route:control(self.story) end
    local len=math.sqrt(x*x+z*z);local actor=self.story.normi
    ---@type {x:number,y:number,z:number}
    local pos=actor.pos
    if self.story:controlEnabled() and len>0 then
        actor:moveStick({x=pos.x+x/len*.8,y=0,z=pos.z+z/len*.8});self.keyDriven=true
    elseif self.keyDriven then actor:release();self.keyDriven=false end
    self.story:update(dt,{camYaw=self.view.camYaw,moving=len>0})
    self:events()
    self.view.bridgeDistance=self.bridge.distance
    self.view:update(dt,self.story)
    self.post.effects:update(dt)
    self.post.particles.model:update(dt)
    self.screen:place(self.view:actorScreen(self.story));self.screen:update(dt)
    self:updatePost(dt)
end
function Probe:updatePost(dt)
    self.bridge:update(dt or 0,0)
    if self.post then self.post:updateGame(self.story,self.screen,dt or 0,'store',nil,self.bridge) end
end
function Probe:focus(on) self.focused=on;self.keyDriven=false;self.screen:cancelPointer();self.story.normi:release() end
function Probe:events()
    for _,event in ipairs(self.story:drainEvents()) do
        require('game.AudioPlayback').get():event(event,'store')
        self.post.effects:event(event)
        self.post.particles.model:event(event)
        if event.kind=='caption' then self.caption=event.text;self.captionUntil=self.story.t+4.5
        elseif event.kind=='hint' then self.hint=event.text;self.hintUntil=self.story.t+(event.duration or 5)
        elseif event.kind=='clearCaptions' then self.captionUntil=0
        elseif event.kind=='doorForce' then self.view.dynamics:forceDoor(event.duration)
        elseif event.kind=='finish' then self.finished=true;print('STORE_PROBE_DONE: transition to native prologue echo') end
    end
end
function Probe:stageFrame()
    self.diagnostic=true
    self.finished=false
    -- Development snapshots replay the real model, but skip intermediate GPU
    -- frames. They are not an end-to-end real-time playthrough.
    self.stageIndex=(self.stageIndex or 0)%4+1
    self.story=Story.new({random=function() return .37 end})
    self.post.effects:reset()
    self.post.particles.model:reset()
    self.view.dynamics=Dynamics.new(function() return .37 end);self:events()
    local reached=false
    for _=1,4000 do
        self.story:update(.05,{camYaw=0,moving=false});self:events()
        self.post.effects:camera(.05);self.post.effects:update(.05)
        self.post.particles.model:update(.05)
        local s=self.story;local p=s.normi.pos
        self.view.dynamics:update(.05,{stress=s.sv,time=s.t,power=s.power,flickBoost=s.flickBoost,fold=s.fx.fold,pos={p.x,p.y,p.z}})
        if self.stageIndex>=3 and s.phase=='pig' then
            s.normi:setPosition(-3.35,0,-3.2);s:interact('pig');self:events()
        end
        if (self.stageIndex==1 and s.phase=='dark' and s.darkT>=3.5) or
            (self.stageIndex==2 and s.phase=='pig') or
            (self.stageIndex==3 and s.phase=='fold' and s.foldT>=2.6) or
            (self.stageIndex==4 and s.phase=='fold' and s.foldT>=4.7) then reached=true;break end
    end
    assert(reached,'Store diagnostic could not reach requested real-model stage')
    self.screen.story=self.story;self.screen:cancelPointer();self.screen:update(0)
    self.captionUntil=0;self.hintUntil=0;self.paused=true;self.reference=false
    self.view.look={x=0,y=2.05,z=-1.1};self.view.time=self.story.t;self.view:update(0,self.story)
    self.screen:place(self.view:actorScreen(self.story))
    print('STORE_STAGE_FIXTURE: '..self.stageIndex..' phase='..self.story.phase..' power='..self.story.power..' fold='..self.story.fx.fold..'; model replay, not full playthrough')
end
function Probe:key(key,repeated)
    if Diagnostics.blocks(key) then return end
    if repeated then return end
    if key==KEY_F7 and not self.reference and self.view.ready then
        -- Frozen-time visual fixture. This deliberately replays model time,
        -- and must never count as a live gameplay route.
        self.story=Story.new({random=function() return .37 end})
        for _=1,200 do self.story:update(.05,{camYaw=0,moving=false}) end
        self.story:drainEvents();self.story:openPhone('chat')
        for _=1,30 do self.story:update(.05,{camYaw=0,moving=false}) end
        self.story:drainEvents();self.paused=true;self.diagnostic=true
        self.screen.story=self.story;self.screen:cancelPointer();self.captionUntil=0;self.hintUntil=0
        self.view:update(0,self.story);self.screen:place(self.view:actorScreen(self.story));self.screen:update(1)
        if not self.post then self.post=require('render.ScenePost').new(self.view) end
        self.post:setEnabled(true);self:updatePost()
        print('SCENE_POST_FIXTURE: phone k='..self.story.phone.k..'; edge='..self.screen.placement.frostEdge..'; model replay, not live gameplay')
        return
    end
    if key==KEY_F12 and not self.reference and self.view.ready then
        if not self.post then self.post=require('render.ScenePost').new(self.view) end
        self.post:setEnabled(not self.post.enabled);self:updatePost(0);return
    end
    if key==KEY_F2 then self.view:shadowDiagnostic(true);return end
    if key==KEY_F3 then
        if self.reference then self.view:shadowNormalDiagnostic() else self.view:shadowBiasDiagnostic() end
        return
    end
    if key==KEY_F7 and self.reference then self.view:shadowMapDiagnostic();return end
    if key==KEY_F1 and self.reference then self.view:shadowSignedBiasDiagnostic();return end
    if key==KEY_F11 then self.view:shadowFocusDiagnostic();return end
    if key==KEY_F12 and self.reference then self.view:shadowCasterDiagnostic();return end
    if key==KEY_F4 and self.view.ready then self:stageFrame();return end
    if key==KEY_F5 and self.view.ready then
        self.diagnostic=true
        self.finished=false
        self.story=Story.new({deferIntro=true});self.story.normi:setPosition(4.3,0,-4.85)
        self.screen.story=self.story;self.screen:cancelPointer();self.captionUntil=0;self.hintUntil=0
        self.view:referenceFrame(self.story)
        self.post:setEnabled(false)
        self.paused=true;self.reference=true
        print('STORE_REFERENCE_FRAME: source camera, idle actor, t=0, 1920x1080; no post parity claimed');return
    end
    if key==KEY_F6 then
        if self.reference then self.reference=false;self.story:begin() end
        self.paused=not self.paused;print('STORE_PROBE_PAUSED: '..tostring(self.paused));return
    end
    if key==KEY_J or key==KEY_SPACE then self.story:togglePhone()
    elseif key==KEY_F then self.story:interact()
    elseif key==KEY_TAB then self.story:cycleInteraction()
    elseif key==KEY_ESCAPE then if self.story.browse.open then self.story:closeBrowse() else self.story:closePhone() end end
end
function Probe:hud(canvas)
    local light={240,237,223,255}
    if Diagnostics.enabled then
    canvas:text('原生场景接入校验 · 光影/后处理尚未验收',20,18,15,light,true)
    canvas:text('WASD 移动 · J 手机 · F 交互 · F4 阶段检查 · F5 对照帧 · F6 暂停 · F8 标题',20,42,14,light,true)
    end
    if not self.view.ready then canvas:text('正在加载…',20,18,18,light,true);return end
    if Diagnostics.enabled then canvas:text(self.story:hm()..'  '..self.story.phase..(self.paused and ' · 暂停' or ''),20,68,16,light,true) end
    if self.captionUntil>self.story.t then
        local width=canvas:measure(self.caption,20);canvas:text(self.caption,math.max(16,(canvas.w-width)/2),canvas.h-100,20,light,true)
    end
    if self.hintUntil>self.story.t then
        local width=canvas:measure(self.hint,16);canvas:text(self.hint,math.max(16,(canvas.w-width)/2),canvas.h-60,16,light,true)
    end
end
function Probe:dispose() if self.post then self.post:dispose() end;self.screen:dispose();self.view:dispose() end
return Probe
