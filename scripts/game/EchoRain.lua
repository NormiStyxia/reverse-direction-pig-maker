-- Frozen rewind-levels.js applyRoom rain motion, in source RH coordinates.
-- This is presentation only: it never changes puzzles, player motion or save state.
---@class EchoRain
---@field drops number[][]
local Rain={}
Rain.__index=Rain
function Rain.new(seeds)
    local self=setmetatable({drops={}},Rain)
    for i,p in ipairs(seeds) do self.drops[i]={p[1],p[2],p[3]} end
    return self
end
function Rain:update(dt,rewindMix,random)
    random=random or math.random
    local fall=dt*(12+(-7-12)*rewindMix)
    for _,p in ipairs(self.drops) do
        p[2]=p[2]-fall;p[1]=p[1]-fall*.1
        if p[2]<0 then p[2]=p[2]+9;p[1]=(random()-.5)*18 end
        if p[2]>9 then p[2]=p[2]-9;p[1]=(random()-.5)*18 end
    end
end
return Rain
