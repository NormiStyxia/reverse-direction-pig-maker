-- Development integration of native meeting/office and source-verified story model.
local Story=require('game.Chapter1State')
local Panels=require('game.Chapter1Panels')
local View=require('render.Chapter1Renderer')
local Canvas=require('render.StoryOverlay')
local End=require('render.ChapterEnd')
local Diagnostics=require('game.Diagnostics')
local Captions=require('render.CaptionOverlay')
local Probe={};Probe.__index=Probe
function Probe.new(mode,look,answer,options) local self=setmetatable({},Probe);self:init(mode,look,answer,options);return self end
function Probe:init(mode,look,answer,options)
    options=options or {};options.mode=mode or 'meeting';options.answer=answer
    local Model=mode=='timeline' and require('game.TimelineState') or mode=='dream' and require('game.DreamState') or mode=='night' and require('game.NightOfficeState') or mode=='dorm' and require('game.DormState') or Story
    local Renderer=mode=='timeline' and require('render.TimelineRenderer') or mode=='dream' and require('render.DreamRenderer') or mode=='night' and require('render.NightOfficeRenderer') or mode=='dorm' and require('render.DormRenderer') or View
    self.story=Model.new(options);self.view=Renderer.new(self.story,look);self.screen=Canvas.new(self.story.browse and self.story or Panels.new(self.story))
    self.captions=Captions.new()
    self.screen.lookProject=function(target)
        local view=self.view.view;local point=Vector3(target.x,target.y,-target.z)
        if view.cameraNode:WorldToLocal(point).z<=0 then return end
        local p=view.camera:WorldToScreenPoint(point);return p.x*self.screen.w,p.y*self.screen.h
    end
    self.active=true;self.paused=false;self.focused=true;self.keyDriven=false;self.finished=false
    self.caption='';self.captionUntil=0;self.hint='';self.hintUntil=0;self.reference=false;self.stage=0
    self.ending=End.new()
    self.post=require('render.ScenePost').new(self.view.view);self.post:setEnabled(true)
    self.screen.sceneActions=require('render.SceneActions').new(self.screen,function() if self.view.ready and not self.ending.active then return self.story end end,self.story.browse~=nil)
    self.diagnostic=false
    ---@type table|false
    self.route=false
    local canvas=self.screen;local down,up,cancel=canvas.pointerDown,canvas.pointerUp,canvas.cancelPointer
    canvas.pointerDown=function(c,x,y,id) if self.ending.active then self.ending:down(c,x,y,id);return true end;return down(c,x,y,id) end
    canvas.pointerUp=function(c,x,y,id) if self.ending.active then self.ending:up(c,x,y,id);return true end;return up(c,x,y,id) end
    canvas.cancelPointer=function(c) self.ending:cancel();cancel(c) end
    self.screen.sceneHUD=function(canvas) self:hud(canvas) end
    if mode=='timeline' then require('render.TimelineOverlay').attach(self.screen,self.view,self.story) end
    print('CHAPTER1_NATIVE: '..self.story.mode..'; WASD/F/J/Tab, choices 1/2/3; F4 staged model replay, F5 reference, F6 pause, F7 morning diagnostic, F8 title')
end
function Probe:events()
    for _,e in ipairs(self.story:drainEvents()) do
        self.captions:event(e,self.story.t)
        require('game.AudioPlayback').get():event(e,'chapter')
        self.post.effects:event(e)
        self.post.particles.model:event(e)
        if e.kind=='caption' then self.caption=e.text;self.captionUntil=self.story.t+4.5
        elseif e.kind=='hint' then self.hint=e.text;self.hintUntil=self.story.t+(e.duration or 5)
        elseif e.kind=='clearCaptions' then self.captionUntil=0
        elseif e.kind=='finish' then self.finished=true;print('CHAPTER1_NATIVE_FINISH: '..self.story.mode..' answer='..tostring(self.story.answer)) end
    end
end
function Probe:update(dt)
    self.view.view:pumpBuild()
    if not self.view.view.ready then return end
    dt=math.min(.05,dt)
    self.ending:update(dt)
    if not self.paused and self.focused then
        local x=((input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT)) and 1 or 0)-((input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT)) and 1 or 0)
        local z=((input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN)) and 1 or 0)-((input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP)) and 1 or 0)
        if self.touchInput then x=x+self.touchInput.x;z=z+self.touchInput.y end
        if self.route then x,z=self.route:control(self.story) end
        local length=math.sqrt(x*x+z*z);local n=self.story.normi;local p=n.pos
        if length>0 and self.story:controlEnabled() and self.story.phase~='pigwalk' then n:moveStick({x=p.x+x/length*.8,y=0,z=p.z+z/length*.8});self.keyDriven=true
        elseif self.keyDriven then n:release();self.keyDriven=false end
        self.story:update(dt,{camYaw=self.view.camYaw,cameraPosition=self.view:cameraPosition(),moving=length>0,input={x=x,y=z},aspect=graphics:GetWidth()/math.max(1,graphics:GetHeight())});self:events();self.view:update(dt,self.story)
        require('game.AudioPlayback').get():environment(dt,self.story,'chapter')
        self.post.effects:update(dt)
        self.post.particles.model:update(dt)
    elseif not self.reference then self.view:update(0,self.story) end
    self.screen:place(self.view:actorScreen(self.story));self.screen:update(dt)
    self.post:updateGame(self.story,self.screen,(self.paused or not self.focused) and 0 or dt,'chapter')
end
function Probe:replaceStory(story)
    self.story=story;self.screen.story=Panels.new(story);self.screen.lastView=false;self.screen.lastBrowseCount=-1;self.screen:cancelPointer()
    self.finished=false;self.captionUntil=0;self.hintUntil=0;self.reference=false
end
function Probe:stageFrame()
    if self.story.mode~='meeting' then return end
    self.diagnostic=true
    self.stage=self.stage%4+1;self:replaceStory(Story.new({random=function() return .37 end}))
    local s=self.story;local reached=false
    for _=1,3000 do
        if s.phase=='play' and not s.seen.box then s.normi:setPosition(-3.6,0,1.2);s:interact('box') end
        if #s.phone.choices>0 then
            if self.stage==1 and s.choiceMode=='answer' then reached=true;break end
            s:onPanel(s.choiceMode=='answer' and 'choice:2' or 'choice:0')
        end
        if s.phase=='walk' then
            if not s.carrying then s.normi:setPosition(-3.6,0,1.2);s:interact('take')
            elseif s.doorK<.95 then s.normi:setPosition(-6.8,0,1.8)
            else
                s.normi:setPosition(-13.2,0,2.9)
                if self.stage==2 then reached=true;break end
                s:interact('put')
            end
        end
        if s.phase=='desk' then
            if self.stage==3 then reached=true;break end
            s.normi:setPosition(-14.8,0,2.5);s:interact('pig')
        end
        s:update(.05,{camYaw=0});s:drainEvents()
        if self.stage==4 and s.phase=='fold' and s.foldT>=2.5 then reached=true;break end
    end
    assert(reached,'Chapter1 diagnostic stage unavailable');self.paused=true
    self.view:updateCamera(0,s,true);self.view:update(0,s);self.screen:update(0)
    print('CHAPTER1_STAGE: '..self.stage..' '..s.phase..'; actual model replay, GPU intermediate frames skipped; not full playthrough')
end
function Probe:key(key,repeated)
    if Diagnostics.blocks(key) then return end
    if repeated then return end
    if self.story.mode=='timeline' then
        local s=self.story
        if key==KEY_A or key==KEY_LEFT then s:step(-1) elseif key==KEY_D or key==KEY_RIGHT then s:step(1)
        elseif key==KEY_W or key==KEY_UP then s:pickFloor(1) elseif key==KEY_S or key==KEY_DOWN then s:pickFloor(-1)
        elseif key==KEY_F or key==KEY_RETURN or key==KEY_SPACE then s:confirm() end;return
    end
    if self.ending.active then if key==KEY_RETURN or key==KEY_SPACE then self.ending.replay=true end;return end
    if key==KEY_F6 then self.paused=not self.paused;self.reference=false;return end
    if key==KEY_F4 and self.view.ready then self:stageFrame();return end
    if key==KEY_F5 and self.view.ready then
        self:replaceStory(Story.new({mode=self.story.mode}));self.story:update(0,{camYaw=0});self.story:drainEvents()
        self.view:updateCamera(0,self.story,true);self.view:update(0,self.story);self.reference=true;self.paused=true
        self.post:setEnabled(false)
        print('CHAPTER1_REFERENCE: '..self.story.mode..'; source raw camera/t=0; post excluded');return
    end
    if key==KEY_F7 then
        self.diagnostic=true
        self.post:dispose()
        local mode=self.story.mode=='meeting' and 'morning' or 'meeting';local old=self.view
        self:replaceStory(Story.new({mode=mode,answer=self.story.answer or 'same'}));self.view=View.new(self.story);old:dispose();self.paused=false
        self.post=require('render.ScenePost').new(self.view.view);self.post:setEnabled(true)
        print('CHAPTER1_DIAGNOSTIC: '..mode..'; explicit scene jump, not full route');return
    end
    if key==KEY_J or key==KEY_SPACE then self.story:togglePhone()
    elseif key==KEY_F then self.story:interact()
    elseif key==KEY_TAB then self.story:cycleInteraction()
    elseif key==KEY_ESCAPE then self.story:onPanel('close')
    elseif key==KEY_1 or key==KEY_2 or key==KEY_3 then
        local index=key==KEY_1 and 0 or (key==KEY_2 and 1 or 2)
        if self.story.phone.open and self.story.phone.k>=.6 and self.story.phone.choices and self.story.phone.choices[index+1] then self.story:onPanel('choice:'..index) end
    end
end
function Probe:focus(on) self.focused=on;self.keyDriven=false;self.screen:cancelPointer();self.story.normi:release() end
function Probe:hud(canvas)
    if self.ending.active then self.ending:render(canvas);return end
    local c={240,237,223,255};local s=self.story
    if Diagnostics.enabled then
    canvas:text('第一章原生接入校验 · 光影/后处理尚未验收',20,18,15,c,true)
    canvas:text('WASD 移动 · J 手机 · F 交互 · 1/2/3 回答 · F4 阶段 · F5 对照 · F6 暂停 · F7 早晨 · F8 标题',20,42,14,c,true)
    end
    if not self.view.ready then canvas:text('正在加载…',20,18,18,c,true);return end
    require('render.DialogOverlay').draw(canvas,s)
    if self.view.hud then self.view:hud(canvas,s)end
    if Diagnostics.enabled then canvas:text(s:hm()..'  '..s.phase..(self.paused and ' · 暂停' or ''),20,68,16,c,true) end
    self.captions:draw(canvas,s,self.view)
    Captions.hint(canvas,self.hint,self.hintUntil-s.t)
    if s.screenT and s.screenT>1.7 then
        local k=math.min(1,(s.screenT-1.7)/1.2);k=k*k*(3-2*k)
        local x0,y0,x1,y1=self.view:screenBounds();local x,y=x0*canvas.w*(1-k),y0*canvas.h*(1-k)
        local w,h=(x1-x0)*canvas.w*(1-k)+canvas.w*k,(y1-y0)*canvas.h*(1-k)+canvas.h*k
        local vg=canvas.vg;nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,(s.screenT-1.7)/.25))
        nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,nvgRGBA(1,64,196,255));nvgFill(vg)
        local fw=math.min(w,h*20/9);local fh=fw*9/20
        nvgIntersectScissor(vg,x+(w-fw)/2,y+(h-fh)/2,fw,fh)
        canvas:image('title/plate_flat.jpg',x+(w-fw*1.03)/2,y+(h-fh*1.03)/2,fw*1.03,fh*1.03)
        nvgRestore(vg)
    end
end
function Probe:dispose() self.post:dispose();self.screen:dispose();self.view:dispose() end
return Probe
