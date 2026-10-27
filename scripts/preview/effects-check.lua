-- Isolated first-frame / paused-render effect fixture. No gameplay completion claim.
local Story=require('game.Chapter1State')
local View=require('render.Chapter1Renderer')
local Post=require('render.ScenePost')
local Effects=require('game.ScreenEffects')
local story
---@type table
local view
---@type ScenePost
local post
local elapsed,index,frame,hold=0,1,0,0
local width,height,generation=0,0,0
local cases={'idle','flash','shake','settled'}
local counts={1,24}
local function prepare(which)
    post.effects:reset()
    post.effects.random=function()return .75 end
    view:updateCamera(0,story,true);view:update(0,story)
    if which=='flash' then post.effects:event({kind='flash',amount=.6});post.effects:update(1/60)
    elseif which=='shake' then post.effects:event({kind='cabinetDown'});view:updateCamera(1/60,story);post.effects:update(1/60)
    elseif which=='settled' then
        post.effects:event({kind='merge'})
        for _=1,120 do post.effects:camera(1/60);post.effects:update(1/60) end
        view:updateCamera(0,story,true)
    end
end
function Start()
    Effects.shared:reset()
    story=Story.new({mode='meeting',random=function()return .37 end})
    for _=1,360 do story:update(1/60,{camYaw=0});story:drainEvents() end
    view=View.new(story)
    SubscribeToEvent('Update','EffectsCheckUpdate')
end
function EffectsCheckUpdate(eventType,eventData)
    view.view:pumpBuild()
    if not view.view.ready then return end
    local dt=eventData:GetFloat('TimeStep')
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then
        width=w;height=h;generation=generation+1;elapsed=0;index=1;frame=0;hold=0
        graphics.windowTitle='EFFECTS_WAIT_'..generation
    end
    if index>#cases*#counts then return end
    elapsed=elapsed+dt;if elapsed<10 then return end
    if not post then
        view:updateCamera(0,story,true);view:update(0,story)
        post=Post.new(view.view);post:setEnabled(true)
    end
    local which=cases[math.floor((index-1)/#counts)+1];local count=counts[(index-1)%#counts+1]
    if frame<16+count then
        frame=frame+1
        if frame==1 then prepare('idle');graphics.windowTitle='EFFECTS_WARM_'..generation end
        if frame==17 then prepare(which) end
        -- Repeated paused updates must preserve the same camera offset and flash.
        view:updateCamera(0,story,true);view:update(0,story)
        post.effects:update(0);post:updateGame(story,nil,0,'chapter')
    else
        if hold==0 then
            local e=post.effects
            graphics.windowTitle='EFFECTS_SAMPLE_'..generation..'_'..which..'_'..count
            print('EFFECTS_SAMPLE: '..cjson.encode({case=which,count=count,flash=e.flash,shake=e.shake,x=e.x,y=e.y,width=w,height=h}))
        end
        hold=hold+dt
        if hold>3 then
            index=index+1;frame=0;hold=0
            if index>#cases*#counts then graphics.windowTitle='EFFECTS_COMPLETE_'..generation end
        end
    end
end
function Stop()
    Effects.shared:reset();Effects.shared.random=math.random
    if post then post:dispose() end;if view then view:dispose() end
end
