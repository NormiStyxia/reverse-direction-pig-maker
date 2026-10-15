-- Frozen src/pig.js movement and pose, independent of engine vector bindings.
local Pig = {}
Pig.__index = Pig
Pig.constants={height=1.55,walkSpeed=3,accel=11,chargeSpeed=15,chargeTime=.27,
    chargeCooldown=.45,spinFrame=.0255,spinMove=.75,radius=.5}
local C=Pig.constants
local atan2=math.atan2 or function(y,x) return math.atan(y,x) end
local function vec(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
local function scale(v,k) v.x=v.x*k v.y=v.y*k v.z=v.z*k end
local function clone(v) return vec(v.x,v.y,v.z) end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function Pig.new()
    local self=setmetatable({},Pig)
    self:init()
    return self
end
function Pig:init()
    self.pos=vec(0,0,2.2); self.vel=vec(); self.dir=vec(0,0,-1); self.facing=math.pi
    self.charge=0; self.cooldown=0; self.ghostTimer=0; self.spinning=false; self.spinT=0; self.spinSpeed=0
    self.stop=0; self.squash=0; self.bob=0; self.chargeDir=vec(); self.chargeHits={}; self.ghostIndex=0; self.ghosts={}
    self.spinDir=1; self.spinFrame=C.spinFrame
    for i=1,8 do self.ghosts[i]={life=0,visible=false} end
    self:setFrame(4)
    self.pose={position=clone(self.pos),yaw=0,roll=0,scale=vec(1,1,1)}
end
function Pig:setFrame(k)
    self.frame=math.floor(k)%8
    self.atlas={u=(self.frame%4)/4,v=math.floor(self.frame/4)/2,w=.25,h=.5}
end
function Pig:tryCharge()
    if self.charge>0 or self.cooldown>0 then return false end
    self.chargeHits={}
    self.charge=C.chargeTime self.chargeDir=clone(self.dir)
    self.vel=clone(self.dir) scale(self.vel,C.chargeSpeed)
    self.squash=1 self.stop=0
    return true
end
function Pig:nudge()
    self.stop=.32 self.squash=-.6 scale(self.vel,-.3)
end
function Pig:update(dt,input,camYaw,enabled)
    local x,z=input.x or 0,input.y or 0
    local len=x*x+z*z
    if len>1 then local n=math.sqrt(len) x=x/n z=z/n end
    local co,si=math.cos(camYaw),math.sin(camYaw)
    x,z=x*co+z*si,-x*si+z*co
    if not enabled then x=0 z=0 end
    self.spinning=(input.spin==true and enabled==true)
    self.spinSpeed=self.spinSpeed+((self.spinning and 1 or 0)-self.spinSpeed)*math.min(1,dt*(self.spinning and 10 or 3))
    if self.charge>0 then
        self.charge=self.charge-dt self.ghostTimer=self.ghostTimer-dt
        if self.charge<=0 then scale(self.vel,.25) self.cooldown=C.chargeCooldown end
    else
        self.cooldown=math.max(0,self.cooldown-dt)
        if self.stop>0 then self.stop=self.stop-dt x=0 z=0 end
        ---@type number
        local speed=C.walkSpeed*(self.spinning and C.spinMove or 1)
        local k=math.min(1,dt*C.accel)
        self.vel.x=self.vel.x+(x*speed-self.vel.x)*k
        self.vel.y=self.vel.y+(0-self.vel.y)*k
        self.vel.z=self.vel.z+(z*speed-self.vel.z)*k
        if x*x+z*z>.01 then
            local n=math.sqrt(x*x+z*z) self.dir=vec(x/n,0,z/n)
            self.facing=atan2(x,z)-camYaw
        end
    end
    self.pos.x=clamp(self.pos.x+self.vel.x*dt,-7,7)
    self.pos.y=self.pos.y+self.vel.y*dt
    self.pos.z=clamp(self.pos.z+self.vel.z*dt,-4.9,4.4)
    if self.spinSpeed>.05 then
        local interval=(self.spinFrame and self.spinFrame~=0) and self.spinFrame or C.spinFrame
        local direction=(self.spinDir and self.spinDir~=0) and self.spinDir or 1
        self.spinT=self.spinT+dt*self.spinSpeed/interval*direction
        self:setFrame(self.spinT)
    else
        self:setFrame(math.floor(-self.facing/(math.pi/4)+.5))
        self.spinT=self.frame
    end
    local speed=math.sqrt(self.vel.x*self.vel.x+self.vel.z*self.vel.z)
    self.bob=self.bob+dt*(6+speed*2.5)
    self.squash=self.squash*(.002^dt)
    local sx,sy=1,1
    if self.charge>0 then sx=1.32 sy=.74 else sx=1+self.squash*.25 sy=1-self.squash*.2 end
    local walkBob=(speed>.3 and self.charge<=0) and math.abs(math.sin(self.bob))*.07 or 0
    local breathe=math.sin(self.bob*.4)*.012
    local roll=0
    if self.charge>0 then local sign=self.chargeDir.x<0 and -1 or 1 roll=-sign*.12 end
    self.pose={position=vec(self.pos.x,self.pos.y+walkBob,self.pos.z),yaw=camYaw,roll=roll,scale=vec(sx,sy+breathe,1)}
end
function Pig:updateGhosts(dt,camYaw,random)
    random=random or math.random
    local spawn=self.charge>0 and self.ghostTimer<=0
    if not spawn and self.spinSpeed>.6 then spawn=random()<dt*30 end
    if spawn then
        self.ghostTimer=.03
        local g=self.ghosts[self.ghostIndex%#self.ghosts+1]
        self.ghostIndex=self.ghostIndex+1
        g.life=self.charge>0 and .22 or .14 g.max=g.life g.visible=true
        g.position=clone(self.pose.position) g.position.z=g.position.z-.02
        g.yaw=self.pose.yaw g.roll=self.pose.roll g.scale=clone(self.pose.scale)
        g.frame=self.frame g.color=self.charge>0 and 0xffd39a or 0xc8e0ff
    end
    for _,g in ipairs(self.ghosts) do
        if g.life<=0 then g.visible=false
        else g.life=g.life-dt g.opacity=math.max(0,g.life/g.max)*.35 g.yaw=camYaw end
    end
end
return Pig
