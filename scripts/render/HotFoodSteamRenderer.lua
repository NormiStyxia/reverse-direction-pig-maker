local Model=require('game.HotFoodSteam')
---@class HotFoodSteamRenderer
---@field model HotFoodSteam
---@field view table
---@field source Node
---@field node Node
---@field mesh CustomGeometry
---@field material Material
---@field texture Texture2D?
---@field ready boolean
---@field disposed boolean
local Steam={};Steam.__index=Steam
---@return HotFoodSteamRenderer
function Steam.new(view,source)
    local self=setmetatable({view=view,source=source,model=Model.new(),ready=false,disposed=false},Steam)
    self.node=view.scene:CreateChild('HotFoodSteam');self.mesh=self.node:CreateComponent('CustomGeometry')
    self.mesh:SetNumGeometries(1);self.mesh:SetDynamic(true);self.mesh.castShadows=false;self.mesh.viewMask=1;self.mesh.enabled=false
    self.material=Material:new();assert(self.material:SetSurfaceShader('Shaders/BLGL/HotFoodSteam.shader'))
    -- Source steam renderOrder=3: after ordinary transparent glass/glow.
    self.material.renderOrder=131
    cache:GetResourceAsync('Image','store/generated/dust-linear.png',function(image)
        if self.disposed then return end
        assert(image,'STEAM_TEXTURE_MISSING')
        local t=Texture2D:new();t:SetNumLevels(0);t.sRGB=false;assert(t:SetData(image))
        t:SetFilterMode(FILTER_TRILINEAR);t:SetAddressMode(COORD_U,ADDRESS_CLAMP);t:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        self.texture=t;self.material:SetSurfaceTexture('paint_map',t);self.ready=true
    end)
    return self
end
function Steam:sync()
    if not self.ready then return end
    local camera=self.view.cameraNode;local q=camera.worldRotation
    local right,up,forward=q*Vector3.RIGHT,q*Vector3.UP,q*Vector3.FORWARD
    local tan=math.tan(math.rad(self.view.camera.fov)*.5)
    local pixel=2*tan/math.max(1,graphics:GetHeight())
    local corners={{-.5,.5,0,0},{.5,.5,1,0},{.5,-.5,1,1},{-.5,-.5,0,1}}
    local g=self.mesh;g:BeginGeometry(0,TRIANGLE_LIST)
    for _,p in ipairs(self.model.points) do
        local center=self.source:LocalToWorld(Vector3(p.x,p.y,-p.z))
        local depth=(center-camera.worldPosition):DotProduct(forward)
        -- Three Points attenuation uses h/2, independent of FOV and object scale.
        local size=math.max(self.model.size*tan,depth*pixel)
        for _,i in ipairs({1,2,3,1,3,4}) do
            local v=corners[i];g:DefineVertex(center+right*(v[1]*size)+up*(v[2]*size))
            g:DefineNormal(Vector3(p.r,p.g,p.b));g:DefineTexCoord(Vector2(v[3],v[4]))
        end
    end
    g:Commit();g:SetMaterial(self.material);g.enabled=self.source:IsEnabled()
end
function Steam:dispose()
    self.disposed=true;self.node:Remove();self.material:SetSurfaceTexture('paint_map',nil)
    if self.texture then self.texture:Dispose() end
end
return Steam
