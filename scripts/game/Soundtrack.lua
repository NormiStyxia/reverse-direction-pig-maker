-- Increment04 original Mivo audio. One persistent native bus across scene changes.
local Score={};Score.__index=Score
local MUSIC={title='dream',timeline='dream',dream='dream',night='night',store='night',['store-day']='dawn',meeting='dream',morning='dawn',dorm='dawn',echo='puzzle'}
local GAINS={impact=.65,slide=.3,rewind=.32,mechanism=.48,success=.5,transition=.38,tap=.32,paper=.28,pickup=.42,door=.42,notification=.4,footstep=.13}
-- Keep the original files and provenance; prepared WAVs contain the source loop seam.
local function asset(key)return (key:find('music-',1,true)or key=='rewind')and 'audio/increment04/'..key..'.wav'or 'audio/'..key..'.wav'end
function Score.new(scene)
 local self=setmetatable({scene=scene,scope='title',voices={},buffers={},loading={},failed={},last={},order={},clock=0,enabled=false,paused=false,rewinding=false,bus=.72},Score)
 for key in pairs(GAINS)do self:load(key)end
 return self
end
function Score:load(key)
 if self.buffers[key]or self.loading[key]or self.failed[key]then return end
 self.loading[key]=true
 cache:GetResourceAsync('Sound',asset(key),function(sound)
  self.loading[key]=nil;if self.dead then return end
  if not sound then self.failed[key]=true;print('SCORE_LOAD_FAILED: '..asset(key));return end
  self.buffers[key]=sound
  if key:find('music-',1,true)then
   self.order[#self.order+1]=key
   while #self.order>2 do local old=table.remove(self.order,1);self.buffers[old]=nil;cache:ReleaseResource('Sound',asset(old),false)end
  end
 end)
end
function Score:unlock()self.enabled=true end
function Score:setScene(scope)
 if self.scope==scope then return end
 self.scope=scope;self.rewinding=false;self.steps=0
end
function Score:voice(key,loop,gain,rate)
 local sound=self.buffers[key];if not sound then self:load(key);return end
 sound:SetLooped(loop)
 local node=self.scene:CreateChild('Score-'..key);local source=node:CreateComponent('SoundSource')
 source:Play(sound,sound:GetFrequency()*(rate or 1),gain or 0)
 local v={key=key,node=node,source=source,sound=sound,gain=gain or 0,loop=loop}
 self.voices[#self.voices+1]=v;return v
end
function Score:fade(v,target,duration)
 v.from=v.gain;v.target=target;v.elapsed=0;v.duration=duration
end
function Score:play(key,gain,rate)
 if not self.enabled or self.paused then return true end
 if not self.buffers[key]then self:load(key);return false end
 if self.clock-(self.last[key]or -99)<(key=='footstep'and .28 or .065)then return true end
 local n=0;for _,v in ipairs(self.voices)do if not v.loop then n=n+1 end end;if n>=12 then return true end
 self.last[key]=self.clock;self:voice(key,false,(GAINS[key]or .3)*(gain or 1)*.8*.9,rate);return true
end
function Score:update(dt,paused,rewinding)
 dt=math.max(0,dt);self.clock=self.clock+dt;self.paused=paused;self.rewinding=rewinding
 local wanted=self.enabled and MUSIC[self.scope]and 'music-'..MUSIC[self.scope]or nil
 if wanted and (not self.current or self.current.key~=wanted)then
  if self.buffers[wanted]then
   local duration=self.current and 5.5 or 3
   for _,v in ipairs(self.voices)do if v.music then self:fade(v,0,duration)end end
   self.current=self:voice(wanted,true,0);self.current.music=true;self:fade(self.current,1,duration)
  else self:load(wanted)end
 end
 local target=.72*(paused and .28 or rewinding and .55 or 1);self.bus=self.bus+(target-self.bus)*math.min(1,dt/.25)
 local rewind=self.enabled and rewinding and not paused
 if rewind and not self.rewindVoice then self.rewindVoice=self:voice('rewind',true,0);if self.rewindVoice then self:fade(self.rewindVoice,.32*.8*.9,.12)end
 elseif not rewind and self.rewindVoice then self:fade(self.rewindVoice,0,.08);self.rewindVoice=nil end
 for i=#self.voices,1,-1 do
  local v=self.voices[i]
  if v.duration then
   v.elapsed=math.min(v.duration,v.elapsed+dt);local u=v.elapsed/v.duration
   if v.music then local s=u*u*(3-2*u);local mix=math.sin(s*math.pi/2)^2;v.gain=math.sqrt(math.max(0,v.from*v.from*(1-mix)+v.target*v.target*mix))
   else v.gain=v.from+(v.target-v.from)*u end
  end
  if not v.source.playing or(v.target==0 and v.elapsed>=v.duration)or(paused and not v.loop)then
   v.source:StopImmediate();v.node:Remove();table.remove(self.voices,i)
  else v.source:SetGain(v.gain*(v.music and self.bus*.9 or 1))end
 end
end
function Score:footsteps(dt,speed)
 if dt<=0 or speed<.3 then self.steps=0;return end
 self.steps=(self.steps or 0)+math.min(dt,.1)*speed
 if self.steps>1.1 then self.steps=0;self:play('footstep',1,.94+math.random()*.12)end
end
function Score:event(e,scope)
 local d=e.data or e
 if e.kind=='sound'then
  local map={tap='tap',send='notification',buzz='notification',slide='slide',chime='success',pickup='pickup',door='door',paper='paper'}
  local key=map[d.name];if key then return self:play(key,d.name=='send'and .45 or 1,d.name=='send'and 1.15 or 1)end
 elseif scope=='echo'then
  local map={cratePush='slide',automaticSlide='slide',crateStop='impact',cabinetTip='impact',cabinetBlocked='impact',cabinetDown='impact',platePressed='mechanism',exitReached='success',merge='mechanism'}
  if map[e.kind]then return self:play(map[e.kind])end
 end
 return false
end
function Score:dispose()
 self.dead=true;for _,v in ipairs(self.voices)do v.source:StopImmediate();v.node:Remove()end;self.voices={};self.buffers={}
end
return Score
