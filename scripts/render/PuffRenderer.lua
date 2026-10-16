-- Opaque double-sided paper, not blended smoke. Participates in main depth/ink/DOF.
local Particles=require('game.SpriteParticles')
---@class PuffRenderer
---@field view table
---@field model SpriteParticles
---@field meshes table
---@field disposed boolean
local Renderer={};Renderer.__index=Renderer
---@param view table
---@param model SpriteParticles?
---@return PuffRenderer
function Renderer.new(view,model)
    local self=setmetatable({view=view,model=model or Particles.shared,meshes={},disposed=false},Renderer)
    for _,kind in ipairs({'puff','burst'}) do
        local node=view.scene:CreateChild('Paper-'..kind)
        local g=node:CreateComponent('CustomGeometry');g:SetNumGeometries(1);g:SetDynamic(true)
        g.castShadows=false;g.viewMask=1;g.enabled=false
        local material=Material:new();assert(material:SetSurfaceShader('Shaders/BLGL/PuffPaper.shader'))
        local entry={node=node,mesh=g,material=material,ready=false};self.meshes[kind]=entry
        cache:GetResourceAsync('Image','effects/'..kind..'-linear.png',function(image)
            if self.disposed then return end
            assert(image,'PUFF_IMAGE_FAILED: '..kind)
            local texture=Texture2D:new();texture:SetNumLevels(0);texture.sRGB=false
            assert(texture:SetData(image),'PUFF_UPLOAD_FAILED: '..kind)
            texture:SetFilterMode(FILTER_TRILINEAR);texture:SetAddressMode(COORD_U,ADDRESS_CLAMP);texture:SetAddressMode(COORD_V,ADDRESS_CLAMP)
            material:SetSurfaceTexture('paint_map',texture);entry.texture=texture;entry.ready=true
        end)
    end
    return self
end
function Renderer:sync()
    local q=self.view.cameraNode.worldRotation;local right,up=q*Vector3.RIGHT,q*Vector3.UP
    local corners={{-.5,.5,0,0},{.5,.5,1,0},{.5,-.5,1,1},{-.5,-.5,0,1}}
    for kind,e in pairs(self.meshes) do
        if e.ready then
            local g=e.mesh;local count=0
            g:BeginGeometry(0,TRIANGLE_LIST)
            for _,p in ipairs(self.model.list) do
                if p.kind==kind then
                    count=count+1
                    local c,s=math.cos(p.angle),math.sin(p.angle);local size=p.size*p.scale
                    for _,i in ipairs({1,2,3,1,3,4}) do
                        local v=corners[i];local x,y=(c*v[1]-s*v[2])*size,(s*v[1]+c*v[2])*size
                        g:DefineVertex(Vector3(p.x,p.y,-p.z)+right*x+up*y)
                        g:DefineNormal(q*Vector3(0,0,-1));g:DefineTexCoord(Vector2(v[3],v[4]))
                    end
                end
            end
            g.enabled=count>0
            if count>0 then g:Commit();g:SetMaterial(e.material) end
        end
    end
end
function Renderer:dispose()
    self.disposed=true
    for _,e in pairs(self.meshes) do
        e.node:Remove();e.material:SetSurfaceTexture('paint_map',nil)
        if e.texture then e.texture:Dispose() end
    end
    self.meshes={}
end
return Renderer
