-- Engine-independent port of the frozen rewind-levels.js simulation.
-- Coordinates stay source right-handed. Render adapters must convert Z once.
local Timeline = require('game.Timeline')
local Echo = {}
Echo.__index = Echo
local BOX, HALF, HEIGHT, SLIDE = .45, .4, 2.4, 7
local keys = {'+x', '-x', '+z', '-z'}
local dirs = {['+x']={1,0}, ['-x']={-1,0}, ['+z']={0,1}, ['-z']={0,-1}}
local function copy(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
local function overlap(a,b) return a.x0<b.x1 and a.x1>b.x0 and a.z0<b.z1 and a.z1>b.z0 end
local function shrink(a,k) return {x0=a.x0+k,x1=a.x1-k,z0=a.z0+k,z1=a.z1-k} end
local function hypot(x,z) return math.sqrt(x*x+z*z) end
local function sign(x) return x>0 and 1 or x<0 and -1 or 0 end
local function rect(x0,x1,z0,z1) return {x0=x0,x1=x1,z0=z0,z1=z1} end
function Echo:emit(kind,data) self.events[#self.events+1]={kind=kind,data=data,time=self.t} end
function Echo:drainEvents() local e=self.events self.events={} return e end
function Echo.makeCrate(c)
    local kind=c.kind or (c.gold and 'gold' or 'card')
    local holo=kind=='tonight' or kind=='bag'
    return {x=c.x,z=c.z,vx=0,vz=0,moving=false,kind=kind,holo=holo,
        gold=c.gold==true or holo or kind=='now',origin=c.origin,slide=c.slide}
end
function Echo.new(level,theme)
    local self=setmetatable({},Echo)
    self:init(level,theme)
    return self
end
function Echo:init(level,theme)
    self.L=level; self.theme=theme or 'store'; self.t=0; self.playAt=0
    self.events={}; self.flags={}; self.rwCrates={}
    local R={crates={},cabinets={},plates={},statics={},merged=0,doorOpen=0.0,doorTimer=0}
    R.doorOpen=#level.door.plates==0 and 1.0 or 0.0
    self.room=R
    local pz,dx=level.partition,level.door.x
    for _,seg in ipairs({{-7.6,dx-1.23},{dx+1.23,7.6}}) do
        if seg[2]-seg[1]>.2 then R.statics[#R.statics+1]=rect(seg[1],seg[2],pz-.35,pz+.35) end
    end
    for _,w in ipairs(level.walls or {}) do
        if w.z0 then R.statics[#R.statics+1]=rect(w.x-.35,w.x+.35,w.z0,w.z1)
        else R.statics[#R.statics+1]=rect(w.x0,w.x1,w.z-.35,w.z+.35) end
    end
    if self.theme~='meeting' then R.statics[#R.statics+1]=rect(-7.6,-6.2,-4.9,-3.5) end
    for _,c in ipairs(level.crates or {}) do
        local crate=Echo.makeCrate(c)
        R.crates[#R.crates+1]=crate
        if not crate.gold then self.rwCrates[#self.rwCrates+1]=crate end
    end
    for _,c in ipairs(level.cabinets or {}) do
        local dir=2
        for i,key in ipairs(keys) do if c.auto==key then dir=i-1 end end
        R.cabinets[#R.cabinets+1]={x=c.x,z=c.z,auto=c.auto,a=0,w=0,ph=0,dir=dir,tm=0}
    end
    for _,p in ipairs(level.plates or {}) do
        local plate=copy(p)
        plate.type=p.type or (p.gold and 'gold' or 'plain')
        plate.pressed=false
        R.plates[#R.plates+1]=plate
    end
    self.timeline=Timeline.new(function() return self:snapshot() end,function(s) self:restore(s) end)
end
function Echo:snapshot()
    local s={}
    for _,c in ipairs(self.rwCrates) do s[#s+1]=c.x s[#s+1]=c.z end
    for _,k in ipairs(self.room.cabinets) do
        for _,field in ipairs({'a','w','ph','dir','tm'}) do s[#s+1]=k[field] end
    end
    return s
end
function Echo:restore(s)
    local i=1
    for _,c in ipairs(self.rwCrates) do
        if not c.gone then c.x=s[i] c.z=s[i+1] c.vx=0 c.vz=0 c.moving=false end
        i=i+2
    end
    for _,k in ipairs(self.room.cabinets) do
        for _,field in ipairs({'a','w','ph','dir','tm'}) do k[field]=s[i] i=i+1 end
    end
end
function Echo:crateBox(c,x,z) x=x or c.x z=z or c.z return rect(x-BOX,x+BOX,z-BOX,z+BOX) end
function Echo:doorBox() local x,z=self.L.door.x,self.L.partition return rect(x-1.1,x+1.1,z-.35,z+.35) end
function Echo:cabBox(k,a,key)
    a=a or k.a
    local d=dirs[key or keys[math.floor(k.dir+.5)+1]]
    local dx,dz=d[1],d[2]
    if a<.001 then return rect(k.x-HALF,k.x+HALF,k.z-HALF,k.z+HALF) end
    local function along(c,s)
        local p=c+s*HALF
        local b=p-s*HALF*2*math.cos(a)
        local f=p+s*HEIGHT*math.sin(a)
        return math.min(b,f,p),math.max(b,f,p)
    end
    if dx~=0 then local x0,x1=along(k.x,dx) return rect(x0,x1,k.z-HALF,k.z+HALF) end
    local z0,z1=along(k.z,dz) return rect(k.x-HALF,k.x+HALF,z0,z1)
end
function Echo:solids()
    local out={}
    for _,s in ipairs(self.room.statics) do out[#out+1]=s end
    for _,k in ipairs(self.room.cabinets) do out[#out+1]=self:cabBox(k) end
    if self.room.doorOpen<.8 then out[#out+1]=self:doorBox() end
    return out
end
function Echo:crateHit(c,x,z)
    if math.abs(x)>6.8 or z< -4.45 or z>3.95 then return 'wall' end
    local b=shrink(self:crateBox(c,x,z),.0001)
    for _,s in ipairs(self:solids()) do if overlap(b,s) then return 'wall' end end
    for _,o in ipairs(self.room.crates) do if o~=c and overlap(b,self:crateBox(o)) then return o end end
    return nil
end
function Echo:pair(a,b)
    return a~=nil and b~=nil and not a.gone and not b.gone and a.origin~=nil and a.origin~='' and a.origin==b.origin
        and ((a.kind=='past' and b.kind=='tonight') or (a.kind=='tonight' and b.kind=='past'))
end
function Echo:merge(a,b)
    a.gone=true b.gone=true a.moving=false b.moving=false a.vx=0 a.vz=0 b.vx=0 b.vz=0
    local remaining={}
    for _,c in ipairs(self.room.crates) do if c~=a and c~=b then remaining[#remaining+1]=c end end
    local now=Echo.makeCrate({x=b.x,z=b.z,kind='now'})
    now.spawnT=self.t now.pushed=true
    remaining[#remaining+1]=now
    self.room.crates=remaining
    self.room.merged=self.room.merged+1
    self:emit('merge',{pastAndTonight={a,b},now=now})
    self:emit('puff',{x=b.x,y=.6,z=b.z,count=6})
end
function Echo:tipCabinet(k,key)
    local fallen=shrink(self:cabBox(k,math.pi/2,key),.05)
    local blocked=false
    for _,c in ipairs(self.room.crates) do if overlap(fallen,self:crateBox(c)) then blocked=true end end
    for _,o in ipairs(self.room.cabinets) do if o~=k and overlap(fallen,self:cabBox(o)) then blocked=true end end
    if blocked then k.wob=.5 self:emit('cabinetBlocked',k) return false end
    for i,d in ipairs(keys) do if d==key then k.dir=i-1 end end
    k.ph=1 k.tm=0
    self:emit('cabinetTip',k)
    return true
end
-- Low-level impulse; the player controller must first enforce faceKey/hit distance.
function Echo:push(c,key)
    local d=assert(dirs[key])
    c.vx=d[1]*SLIDE c.vz=d[2]*SLIDE c.moving=true c.pushed=true
    self:emit('cratePush',c)
    self:emit('puff',{x=c.x,y=.2,z=c.z,count=3})
end
function Echo:simulate(dt,onlyGold)
    local R=self.room
    if not onlyGold then
        for _,c in ipairs(R.crates) do
            if c.slide and not c.slid and self.t-self.playAt>=1 then
                c.slid=true
                local d=dirs[c.slide]
                c.vx=d[1]*SLIDE c.vz=d[2]*SLIDE c.moving=true
                self:emit('automaticSlide',c)
            end
        end
    end
    local list={} for _,c in ipairs(R.crates) do list[#list+1]=c end
    for _,c in ipairs(list) do
        if not c.gone and c.moving and not (onlyGold and not c.gold) then
            local left=hypot(c.vx,c.vz)*dt
            local ux,uz=sign(c.vx),sign(c.vz)
            while left>0 do
                local s=math.min(.05,left) left=left-s
                local hit=self:crateHit(c,c.x+ux*s,c.z+uz*s)
                if not hit then c.x=c.x+ux*s c.z=c.z+uz*s
                else
                    if hit~='wall' and self:pair(c,hit) then self:merge(c,hit) break end
                    if hit~='wall' and self.theme=='meeting' and (c.holo or hit.holo) then self:emit('notSame',c) end
                    if hit~='wall' and not hit.moving then hit.vx=c.vx hit.vz=c.vz hit.moving=true end
                    c.vx=0 c.vz=0 c.moving=false left=0
                    self:emit('crateStop',c)
                    self:emit('puff',{x=c.x+ux*BOX,y=.2,z=c.z+uz*BOX,count=2})
                end
            end
        end
    end
    if onlyGold then return end
    for index,k in ipairs(R.cabinets) do
        local key='auto-'..(index-1)
        if k.ph==0 and k.auto and not self.flags[key] and self.t-self.playAt>1.6 then
            self.flags[key]=true k.ph=1 k.tm=0 self:emit('cabinetTip',k)
        end
        if k.ph==1 then
            k.tm=k.tm+dt
            k.a=math.abs(math.sin(k.tm*26))*.05*math.min(1,k.tm/.3)
            if k.tm>.5 then k.ph=2 k.w=.8 end
        elseif k.ph==2 then
            k.w=k.w+(2.5+9*math.sin(k.a))*dt k.a=k.a+k.w*dt
            if k.a>=math.pi/2 then
                k.a=math.pi/2 k.w=0 k.ph=3 self:emit('cabinetDown',k)
                self:emit('puffCabinet',{bounds=self:cabBox(k)})
            end
        end
    end
end
function Echo:accepts(p,c)
    if p.type=='holo' then return c.holo end
    if p.type=='gold' then return c.gold and not c.holo end
    return not c.holo
end
function Echo:solved()
    if #self.L.door.plates==0 then return false end
    for _,index in ipairs(self.L.door.plates) do if not self.room.plates[index+1].pressed then return false end end
    return true
end
function Echo:exitOn()
    for _,index in ipairs(self.L.exitPlates or {}) do if not self.room.plates[index+1].pressed then return false end end
    return true
end
function Echo:rewindOk(s)
    local R=self.room
    local golds={} for _,c in ipairs(R.crates) do if c.gold then golds[#golds+1]=c end end
    local door=R.doorOpen<.8 and self:doorBox() or nil
    local i,hitC,hitO=1,nil,nil
    for _,c in ipairs(self.rwCrates) do
        local b=shrink(self:crateBox(c,s[i],s[i+1]),.02) i=i+2
        if not c.gone then
            for _,o in ipairs(golds) do if overlap(b,self:crateBox(o)) then hitC=c hitO=o break end end
            if not hitC and door and overlap(b,door) then hitC=c end
            if hitC then break end
        end
    end
    if not hitC then
        for _,k in ipairs(R.cabinets) do
            local prev=copy(k) prev.a=s[i] prev.dir=s[i+3] i=i+5
            local b=shrink(self:cabBox(prev),.05)
            for _,o in ipairs(golds) do if overlap(b,self:crateBox(o)) then hitC=k hitO=o break end end
            if hitC then break end
        end
    end
    if not hitC then return true end
    if hitO and self:pair(hitC,hitO) then self:merge(hitC,hitO) return true end
    self:emit('rewindBlocked',{object=hitC,obstacle=hitO})
    return false
end
function Echo:updatePlatesAndDoor(dt)
    local R=self.room
    for _,p in ipairs(R.plates) do
        local was=p.pressed
        p.pressed=false
        for _,c in ipairs(R.crates) do
            if self:accepts(p,c) and hypot(c.x-p.x,c.z-p.z)<.5 then p.pressed=true break end
        end
        if not p.pressed and p.type=='plain' then
            for _,k in ipairs(R.cabinets) do
                if k.ph==3 and overlap(rect(p.x-.01,p.x+.01,p.z-.01,p.z+.01),shrink(self:cabBox(k),.05)) then p.pressed=true break end
            end
        end
        if p.pressed and not was then self:emit('platePressed',p) end
    end
    local D=self.L.door
    local pressed=#D.plates==0 or self:solved()
    if pressed then R.doorTimer=D.hold or 0 else R.doorTimer=math.max(0,R.doorTimer-dt) end
    local want=(pressed or R.doorTimer>0) and 1 or 0
    R.doorOpen=R.doorOpen+(want-R.doorOpen)*math.min(1,dt*3)
end
-- Call only during the playable phase, after the player controller's hit test.
function Echo:step(dt,rewinding,absoluteTime)
    self.t=absoluteTime or (self.t+dt)
    if rewinding then
        local moved=self.timeline:rewind(dt*1.15,function(s) return self:rewindOk(s) end)
        self.lastRewindMoved=moved
        if moved then
            local positions={}
            for _,c in ipairs(self.room.crates) do if not c.gold and not c.gone then positions[#positions+1]={x=c.x,y=.3,z=c.z} end end
            self:emit('rewindPuffs',{dt=dt,positions=positions})
        end
        self:simulate(dt,true)
    else
        self:simulate(dt,false)
        self.timeline:record(dt)
    end
    self:updatePlatesAndDoor(dt)
end
return Echo
