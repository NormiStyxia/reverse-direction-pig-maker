-- Chapter 1 uses BrowseOverlay for every panel, including the phone schedule.
-- Adapt it to the shared raw NVG renderer without introducing another UI system.
local Adapter={};Adapter.__index=Adapter
function Adapter.new(story)
    local self=setmetatable({},Adapter);self:init(story);return self
end
function Adapter:init(story)
    self.story=story;self.browse=story.phone
    self.phone={open=false,k=0,elapsed=0,draft='',view='lock',history={},msgs={},buttons={}}
end
function Adapter:onBrowse(id) self.story:onPanel(id) end
function Adapter:onPhone(id) self.story:onPanel(id) end
function Adapter:togglePhone() self.story:togglePhone() end
function Adapter:update(dt,ctx) self.story:update(dt,ctx) end
function Adapter:drainEvents() return self.story:drainEvents() end
return Adapter
