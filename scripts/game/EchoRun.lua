-- Echo flow and main-loop ordering. No rendering APIs or debug-skip shortcuts.
local Simulation=require('game.EchoSimulation')
local Pig=require('game.PigController')
local Contact=require('game.EchoPlayer')
local Run={}
Run.__index=Run
local function smooth(t,a,b)
    local x=math.max(0,math.min(1,(t-a)/(b-a))) return x*x*(3-2*x)
end
function Run.new(levels,theme)
    local self=setmetatable({},Run)
    self:init(levels,theme)
    return self
end
---@param levels {start:number[],exit:number[]}[]
function Run:init(levels,theme)
    self.levels=levels; self.theme=theme or 'store'; self.pig=Pig.new()
    self.events={}; self.hitstop=0; self.loadId=0
    self.pig.spinDir=-1 self.pig.spinFrame=.05
    self:load(1)
end
function Run:emit(kind,data) self.events[#self.events+1]={kind=kind,data=data,level=self.index,loadId=self.loadId} end
function Run:drainEvents() local e=self.events self.events={} return e end
function Run:load(index)
    assert(self.levels[index],'Invalid echo level')
    self.index=index self.loadId=self.loadId+1
    self.sim=Simulation.new(self.levels[index],self.theme)
    self.t=0 self.phase='unfold' self.playAt=math.huge self.fold=0
    self.veil={k=1,r=-.2}
    local P=self.pig
    ---@type {start:number[],exit:number[]}
    local L=self.levels[index]
    P.pos.x=L.start[1] P.pos.y=0 P.pos.z=L.start[2]
    P.vel.x=0 P.vel.y=0 P.vel.z=0 P.facing=0 P.charge=0
    self:emit('loadLevel',{index=index,definition=L})
end
function Run:leave(nextIndex,duration)
    self.phase='out' self.outT=0 self.outDur=duration or 1.4 self.nextIndex=nextIndex
    self:emit('leaveLevel',{nextIndex=nextIndex,duration=self.outDur})
end
function Run:restart()
    if self.phase~='play' then return false end
    self:leave(self.index,.7) return true
end
function Run:update(realDt,input,camYaw,random)
    if self.phase=='done' then return end
    local dt=math.min(.05,realDt)
    if self.hitstop>0 then self.hitstop=self.hitstop-dt dt=dt*.05 end
    self.lastDt=dt
    input=input or {}
    if input.restart then self:restart() end
    if input.charge and self.phase=='play' and not input.revealing then
        if self.pig:tryCharge() then self:emit('playerCharge',self.pig.pos) end
    end
    local live=self.phase=='play' and not input.revealing
    self.pig:update(dt,live and input or {x=0,y=0,spin=false},input.revealing and 0 or (camYaw or 0),live)
    self.pig:updateGhosts(dt,camYaw or 0,random)
    self.t=self.t+dt self.sim.t=self.t
    local P,S=self.pig,self.sim
    if self.phase=='unfold' then
        local T=self.t
        self.fold=smooth(T,.3,2.4)
        P.spinT=P.spinT-dt/.05*(1-smooth(T,1.8,2.6))
        if T<2.6 then P:setFrame(P.spinT) end
        self.veil={k=1-smooth(T,2.7,3.4),r=-.2+2.1*smooth(T,.1,2.9)}
        if T>2.6 then
            self.phase='play' self.playAt=T S.playAt=T self.veil=nil self.fold=1
            P.squash=1.1 P:setFrame(0)
            self:emit('levelPlayable',self.index)
        end
    end
    if self.phase=='out' then
        self.outT=self.outT+dt
        local T,D=self.outT,self.outDur
        self.veil={k=smooth(T,0,D*.25),r=1.9-2.1*smooth(T,D*.05,D*.9)}
        if T>=D then
            if self.nextIndex>#self.levels then self.phase='done' self:emit('echoFinished',self.theme) return end
            self:load(self.nextIndex)
        end
        return
    end
    live=self.phase=='play'
    S.rewinding=live and P.spinning and P.spinSpeed>.35
    if live then
        Contact.hitTest(S,P,dt)
        S:step(dt,S.rewinding,self.t)
    else S:updatePlatesAndDoor(dt) end
    if self.phase~='unfold' then Contact.collide(S,P.pos) end
    ---@type {start:number[],exit:number[]}
    local L=self.levels[self.index]
    local dx,dz=P.pos.x-L.exit[1],P.pos.z-L.exit[2]
    if live and S:exitOn() and math.sqrt(dx*dx+dz*dz)<.8 then
        self:emit('exitReached',self.index)
        self:leave(self.index+1,self.index==#self.levels and 2.4 or 1.4)
    end
    for _,event in ipairs(S:drainEvents()) do
        if event.kind=='hitstop' then self.hitstop=math.max(self.hitstop,event.data)
        elseif event.kind=='merge' then self.hitstop=math.max(self.hitstop,.1)
        elseif event.kind=='cabinetDown' then self.hitstop=math.max(self.hitstop,.05) end
        self:emit(event.kind,event.data)
    end
end
return Run
