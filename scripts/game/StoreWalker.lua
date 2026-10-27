-- Frozen store.js walker motion; source RH coordinates and zero-based callbacks.
local Spec=require('game.data.Chapter03WalkersScene').rider
local Walker={};Walker.__index=Walker
function Walker.new(onStep)
    local p=Spec.path[1].p
    return setmetatable({kind='rider',path=Spec.path,h=Spec.h,faces=Spec.faces,pos={p[1],p[2],p[3]},head={x=0,y=0,z=0},
        i=1,wait=0,side=1,flip=1,walkPhase=0,sway=0,done=false,onStep=onStep},Walker)
end
function Walker:update(dt,yaw)
    if self.done then return end
    local node=self.path[self.i];local p=self.pos;local x,z=node.p[1]-p[1],node.p[3]-p[3]
    local d=math.sqrt(x*x+z*z);local moved=0
    if d>.05 then
        moved=math.min(d,(node.speed or 1.4)*dt);x=x/d;z=z/d;p[1]=p[1]+x*moved;p[3]=p[3]+z*moved
        local screenX=x*math.cos(yaw)-z*math.sin(yaw)
        if math.abs(screenX)>.05 then self.side=screenX<0 and -1 or 1 end
    else
        self.wait=self.wait+dt
        if self.wait>=(node.wait or 0)then
            self.wait=0
            if self.onStep then self.onStep(self,self.i-1)end
            self.i=self.i+1;if self.i>#self.path then self.done=true end
        end
    end
    if d<=.05 and node.face then self.side=node.face end
    self.walkPhase=self.walkPhase+moved*6.5
    local sway=moved>0 and math.sin(self.walkPhase)*.095 or 0
    self.sway=self.sway+(sway-self.sway)*(1-math.exp(-dt*16))
    self.flip=self.flip+(self.side-self.flip)*(1-math.exp(-dt*14))
    local flip=math.abs(self.flip)<.06 and .06*(self.flip<0 and -1 or 1)or self.flip
    self.scale=flip*self.faces;self.castShadow=p[3]>-5.5
    self.head.x=p[1];self.head.y=p[2]+self.h*.95;self.head.z=p[3]
    -- Three Euler YXZ with x=0, then the renderer reflects Z once.
    local a,b=math.sin(yaw/2),math.cos(yaw/2);local c,e=math.sin(self.sway/2),math.cos(self.sway/2)
    self.quaternion={a*c,a*e,b*c,b*e}
end
return Walker
