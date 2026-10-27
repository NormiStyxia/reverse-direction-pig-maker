-- Native PCM synthesis of the frozen StoreAudio.tone envelope and pitch ramp.
-- Band-limited edges avoid aliasing for the short keyboard/clock square waves.
local Synth={rate=44100}
local PI=math.pi
local function blep(t,dt)
    if t<dt then local x=t/dt;return x+x-x*x-1 end
    if t>1-dt then local x=(t-1)/dt;return x*x+x+x+1 end
    return 0
end
function Synth.tone(spec)
    local hz=assert(spec.frequency);local dur=spec.dur or spec.duration or .6
    local gain=spec.gain or .12;local wave=spec.wave or 'sine';local slide=spec.slide or 0
    assert(hz>0 and hz<Synth.rate/2 and dur>0 and dur<=8 and gain>0 and gain<=1,'Invalid source tone')
    local phase=0;local logSlide=slide>0 and math.log(slide)or 0
    return math.ceil((dur+.05)*Synth.rate),function(i)
        local t=(i-1)/Synth.rate;local freq=hz*math.exp(logSlide*math.min(t/dur,1));local inc=math.min(.49,freq/Synth.rate)
        local s
        if wave=='square' then s=(phase<.5 and 1 or -1)+blep(phase,inc)-blep((phase+.5)%1,inc)
        elseif wave=='sawtooth' then s=2*phase-1-blep(phase,inc)
        elseif wave=='triangle' then
            s=0;local max=math.min(31,math.floor(Synth.rate/2/freq));for k=1,max,2 do s=s+((-1)^((k-1)/2))*math.sin(2*PI*k*phase)/(k*k)end;s=s*8/(PI*PI)
        else s=math.sin(2*PI*phase)end
        phase=(phase+inc)%1
        local env=t<=.012 and .0001*(gain/.0001)^(t/.012)or gain*(.0001/gain)^math.min(1,(t-.012)/math.max(.000001,dur-.012))
        return s*env*.9
    end
end
function Synth.sound(count,sample,looped)
    local buffer=VectorBuffer()
    for i=1,count do local v=sample(i);buffer:WriteShort(math.max(-32768,math.min(32767,math.floor(v*32767+.5))))end
    -- VectorBuffer exposes read methods but its generated Lua registration does
    -- not advertise the Deserializer base. Explicitly select that read interface.
    buffer:Seek(0);local reader=tolua.cast(buffer,'Deserializer')
    assert(reader:GetSize()==count*2,'Native PCM reader size mismatch')
    local sound=Sound();assert(sound:LoadRaw(reader),'Native PCM load failed')
    sound:SetFormat(Synth.rate,true,false);sound:SetLooped(looped or false);return sound
end
function Synth.make(spec)local n,s=Synth.tone(spec);return Synth.sound(n,s)end
return Synth
