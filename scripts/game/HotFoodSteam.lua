-- Frozen store-props.js buildHotFood. Positions and colors are Float32Array
-- outputs; internal particle integration remains double precision. RH space.
---@class HotFoodSteam
---@field parts table[]
---@field points table[]
---@field random fun():number
---@field size number
local Steam={};Steam.__index=Steam
local function f32(v) return (string.unpack('f',string.pack('f',v))) end
local emit={{4.55,1.33+.28,.75,.6,.35,.5},{5.45,1.33+.04+.62+.06,.75,.4,.3,.35},{3.72,1.33+.24,.75,.3,.3,.15}}
function Steam:respawn(p)
    local rand=self.random;local r=rand();local e=emit[1]
    for _,em in ipairs(emit) do if r<em[6] then e=em;break end;r=r-em[6] end
    p.x=e[1]+(rand()-.5)*e[4];p.y=e[2];p.z=e[3]+(rand()-.5)*e[5]
    p.vx=(rand()-.5)*.08;p.max=2+rand()*1.6;p.life=p.max
end
---@return HotFoodSteam
function Steam.new()
    local state=(77*2654435761)&0xffffffff
    local function rand()
        state=(state ~ (state<<13))&0xffffffff;state=state ~ (state>>17)
        state=(state ~ (state<<5))&0xffffffff;return state/4294967296
    end
    -- The same seeded stream first builds sausage, oden and fried-food geometry.
    for _=1,6 do if rand()>.15 then rand() end end
    for i=0,15 do rand();rand();rand();if i%2==0 then rand() end end
    for _=1,18 do rand();rand();rand();rand() end
    local self=setmetatable({random=rand,parts={},points={},size=.32},Steam)
    for i=1,90 do
        local p={};self:respawn(p);p.life=rand()*p.max;self.parts[i]=p
        self.points[i]={x=0,y=0,z=0,r=0,g=0,b=0}
    end
    return self
end
function Steam:update(dt,time,amount)
    amount=amount or 1
    for i,p in ipairs(self.parts) do
        p.life=p.life-dt;if p.life<=0 then self:respawn(p) end
        local k=1-p.life/p.max
        p.y=p.y+dt*(.35+k*.15);p.x=p.x+(p.vx+math.sin(time*1.3+i-1)*.05)*dt
        local a=math.sin(math.min(1,k)*math.pi)*.32*amount
        local v=self.points[i];v.x=f32(p.x);v.y=f32(p.y);v.z=f32(p.z)
        v.r=f32(a);v.g=f32(a);v.b=f32(a*.95)
    end
    self.size=.34+amount*.1
end
return Steam
