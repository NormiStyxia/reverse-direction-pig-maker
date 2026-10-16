-- Frozen browse.js sequencing, independent of NVG. Entry/choice delays are gameplay.
local Browse={}
Browse.__index=Browse
function Browse.new()
    local self=setmetatable({},Browse);self:init();return self
end
function Browse:init()
    self.open=false;self.k=0;self.elapsed=0;self.nextAt=0.0;self.choicesAt=0.0
    self.queue={};self.entries={};self.choices={};self.pendingChoices=false;self.choicesWaiting=false
    self.title='';self.sub='';self.closeLabel='';self.clock='';self.layoutSide=false
end
function Browse:show(title,sub)
    self.open=true;self.layoutSide=false;self:retitle(title,sub)
    self.entries={};self.choices={};self.queue={};self.nextAt=self.elapsed+.25
    self.pendingChoices=false;self.choicesWaiting=false
end
function Browse:retitle(title,sub) self.title=title;self.sub=sub or '' end
function Browse:hide()
    self.open=false;self.queue={};self.pendingChoices=false;self.choicesWaiting=false;self.choices={}
end
function Browse:push(entries,choices)
    for _,e in ipairs(entries) do self.queue[#self.queue+1]=e end
    self.pendingChoices=choices;self.choicesWaiting=false;self.choices={}
    if self.nextAt<self.elapsed then self.nextAt=self.elapsed+.15 end
end
function Browse:update(dt)
    self.elapsed=self.elapsed+dt
    local target=self.open and 1 or 0
    self.k=self.k+(target-self.k)*(1-math.exp(-dt*(self.open and 7 or 9)))
    if math.abs(self.k-target)<.002 then self.k=target end
    if self.k<.02 then return end
    if #self.queue>0 and self.elapsed>=self.nextAt then
        local e=table.remove(self.queue,1);self.entries[#self.entries+1]=e
        local delays={line=.75,thought=.95,msg=1.5,pic=1.4,divider=.5}
        self.nextAt=self.elapsed+(delays[e.kind] or 1.2)
        if #self.queue==0 and self.pendingChoices then
            self.choicesWaiting=self.pendingChoices;self.pendingChoices=false;self.choicesAt=self.nextAt
        end
    end
    if self.choicesWaiting and self.elapsed>=self.choicesAt then
        self.choices=self.choicesWaiting;self.choicesWaiting=false
    end
end
-- Same hysteresis as the source; coordinates are normalized projected actor bounds.
function Browse:place(left,right)
    local center=(left+right)/2
    if not self.layoutSide then self.layoutSide=center>.5 and 'left' or 'right'
    elseif self.layoutSide=='right' and center>.58 then self.layoutSide='left'
    elseif self.layoutSide=='left' and center<.42 then self.layoutSide='right' end
    self.frostEdge=self.layoutSide=='right' and math.max(.48,right+.035) or math.min(.52,left-.035)
    self.clearCenter=self.layoutSide=='right' and self.frostEdge/2 or (1+self.frostEdge)/2
    self.clearWidth=self.layoutSide=='right' and self.frostEdge or 1-self.frostEdge
end
return Browse
