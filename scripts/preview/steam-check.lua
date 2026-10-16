-- Isolated source steam / transparency / camera / fold comparison, not gameplay.
local Model=require('game.HotFoodSteam')
---@type table
local view
---@type ScenePost
local post
---@type HotFoodSteamRenderer
local steam
local frame,hold,index,wait=0,0,1,0
local width,height,generation=0,0,0
local function sample()
    steam.model=Model.new()
    local amount=index==3 and 0 or .64
    for i=1,(index==1 and 0 or 120) do steam.model:update(1/60,i/60,amount) end
    steam.model:update(0,index==1 and 0 or 2,amount)
    local moved=index==4 or index==5
    view.cameraNode.position=Vector3(moved and 5.4 or 4.6,2.8,-6.75)
    view.cameraNode:LookAt(Vector3(4.6,2.1,-.75))
    steam.source.position=Vector3(0,0,0);steam.source.rotation=Quaternion.IDENTITY;steam.source.scale=Vector3(1,1,1)
    if index==6 then
        steam.source.position=Vector3(2,1,0);steam.source.rotation=Quaternion(17,Vector3.FORWARD);steam.source.scale=Vector3(.5,.5,.5)
    end
    steam:sync()
end
function Start()
    local scene=Scene();scene:CreateComponent('Octree')
    local zone=scene:CreateComponent('Zone');zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.depthFogEnable=false;zone.heightFogEnable=false;zone.fogColor=Color(0,0,0)
    zone.tonemapMode=TONEMAP_MODE_NONE;zone:SetAttribute('Bloom Enable',Variant(false))
    local node=scene:CreateChild('Camera');local camera=node:CreateComponent('Camera')
    camera.fov=24;camera.nearClip=1;camera.farClip=1400;camera.viewMask=1
    local viewport=Viewport:new(scene,camera);local path=viewport:GetRenderPath():Clone()
    assert(path:Load(cache:GetResource('XMLFile','RenderPaths/Forward.xml')));viewport:SetRenderPath(path)
    view={scene=scene,zone=zone,cameraNode=node,camera=camera,viewport=viewport}
    steam=require('render.HotFoodSteamRenderer').new(view,scene:CreateChild('SourceFurniture'))
    post=require('render.ScenePost').new(view);post:setEnabled(true)
    assert(post.final.material:SetSurfaceShader('Shaders/BLGL/DustInspect.shader'))
    SubscribeToEvent('Update','SteamCheckUpdate')
end
function SteamCheckUpdate(eventType,eventData)
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then width=w;height=h;generation=generation+1;frame=0;hold=0;index=1;wait=0;graphics.windowTitle='STEAM_WAIT_'..generation end
    wait=wait+eventData:GetFloat('TimeStep');if wait<10 or not steam.ready then return end
    if index>7 then return end
    post.dust.mainMesh.enabled=false;post.dust.nearMesh.enabled=false
    if frame<(index==4 and 1 or 24) then
        post:resize(w,h);sample()
        if index==7 and frame==0 then assert(post.final.material:SetSurfaceShader('Shaders/BLGL/PuffDepthInspect.shader')) end
        post.final.material:SetShaderParameter('reverse_depth',Variant(view.camera:UseReverseZ() and 1 or 0))
        post.final.material:SetShaderParameter('coverage',Variant(0));post.final.material:SetSurfaceTexture('tColor',index==7 and post.depthTexture or post.targets[1])
        post:update(nil,0);frame=frame+1
    else
        if hold==0 then graphics.windowTitle='STEAM_SAMPLE_'..generation..'_'..index end
        hold=hold+eventData:GetFloat('TimeStep')
        if hold>3 then index=index+1;frame=0;hold=0;graphics.windowTitle=index>7 and ('STEAM_COMPLETE_'..generation) or 'STEAM_WARMUP' end
    end
end
function Stop() if steam then steam:dispose() end;if post then post:dispose() end;if view then view.scene:Dispose() end end
