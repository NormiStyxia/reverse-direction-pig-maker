-- Frozen main.js startBridge/updateBridge; camera consumes the previous frame's
-- distance before this step, as in the original updateCamera -> updateBridge order.
local Bridge={};Bridge.__index=Bridge
function Bridge.new()
    return setmetatable({on=false,t=0,distance=1,blue=0,sweep=0},Bridge)
end
function Bridge:start() self.on=true;self.t=0 end
function Bridge:update(dt,rewindBlue)
    if not self.on then self.blue=rewindBlue or 0;self.sweep=0;self.distance=1;return end
    self.t=self.t+dt
    local k=math.max(0,math.min(1,(self.t-1.8)/3))
    self.blue=1;self.sweep=k*k*k*(k*(k*6-15)+10)
    self.distance=1+.22*(1-math.min(1,self.t/5.2))^3
    if self.t>5.2 then self.on=false;self.distance=1 end
end
return Bridge
