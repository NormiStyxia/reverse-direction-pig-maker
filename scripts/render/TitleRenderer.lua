-- Native scene + SurfaceShader renderer. No browser/HTML runtime.
local Particles=require('game.TitleParticles')
local Title=require('game.TitleState')
---@class TitleSpriteDrawable
---@field geometry CustomGeometry
---@field material Material
---@class TitleRenderer
---@field scene Scene
---@field camera Camera
---@field viewport Viewport
---@field plate Material
---@field sprites TitleSpriteDrawable[]
---@field pigAspect number
---@field resize fun(self:TitleRenderer,width:number,height:number)
---@field update fun(self:TitleRenderer,title:table)
---@field dispose fun(self:TitleRenderer)
local Renderer={}
Renderer.__index=Renderer
local ASPECT=20/9
local INDICES={1,2,3,1,3,4}
---@param geometry CustomGeometry
local function writeQuad(geometry,vertices,z)
    geometry:BeginGeometry(0,TRIANGLE_LIST)
    for _,i in ipairs(INDICES) do
        local v=vertices[i]
        geometry:DefineVertex(Vector3(v[1],v[2],z))
        geometry:DefineNormal(Vector3(0,0,-1))
        geometry:DefineTexCoord(Vector2(v[3],v[4]))
    end
    geometry:Commit()
end
---@param scene Scene
---@param material Material
---@return CustomGeometry
local function geometry(scene,name,material,dynamic)
    local node=scene:CreateChild(name)
    local mesh=node:CreateComponent('CustomGeometry')
    mesh.dynamic=dynamic
    mesh:SetMaterial(material)
    mesh.castShadows=false
    return mesh
end
---@return TitleRenderer
function Renderer.new()
    local self=setmetatable({},Renderer)
    self:init()
    return self
end
function Renderer:init()
    self.scene=Scene()
    self.scene:CreateComponent('Octree')
    -- Exact flat title art: no scene lights, tone mapping, fog or auto exposure.
    local zone=self.scene:CreateComponent('Zone')
    zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.fogColor=Color(1/255,64/255,196/255)
    zone.depthFogEnable=false
    zone.heightFogEnable=false
    zone:SetAttribute('Bloom Enable',Variant(false))
    zone.tonemapMode=TONEMAP_MODE_NONE
    local cameraNode=self.scene:CreateChild('TitleCamera')
    cameraNode.position=Vector3(0,0,-10)
    self.camera=cameraNode:CreateComponent('Camera')
    self.camera.orthographic=true
    self.camera.nearClip=.1; self.camera.farClip=30
    self.viewport=Viewport:new(self.scene,self.camera)
    renderer:SetViewport(0,self.viewport)
    renderer.hdrRendering=false
    self.plate=assert(cache:GetResource('Material','Materials/TitlePlate.xml'),'Missing TitlePlate material')
    local plateGeometry=geometry(self.scene,'TitlePlate',self.plate,false)
    writeQuad(plateGeometry,{{-ASPECT,1,0,0},{ASPECT,1,1,0},{ASPECT,-1,1,1},{-ASPECT,-1,0,1}},0)
    self.sprites={}
    for i=1,11 do
        local path=i==11 and 'Materials/TitlePig.xml' or 'Materials/TitleParticles.xml'
        local source=assert(cache:GetResource('Material',path),'Missing title sprite material')
        local material=source:Clone()
        self.sprites[i]={geometry=geometry(self.scene,'TitleSprite'..i,material,true),material=material}
    end
    local pig=assert(cache:GetResource('Texture2D','title/pig-premult.png'),'Missing title pig')
    self.pigAspect=pig.width/pig.height
    self:resize(graphics:GetWidth(),graphics:GetHeight())
end
function Renderer:resize(width,height)
    local frame=Title.layout(width,height)
    self.camera.orthoSize=2*height/frame.height
end
---@param material Material
local function common(material,st)
    material:SetShaderParameter('uTime',Variant(st.t))
    material:SetShaderParameter('uWorld',Variant(st.world))
    material:SetShaderParameter('uProg',Variant(st.prog))
    material:SetShaderParameter('uAspect',Variant(ASPECT))
    material:SetShaderParameter('uC',Variant(Vector2(784.8/2560,435.4/1152)))
    material:SetShaderParameter('uZoom',Variant(st.zoom))
    material:SetShaderParameter('uCam',Variant(Vector2(st.cam.x,st.cam.y)))
    material:SetShaderParameter('uPar',Variant(Vector2(st.par.x,st.par.y)))
    material:SetShaderParameter('uWash',Variant(st.wash))
end
function Renderer:update(title)
    local st,opts=title.st,title.opts
    common(self.plate,st)
    for name,value in pairs({uReveal=st.reveal,uRewind=st.rewind,uMotion=opts.motion and 1 or 0,
        uSil=st.sil,uFlash=st.flash,uGlitch=st.phase=='idle' and st.glitch or 0,uGSil=st.phase=='idle' and st.gsil or 0}) do
        self.plate:SetShaderParameter(name,Variant(value))
    end
    local quads=Particles.build(st.world)
    quads[11]=Particles.pig(st,self.pigAspect)
    for i,q in ipairs(quads) do
        ---@type TitleSpriteDrawable
        local sprite=self.sprites[i]
        sprite.geometry.enabled=i==11 or opts.motion
        local vertices={}
        local offX=st.par.x*(-.004-.007*q.depth)
        local offY=st.par.y*(-.003-.005*q.depth)
        for j,v in ipairs(q.vertices) do
            local x=(v[1]-offX-st.cam.x)*st.zoom+.5
            local y=(v[2]-offY-st.cam.y)*st.zoom+.5
            vertices[j]={(x*2-1)*ASPECT,1-y*2,v[3],v[4]}
        end
        writeQuad(sprite.geometry,vertices,-.01-i*.001)
        common(sprite.material,st)
        sprite.material:SetShaderParameter('uShow',Variant(st.reveal))
        sprite.material:SetShaderParameter('uMeta',Variant(Vector3(q.alpha,q.depth,q.occlude)))
    end
end
function Renderer:dispose() self.scene:Dispose() end
return Renderer
