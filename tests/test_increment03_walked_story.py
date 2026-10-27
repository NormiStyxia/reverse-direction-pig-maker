"""Full story player-action routes, no teleport/skip; Lua model, not native/device proof."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import json
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
run=lua.eval('''function(kind,answer)
 local modules={dream='DreamState',night='NightOfficeState',store='PrologueState',dorm='DormState',dormEnd='DormState',morning='Chapter1State',meeting='Chapter1State',meetingAgain='Chapter1State'}
 local opts={mode=kind,random=function()return .37 end}
 if kind=='night'then opts.wake=true end
 if kind=='meetingAgain'then opts.mode='meeting';opts.morningBranch=answer end
 if kind=='dormEnd'then opts.afterEcho=true;opts.dormChoice=answer end
 local s=require('game.'..modules[kind]).new(opts)
 local route=require('preview.Increment03StoryRoute').new(kind,answer)
 local frames,phases,seen=0,{},{}
 for i=1,20000 do
  frames=i;local x,z=route:control(s);local len=math.sqrt(x*x+z*z);local n=s.normi;local p=n.pos
  if len>0 and s:controlEnabled() and s.phase~='pigwalk'then n:moveStick({x=p.x+x/len*.8,y=0,z=p.z+z/len*.8})else n:release()end
  s:update(1/60,{camYaw=0,cameraPosition={x=0,y=8,z=22},moving=len>0,input={x=x,y=z},aspect=16/9})
  s:drainEvents();if not seen[s.phase]then phases[#phases+1]=s.phase;seen[s.phase]=true end
  if s.result then return {frames=frames,phase=s.phase,answer=s.answer,branch=s.morningBranch,dorm=s.dormChoice,ended=s.result.ended,phases=phases}end
 end
 error(kind..' '..tostring(answer)..' stalled at '..s.phase)
end''')
scenarios=[('dream','same'),('night','same'),('store','same')]
scenarios +=[(kind,a)for kind,answers in [('meeting',['same','late','done']),('morning',['fix','wreck','leave']),('meetingAgain',['fix','wreck','leave']),('dorm',['sick','pc','off']),('dormEnd',['sick','pc','off'])]for a in answers]
results=[]
for kind,answer in scenarios:
 r=run(kind,answer)
 if kind=='meeting':assert r.answer==answer
 if kind in ['morning','meetingAgain']:assert r.branch==answer
 if kind=='dorm':assert r.dorm==answer
 if kind=='dormEnd':assert r.ended
 phases=[r.phases[i]for i in range(1,len(r.phases)+1)]
 if kind=='dream':assert all(p in phases for p in ['phone','swap','pigwalk','unswap','voice','break','done'])
 results.append(dict(scene=kind,answer=answer,frames=r.frames,seconds=round(r.frames/60,2),phases=phases));print(kind,answer,r.frames)
report=dict(result='PASS',scenarios=results,scope='Lua 5.4 player-action routes: movement/interaction/choices and natural timers. No position/phase/time writes or skip. Does not prove native rendering, physical devices or cross-process storage.')
Path('docs/migration/increment03-walked-story-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
