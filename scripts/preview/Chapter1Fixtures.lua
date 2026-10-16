-- Actual model actions, frozen only for isolated NVG inspection (no GPU scene claim).
local Story=require('game.Chapter1State')
local Panels=require('game.Chapter1Panels')
local Fixtures={}
Fixtures.names={'第一章日程','组会三个回答','没问题回答','来不及回答','已经做完回答','小周消息','小周回复回想','早晨没问题','早晨来不及','早晨已做完'}
function Fixtures.make(index)
    ---@type string[]
    local answers={'same','late','done'}
    local story=Story.new({random=function() return .37 end,mode=index>=8 and 'morning' or 'meeting',answer=answers[index-7]})
    local function step(seconds) for _=1,math.floor(seconds/.05+.5) do story:update(.05,{camYaw=0});story:drainEvents() end end
    if index>=8 then step(20.5)
    elseif index==1 then step(4);story:togglePhone();step(3)
    else
        step(4);story.normi:setPosition(-3.6,0,1.2);story:interact('box');step(12)
        if index>=3 then
            story:onPanel('choice:'..(index<=5 and index-3 or 0));step(index<=4 and 4.8 or (index==5 and 5.8 or 15))
            if index==7 then story:onPanel('choice:0');step(4.5) end
        end
    end
    return Panels.new(story)
end
return Fixtures
