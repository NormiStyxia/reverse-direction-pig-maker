-- App-owned render textures and SurfaceShaders; no engine/Technique changes.
-- Source stylize/DOF, bloom, frost and final color. Native NVG remains outside the chain.
---@class ScenePost
---@field style table
---@field effects ScreenEffects
---@field dust WorldDust
---@field particles PuffRenderer
---@field nearTexture Texture2D?
---@field nearSurface RenderSurface?
---@field dof table
---@field ink table
---@field depthTexture Texture2D?
---@field depthSurface RenderSurface?
---@field present table?
---@field presentDepth Texture2D?
---@field presentDepthSurface RenderSurface?
---@field bloom table[]
---@field bloomTargets Texture2D[]
---@field bloomSurfaces RenderSurface[]
---@field view table
---@field passes table[]
---@field final table
---@field targets Texture2D[]
---@field surfaces RenderSurface[]
---@field width number
---@field height number
---@field enabled boolean
local Post={};Post.__index=Post
---@param m Material
local function parameter(m,name,value) m:SetShaderParameter(name,Variant(value)) end
---@return table
local function pass(shader)
    local scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone')
    zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.depthFogEnable=false;zone.heightFogEnable=false
    zone:SetAttribute('Bloom Enable',Variant(false));zone.tonemapMode=TONEMAP_MODE_NONE
    local cameraNode=scene:CreateChild('PostCamera');cameraNode.position=Vector3(0,0,-1)
    local camera=cameraNode:CreateComponent('Camera')
    camera.orthographic=true;camera.orthoSize=2;camera.nearClip=.01;camera.farClip=10;camera.autoAspectRatio=false
    local viewport=Viewport:new(scene,camera)
    local path=viewport:GetRenderPath():Clone()
    assert(path:Load(assert(cache:GetResource('XMLFile','RenderPaths/Forward.xml'))));viewport:SetRenderPath(path)
    local material=Material:new();assert(material:SetSurfaceShader(shader),'SCENE_POST_SHADER: '..shader)
    local node=scene:CreateChild('Fullscreen');local mesh=node:CreateComponent('CustomGeometry')
    mesh:SetNumGeometries(1);mesh.castShadows=false
    mesh:BeginGeometry(0,TRIANGLE_LIST)
    local vertices={{-1,1,0,0},{1,1,1,0},{1,-1,1,1},{-1,-1,0,1}}
    for _,i in ipairs({1,2,3,1,3,4}) do
        local v=vertices[i];mesh:DefineVertex(Vector3(v[1],v[2],0));mesh:DefineNormal(Vector3(0,0,-1));mesh:DefineTexCoord(Vector2(v[3],v[4]))
    end
    mesh:Commit();mesh:SetMaterial(material)
    return {scene=scene,camera=camera,node=node,viewport=viewport,material=material}
end
---@param viewport Viewport
---@return Texture2D, RenderSurface
local function target(viewport,w,h)
    local t=Texture2D:new();t:SetNumLevels(1);t.sRGB=false
    assert(t:SetSize(w,h,Graphics:GetRGBAFloat16Format(),TEXTURE_RENDERTARGET),'SCENE_POST_RT_ALLOCATION')
    t:SetFilterMode(FILTER_BILINEAR);t:SetAddressMode(COORD_U,ADDRESS_CLAMP);t:SetAddressMode(COORD_V,ADDRESS_CLAMP)
    local surface=t:GetRenderSurface();surface:SetViewport(0,viewport);surface:SetUpdateMode(SURFACE_MANUALUPDATE)
    return t,surface
end
---@return ScenePost
function Post.new(view)
    local self=setmetatable({view=view,passes={},targets={},surfaces={},width=0,height=0,enabled=false},Post)
    self.effects=require('game.ScreenEffects').shared;view.screenEffects=self.effects
    for i=1,4 do self.passes[i]=pass('Shaders/BLGL/SceneBlur.shader') end
    self.final=pass('Shaders/BLGL/SceneComposite.shader')
    self.dof=pass('Shaders/BLGL/SceneDof.shader')
    self.ink=pass('Shaders/BLGL/SceneStylize.shader')
    self.style=require('render.SceneStyle').new(view,self.ink.material,self.dof.material)
    self.dust=require('render.WorldDust').new(view)
    self.particles=require('render.PuffRenderer').new(view)
    self.bloom={pass('Shaders/BLGL/SceneBright.shader')}
    for i=2,7 do self.bloom[i]=pass('Shaders/BLGL/SceneBlur.shader') end
    self.bloomTargets={};self.bloomSurfaces={}
    local f=self.final.material
    for k,v in pairs({frost=0,frostSide=1,frostEdge=.5,frostFeather=.08,bloom=0,exposure=1,paperOn=0,vignette=0,edgeK=1,blueInk=0,shock=0,shockSeed=0,flash=0,veil=0,veilR=1.9,blue=0,blueLo=.06,blueHi=.5,blueSweep=0,presentOn=0,time=0}) do parameter(f,k,v) end
    parameter(f,'grade',Vector3(1,1,1));parameter(f,'veilC',Vector2(.5,.5));parameter(f,'blueC',Vector2(.5,.5))
    if view.data and view.data.definition then self.present=require('render.PresentMask').new(view) end
    self:resize(graphics:GetWidth(),graphics:GetHeight())
    return self
end
function Post:detachTargets()
    if self.surfaces[1] then self.surfaces[1]:SetLinkedDepthStencil(nil) end
    if self.surfaces[8] then self.surfaces[8]:SetLinkedDepthStencil(nil) end
    for _,surface in ipairs(self.surfaces) do surface:SetNumViewports(0) end
    for _,surface in ipairs(self.bloomSurfaces) do surface:SetNumViewports(0) end
    self.dof.material:SetSurfaceTexture('tStyled',nil)
    self.dof.material:SetSurfaceTexture('tDepth',nil)
    self.dof.material:SetSurfaceTexture('tNear',nil)
    if self.nearSurface then self.nearSurface:SetNumViewports(0);self.nearSurface=nil end
    self.ink.material:SetSurfaceTexture('tColor',nil)
    self.ink.material:SetSurfaceTexture('tDepth',nil)
    self.depthSurface=nil;self.presentDepthSurface=nil
    for _,name in ipairs({'tColor','tFrost','tBloomA','tBloomB','tPresent','tSceneDepth'}) do self.final.material:SetSurfaceTexture(name,nil) end
    for _,p in ipairs(self.passes) do p.material:SetSurfaceTexture('input_color',nil) end
    for i,p in ipairs(self.bloom) do p.material:SetSurfaceTexture(i==1 and 'tColor' or 'input_color',nil) end
    self.surfaces={};self.bloomSurfaces={}
end
function Post:releaseTargets()
    self:detachTargets()
    -- Runtime GetRenderSurface adds a Lua ref; its GC releases that ref. The
    -- surface destructor dereferences parentTexture even after GPU Release().
    -- Drop borrowed surface wrappers BEFORE disposing their parent textures.
    -- Keep the detach in a separate call so no loop-local surface survives GC.
    if #self.targets>0 then collectgarbage('collect') end
    for _,t in ipairs(self.bloomTargets) do t:Dispose() end
    for _,t in ipairs(self.targets) do t:Dispose() end
    if self.depthTexture then self.depthTexture:Dispose();self.depthTexture=nil end
    if self.presentDepth then self.presentDepth:Dispose();self.presentDepth=nil end
    if self.nearTexture then self.nearTexture:Dispose();self.nearTexture=nil end
    self.targets={};self.bloomTargets={}
end
function Post:resize(w,h)
    if w==self.width and h==self.height then return end
    self:releaseTargets();self.width=w;self.height=h
    local qw,qh=math.max(1,math.floor(w/4+.5)),math.max(1,math.floor(h/4+.5))
    -- Keep main color/depth together, then rasterize ink ONCE into its own RT.
    -- Sampling a hinted transient scene depth inside the main view caused
    -- nondeterministic cutout edges even with camera/time/geometry frozen.
    -- Targets: 1 raw scene, 2..5 frost, 6 DOF, 7 ink.
    -- The native renderer draws manually queued views in reverse registration
    -- order. SurfaceShader's named samplers do not establish recursive view
    -- dependencies here. Register consumers before producers: otherwise the
    -- ink/DOF/bloom chain reads previous-frame results during camera movement.
    -- QueueUpdate alone is a flag, not an execution-order API.
    if self.present then
        self.targets[8],self.surfaces[8]=target(self.present.viewport,w,h)
        self.presentDepth=Texture2D:new();self.presentDepth:SetNumLevels(1)
        assert(self.presentDepth:SetSize(w,h,Graphics:GetReadableDepthFormat(),TEXTURE_DEPTHSTENCIL),'PRESENT_DEPTH_ALLOCATION')
        self.presentDepth:SetFilterMode(FILTER_NEAREST)
        self.presentDepthSurface=self.presentDepth:GetRenderSurface()
        self.surfaces[8]:SetLinkedDepthStencil(self.presentDepthSurface)
        self.final.material:SetSurfaceTexture('tPresent',self.presentDepth)
    end
    for i=7,1,-1 do
        local p=self.bloom[i]
        local divisor=i==1 and 2 or (i<=3 and 4 or 8)
        local bw,bh=math.max(1,math.floor(w/divisor+.5)),math.max(1,math.floor(h/divisor+.5))
        p.camera.aspectRatio=bw/bh;p.node.scale=Vector3(bw/bh,1,1)
        self.bloomTargets[i],self.bloomSurfaces[i]=target(p.viewport,bw,bh)
        if i>1 then parameter(p.material,'blur_dir',i%2==0 and Vector2(1/bw,0) or Vector2(0,1/bh)) end
    end
    for i=4,1,-1 do
        local p=self.passes[i]
        p.camera.aspectRatio=qw/qh;p.node.scale=Vector3(qw/qh,1,1)
        self.targets[i+1],self.surfaces[i+1]=target(p.viewport,qw,qh)
        local s=i<=2 and 1.2 or 2.4
        parameter(p.material,'blur_dir',i%2==1 and Vector2(s/qw,0) or Vector2(0,s/qh))
    end
    self.dof.camera.aspectRatio=w/h;self.dof.node.scale=Vector3(w/h,1,1)
    self.targets[6],self.surfaces[6]=target(self.dof.viewport,w,h)
    -- Consumer-first registration also applies to this independent near view.
    self.nearTexture,self.nearSurface=target(self.dust.viewport,w,h)
    self.dof.material:SetSurfaceTexture('tNear',self.nearTexture)
    self.ink.camera.aspectRatio=w/h;self.ink.node.scale=Vector3(w/h,1,1)
    self.targets[7],self.surfaces[7]=target(self.ink.viewport,w,h)
    self.targets[1],self.surfaces[1]=target(self.view.viewport,w,h)
    self.depthTexture=Texture2D:new();self.depthTexture:SetNumLevels(1)
    assert(self.depthTexture:SetSize(w,h,Graphics:GetReadableDepthFormat(),TEXTURE_DEPTHSTENCIL),'SCENE_POST_DEPTH_ALLOCATION')
    self.depthTexture:SetFilterMode(FILTER_NEAREST)
    self.depthSurface=self.depthTexture:GetRenderSurface()
    self.surfaces[1]:SetLinkedDepthStencil(self.depthSurface)
    self.final.material:SetSurfaceTexture('tSceneDepth',self.depthTexture)
    self.ink.material:SetSurfaceTexture('tColor',self.targets[1])
    self.ink.material:SetSurfaceTexture('tDepth',self.depthTexture)
    self.dof.material:SetSurfaceTexture('tStyled',self.targets[7])
    self.dof.material:SetSurfaceTexture('tDepth',self.depthTexture)
    local src=self.targets[6]
    for i,p in ipairs(self.passes) do
        p.material:SetSurfaceTexture('input_color',src)
        src=self.targets[i+1]
    end
    self.final.camera.aspectRatio=w/h;self.final.node.scale=Vector3(w/h,1,1)
    self.final.material:SetSurfaceTexture('tColor',self.targets[6]);self.final.material:SetSurfaceTexture('tFrost',src)
    src=self.targets[6]
    for i,p in ipairs(self.bloom) do
        p.material:SetSurfaceTexture(i==1 and 'tColor' or 'input_color',src)
        src=self.bloomTargets[i]
    end
    self.final.material:SetSurfaceTexture('tBloomA',self.bloomTargets[3]);self.final.material:SetSurfaceTexture('tBloomB',self.bloomTargets[7])
    parameter(self.final.material,'res',Vector2(w,h))
    print('SCENE_POST_TARGETS: '..w..'x'..h..'; frost '..qw..'x'..qh..'; RGBA16F, four passes')
end
function Post:setEnabled(on)
    self.enabled=on
    self.view.zone:SetAttribute('Bloom Enable',Variant(not on))
    renderer:SetViewport(0,on and self.final.viewport or self.view.viewport)
    print('SCENE_POST_ENABLED: '..tostring(on)..'; source stylize/DOF/bloom/frost/final; visual acceptance pending')
end
function Post:update(canvas,haze)
    if not self.enabled then return end
    self:resize(graphics:GetWidth(),graphics:GetHeight())
    local story=canvas and canvas.story;local p=story and (canvas.channel=='browse' and story.browse or story.phone) or {k=0}
    local placement=canvas and (canvas.channel=='browse' and story.browse or canvas.placement) or {layoutSide='right',frostEdge=.5}
    local k,side,edge=p.k,placement.layoutSide=='left' and -1 or 1,placement.frostEdge
    if p.presentation=='look'then k=0 end -- Object cards use focus DOF, not phone half-screen frost.
    if (haze or 0)>k then k=haze;side=1;edge=-.2 end
    parameter(self.final.material,'frost',k);parameter(self.final.material,'frostSide',side);parameter(self.final.material,'frostEdge',edge)
    -- Custom SurfaceShader sampler dependencies are not recursively queued by
    -- UPDATEVISIBLE on this runtime. Request every owned pass explicitly.
    for i,surface in ipairs(self.surfaces) do if i~=8 or self.presentActive then surface:QueueUpdate() end end
    for _,surface in ipairs(self.bloomSurfaces) do surface:QueueUpdate() end
    self.nearSurface:QueueUpdate()
end
local function smooth(v,a,b) local k=math.max(0,math.min(1,(v-a)/(b-a)));return k*k*(3-2*k) end
function Post:updateGame(story,canvas,dt,kind,pose,bridge)
    if not self.enabled then return end
    self.dust:update(dt)
    self.particles:sync()
    local tune=story.tune or require('game.data.Tuning').store
    local fx=story.fx or {};local actor=story.normi and story.normi.pos or story.pig.pos
    local focusActor={x=actor.x,y=story.normi and 1.3 or .7,z=actor.z}
    if kind=='store' then
        local stress=story.sv or 0
        fx={grade={1,.97,.98},exposure=1+.08*story.power,kFar=tune.dofFar*(1+stress*.35),kNear=tune.dofNear,
            desat=stress*.12,vignette=smooth(stress,.3,1)*.5,haze=fx.haze,veil=fx.veil}
        if story.mode=='store-day'then
            local k=story.duskK or 0
            fx.grade={tune.gradeR+(1.07-tune.gradeR)*k,tune.gradeG+(.98-tune.gradeG)*k,tune.gradeB+(.88-tune.gradeB)*k}
            fx.exposure=tune.exposure*(1-.1*k)
        end
    elseif kind=='echo' then
        local k=pose and pose.rwK or 0;local meeting=story.theme~='store'
        local base=({meeting={1.04,1,.93},office={1.06,.99,.94},dorm={1.03,1,.96},store={.9,.98,1.04}})[story.theme]
        local cold=meeting and {.82,.92,1.12} or {.78,.92,1.16};local grade={}
        for i=1,3 do grade[i]=base[i]+(cold[i]-base[i])*k*.8;if not meeting then grade[i]=grade[i]*({.86/.9,.93/.98,1.1/1.04})[i] end end
        fx={grade=grade,exposure=meeting and (1-k*.06) or 1,kFar=meeting and 4 or 7,kNear=44,veil=story.veil,blue=story.fx and story.fx.blue}
    end
    if story.postSettings then
        local resolved={};for k,v in pairs(tune)do resolved[k]=v end
        for k,v in pairs(story.postSettings)do resolved[k]=v end;tune=resolved
    end
    if kind=='echo'and (story.topK or 0)>0 then fx.kFar=fx.kFar*(1-story.topK);fx.kNear=fx.kNear*(1-story.topK)end
    self.style:update(tune,fx,story.t,focusActor,dt)
    local f=self.final.material;local g=fx.grade or {1,1,1}
    parameter(f,'shock',self.effects.shock);parameter(f,'shockSeed',self.effects.shockSeed);parameter(f,'flash',self.effects.flash)
    local blue=fx.blue or (bridge and bridge.blue) or ( (kind=='echo' and pose and pose.rwK*.6 or 0))
    parameter(f,'blue',blue);parameter(f,'blueSweep',bridge and bridge.sweep or 0)
    parameter(f,'blueLo',fx.blueLo or (kind=='store' and .015 or .035));parameter(f,'blueHi',fx.blueHi or (kind=='store' and .26 or .4))
    if bridge and bridge.blue>0 then
        local center=self.view.camera:WorldToScreenPoint(Vector3(focusActor.x,focusActor.y,-focusActor.z))
        parameter(f,'blueC',Vector2(center.x,1-center.y))
    end
    self.presentActive=blue>.001 and self.present and self.present:update() or false
    parameter(f,'presentOn',self.presentActive and 1 or 0)
    parameter(f,'depth_reverse',self.view.camera:UseReverseZ() and 1 or 0)
    parameter(f,'grade',Vector3(g[1],g[2],g[3]));parameter(f,'exposure',fx.exposure or 1)
    parameter(f,'time',story.t);parameter(f,'vignette',fx.vignette or 0)
    parameter(f,'edgeK',fx.edgeK or 1);parameter(f,'blueInk',fx.ink or 0)
    parameter(f,'paperOn',tune.paper==false and 0 or 1);parameter(f,'bloom',tune.bloom==false and 0 or (tune.bloomStrength or 1))
    parameter(self.bloom[1].material,'threshold',tune.bloomThreshold or 1)
    parameter(self.dof.material,'desat',fx.desat or 0);parameter(self.dof.material,'sat',fx.sat or 1)
    local veil=fx.veil
    parameter(f,'veil',veil and veil.k or 0);parameter(f,'veilR',veil and veil.r or 1.9)
    local cx,cy=.5,.5
    if veil then
        if veil.cx then cx=veil.cx;cy=veil.cy
        else
            local pivot=veil.pivot or (kind=='store' and {x=-3.35,y=1,z=-3.2} or actor)
            local p=self.view.camera:WorldToScreenPoint(Vector3(pivot.x,pivot.y,-pivot.z));cx=p.x;cy=1-p.y
        end
    end
    parameter(f,'veilC',Vector2(cx,cy))
    self:update(canvas,fx.haze or 0)
end
function Post:dispose()
    if self.disposed then return end
    self.disposed=true;self.enabled=false
    if renderer:GetViewport(0)==self.final.viewport then renderer:SetViewport(0,self.view.viewport) end
    self:releaseTargets()
    if self.present then self.present:dispose() end
    self.dust:dispose()
    self.particles:dispose()
    for _,p in ipairs(self.passes) do p.scene:Dispose() end
    for _,p in ipairs(self.bloom) do p.scene:Dispose() end
    self.ink.scene:Dispose();self.dof.scene:Dispose();self.final.scene:Dispose()
end
return Post
