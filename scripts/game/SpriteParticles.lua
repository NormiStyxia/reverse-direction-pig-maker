-- Frozen main.js spawnSprite/puff/updateSprites in source RH coordinates.
-- Engine-independent; the renderer converts Z and faces the current camera.
---@alias SpriteParticle {kind:string,x:number,y:number,z:number,vx:number,vy:number,vz:number,size:number,life:number,max:number,spin:number,angle:number,grow:number,scale:number}

---@class SpriteParticles
---@field list SpriteParticle[]
---@field random fun():number
---@field puffT number
local Particles={};Particles.__index=Particles
---@param random (fun():number)?
---@return SpriteParticles
function Particles.new(random)
    ---@type SpriteParticles
    local self=setmetatable({random=random or math.random},Particles);self:reset();return self
end
function Particles:reset() self.list={};self.puffT=0 end
function Particles:spawn(kind,p,size,life,v,spin,grow)
    self.list[#self.list+1]={kind=kind,x=p.x,y=p.y,z=p.z,size=size or 1,life=life or .3,max=life or .3,
        vx=v and v.x or 0,vy=v and v.y or 0,vz=v and v.z or 0,spin=spin or 0,grow=grow or 1.6,scale=1,angle=0}
end
function Particles:puff(p,count)
    local rand=self.random
    for _=1,count or 3 do
        local pos={x=p.x+(rand()-.5)*.6,y=p.y+.15,z=p.z+(rand()-.5)*.4}
        local size=.45+rand()*.3
        local vel={x=(rand()-.5)*1.2,y=.8,z=(rand()-.5)*1.2}
        self:spawn('puff',pos,size,.45,vel,(rand()-.5)*4,.3)
    end
end
function Particles:burst(p) self:spawn('burst',{x=p.x,y=p.y+.7,z=p.z+.2},1.5,.22,nil,3,1.5) end
function Particles:event(e)
    local d=e.data or e
    if e.kind=='puff' then self:puff(d.pos or d,d.count)
    elseif e.kind=='puffCabinet' then
        local b=d.bounds
        for _=1,4 do
            local p={x=b.x0+(b.x1-b.x0)*self.random(),y=.1,z=b.z0+(b.z1-b.z0)*self.random()}
            self:puff(p,2)
        end
    elseif e.kind=='rewindPuffs' then
        self.puffT=self.puffT-d.dt
        if self.puffT>0 then return end
        self.puffT=.14
        for _,p in ipairs(d.positions) do self:puff(p,1) end
    end
end
function Particles:update(dt)
    for i=#self.list,1,-1 do
        local s=self.list[i];s.life=s.life-dt
        if s.life<=0 then table.remove(self.list,i)
        else
            local k=1-s.life/s.max
            s.x=s.x+s.vx*dt;s.y=s.y+s.vy*dt;s.z=s.z+s.vz*dt;s.angle=s.spin*k
            local sc=1+k*(s.grow-1);s.scale=s.life/s.max<.25 and sc*(s.life/s.max)*4 or sc
        end
    end
end
-- The source particle scene survives changes of rooms; particles expire normally.
Particles.shared=Particles.new()
return Particles
