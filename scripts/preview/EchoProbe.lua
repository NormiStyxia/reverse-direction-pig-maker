-- Native playable prologue echo adapter; F7 diagnostics do not count as a playthrough.
local Run=require('game.EchoRun')
local Levels=require('game.data.Levels')
local View=require('render.EchoRenderer')
local Screen=require('render.EchoOverlay')
local Probe={}
Probe.__index=Probe
function Probe.new(look,theme,answer,startLevel,onProgress)
    local self=setmetatable({},Probe);self:init(look,theme,answer,startLevel,onProgress);return self
end
function Probe:init(look,theme,answer,startLevel,onProgress)
    self.run=Run.new(theme=='meeting' and Levels.chapter1 or Levels.prologue,theme or 'store');self.run.answer=answer or 'same'
    if startLevel and startLevel>1 then self.run:drainEvents();self.run:load(startLevel) end
    self.onProgress=onProgress
    self.allowFixtureProgress=false
    self.view=View.new(self.run,look);self.screen=Screen.new(self.run)
    self.active=true;self.focused=true;self.charge=false;self.restart=false;self.paused=false
    self.replay=false;self.replayFrame=0;self.replayAccumulator=0
    self.referencePending=false;self.reference=false;self.alphaStep=0
    ---@type number|false
    self.referenceAlpha=false
    self:events();print('ECHO_PROBE: '..self.run.theme..' '..#self.run.levels..' rooms; answer='..self.run.answer..'; WASD/J/K/R; F7 diagnostics, F6 pause, F8 title; visual acceptance pending')
    return self
end
function Probe:events()
    for _,e in ipairs(self.run:drainEvents()) do
        self.screen:event(e)
        if self.onProgress then self.onProgress(e) end
        if e.kind=='merge' then self.view.pose:merge(e.data,self.run.t) end
        if e.kind=='loadLevel' or e.kind=='levelPlayable' or e.kind=='exitReached' or e.kind=='echoFinished' then
            print('ECHO_FLOW: '..e.kind..' level='..e.level..' load='..e.loadId)
        end
        if e.kind=='cabinetBlocked' then
            for i,k in ipairs(self.run.sim.room.cabinets) do if k==e.data then self.view.pose.wob[i]={input=.5,value=.5} end end
        end
    end
end
function Probe:beginInputReplay()
    assert(self.run.index==1 and self.run.phase=='unfold','Continuous replay must enter the natural first level')
    self.replay=require(self.run.theme=='meeting' and 'preview.ChapterEchoRoute' or 'preview.PrologueEchoRoute')
    self.replayFrame=0;self.replayAccumulator=0;self.paused=false
    print('ECHO_CONTINUOUS_INPUT: natural chapter handoff; theme='..self.run.theme..'; no model reset')
end
function Probe:update(dt)
    if self.run.loadId~=self.view.loadId then self.view:load(self.run) end
    self.screen.loading=not self.view.view.ready
    if self.screen.loading then return end
    if self.referencePending then
        local v,r=self.view,self.run
        ---@type {x:number,y:number,z:number}
        local p=r.pig.pos
        local meeting=r.theme=='meeting'
        v.look={x=meeting and p.x*.12 or math.max(-4.5,math.min(4.5,p.x))*.85,y=meeting and .5 or .8,z=meeting and (-.7+p.z*.08) or (p.z*.7+.4)}
        v.time=r.t;v.yawOff=0;v.fovMul=1;v:update(0,r);v:updateCamera(1,r)
        self.referencePending=false;self.reference=true
        self.view.view:shadowDiagnostic(false)
        print('ECHO_REFERENCE: '..cjson.encode({level=r.index,theme=r.theme,time=r.t,look=v.look,exitAlpha=v.pose.exitAlpha,door=r.sim.room.doorOpen,width=graphics:GetWidth(),height=graphics:GetHeight()}))
    end
    if self.replay and not self.paused and self.focused then
        self.replayAccumulator=self.replayAccumulator+math.min(dt,.05)
        while self.replayAccumulator>=1/60 and self.run.phase~='done' do
            self.replayAccumulator=self.replayAccumulator-1/60;self.replayFrame=self.replayFrame+1
            local frame=self.replayFrame;local control=self.replay.inputs[frame];assert(control,'Replay exhausted')
            self.run:update(1/60,control,0,function() return .7 end);self:events()
            local e=self.replay.states[frame];local r=self.run
            assert(e.level==r.index and e.phase==r.phase and math.abs(e.x-r.pig.pos.x)<1e-7 and math.abs(e.z-r.pig.pos.z)<1e-7 and math.abs(e.door-r.sim.room.doorOpen)<1e-7 and e.timeline==#r.sim.timeline.h,'CH1 native route state mismatch frame '..frame)
            self.view:update(r.lastDt or 0,r);self.screen:update(1/60)
            if r.phase=='done' then print('ECHO_NATIVE_ROUTE: PASS; theme='..r.theme..'; '..frame..' frames; '..#r.levels..' levels; source-verified controls; no teleports; answer='..r.answer) end
            if r.loadId~=self.view.loadId or not self.view.view.ready then break end
        end
        return
    end
    if not self.paused and self.focused then
        local function held(key) return input:GetKeyDown(key) end
        local x=((held(KEY_D) or held(KEY_RIGHT)) and 1 or 0)-((held(KEY_A) or held(KEY_LEFT)) and 1 or 0)
        local y=((held(KEY_S) or held(KEY_DOWN)) and 1 or 0)-((held(KEY_W) or held(KEY_UP)) and 1 or 0)
        local spin=held(KEY_K) or held(KEY_SHIFT) or held(KEY_LSHIFT) or held(KEY_RSHIFT)
        self.run:update(dt,{x=x,y=y,spin=spin,charge=self.charge,restart=self.restart},self.view.camYaw)
        self.charge=false;self.restart=false;self:events()
        self.view:update(self.run.lastDt or 0,self.run);self.screen:update(math.min(dt,.05))
    else self.view:update(0,self.run) end
    if self.referenceAlpha~=false then self.view:tint(self.view.data.handles.exit,self.referenceAlpha) end
end
function Probe:key(key,repeated)
    if repeated then return end
    if key==KEY_F2 then self.view.view:shadowDiagnostic(true);return end
    if key==KEY_F3 then self.view.view:shadowBiasDiagnostic();return end
    if key==KEY_F11 then self.view.view:shadowFocusDiagnostic();return end
    if key==KEY_F12 and self.reference then self.view.view:shadowReceiverDiagnostic();return end
    if key==KEY_F4 or key==KEY_F6 or key==KEY_F7 then
        self.reference=false;self.referencePending=false;self.referenceAlpha=false
    end
    if key==KEY_F5 then
        self.onProgress=false;self.replay=false;self.paused=true;self.referenceAlpha=false;self.alphaStep=0
        local old=self.run;self.run=Run.new(old.levels,old.theme);self.run.answer=old.answer
        self.run:drainEvents();self.run:load(old.index);self.run.loadId=old.loadId+1
        for _=1,300 do self.run:update(1/60,{},0,function() return .7 end) end
        self.screen.run=self.run;self:events();self.view:load(self.run);self.referencePending=true;return
    end
    if key==KEY_F1 and self.reference then
        self.alphaStep=self.alphaStep%3+1;self.referenceAlpha=({0,.2,1})[self.alphaStep]
        print('ECHO_ALPHA_PROBE: '..self.referenceAlpha);return
    end
    if key==KEY_F4 then
        if not self.allowFixtureProgress then self.onProgress=false end
        -- Reset only at the start of this explicitly requested diagnostic replay.
        local old=self.run;self.run=Run.new(old.theme=='meeting' and Levels.chapter1 or Levels.prologue,old.theme);self.run.answer=old.answer;self.run.loadId=old.loadId+1
        self.screen.run=self.run;self.view:load(self.run);self:events()
        self.replay=require(old.theme=='meeting' and 'preview.ChapterEchoRoute' or 'preview.PrologueEchoRoute');self.replayFrame=0;self.replayAccumulator=0;self.paused=false
        print('ECHO_NATIVE_ROUTE: begin fixed-step real-time replay of source-verified controls; theme='..old.theme);return
    end
    if key==KEY_J or key==KEY_SPACE then self.charge=true
    elseif key==KEY_R then self.restart=true
    elseif key==KEY_F6 then self.paused=not self.paused
    elseif key==KEY_F10 then
        local r=self.run
        ---@type {x:number,y:number,z:number}
        local p=r.pig.pos
        print(string.format('ECHO_SNAPSHOT: level=%d phase=%s position=%.4f,%.4f spin=%.4f door=%.4f frames=%d',r.index,r.phase,p.x,p.z,r.pig.spinSpeed,r.sim.room.doorOpen,#r.sim.timeline.h))
    elseif key==KEY_F7 then
        self.onProgress=false
        self.run:load(self.run.index%#self.run.levels+1);self:events();self.charge=false;self.restart=false
        print('ECHO_DIAGNOSTIC_LEVEL: explicit diagnostic jump, not a solved route')
    end
end
function Probe:focus(focused) self.focused=focused;self.charge=false;self.restart=false;self.screen:cancelPointer() end
function Probe:dispose() self.screen:dispose();self.view:dispose() end
return Probe
