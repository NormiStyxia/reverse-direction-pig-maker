-- Player/object contact methods ported from frozen rewind-levels.js.
local Player={}
local dirs={['+x']={1,0},['-x']={-1,0},['+z']={0,1},['-z']={0,-1}}
local radius=.5
local function scale(v,k) v.x=v.x*k v.y=v.y*k v.z=v.z*k end
function Player.faceKey(P,c)
    local rx,rz=P.pos.x-c.x,P.pos.z-c.z
    local key
    if math.abs(rx)>math.abs(rz) then key=rx>0 and '-x' or '+x'
    else key=rz>0 and '-z' or '+z' end
    local d=dirs[key]
    if d[1]*P.chargeDir.x+d[2]*P.chargeDir.z>.45 then return key end
    return nil
end
function Player.hitTest(S,P,dt)
    local R=S.room
    local function distance(o)
        local x=math.max(math.abs(P.pos.x-(o.x0+o.x1)/2)-(o.x1-o.x0)/2,0)
        local z=math.max(math.abs(P.pos.z-(o.z0+o.z1)/2)-(o.z1-o.z0)/2,0)
        return math.sqrt(x*x+z*z)
    end
    local near
    local function consider(kind,o,b)
        local d=distance(b)
        -- Stable tie order matches JS: crates first, then cabinets in room order.
        if not near or d<near.d then near={kind=kind,o=o,d=d} end
    end
    for _,c in ipairs(R.crates) do if not c.moving and not c.phased then consider('crate',c,S:crateBox(c)) end end
    for _,k in ipairs(R.cabinets) do if k.ph==0 and not k.auto then consider('cab',k,S:cabBox(k)) end end
    if P.charge>0 and near and near.d<radius+.2 and not P.chargeHits[near.o] then
        local cd=P.chargeDir
        local key
        if math.abs(cd.x)>math.abs(cd.z) then key=cd.x>0 and '+x' or '-x'
        else key=cd.z>0 and '+z' or '-z' end
        local face=key
        if near.kind=='crate' then face=Player.faceKey(P,near.o) end
        if not face then return end
        P.chargeHits[near.o]=true P.charge=.001 scale(P.vel,.1)
        S.stuckT=0 S:emit('hitstop',.06) S:emit('shake',.22)
        if near.kind=='crate' then S:push(near.o,face) else S:tipCabinet(near.o,key) end
        return
    end
    local leaning=P.charge<=0 and near and near.kind=='crate' and near.d<radius+.06
        and math.sqrt(P.vel.x*P.vel.x+P.vel.z*P.vel.z)>.2 and not S.rewinding
    S.stuckT=leaning and (S.stuckT or 0)+dt or 0
    if S.stuckT>.45 then S.stuckT=-3 S:emit('tooHeavy',near.o) end
end
function Player.collide(S,p)
    local list={}
    for _,s in ipairs(S.room.statics) do list[#list+1]=s end
    for _,k in ipairs(S.room.cabinets) do list[#list+1]=S:cabBox(k) end
    for _,c in ipairs(S.room.crates) do if not c.phased then list[#list+1]=S:crateBox(c) end end
    if S.room.doorOpen<.8 then list[#list+1]=S:doorBox() end
    for _,o in ipairs(list) do
        local x0,x1,z0,z1=o.x0-radius,o.x1+radius,o.z0-radius,o.z1+radius
        if p.x>x0 and p.x<x1 and p.z>z0 and p.z<z1 then
            local dl,dr,db,df=p.x-x0,x1-p.x,p.z-z0,z1-p.z
            local m=math.min(dl,dr,db,df)
            if m==dl then p.x=x0 elseif m==dr then p.x=x1 elseif m==db then p.z=z0 else p.z=z1 end
        end
    end
    p.x=math.max(-7,math.min(7,p.x)) p.z=math.max(-4.9,math.min(4.4,p.z))
end
return Player
