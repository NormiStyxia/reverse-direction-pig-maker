-- Port of frozen src/rewind-levels.js Timeline. Engine-independent.
-- get() returns a fresh dense numeric array; set() applies a snapshot.
local Timeline = {}
Timeline.__index = Timeline
function Timeline.new(get, set)
    local self=setmetatable({},Timeline)
    self:init(get,set)
    return self
end
---@param get fun():number[]
---@param set fun(snapshot:number[])
function Timeline:init(get,set)
    self.get=get; self.set=set
    ---@type {dt:number,s:number[]}[]
    self.h={{dt=0.0,s=get()}}
    self.total=0.0
end
function Timeline:same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if not (math.abs(a[i] - b[i]) < 0.0001) then return false end
    end
    return true
end
function Timeline:record(dt)
    local s = self.get()
    local last = self.h[#self.h]
    if self:same(s, last.s) then
        local add = math.max(0, math.min(dt, 0.3 - last.dt))
        last.dt = last.dt + add
        self.total = self.total + add
    else
        self.h[#self.h + 1] = {dt = dt, s = s}
        self.total = self.total + dt
    end
    while self.total > 90 and #self.h > 2 do
        self.total = self.total - self.h[2].dt
        table.remove(self.h, 2)
    end
end
function Timeline:rewind(dt, ok)
    local before, budget = #self.h, dt
    self.blocked = false
    while budget > 0 and #self.h > 1 do
        local last = self.h[#self.h]
        if last.dt <= budget then
            if ok and not ok(self.h[#self.h - 1].s) then
                self.blocked = true
                break
            end
            budget = budget - last.dt
            self.total = self.total - last.dt
            table.remove(self.h)
        else
            last.dt = last.dt - budget
            self.total = self.total - budget
            budget = 0
        end
    end
    if #self.h ~= before then self.set(self.h[#self.h].s) end
    return #self.h ~= before
end
return Timeline
