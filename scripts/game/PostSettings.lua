-- Frozen main.js owns one Post across scenes. These are its explicit settings,
-- not UrhoX defaults. Scene lighting/material tuning remains on each story.
local Tuning=require('game.data.Tuning')
local Settings={};Settings.__index=Settings
local fields={'bloomStrength','bloomThreshold','wobbleAmp','lineScale','paper'}
local function copy(t)local r={};for k,v in pairs(t)do r[k]=v end;return r end
local function human(mode)return mode=='meeting'or mode=='morning'or mode=='dorm'end
function Settings.new()local s=setmetatable({},Settings);s:reset();return s end
function Settings:reset(landed)
    local cadence=landed and self.values and self.values.wobbleFps or 8
    self.values={dof=true,lines=true,paper=true,wobble=true,bloom=true,bloomStrength=1,bloomThreshold=1,wobbleAmp=1,wobbleFps=cadence,lineScale=1}
    self.mode='title';self.timelineWas=nil
end
function Settings:enter(mode)
    local v=self.values
    if self.mode=='timeline' then
        v.dof=self.timelineWas.dof;v.wobble=self.timelineWas.wobble;self.timelineWas=nil
    elseif human(self.mode) then
        -- endHuman(): reset chapter post effects, but retain wobble cadence.
        v.bloomStrength=1;v.bloomThreshold=1;v.wobbleAmp=1;v.lineScale=1;v.paper=true
    end
    if mode=='store'or human(mode) then
        local t=mode=='store'and Tuning.store or Tuning.ch1
        for _,key in ipairs(fields)do v[key]=t[key]end
        if mode=='store'then v.wobbleFps=t.wobbleFps end
    elseif mode=='timeline' then
        self.timelineWas={dof=v.dof,wobble=v.wobble};v.dof=false;v.wobble=false
    end
    self.mode=mode;return copy(v)
end
return Settings
