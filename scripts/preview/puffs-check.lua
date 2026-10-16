-- Isolated paper particle fixture. Does not skip or complete gameplay.
local Particles=require('game.SpriteParticles')
---@type table
local view
---@type ScenePost
local post
local frame,hold,index,wait=0,0,1,0
local width,height,generation=0,0,0
local times={0,.12,.34,.12,.12,.5,.12}
local names={'fresh','moving','shrinking','camera-first','camera-stable','expired','depth-cutout'}
local function sample()
    post.particles.model:reset();post.particles.model.random=function()return .37 end
    post.particles.model:puff({x=0,y=0,z=0},1)
    post.particles.model:update(times[index])
    -- Keep the conditional scalar explicit: Lua 'or' does not coerce booleans.
    view.cameraNode.position=Vector3((index==4 or index==5) and .8 or 0,0,-6)
    view.cameraNode:LookAt(Vector3(0,0,0))
    post.particles:sync()
end
function Start()
    local scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.depthFogEnable=false;zone.heightFogEnable=false;zone.fogColor=Color(0,0,0)
    zone.tonemapMode=TONEMAP_MODE_NONE;zone:SetAttribute('Bloom Enable',Variant(false))
    local node=scene:CreateChild('Camera');node.position=Vector3(0,0,-6);node:LookAt(Vector3(0,0,0))
    local camera=node:CreateComponent('Camera');camera.fov=24;camera.nearClip=1;camera.farClip=1400;camera.viewMask=1
    local viewport=Viewport:new(scene,camera);local path=viewport:GetRenderPath():Clone()
    assert(path:Load(cache:GetResource('XMLFile','RenderPaths/Forward.xml')));viewport:SetRenderPath(path)
    view={scene=scene,zone=zone,cameraNode=node,camera=camera,viewport=viewport}
    post=require('render.ScenePost').new(view);post:setEnabled(true)
    assert(post.final.material:SetSurfaceShader('Shaders/BLGL/DustInspect.shader'))
    SubscribeToEvent('Update','PuffsCheckUpdate')
end
function PuffsCheckUpdate(eventType,eventData)
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then width=w;height=h;generation=generation+1;frame=0;hold=0;index=1;wait=0;graphics.windowTitle='PUFFS_WAIT_'..generation end
    wait=wait+eventData:GetFloat('TimeStep')
    if wait<10 or not post.particles.meshes.puff.ready then return end
    if index>#names then return end
    post.dust.mainMesh.enabled=false;post.dust.nearMesh.enabled=false
    if frame<(index==4 and 1 or 24) then
        post:resize(w,h);sample()
        if index==7 and frame==0 then assert(post.final.material:SetSurfaceShader('Shaders/BLGL/PuffDepthInspect.shader')) end
        post.final.material:SetShaderParameter('reverse_depth',Variant(view.camera:UseReverseZ() and 1 or 0))
        post.final.material:SetShaderParameter('coverage',Variant(0));post.final.material:SetSurfaceTexture('tColor',index==7 and post.depthTexture or post.targets[1])
        post:update(nil,0);frame=frame+1
    else
        if hold==0 then graphics.windowTitle='PUFFS_SAMPLE_'..generation..'_'..index;print('PUFFS_SAMPLE: '..names[index]..' '..w..'x'..h) end
        hold=hold+eventData:GetFloat('TimeStep')
        if hold>3 then index=index+1;frame=0;hold=0;graphics.windowTitle=index>#names and ('PUFFS_COMPLETE_'..generation) or 'PUFFS_WARMUP' end
    end
end
function Stop()
    Particles.shared:reset();Particles.shared.random=math.random
    if post then post:dispose() end;if view then view.scene:Dispose() end
end
