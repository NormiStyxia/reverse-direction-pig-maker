"""Source RewindLevels sound calls versus native cue routing on all 11 rooms.
Same-frame sounds mix concurrently; compare per-frame multisets, not log order.
Source later() is stubbed in these routes; delayed merge chime tested separately.
"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import json,subprocess,collections
root=Path(__file__).resolve().parents[1];reports=[]
catalog={v['id']:v for v in json.loads((root/'tests/audio-clips.json').read_text())}
def canonical(method,args):
 if method=='tone':
  p=args[1] if len(args)>1 else {}
  args=[args[0],p.get('at',0),p.get('dur',.6),p.get('gain',.12),p.get('type','sine'),p.get('slide',0)]
 return json.dumps([method,args],sort_keys=True)
for theme,oracle,folder,name in [('store','prologue-echo-route-oracle.mjs','echo','prologue-six'),('meeting','ch1-echo-route-oracle.mjs','ch1-echo','five')]:
 code=(root/'tests'/oracle).read_text().replace("'../reference/","'./reference/")
 code=code.replace('const noop=()=>{};',"const audioFrames=[];let audioFrame=[];const audioSpy=new Proxy({},{get:(_,name)=>(...args)=>audioFrame.push({method:name,args})});const noop=()=>{};")
 code=code.replace('audio:new Proxy({},{get:()=>noop})','audio:audioSpy')
 code=code.replace('for(let i=0;i<inputs.length;i++){','for(let i=0;i<inputs.length;i++){audioFrame=[];')
 code=code.replace(' const got={level:', ' audioFrames.push(audioFrame);'+chr(10)+' const got={level:')
 code=code[:code.index('if(!finished)')]+"console.log(JSON.stringify(audioFrames));"
 expected=json.loads(subprocess.check_output(['node','--input-type=module','-e',code],text=True))
 lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
 resolve=lua.eval("require('game.AudioCues').resolve")
 run=lua.eval("require('game.EchoRun').new(require('game.data.Levels')."+('prologue' if theme=='store' else 'chapter1')+",'"+theme+"')")
 run.drainEvents(run);total=0;types=collections.Counter()
 inputs=json.loads((root/'validation'/folder/f'{name}-inputs.json').read_text())
 assert len(expected)==len(inputs)
 for i,(control,refs) in enumerate(zip(inputs,expected)):
  run.update(run,1/60,lua.table_from(control),0,lambda:.7);got=[]
  for event in run.drainEvents(run).values():
   cues=resolve(event,'echo');assert not isinstance(cues,tuple),cues
   for cue in cues.values():
    if cue.delay:continue
    spec=catalog[cue.clip];got.append(canonical(spec['method'],spec['args']));types[cue.clip]+=1
  want=[canonical(r['method'],r['args']) for r in refs]
  assert sorted(got)==sorted(want),(theme,i,got,want)
  total+=len(got)
 reports.append(dict(theme=theme,frames=len(inputs),cues=total,types=dict(types),result='PASS'))
report=dict(result='PASS',routes=reports,scope='actual frozen immediate tone/chime/tap calls versus native cues per frame; same-frame multiset; no native audio device or ambient validation')
(root/'docs/migration/audio-route-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report,indent=2))
