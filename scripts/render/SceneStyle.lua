-- Source STYLIZE/DOF uniforms. Both passes read the same owned scene depth.
---@class SceneStyle
---@field view table
---@field material Material
---@field dofMaterial Material?
---@field focus number
---@field range number
local Style={};Style.__index=Style
local function set(m,k,v) m:SetShaderParameter(k,Variant(v)) end
function Style.new(view,material,dofMaterial)
    local self=setmetatable({view=view,material=material,dofMaterial=dofMaterial,focus=21,range=2.2},Style)
    set(material,'inkColor',Vector3(.024157632448504756,.01520851442291271,.012286488356915872))
    return self
end
function Style:update(tune,fx,time,actor,dt)
    local c=self.view.camera;local m=self.material
    local w,h=math.max(1,graphics:GetWidth()),math.max(1,graphics:GetHeight())
    set(m,'cNear',c.nearClip);set(m,'cFar',c.farClip);set(m,'depth_reverse',c:UseReverseZ() and 1 or 0)
    set(m,'res',Vector2(w,h));set(m,'time',time);set(m,'pxScale',h/1000)
    set(m,'lineOn',tune.lines==false and 0 or 1);set(m,'lineWidth',math.max(1,h/900)*1.6*(tune.lineScale or 1))
    set(m,'paperOn',tune.paper==false and 0 or 1)
    set(m,'wobbleOn',tune.wobble==false and 0 or (tune.wobbleAmp or 1))
    -- Frozen main.js applies store's 4 Hz first; chapter tuning changes the
    -- amplitude but does not replace that cadence. Preserve it across scenes.
    set(m,'wobbleFps',tune.wobbleFps or require('game.data.Tuning').store.wobbleFps)
    if actor then
        local p=self.view.cameraNode.position
        -- Match frozen main.js focus target; source uses distanceTo for the rig.
        local target=math.sqrt((p.x-actor.x)^2+(p.y-actor.y)^2+(p.z+actor.z)^2)
        if fx.focus then target=target+(fx.focus.dist-target)*fx.focus.k end
        self.focus=self.focus+(target-self.focus)*math.min(1,(dt or 0)*5)
        self.range=self.range+(2.4-self.range)*math.min(1,(dt or 0)*5)
    end
    local dof=self.dofMaterial
    if dof then
        set(dof,'cNear',c.nearClip);set(dof,'depth_reverse',c:UseReverseZ() and 1 or 0)
        set(dof,'cFar',c.farClip);set(dof,'res',Vector2(w,h));set(dof,'pxScale',h/1000)
        set(dof,'focus',self.focus);set(dof,'range',self.range);set(dof,'kNear',fx.kNear or 44);set(dof,'kFar',fx.kFar or 34)
        set(dof,'maxCoc',26);set(dof,'enabled',tune.dof==false and 0 or 1)
    end
end
return Style
