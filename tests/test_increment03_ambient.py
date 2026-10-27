"""Lifecycle/gain checks for frozen ambience; mock boundary, not device acoustics."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import json,wave,struct
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
loads={};plays=0;stops=0
cache={GetResourceAsync=function(_,kind,path,cb)loads[path]=cb end}
scene={CreateChild=function(_,name)return {Remove=function()end,CreateComponent=function()
 return {SetDeclickEnabled=function()end,Play=function(_,sound,rate,gain)assert(gain==0);plays=plays+1 end,
 SetGain=function(s,k)s.gain=k end,SetFrequency=function(s,k)s.frequency=k end,StopImmediate=function()stops=stops+1 end}
end}end}
a=require('game.AmbientAudio').new(scene)
function loaded(except)for path,cb in pairs(loads)do if not except or not path:find(except,1,true)then cb({SetLooped=function()end})end end end
function loops()local n=0;for _ in pairs(a.loops)do n=n+1 end;return n end
world={power=1,t=0,fx={}};dream={mode='dream',t=0,near=0,phase='intro',fx={}}
''')
g=lua.globals();a=g.a
assert g.plays==0
# Delayed readiness cannot let either phase-related waveform start alone.
g.loaded('hum-negative');a.update(a,.1,g.world,'store',0);assert g.plays==0
g.loaded();a.update(a,.1,g.world,'store',0);assert g.loops()==7 and g.plays==7
assert a.loops['hum-negative'].source.gain==0
for _ in range(100):a.update(a,.1,g.world,'store',0)
assert a["values"].cri>0 and a["values"].cic<1e-10
g.world.power=0
for _ in range(100):a.update(a,.1,g.world,'store',0)
assert a["values"].room<1e-10 and a["values"].hum<1e-10
negative_seen=False
for _ in range(100):
 a.update(a,.1,g.world,'store',0)
 negative_seen|=a.loops['hum-negative'].source.gain>0
assert negative_seen and g.plays==7
lua.execute("echo={theme='store'}")
a.update(a,.1,g.echo,'echo',0);assert a.power==0
lua.execute("day={mode='morning',fx={}}")
a.update(a,.1,g.day,'chapter',0);assert a.power==1
# All wind bands remain alive at zero gain, preserving phase while crossfading.
a.update(a,.1,g.dream,'chapter',0);assert g.loops()==16 and g.plays==23
for _ in range(100):a.update(a,.1,g.dream,'chapter',0)
assert g.plays==23 and 0<a.dreamGain<=1
g.dream.fx.audioFade=1;a.update(a,.1,g.dream,'chapter',0)
assert all(v.source.gain==0 for _,v in a.loops.items())
a.stop(a);assert g.loops()==0 and g.stops==23
# Asset pair cancellation and common initial phase are checked byte-for-byte.
def samples(name):
 with wave.open('assets/audio/increment03/'+name+'.wav','rb')as w:
  assert w.getframerate()==44100 and w.getnchannels()==1
  return struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
x,y=samples('hum'),samples('hum-negative');assert all(i==-j for i,j in zip(x,y))
assert all(samples('pad-'+f)[0]==0 for f in ['110','110.7','164.4'])
report={'result':'PASS','scope':'mock lifecycle/gain, late load synchronization, power continuation, phase-related PCM, dream cut and title silence; not native playback or acoustic equivalence'}
Path('docs/migration/increment03-ambient-test.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
