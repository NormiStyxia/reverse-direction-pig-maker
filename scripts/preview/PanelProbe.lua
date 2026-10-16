local Fixtures=require('preview.PanelFixtures')
local StoryCanvas=require('render.StoryOverlay')
local Probe={}
Probe.__index=Probe
function Probe.new()
    local self=setmetatable({},Probe);self:init();return self
end
function Probe:init()
    self.index=2;self.live=false;self.active=true
    self.story=Fixtures.make(self.index);self.screen=StoryCanvas.new(self.story);self.screen.probeBackdrop=true
    self.screen:update(0)
end
function Probe:cycle()
    self.index=self.index%#Fixtures.names+1;self.story=Fixtures.make(self.index);self.live=false
    self.screen.story=self.story;self.screen.lastView=false;self.screen.lastDraft='';self.screen.lastCount=-1;self.screen.lastBrowseCount=-1
    self.screen.scrollBottom=true;self.screen.placement.layoutSide=false;self.screen:cancelPointer();self.screen:update(0)
    print('STORY_PANEL_PROBE: '..Fixtures.names[self.index]..'; frozen fixture; F7 next, F8 title')
end
function Probe:update(dt)
    if not self.active then return end
    if self.live then self.story:update(math.min(.05,dt),{camYaw=0,moving=false});self.story:drainEvents() end
    self.screen:update(dt)
end
return Probe
