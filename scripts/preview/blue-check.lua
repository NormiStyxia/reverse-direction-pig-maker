-- Isolated rendering fixture, never referenced by the player application.
-- Tests source sweep uniforms and present-depth visibility, not live gameplay.
local Bridge=require('game.SceneBridge')
local Post=require('render.ScenePost')
local story,view,post,echo
local index,frame,hold,wait=1,0,0,0
local width,height,generation=0,0,0
local samples={'store-blue','store-sweep','store-color','echo-color','echo-blue-all','echo-blue-present','hidden-blue-all','hidden-blue-present','chapter-color','chapter-blue-present'}
local function store()
    story=require('game.PrologueState').new({deferIntro=true,random=function() return .37 end})
    view=require('render.StoreRenderer').new()
end
local function enterEcho(meeting)
    post:dispose();post=nil
    local old=view
    local levels=require('game.data.Levels')
    story=require('game.EchoRun').new(meeting and levels.chapter1 or levels.prologue,meeting and 'meeting' or 'store');story.answer='same'
    story:drainEvents();story:load(meeting and 1 or 5)
    for _=1,300 do story:update(1/60,{},0,function() return .7 end);story:drainEvents() end
    echo=require('render.EchoRenderer').new(story)
    view=echo.view;old:dispose()
end
local function sample()
    if index==4 and not echo then enterEcho();return false end
    if index==9 and view.data.theme~='meeting' then enterEcho(true);return false end
    if not view.ready then return false end
    if not post then
        if echo then echo:update(0,story);echo:updateCamera(1,story) end
        post=Post.new(view);post:setEnabled(true)
    end
    local b=Bridge.new()
    if index<=3 then
        if index<3 then b:start();b:update(index==1 and 0 or 3.1,0) end
        view.bridgeDistance=b.distance;view:update(0,story)
        post:updateGame(story,nil,0,'store',nil,b)
    else
        echo:update(0,story)
        if index==7 or index==8 then
            for i,c in ipairs(story.sim.room.crates) do
                if c.gold then view.nodes[echo.data.handles.crates[i].id].position=Vector3(0,-1.5,3) end
            end
            -- The golden plate also moves below the opaque floor.
            for _,id in ipairs(require('render.PresentSelection').ids(view.data)) do
                local n=view.data.nodes[id]
                for _,mat in ipairs(n.materials or {}) do
                    for _,plate in ipairs(view.data.handles.plates) do
                        if mat==plate then view.nodes[id].position=Vector3(0,-1.5,3) end
                    end
                end
            end
        end
        b.blue=(index==4 or index==9) and 0 or .6
        post:updateGame(story,nil,0,'echo',echo.pose,b)
        if index==5 or index==7 then post.final.material:SetShaderParameter('presentOn',Variant(0)) end
    end
    return true
end
function Start() store();SubscribeToEvent('Update','BlueCheckUpdate') end
function BlueCheckUpdate(eventType,eventData)
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then
        width=w;height=h;generation=generation+1;frame=0;hold=0;wait=0
        if echo then post:dispose();post=nil;local old=view;echo=nil;store();old:dispose() end
        index=1;graphics.windowTitle='BLUE_WAIT_'..generation
    end
    if index>#samples then return end
    wait=wait+eventData:GetFloat('TimeStep');if wait<10 then return end
    if frame<24 then
        if sample() then frame=frame+1 end
    else
        -- Retain a stable GPU result while the OS captures it.
        if hold==0 then graphics.windowTitle='BLUE_SAMPLE_'..generation..'_'..index;print('BLUE_SAMPLE: '..samples[index]) end
        hold=hold+eventData:GetFloat('TimeStep')
        if hold>3 then
            index=index+1;frame=0;hold=0
            graphics.windowTitle=index>#samples and ('BLUE_COMPLETE_'..generation) or 'BLUE_WARMUP'
        end
    end
end
function Stop() if post then post:dispose() end;if view then view:dispose() end end
