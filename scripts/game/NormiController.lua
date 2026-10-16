-- Frozen normi.js movement/poses in H5 coordinates. Only the renderer flips Z.
local Normi={}
Normi.__index=Normi
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function vec(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
local function sign(x) return x<0 and -1 or (x>0 and 1 or 0) end
local poses={idle=0,walkA=1,walkB=2,hesitate=3,touch=4,shrink=5,breakdown=6}
function Normi.new(layout,random)
    local self=setmetatable({},Normi);self:init(layout,random);return self
end
function Normi:init(layout,random)
    self.layout=layout or {frames={},walk={1}};self.random=random or math.random
    self.hang=2.6*(.92-16/768);self.stickLen=12;self.stickR=.022
    self.pos=vec();self.stickTarget=vec();self.stickTop=vec();self.vel=vec();self.dir=vec(1)
    self.verticalSpeed=0;self.side=1;self.flip=1;self.back=0;self.walking=false
    self.sway=0;self.lift=0;self.walkPhase=0;self.walkRock=0;self.act=false;self.pose=0
    self.tense=0;self.frozen=false;self.override=false;self.collapse=0;self.stickRelease=0
    self.walkPose=false;self.visible=true;self.obstacles={};self.bounds={halfW=6,zMin=-4,zMax=4}
    self:setPosition(0,0,2)
end
function Normi:setPosition(x,y,z)
    self.pos=vec(x,y,z);self.stickTarget=vec(x,y,z);self.stickTop=vec(x,y+self.hang+self.stickLen,z);self.vel=vec()
end
function Normi:moveStick(target)
    local b=self.bounds
    self.stickTarget=vec(clamp(target.x,b.xMin or -b.halfW,b.xMax or b.halfW),clamp(target.y,0,1.8),clamp(target.z,b.zMin,b.zMax))
end
function Normi:frameIndex(name)
    for _,f in ipairs(self.layout.frames) do if f.name==name then return f.index end end
    return false
end
function Normi:busy() return not not self.act or self.frozen end
function Normi:doTouch(after)
    after=after or 'shrink'
    self.act={pose=4,t=.42,next={pose=poses[after],t=after=='shrink' and .7 or .45}}
    self.vel.x=self.vel.x*.2;self.vel.y=self.vel.y*.2;self.vel.z=self.vel.z*.2
end
function Normi:flinch(t) if not self.frozen then self.act={pose=5,t=t or .6} end end
function Normi:face(x) if math.abs(x)>.05 then self.side=sign(x) end end
function Normi:release() self:moveStick(vec(self.pos.x+self.vel.x/6,self.stickTarget.y,self.pos.z+self.vel.z/6)) end
function Normi:collide()
    local p,b=self.pos,self.bounds
    p.x=clamp(p.x,b.xMin or -b.halfW,b.xMax or b.halfW);p.z=clamp(p.z,b.zMin,b.zMax)
    for _,o in ipairs(self.obstacles) do
        local x0,x1,z0,z1=o.x0-.42,o.x1+.42,o.z0-.42,o.z1+.42
        if p.x>x0 and p.x<x1 and p.z>z0 and p.z<z1 then
            local dl,dr,db,df=p.x-x0,x1-p.x,p.z-z0,z1-p.z;local m=math.min(dl,dr,db,df)
            if m==dl then p.x=x0 elseif m==dr then p.x=x1 elseif m==db then p.z=z0 else p.z=z1 end
        end
    end
end
function Normi:update(dt,camYaw,enabled,stress)
    stress=stress or 0
    local top,p,v=self.stickTop,self.pos,self.vel
    if not self.frozen then
        local k=1-math.exp(-dt*18)
        top.x=top.x+(self.stickTarget.x-top.x)*k
        top.y=top.y+(self.stickTarget.y+self.hang+self.stickLen-top.y)*k
        top.z=top.z+(self.stickTarget.z-top.z)*k
    end
    local mx,mz=top.x-p.x,top.z-p.z
    local dx,dz=mx*4,mz*4;local len=math.sqrt(dx*dx+dz*dz)
    local speed=1.5*(1-stress*.25);local k=math.min(len,speed)/(len>0 and len or 1)
    dx=dx*k;dz=dz*k
    if mx*mx+mz*mz<.09 and dx*v.x+dz*v.z<0 then dx=0;dz=0 end
    if not enabled or self:busy() then dx=0;dz=0 end
    k=1-math.exp(-dt*6);v.x=v.x+(dx-v.x)*k;v.z=v.z+(dz-v.z)*k;v.y=v.y*(1-k)
    if self.frozen or not enabled then v.x=0;v.y=0;v.z=0 end
    local oldX,oldZ=p.x,p.z;p.x=p.x+v.x*dt;p.y=p.y+v.y*dt;p.z=p.z+v.z*dt
    local beforeX,beforeY,beforeZ=p.x,p.y,p.z
    if enabled and not self.frozen then p.y=p.y+(self.stickTarget.y-p.y)*(1-math.exp(-dt*7)) end
    self.verticalSpeed=dt>0 and (p.y-beforeY)/dt or 0
    self:collide()
    if p.x~=beforeX then self.stickTarget.x=p.x;v.x=0 end
    if p.z~=beforeZ then self.stickTarget.z=p.z;v.z=0 end
    local distance=math.sqrt((p.x-oldX)^2+(p.z-oldZ)^2)
    self.walking=enabled and not self:busy() and p.y<.25 and distance>dt*(self.walking and .08 or .18)
    if self.walking then self.dir=vec((p.x-oldX)/distance,0,(p.z-oldZ)/distance);self:face(self.dir.x*math.cos(camYaw)-self.dir.z*math.sin(camYaw)) end
    if self.act then
        self.act.t=self.act.t-dt;self.pose=self.act.pose
        if self.act.t<=0 then self.act=self.act.next or false end
    elseif not self.frozen then
        if type(self.override)=='number' and not self.walking then self.pose=self.override
        elseif self.walking then self.pose=self.walkPose or (self.layout.walk and self.layout.walk[1]) or 1
        else
            self.tense=self.tense-dt
            if self.tense < -3 then self.tense=1.2+self.random()*1.5*stress end
            self.pose=stress>.35 and self.tense>0 and 3 or 0
        end
    end
    self.flip=self.flip+(self.side-self.flip)*(1-math.exp(-dt*14))
    self.flipScale=math.abs(self.flip)<.06 and .06*(self.flip==0 and 1 or sign(self.flip)) or self.flip
    if self.walking then self.walkPhase=self.walkPhase+distance*6.5 end
    if not self.frozen then
        local rock=self.walking and math.sin(self.walkPhase)*.105 or 0
        self.walkRock=self.walkRock+(rock-self.walkRock)*(1-math.exp(-dt*16))
        local sway=clamp((mx*math.cos(camYaw)-mz*math.sin(camYaw))*.04,-.09,.09)
        self.sway=self.sway+(sway+(self.act and self.act.pose==4 and .08*self.side or 0)-self.sway)*math.min(1,dt*8)
    end
    self.lift=self.lift*(1-math.min(1,dt*12))
end
return Normi
