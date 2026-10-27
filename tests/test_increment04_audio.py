"""Native bus model; no audio device or user save is accessed."""
from lupa.lua54 import LuaRuntime
l=LuaRuntime();l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
local requests={};cache={GetResourceAsync=function(_,kind,path,fn)requests[#requests+1]={path=path,fn=fn}end,ReleaseResource=function()end}
local function load()for _,r in ipairs(requests)do r.fn({SetLooped=function()end,GetFrequency=function()return 44100 end})end;requests={}end
local scene={CreateChild=function(_,name)
 local n={Remove=function(self)self.removed=true end};function n:CreateComponent()
  local s={playing=false};function s:Play(sound,hz,gain)assert(math.abs(hz-44100)<1e-7 or math.abs(hz-50715)<1e-7);self.playing=true;self.gain=gain end
  function s:SetGain(g)assert(g>=0 and g<=1);self.gain=g end;function s:StopImmediate()self.playing=false end;return s
 end;return n
end}
local score=require('game.Soundtrack').new(scene);load();score:update(10,false,false);assert(#score.voices==0,'First title must be silent')
score:unlock();score:update(.1,false,false);load();score:update(0,false,false);assert(score.current.key=='music-dream')
score:update(3,false,false);assert(math.abs(score.current.gain-1)<1e-8)
local titleVoice=score.current;score:setScene('timeline');score:update(1,false,false);assert(score.current==titleVoice,'Title/timeline must not restart')
score:setScene('store');score:update(.1,false,false);load();score:update(0,false,false);local night=score.current;assert(night.key=='music-night')
score:update(2.75,false,false);assert(math.abs(night.gain^2+titleVoice.gain^2-1)<1e-8,'Equal-power crossfade')
score:update(2.8,false,false);assert(titleVoice.node.removed and #score.voices==1)
score:update(.25,true,false);assert(math.abs(score.bus-.72*.28)<1e-8)
score:update(.25,false,true);assert(score.rewindVoice and math.abs(score.bus-.72*.55)<1e-8)
score:update(.1,false,false);assert(not score.rewindVoice)
score:play('tap');local n=#score.voices;score:play('tap');assert(#score.voices==n,'Debounce')
score:update(.3,false,false);score:play('notification',.45,1.15)
score:dispose();assert(#score.voices==0)
''')
print('PASS: quiet first title, continuous title/timeline, 5.5s equal-power fade, pause/rewind bus, debounce, rate and dispose')
