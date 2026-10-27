-- Frozen world dust, separate from steam/rain. Main dust participates in ink
-- and DOF; camera-local dust is composited afterwards, as in post.js.
local Pattern=require('render.DustPattern')
---@class WorldDust
---@field view table
---@field scene Scene
---@field camera Camera
---@field viewport Viewport
---@field mainMaterial Material
---@field nearMaterial Material
---@field mainNode Node
---@field nearNode Node
---@field mainMesh CustomGeometry
---@field nearMesh CustomGeometry
---@field texture Texture2D?
---@field ready boolean
---@field disposed boolean
local Dust={};Dust.__index=Dust
-- The source world survives scene changes. Preserve its rotation across views.
local angle=0
---@param m Material
local function set(m,k,v) m:SetShaderParameter(k,Variant(v)) end
---@param scene Scene
---@param material Material
---@return Node, CustomGeometry
local function mesh(scene,name,points,near,material)
    local node=scene:CreateChild(name)
    if not near then node.position=Vector3(0,0,6) end
    local g=node:CreateComponent('CustomGeometry');g:SetNumGeometries(1)
    g.castShadows=false;g.viewMask=1;g.enabled=false;g:BeginGeometry(0,TRIANGLE_LIST)
    local corners={{0,0},{1,0},{1,1},{0,1}}
    for _,p in ipairs(points) do
        for _,i in ipairs({1,2,3,1,3,4}) do
            g:DefineVertex(Vector3(p[1],p[2]-(near and 2 or 0),-p[3]+(near and 6.5 or 0)))
            g:DefineNormal(Vector3(0,0,-1));g:DefineTexCoord(Vector2(corners[i][1],corners[i][2]))
        end
    end
    g:Commit();g:SetMaterial(material)
    return node,g
end
---@param view table
---@return WorldDust
function Dust.new(view)
    local self=setmetatable({view=view,ready=false,disposed=false},Dust)
    self.scene=Scene();self.scene:CreateComponent('Octree')
    local zone=self.scene:CreateComponent('Zone')
    zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.depthFogEnable=false;zone.heightFogEnable=false;zone.tonemapMode=TONEMAP_MODE_NONE
    zone:SetAttribute('Bloom Enable',Variant(false))
    self.camera=self.scene:CreateChild('NearDustCamera'):CreateComponent('Camera')
    self.viewport=Viewport:new(self.scene,self.camera)
    local path=self.viewport:GetRenderPath():Clone()
    assert(path:Load(assert(cache:GetResource('XMLFile','RenderPaths/Forward.xml'))))
    for i=0,path:GetNumCommands()-1 do
        local c=path:GetCommand(i)
        if c.type==CMD_CLEAR then c.useFogColor=false;c.clearColor=Color(0,0,0,0);path:SetCommand(i,c) end
    end
    self.viewport:SetRenderPath(path)
    self.camera.viewMask=1
    self.mainMaterial=Material:new();assert(self.mainMaterial:SetSurfaceShader('Shaders/BLGL/WorldDust.shader'))
    self.nearMaterial=Material:new();assert(self.nearMaterial:SetSurfaceShader('Shaders/BLGL/NearDust.shader'))
    self.mainNode,self.mainMesh=mesh(view.scene,'WorldDust',Pattern.main,false,self.mainMaterial)
    self.nearNode,self.nearMesh=mesh(self.camera.node,'NearDust',Pattern.near,true,self.nearMaterial)
    -- timeline.show() hides both world dust groups while its own 3D stars stay.
    if view.data and view.data.chapter=='timeline'then self.ready=true;return self end
    -- Derived from exact paintDot with RGB decoded once, alpha unchanged. Runtime
    -- builds CPU mipmaps: averaging encoded sRGB darkened subpixel dust.
    -- The linear derivative makes mip averaging match WebGL's sRGB texture.
    cache:GetResourceAsync('Image','store/generated/dust-linear.png',function(image)
        if self.disposed then return end
        assert(image,'DUST_IMAGE_FAILED')
        self.texture=Texture2D:new();self.texture:SetNumLevels(0);self.texture.sRGB=false
        assert(self.texture:SetData(image),'DUST_TEXTURE_UPLOAD_FAILED')
        self.texture:SetFilterMode(FILTER_TRILINEAR)
        self.texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);self.texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
        self.mainMaterial:SetSurfaceTexture('paint_map',self.texture)
        self.nearMaterial:SetSurfaceTexture('paint_map',self.texture)
        self.ready=true;self.mainMesh.enabled=true;self.nearMesh.enabled=true
    end)
    return self
end
function Dust:updateNearFigures()
    local v=self.view
    if not v.ready then return end
    if not self.nearFigures then
        self.nearFigures={}
        for _,source in ipairs(v.data.nodes)do
            if source.type=='Mesh' and ((source.sourceLayers or 1)&2)~=0 then
                local node=self.scene:CreateChild('NearFigure'..source.id)
                local draw=node:CreateComponent('StaticModel');draw.model=v:model(source.geometry,#source.materials)
                for slot,id in ipairs(source.materials)do draw:SetMaterial(slot-1,v:sourceMaterial(source,id))end
                draw.castShadows=false;draw.viewMask=1
                self.nearFigures[#self.nearFigures+1]={node=node,source=v.nodes[source.id]}
            end
        end
        if #self.nearFigures>0 then print('NATIVE_NEAR_FIGURES: '..#self.nearFigures..'; frozen near layer outside main ink/DOF')end
    end
    for _,f in ipairs(self.nearFigures)do
        f.node.enabled=f.source.enabled
        f.node.position=f.source.worldPosition;f.node.rotation=f.source.worldRotation;f.node.scale=f.source.worldScale
    end
end
function Dust:update(dt)
    angle=angle+(dt or 0)*.01
    local c=self.view.camera;local q=self.view.cameraNode.worldRotation
    self.camera.node.position=self.view.cameraNode.worldPosition;self.camera.node.rotation=q
    self:updateNearFigures()
    self.camera.nearClip=c.nearClip;self.camera.farClip=c.farClip;self.camera.fov=c.fov
    self.camera.autoAspectRatio=c.autoAspectRatio;self.camera.aspectRatio=c.aspectRatio
    local tangent=math.tan(math.rad(c.fov)*.5)
    local m=self.mainMaterial
    set(m,'spin',angle);set(m,'diameter',.09*tangent)
    set(m,'camera_right',q*Vector3.RIGHT);set(m,'camera_up',q*Vector3.UP)
    set(m,'camera_forward',q*Vector3.FORWARD)
    set(m,'camera_position',self.view.cameraNode.worldPosition-self.mainNode.worldPosition)
    set(m,'pixel_world',2*tangent/math.max(1,graphics:GetHeight()))
    set(self.nearMaterial,'diameter',.05*tangent)
    set(self.nearMaterial,'pixel_world',2*tangent/math.max(1,graphics:GetHeight()))
end
function Dust:dispose()
    self.disposed=true
    self.mainNode:Remove();self.scene:Dispose()
    self.mainMaterial:SetSurfaceTexture('paint_map',nil);self.nearMaterial:SetSurfaceTexture('paint_map',nil)
    if self.texture then self.texture:Dispose();self.texture=nil end
end
return Dust
