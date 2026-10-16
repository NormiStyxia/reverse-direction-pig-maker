-- Test-only input driver. Uses movement, interaction and panel inputs; never
-- assigns actor positions, clocks, phases, choices, or completion state.
local Route={};Route.__index=Route
function Route.new(kind,answer)
    local self=setmetatable({},Route);self:init(kind,answer);return self
end
function Route:init(kind,answer) self.kind=kind;self.answer=answer or 'same';self.waypoint=1;self.frames=0 end
local function toward(s,x,z)
    local p=s.normi.pos;local dx,dz=x-p.x,z-p.z;local d=math.sqrt(dx*dx+dz*dz)
    if d<.10 then return 0,0,true end
    return dx/d,dz/d,false
end
function Route:control(s)
    self.frames=self.frames+1
    if self.kind=='store' then
        if s.phase=='pig' then
            if s.phone.open then s:closePhone() end
            s:interact('pig')
            if s.phase=='pig' then return toward(s,-3.35,-3.2) end
        end
        return 0,0
    end
    if s.mode=='morning' then return 0,0 end
    if s.phone.open and s.phone.k>=.6 and #s.phone.choices>0 then
        local choice=s.choiceMode=='answer' and ({same=0,late=1,done=2})[self.answer] or 0
        s:onPanel('choice:'..choice)
    end
    if not s:controlEnabled() then return 0,0 end
    if s.phase=='play' or (s.phase=='walk' and not s.carrying) then
        s:interact(s.phase=='play' and 'box' or 'take')
        return toward(s,-3.65,1.3)
    end
    if s.phase=='walk' then
        local path={{-6.3,2.2},{-8.6,2.2},{-8.6,3.05},{-13.2,3.05}}
        local point=path[self.waypoint]
        if point then
            local x,z,arrived=toward(s,point[1],point[2])
            if arrived then self.waypoint=self.waypoint+1 end
            return x,z
        end
        s:interact('put')
    elseif s.phase=='desk' then s:interact('pig') end
    return 0,0
end
return Route
