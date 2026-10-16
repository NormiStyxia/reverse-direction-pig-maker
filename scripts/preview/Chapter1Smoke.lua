-- Native Lua VM only: exercises all answers and morning completion, not rendering.
local Story=require('game.Chapter1State')
local Smoke={}
function Smoke.run()
    local frames=0;local finished=0
    for index,answer in ipairs({'same','late','done'}) do
        local s=Story.new({random=function() return .37 end})
        local finishEvents,ready=0,0
        for _=1,2400 do
            if s.phase=='play' and not s.seen.box then s.normi:setPosition(-3.6,0,1.2);s:interact('box') end
            if #s.phone.choices>0 then s:onPanel(s.choiceMode=='answer' and 'choice:'..(index-1) or 'choice:0') end
            if s.phase=='walk' then
                if not s.carrying then s.normi:setPosition(-3.6,0,1.2);s:interact('take')
                elseif s.doorK<.9 then s.normi:setPosition(-6.8,0,1.8)
                else s.normi:setPosition(-13.2,0,2.9);s:interact('put') end
            end
            if s.phase=='desk' then s.normi:setPosition(-14.8,0,2.5);s:interact('pig') end
            s:update(.05,{camYaw=0});frames=frames+1
            for _,e in ipairs(s:drainEvents()) do if e.kind=='finish' then finishEvents=finishEvents+1 elseif e.kind=='pigReady' then ready=ready+1 end end
            if s.result then break end
        end
        assert(s.result and s.result.answer==answer and finishEvents==1 and ready==1,'Chapter1 meeting handoff failed')
        assert(s.tonightAnswer==answer and s.tonightVisible and s.frozen and s.clockBack==1,'Chapter1 desk state mismatch')
        assert(s.slide==(answer=='done') and s.tune.paper==false,'Chapter1 branch/tuning mismatch');finished=finished+1
        local morning=Story.new({mode='morning',answer=answer,random=function() return .37 end})
        for _=1,620 do morning:update(.05,{camYaw=0});morning:drainEvents();frames=frames+1 end
        assert(morning.result and morning.clockMin==598 and morning.expr=='deadpan','Chapter1 morning completion failed');finished=finished+1
    end
    print('CHAPTER1_MODEL_SMOKE: PASS; '..frames..' frames; '..finished..' model completions; same/late/done; paper=false; visuals not tested')
end
return Smoke
