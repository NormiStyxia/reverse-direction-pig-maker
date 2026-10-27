-- Isolated render regression entry. Never referenced by the player application.
-- Reuses the native chapter adapter; freezes camera/story and varies ONLY ink time.
local Story=require('game.Chapter1State')
local View=require('render.Chapter1Renderer')
local Post=require('render.ScenePost')
local story
---@type table
local view
---@type ScenePost
local post
local index,last,elapsed,frames=1,0,0,0
local samples={1.0,1.10,1.20,1.26,1.36}
function Start()
    story=Story.new({mode='meeting',random=function() return .37 end})
    for _=1,360 do story:update(1/60,{camYaw=0});story:drainEvents() end
    view=View.new(story)
    graphics.windowTitle='反方向的猪 · 描边连续帧校验'
    SubscribeToEvent('Update','OutlineCheckUpdate')
end
function OutlineCheckUpdate(eventType,eventData)
    view.view:pumpBuild()
    frames=frames+1
    if frames%120==0 then
        print('OUTLINE_HEARTBEAT: frame='..frames..' dt='..eventData:GetFloat('TimeStep')..' elapsed='..elapsed..' ready='..tostring(view.view.ready))
    end
    if not view.view.ready then return end
    if not post then
        view:updateCamera(0,story,true);view:update(0,story)
        post=Post.new(view.view);post:setEnabled(true)
    end
    elapsed=elapsed+eventData:GetFloat('TimeStep')
    index=math.floor(elapsed/3)%#samples+1
    post:updateGame(story,nil,0,'chapter')
    post.style.material:SetShaderParameter('time',Variant(samples[index]))
    if index~=last then
        last=index
        graphics.windowTitle='OUTLINE_PHASE_'..index
        print('OUTLINE_FIXED_FRAME: '..index..' time='..samples[index]..' fps=4; camera/story/lighting frozen')
    end
end
