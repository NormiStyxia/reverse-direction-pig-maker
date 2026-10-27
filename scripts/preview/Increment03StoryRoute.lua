-- Test-only player actions for the entire frozen story. No teleport/skip/phase writes.
local Route={};Route.__index=Route
function Route.new(kind,answer) return setmetatable({kind=kind,answer=answer or 'same',waypoint=1,frames=0,nextAction=0},Route)end
local function toward(s,x,z)
    local p=s.normi.pos;local dx,dz=x-p.x,z-p.z;local d=math.sqrt(dx*dx+dz*dz)
    if d<.1 then return 0,0,true end;return dx/d,dz/d,false
end
function Route:path(s,points)
    local p=points[self.waypoint];if not p then return 0,0,true end
    local x,z,done=toward(s,p[1],p[2]);if done then self.waypoint=self.waypoint+1 end;return x,z,false
end
function Route:control(s)
    self.frames=self.frames+1
    if s.mode=='dream' then
        if s.phase=='pigwalk' then return 1,0 end
        if s.phase=='walk' then return toward(s,18,-.45)end
        return 0,0
    end
    if s.mode=='night' then
        if s.pending and not s.phone.open then s:togglePhone();self.nextAction=s.t+1 end
        if s.pending and s.phone.open and s.t>self.nextAction then
            if not s.draft then s:onPhone('pick');self.nextAction=s.t+1 else s:onPhone('send');self.nextAction=s.t+2 end
        end
        if s.phase=='go' then
            if s.look then if s.look.t>3 then s:onPanel('choice:0')end;return 0,0 end
            if not s.carrying then s:interact('box');return toward(s,2.625,2.6)end
            local x,z,done=self:path(s,{{2.625,3.3},{7.4,3.3},{7.4,2.1}})
            if done then s:interact('door')end;return x,z
        end
        return 0,0
    end
    if self.kind=='store' then
        if s.phase=='play' then
            if (s.unread or s.pending) and not s.phone.open then s:togglePhone();self.nextAction=s.t+1 end
            if s.phone.open and s.phone.view~='chat' then s:onPhone('chat')end
            if s.pending and s.t>self.nextAction then
                if s.pending.later then s:onPhone('later')
                elseif not s.draft then s:onPhone('pick:0');self.nextAction=s.t+1
                else s:onPhone('send');self.nextAction=s.t+2 end
            elseif s.phone.open and not s.pending and s.t>self.nextAction then s:closePhone()end
        elseif s.phase=='pig' then
            if s.phone.open then s:closePhone()end;s:interact('pig');if s.phase=='pig' then return toward(s,-3.35,-3.2)end
        end
        return 0,0
    end
    if s.phone.open and s.phone.k>=.6 and #s.phone.choices>0 and s.t>self.nextAction then
        local choices={answer={same=0,late=1,done=2},chen={fix=0,wreck=1,leave=2},dorm={sick=0,pc=1,off=2}}
        local which=choices[s.choiceMode];local index=which and which[self.answer] or 0
        s:onPanel('choice:'..(index or 0));self.nextAction=s.t+1
    end
    if not s:controlEnabled()then return 0,0 end
    if s.mode=='morning' then
        if s.canFindChen then s:interact('chen');return toward(s,-11.95,2.75)end
        s:interact('box');return 0,0
    end
    if s.mode=='dorm' then
        if s.phase=='play' then s:interact('phone');return toward(s,.3,.5)
        elseif s.phase=='desk' then s:interact('pig')end;return 0,0
    end
    if s.phase=='play' or (s.phase=='walk' and not s.carrying) then
        s:interact(s.phase=='play' and 'box' or 'take');return toward(s,-3.65,1.3)
    elseif s.phase=='walk' then
        local x,z,done=self:path(s,{{-6.3,2.2},{-8.6,2.2},{-8.6,3.05},{-13.2,3.05}})
        if done then s:interact('put')end;return x,z
    elseif s.phase=='desk' then s:interact('pig')end
    return 0,0
end
return Route
