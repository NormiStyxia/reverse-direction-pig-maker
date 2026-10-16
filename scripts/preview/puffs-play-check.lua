-- Two isolated live echo starts, not a title-to-end route. Source input replay.
local Echo=require('preview.EchoProbe')
local Particles=require('game.SpriteParticles')
---@type table
local probe
local which=1
---@type table|false
local pending=false
local hold=0
local finished=false
local function start(theme)
    local old=probe
    Particles.shared:reset()
    probe=Echo.new(nil,theme,'done',1,function(e)
        if (which==1 and e.kind=='cabinetDown') or (which==2 and e.kind=='merge') then pending={t=0,kind=e.kind} end
    end)
    if old then old:dispose() end
    probe:beginInputReplay()
    SubscribeToEvent(probe.screen.vg,'NanoVGRender','PuffsPlayRender')
end
function Start() start('store');SubscribeToEvent('Update','PuffsPlayUpdate') end
function PuffsPlayRender() if probe then probe.screen:render() end end
function PuffsPlayUpdate(eventType,eventData)
    if finished then return end
    local dt=eventData:GetFloat('TimeStep')
    if hold>0 then
        hold=hold-dt;probe:update(0)
        if hold<=0 then
            if which==1 then which=2;pending=false;start('meeting');graphics.windowTitle='PUFF_PLAY_WAIT'
            else finished=true;graphics.windowTitle='PUFF_PLAY_COMPLETE' end
        end
        return
    end
    probe:update(dt)
    if pending and probe.post then
        pending.t=pending.t+(probe.run.lastDt or 0)
        if pending.t>=.1 then
            probe.paused=true;hold=4
            graphics.windowTitle='PUFF_PLAY_'..pending.kind
            print('PUFF_PLAY: '..cjson.encode({kind=pending.kind,particles=#Particles.shared.list,level=probe.run.index,phase=probe.run.phase,frames=probe.replayFrame}))
        end
    end
end
function Stop() if probe then probe:dispose() end;Particles.shared:reset() end
