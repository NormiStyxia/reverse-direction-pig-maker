-- Development-only native VM check. Does not stand in for rendered gameplay.
local Prologue=require('game.PrologueState')
local Smoke={}
function Smoke.run()
    local story=Prologue.new({random=function() return .37 end})
    local phases={};local ready,finished=0,0
    for _=1,3060 do
        if story.phase=='pig' then
            story.normi:setPosition(-3.35,0,-3.2)
            story:interact('pig')
        end
        story:update(.05,{camYaw=0,moving=false})
        phases[story.phase]=true
        for _,e in ipairs(story:drainEvents()) do
            if e.kind=='pigReady' then ready=ready+1 elseif e.kind=='finish' then finished=finished+1 end
        end
    end
    assert(story.phase=='done' and story.result,'Prologue native VM did not finish')
    assert(story.clock==12 and story:hm()=='23:50' and #story.msgs==7,'Prologue timeline mismatch')
    assert(story.power==0 and story.doodleGone and ready==1 and finished==1,'Prologue event mismatch')
    assert(phases.intro and phases.play and phases.dark and phases.pig and phases.fold and phases.done,'Prologue phase missing')
    print('PROLOGUE_MODEL_SMOKE: PASS; 3060 frames; 7 incoming messages; intro/play/dark/pig/fold/done; visuals not tested')
end
return Smoke
