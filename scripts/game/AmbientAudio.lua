-- Frozen StoreAudio gains and Dream pad/wind on native looping PCM stems.
-- Wind filter automation interpolates 50 Hz source-rendered bands.
local Ambient={};Ambient.__index=Ambient
local ids={'hum','hum-negative','room','cic','cri','ring','rain','pad-110','pad-110.7','pad-164.4'}
for hz=500,1100,50 do ids[#ids+1]='wind-'..hz end
local function target(current,want,dt,tau)return current+(want-current)*(1-math.exp(-dt/tau))end
function Ambient.new(scene)
    local s=setmetatable({scene=scene,sounds={},loops={},disposed=false},Ambient);s:defaults()
    for _,id in ipairs(ids)do cache:GetResourceAsync('Sound','audio/increment03/'..id..'.wav',function(sound)
        if s.disposed then return end
        assert(sound,'AMBIENT_LOAD_FAILED: '..id);s.sounds[id]=sound
    end)end
    return s
end
function Ambient:defaults()
    self.values={hum=.035,room=.05,cic=.006,cri=0,ring=0,rain=0,detune=0,pad=.02,beat=110.7,wind=800}
    self.time=0;self.power=1;self.dreamTime=0;self.mode=false
end
function Ambient:stop()
    for _,v in pairs(self.loops)do v.source:StopImmediate();v.node:Remove()end
    self.loops={};self:defaults()
end
function Ambient:loop(id,gain,pitch)
    local v=self.loops[id];local sound=self.sounds[id]
    if not v and sound then
        sound:SetLooped(true);local n=self.scene:CreateChild('Ambient-'..id);local source=n:CreateComponent('SoundSource');source:SetDeclickEnabled(false)
        source:Play(sound,0,0);v={node=n,source=source};self.loops[id]=v
    end
    if v then v.source:SetGain(math.max(0,gain)*(self.busGain or 0));v.source:SetFrequency(44100*(pitch or 1))end
end
function Ambient:update(dt,story,scope,door)
    -- Wait for the entire group: phase-related stems must start together,
    -- including currently silent bands and the inverted hum waveform.
    for _,id in ipairs(ids)do if not self.sounds[id] then return end end
    self.busGain=story.mode=='dream'and 3.6 or scope=='store'and .12*.9 or 0
    self.time=self.time+dt;local dream=story.mode=='dream';local values=self.values
    local mode=dream and 'dream' or 'world'
    if self.mode~=mode then
        for _,v in pairs(self.loops)do v.source:StopImmediate();v.node:Remove()end;self.loops={};self.mode=mode;self.dreamTime=0;self.time=0
    end
    if dream then
        self.dreamTime=self.dreamTime+dt;local near=story.near or 0
        if story.phase~='break' and story.phase~='done'then
            values.pad=target(values.pad,.02+near*.035,dt,.5);values.beat=target(values.beat,110.7+near*3,dt,.8)
            values.wind=target(values.wind,800+math.sin(story.t*.4)*300,dt,.6)
        end
        local out=(story.fx.audioFade or 0)>=1 and 0 or 1-math.exp(-self.dreamTime/1.2)
        self.dreamGain=out
        self:loop('pad-110',values.pad*out);self:loop('pad-110.7',values.pad*out,values.beat/110.7);self:loop('pad-164.4',values.pad*out)
        local low=math.max(500,math.min(1050,math.floor(values.wind/50)*50));local fraction=(values.wind-low)/50
        for hz=500,1100,50 do self:loop('wind-'..hz,.012*out*(hz==low and 1-fraction or hz==low+50 and fraction or 0))end
        return
    end
    self.dreamGain=0
    local night=(scope=='store'and story.mode~='store-day' or story.mode=='night' or story.theme=='store')and 1 or 0
    if scope=='store' then self.power=story.power or 1 elseif story.mode or story.theme~='store'then self.power=1 end
    local stress=scope=='echo' and .4 or story.sv or 0;local quiet=math.max(0,stress-.3)/.7
    local cut=scope=='echo' and .45 or story.fx and story.fx.audioFade or 0
    local rain=story.rainK or 0;local c=1-cut;local bugs=(1-math.min(1,quiet*1.6))*c*(1-rain);door=door or 0
    values.room=target(values.room,.05*(1-quiet*.8)*c*self.power,dt,self.power<1 and .08 or .4)
    values.cic=target(values.cic,(.006+door*.03)*bugs*(1-night),dt,.25)
    values.cri=target(values.cri,(.0035+door*.02)*bugs*night,dt,.25)
    values.rain=target(values.rain,rain*(.07+door*.05),dt,.8)
    values.hum=target(values.hum,(.035*(1+.35*night)+quiet*.03)*(1-math.max(0,cut-.5)*2)*self.power,dt,self.power<1 and .08 or .5)
    values.detune=target(values.detune,-quiet*40,dt,1);values.ring=target(values.ring,math.max(0,stress-.85)*.03*c,dt,.4)
    local hum=values.hum+.008*math.sin(self.time*.31*math.pi*2);local pitch=2^(values.detune/1200)
    self:loop('hum',math.max(0,hum),pitch);self:loop('hum-negative',math.max(0,-hum),pitch)
    for _,id in ipairs({'room','cic','cri','ring','rain'})do self:loop(id,values[id])end
end
function Ambient:dispose()self:stop();self.disposed=true end
return Ambient
