-- App-owned present-depth view. Bit 4 is separate from main=1/shadow=2.
-- Copies reuse source geometry and inherit its transforms, including folds and
-- merges; visibility is explicitly synchronized (Node.enabled is not inherited).
local Mask={};Mask.__index=Mask
function Mask.new(view)
    local self=setmetatable({view=view,entries={},built=false},Mask)
    self.node=view.scene:CreateChild('PresentCamera')
    self.camera=self.node:CreateComponent('Camera');self.camera.viewMask=4
    self.viewport=Viewport:new(view.scene,self.camera)
    local path=self.viewport:GetRenderPath():Clone()
    assert(path:Load(assert(cache:GetResource('XMLFile','RenderPaths/Forward.xml'))));self.viewport:SetRenderPath(path)
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/PresentDepth.shader'))
    return self
end
function Mask:build()
    local v=self.view
    for _,id in ipairs(require('render.PresentSelection').ids(v.data)) do
        local source=v.data.nodes[id]
        for _,original in ipairs(v.sourceDrawables[id] or {}) do
            local node=original.node:CreateChild('PresentDepth')
            local drawable
            if source.type=='LineSegments' then
                drawable=node:CreateComponent('CustomGeometry');drawable:SetNumGeometries(1);drawable:BeginGeometry(0,LINE_LIST)
                local p=v.data.geometries[source.geometry].attributes.position.array
                for i=1,#p,3 do drawable:DefineVertex(Vector3(p[i],p[i+1],-p[i+2]));drawable:DefineNormal(Vector3(0,1,0));drawable:DefineTexCoord(Vector2(0,0)) end
                drawable:Commit();drawable:SetMaterial(0,self.material)
            else
                drawable=node:CreateComponent('StaticModel');drawable.model=v:model(source.geometry,#source.materials)
                for slot=0,#source.materials-1 do drawable:SetMaterial(slot,self.material) end
            end
            drawable.viewMask=4;drawable.castShadows=false
            self.entries[#self.entries+1]={original=original,drawable=drawable,node=node}
        end
    end
    self.built=true
end
function Mask:update()
    local v=self.view
    if not v.ready then return false end
    if not self.built then self:build() end
    self.node.worldPosition=v.cameraNode.worldPosition;self.node.worldRotation=v.cameraNode.worldRotation
    local c=self.camera;local src=v.camera
    c.nearClip=src.nearClip;c.farClip=src.farClip;c.fov=src.fov
    c.autoAspectRatio=src.autoAspectRatio;c.aspectRatio=src.aspectRatio
    for _,e in ipairs(self.entries) do e.drawable.enabled=e.original.enabled end
    return #self.entries>0
end
function Mask:dispose()
    for _,e in ipairs(self.entries) do e.node:Remove() end
    self.entries={};self.node:Remove()
end
return Mask
