"""Increment 02 model contracts; input/UI integration is not yet enabled."""
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
local Store=require('game.PrologueState')
local Chapter=require('game.Chapter1State')
for _,phase in ipairs({'intro','play','dark'}) do
    local s=Store.new();s.phase=phase;s:drainEvents()
    assert(s:skip() and s.phase=='pig' and #s.later==0)
    assert(s.power==0 and s.offline and s.tablePig.visible and s.phoneButtonHidden and s.doodleGone)
    assert(s.clock==12 and not s.pending)
    if phase=='intro' then assert(s.archiveVisible and s.normi.pos.x==-.7 and s.normi.pos.z==-2.85) end
    local ready=0;for _,e in ipairs(s:drainEvents()) do if e.kind=='pigReady' then ready=ready+1 end end
    assert(ready==1 and not s:skip())
    for _=1,220 do s:update(.05) end
    assert(s.phase=='pig') -- old intro timeout must not restore play
    s:startFold();assert(not s:skip())
    for _=1,120 do s:update(.05) end
    assert(s.phase=='done')
end
for i,answer in ipairs({'same','late','done'}) do
    local s=Chapter.new();assert(not s:skip())
    for _=1,70 do s:update(.05) end
    assert(s:skip() and s.phase=='ask' and #s.phone.choices==3 and #s.phone.queue==0)
    assert(s:skip() and not s.answer and #s.phone.choices==3)
    s:onChoice(i-1);assert(s:skip())
    assert(s.phase=='walk' and s.answer==answer and s.tonightAnswer==answer)
    assert(s.carrying and not s.boxVisible and s.clockMin==902 and s.clockDusk and s.replied)
    assert(s.slide==(answer=='done') and not s:canSkip())
    for _,p in ipairs(s.people) do assert(not p.visible) end
    assert(#s.later==0 and not s.waitPanel and not s.phone.open)
    -- Natural office close-up and folding retain their timed phases.
    s:closeUp();assert(not s:skip())
    for _=1,190 do s:update(.05) end
    assert(s.phase=='desk' and s.pig.visible and not s:skip())
    s:startFold();assert(not s:skip())
    for _=1,110 do s:update(.05) end
    assert(s.phase=='done' and s.result.answer==answer)
    local m=Chapter.new({mode='morning',answer=answer});assert(not m:skip())
    for _=1,85 do m:update(.05) end
    assert(m:skip() and m.phase=='done' and m.result and #m.later==0)
end
''')
print('PASS: increment 02 skip model; 3 prologue phases, 3 answers, preserved close-up/fold, morning; UI coverage lives in test_increment02.py')
