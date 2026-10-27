"""Engine boundary contract, not device playback: delayed/load/reset/lifetime."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import json
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
loads={};plays={};stops=0;removes=0
cache={GetResourceAsync=function(_,kind,path,cb) assert(kind=='Sound');loads[path]=cb end}
Scene=function()return {CreateChild=function(_,name)
 local n={name=name};n.Remove=function()removes=removes+1 end
 n.CreateComponent=function(_,kind)
  assert(kind=='SoundSource');local s={playing=false}
  s.SetDeclickEnabled=function(_,v)assert(v==false)end
  s.Play=function(self,sound,hz,gain) assert(hz==0 and gain==1);self.playing=true;plays[#plays+1]={name=name,sound=sound} end
  s.StopImmediate=function(self)self.playing=false;stops=stops+1 end
  return s
 end;return n
end,Dispose=function()end}end
bank=require('game.AudioPlayback').get()
function event(kind,data) bank:event({kind=kind,data=data or {}},'echo') end
function loadAll() for path,cb in pairs(loads)do cb({path=path})end end
''')
g=lua.globals();bank=g.bank;checks=0
def check(v):
 global checks
 assert v;checks+=1
g.event('merge',lua.table());bank.update(bank,0);check(len(g.plays)==0)
g.loadAll();bank.update(bank,0);check(len(g.plays)==1 and g.plays[1].name=='SFX-merge')
bank.update(bank,.119);check(len(g.plays)==1)
bank.update(bank,.0011);check(len(g.plays)==2 and g.plays[2].name=='SFX-chime-1.2')
bank.reset(bank);check(len(bank.queue)==0 and len(bank.active)==0 and g.stops==2)
g.event('merge',lua.table());bank.update(bank,0);g.event('loadLevel',lua.table());bank.update(bank,.2)
check(len(g.plays)==3 and len(bank.queue)==0)
bank.active[1].source.playing=False;bank.update(bank,0);check(len(bank.active)==0)
g.event('sound',lua.table_from({'name':'tap'}));bank.update(bank,0)
check(g.plays[len(g.plays)].name=='SFX-tap')
bank.reset(bank);g.event('merge',lua.table());bank.reset(bank);bank.update(bank,1);check(len(g.plays)==4)
bank.event(bank,lua.table_from({'kind':'tone','frequency':2784.22,'duration':.018,'gain':.008,'wave':'square'}),'chapter')
check(bank.unhandledTones==0 and len(bank.queue)==1)
lua.execute("package.loaded['game.ToneSynth']={make=function(spec)assert(spec.frequency==2784.22);return {nativeTone=true}end}")
bank.update(bank,0);check(g.plays[len(g.plays)].sound.nativeTone and len(bank.queue)==0)
bank.dispose(bank);check(bank.disposed and len(bank.active)==0)
g.loadAll();check(bank.disposed)
report=dict(result='PASS',checks=checks,scope='native API mock: rate reset, original gain, overlap, .12s delayed chime, old-room cancellation, late async resources, finish/replay/dispose; dynamic typing routed with sound lifetime retained; PCM engine API checked separately; not device playback')
Path('docs/migration/audio-playback-contract-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report))
