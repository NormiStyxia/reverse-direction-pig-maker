-- Isolated fixture file only. Does not seed or alter the player's save.
local Native=require('game.NativeSave')
local Smoke={}
function Smoke.run()
    local key='reverse-pig-preview-save-check.json'
    local a=Native.open(key);local previous=a:chapter('validation') or {};local boots=(previous.boots or 0)+1
    print('NATIVE_SAVE_PREVIOUS: reached='..a:reached()..' answer='..a:answer()..' boots='..(previous.boots or 0))
    a:saveChapter('echo',{reached=4});a:echoLoaded(2);a:echoFinished();a:meetingFinished('late');a:saveChapter('validation',{boots=boots})
    local b=Native.open(key)
    assert(a.persisted and b.persisted and b:reached()==4 and b:answer()=='late' and b:chapter('echo').done,'Native file save/readback failed')
    assert(b:chapter('validation').boots==boots,'Native file reload mismatch')
    print('NATIVE_SAVE_SMOKE: PASS; isolated fixture; reached=4; answer=late; done=true; boots='..boots..'; player save untouched')
end
return Smoke
