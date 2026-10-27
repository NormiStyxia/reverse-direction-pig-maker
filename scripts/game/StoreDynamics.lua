-- Native presentation state from frozen store.js update()/fold().
-- Source RH coordinates throughout; StoreRenderer performs the sole conversion.
local Data=require('game.data.StoreScene')
---@class StoreDynamics
---@field random fun():number
---@field door table
---@field panes number[]
---@field flats table[]
local Dynamics={}
Dynamics.__index=Dynamics
local function smooth(v,a,b) local t=math.max(0,math.min(1,(v-a)/(b-a)));return t*t*(3-2*t) end
local function lerp(a,b,t) return a+(b-a)*t end
local function quaternion(x,y,z)
    local a,b,c,d,e,f=math.cos(x/2),math.sin(x/2),math.cos(y/2),math.sin(y/2),math.cos(z/2),math.sin(z/2)
    return {b*c*e+a*d*f,a*d*e-b*c*f,a*c*f+b*d*e,a*c*e-b*d*f}
end
local function rotate(q,v)
    local x,y,z,w=q[1],q[2],q[3],q[4];local vx,vy,vz=v[1],v[2],v[3]
    local tx,ty,tz=2*(y*vz-z*vy),2*(z*vx-x*vz),2*(x*vy-y*vx)
    return {vx+w*tx+y*tz-z*ty,vy+w*ty+z*tx-x*tz,vz+w*tz+x*ty-y*tx}
end
function Dynamics.new(random)
    local self=setmetatable({},Dynamics)
    self.random=random or math.random;self.flickT=0;self.leafT=0;self.windTime=0;self.foodAngle=0
    self.door={open=0,target=0,force=0,wasOpen=false};self.panes={};self.flats={}
    return self
end
function Dynamics:forceDoor(duration) self.door.force=duration end
function Dynamics:update(dt,state)
    local T=Data.tune;local s=state.stress or 0;local time=state.time or 0
    local day=state.day==true
    local fold=state.fold or 0;local pw=state.power==nil and 1 or state.power
    local D=self.door;local pos=state.pos;local door=Data.dynamics.door
    ---@type number
    local want=D.force>0 and 1 or 0;D.force=math.max(0,D.force-dt)
    if pos[1]>door.x0-.9 and pos[1]<door.x1+.9 and pos[3]<-4 then want=1 end
    -- Use pre-step walker positions, as in frozen store.update().
    for _,w in ipairs(state.walkers or {}) do
        if not w.done and w.pos[1]>door.x0-.9 and w.pos[1]<door.x1+.9 and w.pos[3]>-8.6 and w.pos[3]<-4 then want=math.max(want,w.halfDoor and .45 or 1) end
    end
    D.target=want;D.open=D.open+(want-D.open)*math.min(1,dt*(want>D.open and 3.2 or 2.2))
    self.doorOpened=D.open>.15 and not D.wasOpen;D.wasOpen=D.open>.15
    for i,p in ipairs(Data.handles.doorPanes) do self.panes[i]=p.home+p.side*(door.x1-door.x0)/2*.95*D.open end
    local k=smooth(s,.5,1);local slow=1-k*.7
    self.windTime=self.windTime+dt*slow*.8;self.windGust=1+k*1.5;self.leafT=self.leafT+dt*slow
    local home=Data.dynamics.leavesHome;local lt=self.leafT
    self.leaves={home[1]+(math.sin(lt*.7)*(.18+k*.5)+math.sin(lt*1.9)*.05)*T.leafSway,home[2]+math.sin(lt*.5+1)*(.08+k*.3)*T.leafSway,home[3]}
    local chair=Data.dynamics.emptyHome
    self.chairPosition={chair[1]+k*.35,chair[2],chair[3]};self.chairScale=1+k*.14
    self.clerkAngle=math.sin(time*.6)*.012;self.clerkVisible=fold<.45
    self.bounce={};for i,b in ipairs(Data.handles.bounce) do self.bounce[i]=b.base*T.bounce*(1+k*.6)*(day and 1 or .15)*(1-fold) end
    local glow=T.foodGlow*(1-k*.3)*(1-fold)
    self.food={4*glow*(.95+math.sin(time*2.3)*.05),3*glow};self.foodAngle=self.foodAngle+dt*1.6
    self.foodQuaternion=quaternion(self.foodAngle,0,math.pi/2)
    self.fridge=T.fridgeLight*(1-fold)
    self.flickT=self.flickT-dt
    if self.flickT<=0 then self.flickT=self.random()<.012 and (.06+self.random()*.16) or 0 end
    if self.flickT<=0 and self.random()<.004 then self.flickT=.35 end
    local boost=(state.flickBoost or 0)>0 and self.random()<.45 and .15 or 1
    local on=day and {1,1,1}or {lerp(0,.12,pw),self.flickT>0 and .1 or lerp(.55,.7,pw),lerp(.9,.95,pw)}
    self.tubeColors={}
    for i,v in ipairs(on) do local n=v*boost;self.tubeColors[i]={3.2*n+(day and 0 or .25),3.2*n+(day and 0 or .27),2.9*n+(day and 0 or .3)} end
    self.ceiling={}
    for i=1,#Data.handles.ceiling do
        local flick=s>.8 and self.random()<(s-.8)*.2 and .6 or 1
        self.ceiling[i]=T.ceiling*(1-k*.15)*(day and 1 or (i==1 and lerp(.06,.4,pw) or lerp(.62,1,pw)))*boost*(1-fold)*flick
    end
    self.hemiIntensity=lerp(.3,.72,pw);self.shadowStep=lerp(.04,.08,pw)
    local order={'outside','beams','wallR','back','wallL','furniture','floor'}
    local pivot=Data.dynamics.table
    for i,name in ipairs(order) do
        local j=i-1;local p=smooth(fold,j*.07,.5+j*.07);local sc=math.max(.001,1-p)
        local q=quaternion(p*.5*(j%2==1 and 1 or -1),p*2.4*(j%2==1 and -1 or 1),p*.6)
        local v=rotate(q,{pivot.x*sc,pivot.y*sc,pivot.z*sc})
        self.flats[i]={name=name,position={pivot.x-v[1],pivot.y-v[2],pivot.z-v[3]},quaternion=q,scale=sc}
    end
end
return Dynamics
