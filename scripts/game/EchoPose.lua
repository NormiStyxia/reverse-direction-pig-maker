-- Frozen rewind-levels.js unfold/applyRoom presentation, in source RH coordinates.
-- No gameplay state is modified here. The native adapter alone converts Z.
local Pose={}
Pose.__index=Pose
local function quaternion(x,y,z)
    local a,b,c,d,e,f=math.cos(x/2),math.sin(x/2),math.cos(y/2),math.sin(y/2),math.cos(z/2),math.sin(z/2)
    return {b*c*e+a*d*f,a*d*e-b*c*f,a*c*f+b*d*e,a*c*e-b*d*f}
end
local function rotate(q,v)
    local x,y,z,w=q[1],q[2],q[3],q[4];local a,b,c=v[1],v[2],v[3]
    local tx,ty,tz=2*(y*c-z*b),2*(z*a-x*c),2*(x*b-y*a)
    return {a+w*tx+y*tz-z*ty,b+w*ty+z*tx-x*tz,c+w*tz+x*ty-y*tx}
end
function Pose.new()
    local self=setmetatable({},Pose);self:init();return self
end
function Pose:init()
    self.loadId=0;self.rwK=0;self.handBack=0;self.wob={}
    self.root={position={0,0,0},quaternion={0,0,0,1},scale=1}
    self.crates={};self.cabinets={};self.plates={};self.fading={};self.faded={}
    ---@type number[]
    self.hands={0,0}
end
function Pose:merge(event,t)
    local list=event.pastAndTonight;local b=list[2]
    self.fading[#self.fading+1]={list=list,t=t,x=b.x,z=b.z}
end
function Pose:update(run,dt)
    if self.loadId~=run.loadId then self.loadId=run.loadId;self.rwK=0;self.handBack=0;self.wob={};self.fading={};self.faded={} end
    local S=run.sim;local R=S.room;local L=run.levels[run.index];local tm=run.t
    self.rwK=self.rwK+((S.rewinding and 1 or 0)-self.rwK)*math.min(1,dt*6)
    local k=run.fold;local sc=math.max(.001,k);local q=quaternion((1-k)*.5,(1-k)*2.4,(1-k)*.6)
    local pivot={L.start[1],0,L.start[2]};local v=rotate(q,{pivot[1]*sc,0,pivot[3]*sc})
    self.root={position={pivot[1]-v[1],-v[2],pivot[3]-v[3]},quaternion=q,scale=sc}
    self.crates={};for i,c in ipairs(R.crates) do
        local scale=1
        if c.spawnT then local k=math.min(1,(tm-c.spawnT-.18)/.4);scale=k<=0 and .01 or 1+math.sin(k*math.pi)*.18*(1-k*.5) end
        self.crates[i]={position={c.x,0,c.z},glow=.8+math.sin(tm*3)*.25+self.rwK*.6,scale=scale,source=c}
    end
    self.faded={}
    for _,f in ipairs(self.fading) do
        local k=math.min(1,(tm-f.t)/.3)
        for _,c in ipairs(f.list) do self.faded[#self.faded+1]={source=c,position={c.x+(f.x-c.x)*k*k,0,c.z+(f.z-c.z)*k*k},scale=math.max(.01,1-k*.9),visible=k<1,holoK=2*k} end
    end
    self.cabinets={}
    for i,c in ipairs(R.cabinets) do
        local dir=({{1,0},{-1,0},{0,1},{0,-1}})[math.floor(c.dir+.5)+1]
        local dx,dz=dir[1],dir[2]
        -- The model emits a new blocked wobble; decay presentation independently.
        local old=self.wob[i] or {input=0,value=0}
        if (c.wob or 0)~=old.input then old.input=c.wob or 0;old.value=old.input end
        old.value=math.max(0,old.value-dt);self.wob[i]=old;local wob=old.value
        local a=c.a+math.sin(tm*30)*.04*wob
        self.cabinets[i]={position={c.x+dx*.4,0,c.z+dz*.4},body={-dx*.4,0,-dz*.4},quaternion=quaternion(dz*a,0,-dx*a)}
    end
    self.doorOffset=.54+R.doorOpen*.95;self.doorGlow=R.doorOpen*.32
    local hold=L.door.hold or 0
    local blink=hold>0 and R.doorTimer>0 and R.doorTimer<hold and not S:solved() and (.5+.5*math.sin(tm*(6+(hold-R.doorTimer)*4))) or 0
    self.sign=(.9+.7*R.doorOpen)*(1-blink*.4)
    self.plates={};self.plateAlpha={}
    for i,p in ipairs(R.plates) do
        local base=p.type=='gold' and {.95,.72,.25} or p.type=='holo' and {.12,.5,.46} or {.55,.78,.74}
        local on=p.type=='gold' and {2.4,1.8,.6} or p.type=='holo' and {.5,2.6,2.3} or {1.4,2.2,1.9}
        self.plates[i]=p.pressed and on or base
        self.plateAlpha[i]=p.type=='holo' and (p.pressed and 1 or .55+math.sin(tm*4+p.x)*.2) or 1
    end
    self.curtain={alpha=(1-R.doorOpen)*(.55+math.sin(tm*9)*.05),scale=math.max(.02,1-R.doorOpen),offset=tm*.4}
    self.exitOn=S:exitOn();self.exitAlpha=self.exitOn and (.18+math.sin(tm*2)*.05) or .02;self.ringAngle=tm*.6
    if S.rewinding then self.handBack=self.handBack+dt*3.2 end
    self.hands={-4.25/12*math.pi*2+self.handBack/12,-math.pi/2+self.handBack}
end
return Pose
