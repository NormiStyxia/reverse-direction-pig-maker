-- Isolated raw dust/coverage fixture. Never imported from main.lua.
---@type table
local view
---@type ScenePost
local post
local frame,hold,index,wait=0,0,1,0
local width,height,generation=0,0,0
local names={'near-alpha','near-color','main','main-moved','main-moved-stable','blend-calibration'}
function Start()
    local scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.depthFogEnable=false;zone.heightFogEnable=false;zone.fogColor=Color(0,0,0)
    zone.tonemapMode=TONEMAP_MODE_NONE;zone:SetAttribute('Bloom Enable',Variant(false))
    local node=scene:CreateChild('Camera');node.position=Vector3(0,8,-22);node:LookAt(Vector3(0,0,0))
    local camera=node:CreateComponent('Camera');camera.fov=24;camera.nearClip=1;camera.farClip=1400;camera.viewMask=1
    local viewport=Viewport:new(scene,camera)
    local path=viewport:GetRenderPath():Clone();assert(path:Load(cache:GetResource('XMLFile','RenderPaths/Forward.xml')))
    viewport:SetRenderPath(path)
    view={scene=scene,zone=zone,cameraNode=node,camera=camera,viewport=viewport}
    post=require('render.ScenePost').new(view);post:setEnabled(true)
    assert(post.final.material:SetSurfaceShader('Shaders/BLGL/DustInspect.shader'))
    SubscribeToEvent('Update','DustCheckUpdate')
end
function DustCheckUpdate(eventType,eventData)
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then
        width=w;height=h;generation=generation+1;frame=0;hold=0;index=1;wait=0
        graphics.windowTitle='DUST_WAIT_'..generation
    end
    wait=wait+eventData:GetFloat('TimeStep');if wait<10 or not post.dust.ready then return end
    if index>#names then return end
    if frame<(index==4 and 1 or 24) then
        post:resize(w,h)
        if index>=4 then view.cameraNode.position=Vector3(7,5,-17);view.cameraNode:LookAt(Vector3(0,1,0)) end
        if index==6 and frame==0 then
            local technique=post.dust.mainMaterial:GetTechnique(0)
            for _,pass in ipairs(technique:GetPasses()) do print('DUST_PASS: '..pass.name..' blend='..pass.blendMode) end
            assert(post.dust.mainMaterial:SetSurfaceShader('Shaders/BLGL/DustBlendInspect.shader'))
        end
        post.dust:update(0)
        post.final.material:SetShaderParameter('coverage',Variant(index==1 and 1 or 0))
        post.final.material:SetSurfaceTexture('tColor',index<=2 and post.nearTexture or post.targets[1])
        post:update(nil,0);frame=frame+1
    else
        if hold==0 then graphics.windowTitle='DUST_SAMPLE_'..generation..'_'..index;print('DUST_SAMPLE: '..names[index]..' '..w..'x'..h) end
        hold=hold+eventData:GetFloat('TimeStep')
        if hold>4 then
            index=index+1;frame=0;hold=0
            graphics.windowTitle=index>#names and ('DUST_COMPLETE_'..generation) or 'DUST_WARMUP'
        end
    end
end
function Stop() if post then post:dispose() end;if view then view.scene:Dispose() end end
