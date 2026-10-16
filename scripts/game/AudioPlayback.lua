-- Native SoundSource playback of source-rendered one-shots. Scene survives rooms.
local Clips=require('game.data.AudioClips')
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
    self.queue={};self.generation=self.generation+1
    for _,v in ipairs(self.active) do v.source:StopImmediate();v.node:Remove() end
    self.active={}
end
function Playback:event(event,scope)
    if event.kind=='loadLevel' then
        -- Frozen later() callbacks carry the room loadId; old delayed chimes cancel.
        self.generation=self.generation+1
    end
    local cues,pending=Cues.resolve(event,scope)
    if pending then self.unhandledTones=self.unhandledTones+1;return end
    for _,c in ipairs(cues or {}) do
        assert(Clips[c.clip],'Unknown native audio cue: '..c.clip)
        self.queue[#self.queue+1]={clip=c.clip,at=self.clock+(c.delay or 0),generation=self.generation}
    end
end
function Playback:update(dt)
    self.clock=self.clock+math.max(0,dt)
    for i=#self.active,1,-1 do
        local v=self.active[i]
        if not v.source.playing then v.node:Remove();table.remove(self.active,i) end
    end
    -- Stable order for cues sharing a frame. Loading waits preserve the cue;
    -- title initialization preloads all assets before normal gameplay begins.
    local remaining={}
    for _,c in ipairs(self.queue) do
        if c.generation==self.generation then
            local sound=self.sounds[c.clip]
            if c.at<=self.clock and sound then
                local node=self.scene:CreateChild('SFX-'..c.clip)
                local source=node:CreateComponent('SoundSource');source:SetDeclickEnabled(false)
                source:Play(sound,0,1) -- Hz=0 explicitly selects this asset's rate.
                self.active[#self.active+1]={node=node,source=source}
            else remaining[#remaining+1]=c end
        end
    end
    self.queue=remaining
end
function Playback:dispose()
    self:reset();self.disposed=true;self.scene:Dispose()
end
return Playback
