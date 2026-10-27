-- Native SoundSource playback of source-rendered one-shots. Scene survives rooms.
local Clips=require('game.data.AudioClips')
for id,path in pairs(require('game.data.DreamAudioClips'))do Clips[id]=path end
for _,spec in ipairs(require('game.data.FixedToneClips'))do Clips[spec[1]]='audio/increment03/fixed/'..spec[1]..'.wav' end
local Cues=require('game.AudioCues')
---@class AudioPlayback
---@field scene Scene
---@field sounds table<string, Sound>
---@field active table[]
---@field queue table[]
---@field clock number
---@field generation integer
---@field disposed boolean
local Playback={};Playback.__index=Playback
---@type AudioPlayback?
local shared
---@return AudioPlayback
function Playback.get()
    if shared and not shared.disposed then return shared end
    local self=setmetatable({scene=Scene(),sounds={},active={},queue={},clock=0,generation=0,disposed=false,unhandledTones=0},Playback)
    shared=self
    self.ambient=require('game.AmbientAudio').new(self.scene)
    for id,path in pairs(Clips) do
        cache:GetResourceAsync('Sound',path,function(sound)
            if self.disposed then return end
            if not sound then print('AUDIO_LOAD_FAILED: '..path);return end
            self.sounds[id]=sound
        end)
    end
    return self
end
function Playback:reset()
    self.ambient:stop()
    self.queue={};self.generation=self.generation+1
    for _,v in ipairs(self.active) do v.source:StopImmediate();v.node:Remove() end
    self.active={}
end
function Playback:environment(dt,story,scope,door)
    self.ambient:update(math.max(0,dt),story,scope,door)
end
function Playback:event(event,scope)
    if event.kind=='loadLevel' then
        -- Frozen later() callbacks carry the room loadId; old delayed chimes cancel.
        self.generation=self.generation+1
    end
    local cues,pending=Cues.resolve(event,scope)
    if pending then self.unhandledTones=self.unhandledTones+1;return end
    for _,c in ipairs(cues or {}) do
        if c.clip then assert(Clips[c.clip],'Unknown native audio cue: '..c.clip)end
        self.queue[#self.queue+1]={clip=c.clip,tone=c.tone,gain=c.gain or 1,dream=c.dream,at=self.clock+(c.delay or 0),generation=self.generation}
    end
end
function Playback:update(dt)
    self.clock=self.clock+math.max(0,dt)
    for i=#self.active,1,-1 do
        local v=self.active[i]
        if v.dream then v.source:SetGain(v.gain*(self.ambient.dreamGain or 0))end
        if not v.source.playing then v.node:Remove();table.remove(self.active,i) end
    end
    -- Stable order for cues sharing a frame. Loading waits preserve the cue;
    -- title initialization preloads all assets before normal gameplay begins.
    local remaining={}
    for _,c in ipairs(self.queue) do
        if c.generation==self.generation then
            local sound=c.clip and self.sounds[c.clip]
            if c.tone and c.at<=self.clock then
                if self.synthError then c.failed=true else
                    local ok,result=pcall(require('game.ToneSynth').make,c.tone)
                    if ok then sound=result else
                        c.failed=true;self.synthError=tostring(result);self.unhandledTones=self.unhandledTones+1
                        print('AUDIO_SYNTH_FAILED: '..self.synthError)
                    end
                end
            end
            if c.at<=self.clock and sound then
                local node=self.scene:CreateChild('SFX-'..(c.clip or 'tone'))
                local source=node:CreateComponent('SoundSource');source:SetDeclickEnabled(false)
                source:Play(sound,0,c.gain*(c.dream and(self.ambient.dreamGain or 0)or 1)) -- Hz=0 selects the asset rate.
                self.active[#self.active+1]={node=node,source=source,sound=sound,gain=c.gain,dream=c.dream}
            elseif not c.failed then remaining[#remaining+1]=c end
        end
    end
    self.queue=remaining
end
function Playback:dispose()
    self:reset();self.ambient:dispose();self.disposed=true;self.scene:Dispose()
end
return Playback
