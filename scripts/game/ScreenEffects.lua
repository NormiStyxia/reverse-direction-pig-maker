-- Frozen main.js hooks/updateCamera/final uniforms, independent of engine APIs.
-- Only gameplay events raise these values; never add ambient camera jitter.
---@class ScreenEffects
---@field shock number
---@field shockSeed number
---@field flash number
---@field shake number
---@field x number
---@field y number
---@field random fun():number
local Effects={};Effects.__index=Effects
function Effects.new(random)
    local self=setmetatable({random=random or math.random},Effects);self:reset();return self
end
function Effects:reset() self.shock=0;self.shockSeed=0;self.flash=0;self.shake=0;self.x=0;self.y=0 end
function Effects:trigger(kind,value)
    if kind=='shock' then self.shock=math.max(self.shock,value);self.shockSeed=self.random()*100
    elseif kind=='flash' then self.flash=math.max(self.flash,value)
    elseif kind=='shake' then self.shake=math.max(self.shake,value) end
end
function Effects:event(e)
    local kind=e.kind
    if kind=='flash' or kind=='shake' or kind=='shock' then
        self:trigger(kind,e.amount or (type(e.data)=='number' and e.data) or (e.data and e.data.amount) or 0)
    -- These source hooks are inside RewindLevels methods, represented by semantic
    -- simulation events in the port. No feedback on automatic slide/rewind alone.
    elseif kind=='crateStop' then self:trigger('shake',.12)
    elseif kind=='cabinetDown' then self:trigger('shake',.45)
    elseif kind=='merge' then self:trigger('flash',.6);self:trigger('shake',.3)
    elseif kind=='exitReached' then self:trigger('flash',.4) end
end
function Effects:camera(dt)
    -- Paused/unfocused adapters can redraw with dt=0. Reuse the previous offset
    -- instead of drawing fresh random values, which would shake a frozen frame.
    if dt<=0 then return self.x,self.y end
    self.shake=self.shake*.002^dt
    self.x,self.y=0,0
    if self.shake>.002 then
        self.x=(self.random()-.5)*self.shake*.5
        self.y=(self.random()-.5)*self.shake*.5
    end
    return self.x,self.y
end
function Effects:update(dt)
    self.shock=self.shock*.02^dt
    self.flash=self.flash*.0005^dt
end
-- main.js keeps one fx/rig across all rooms and chapters, reset on page reload.
Effects.shared=Effects.new()
return Effects
