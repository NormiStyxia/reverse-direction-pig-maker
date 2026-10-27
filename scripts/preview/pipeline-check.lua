-- Isolated GPU frame-coherence fixture, based on preview/outline-check.lua.
-- Never required by main.lua. Artificial jumps are NOT a gameplay test.
local Story=require('game.Chapter1State')
local View=require('render.Chapter1Renderer')
local Post=require('render.ScenePost')
local story
---@type table
local view
---@type ScenePost
local post
local frame,index,hold=0,1,0
local samples={1,2,3,4,8,16}
local done=false
local readyWait=0
local width,height,generation=0,0,0
local function pose(which)
    ---@type table
    local n=story.normi
    n.pos.x=which==0 and -2.5 or 1.5
    n.pos.z=which==0 and 1.2 or 2.2
    view:updateCamera(0,story,true);view:update(0,story)
    local camera=view.view.cameraNode
    camera.position=camera.position+Vector3(which==0 and -1 or 1,0,0)
end
function Start()
    story=Story.new({mode='meeting',random=function() return .37 end})
    for _=1,360 do story:update(1/60,{camYaw=0});story:drainEvents() end
    view=View.new(story)
    SubscribeToEvent('Update','PipelineCheckUpdate')
end
function PipelineCheckUpdate(eventType,eventData)
    view.view:pumpBuild()
    if not view.view.ready then return end
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then
        width=w;height=h;generation=generation+1
        frame=0;index=1;hold=0;readyWait=0;done=false
        graphics.windowTitle='PIPELINE_WAIT_'..generation
    end
    if done then return end
    readyWait=readyWait+eventData:GetFloat('TimeStep')
    if readyWait<10 then return end
    if not post then
        view:updateCamera(0,story,true);view:update(0,story)
        post=Post.new(view.view);post:setEnabled(true)
    end
    local count=samples[index]
    if frame<16+count then
        frame=frame+1
        if frame==1 then pose(0);graphics.windowTitle='PIPELINE_WARMUP_'..count end
        if frame==17 then pose(1) end
        -- Warm pose A for 16 renders, then pose B for exactly count renders.
        post:updateGame(story,nil,0,'chapter')
        post.style.material:SetShaderParameter('time',Variant(1.1))
    else
        -- All offscreen targets use MANUALUPDATE. Do not queue during this
        -- hold: the OS capture observes the exact N-update target contents.
        if hold==0 then graphics.windowTitle='PIPELINE_SAMPLE_'..generation..'_'..count;print('PIPELINE_SAMPLE: '..generation..' '..count) end
        hold=hold+eventData:GetFloat('TimeStep')
        if hold>3 then
            index=index+1;frame=0;hold=0
            if index>#samples then done=true;graphics.windowTitle='PIPELINE_COMPLETE_'..generation end
        end
    end
end
function Stop() if post then post:dispose() end;if view then view:dispose() end end
