-- One-shot cue routing. No engine APIs; fixed tones are rendered from frozen JS.
local Cues={}
local echo={cratePush='push',automaticSlide='autoSlide',crateStop='stop',cabinetTip='tip',cabinetBlocked='tip',cabinetDown='fall',platePressed='chime-0.6',exitReached='chime-0.9'}
local tones={
 {'blink',2400,1.6,.006,'sawtooth',0},{'prologuePig',330,.6,.04,'sine',.6},
 {'pig',880,.3,.04,'triangle',.6},{'tick',1300,.08,.05,'triangle',0},
}
for i=0,7 do tones[#tones+1]={'leave-'..i,320-i*30,.25,.03,'triangle',1.4} end
function Cues.resolve(event,scope)
    local d=event.data or event
    if event.kind=='sound' then
        local name=d.name
        if name=='chime' then name='chime-0.8' elseif name=='freeze' then name='tick' end
        if name=='tap' or name=='send' or name=='buzz' or name=='powerCut' or name=='slide' or name=='thunder' or name=='pig' or name=='tick' or name=='chime-0.8' then return {{clip=name}} end
    elseif event.kind=='tone' then
        for _,t in ipairs(tones) do
            if d.frequency==t[2] and (d.dur or d.duration)==t[3] and d.gain==t[4] and (d.wave or 'sine')==t[5] and (d.slide or 0)==t[6] then return {{clip=t[1]}} end
        end
        -- Dynamic typing is intentionally not approximated by pitch-shifting a
        -- fixed envelope. Its native synthesis remains a separate pending item.
        return nil,'dynamic-tone'
    elseif scope=='echo' then
        if echo[event.kind] then return {{clip=echo[event.kind]}} end
        if event.kind=='merge' then return {{clip='merge'},{clip='chime-1.2',delay=.12}} end
        if event.kind=='rewindTick' then return {{clip=d.moved and 'rewind' or 'rewindEnd'}} end
    end
    return {}
end
return Cues
