"""Compare actual frozen RewindLevels puff calls against all 11 native input routes."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import json,subprocess
root=Path(__file__).resolve().parents[1];reports=[]
for theme,oracle,folder,name in [('store','prologue-echo-route-oracle.mjs','echo','prologue-six'),('meeting','ch1-echo-route-oracle.mjs','ch1-echo','five')]:
 code=(root/'tests'/oracle).read_text().replace("'../reference/","'./reference/")
 code=code.replace('const noop=()=>{};','const puffFrames=[];let frameCalls=[];const recordPuff=(p,n=3)=>frameCalls.push({pos:{x:p.x,y:p.y,z:p.z},count:n});const noop=()=>{};')
 code=code.replace('vm.createContext(scope);','scope.Math=Object.create(Math);scope.Math.random=()=>.37;vm.createContext(scope);')
 code=code.replace('puff:noop','puff:recordPuff').replace(',rewindPuffs:noop','')
 code=code.replace('for(let i=0;i<inputs.length;i++){','for(let i=0;i<inputs.length;i++){frameCalls=[];')
 code=code.replace('if(input.charge&&e.controlEnabled)pig.tryCharge();','if(input.charge&&e.controlEnabled&&pig.tryCharge())e.puff(pig.pos,3);')
 code=code.replace(' const got={level:', ' puffFrames.push(frameCalls);'+chr(10)+' const got={level:')
 code=code[:code.index('if(!finished)')]+"console.log(JSON.stringify(puffFrames));"
 expected=json.loads(subprocess.check_output(['node','--input-type=module','-e',code],text=True))
 lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
 lua.execute('''local P=require('game.SpriteParticles');particles=P.new(function()return .37 end);calls={};local old=P.puff
 particles.puff=function(self,p,n) calls[#calls+1]={x=p.x,y=p.y,z=p.z,count=n or 3};old(self,p,n) end''')
 run=lua.eval("require('game.EchoRun').new(require('game.data.Levels')."+('prologue' if theme=='store' else 'chapter1')+",'"+theme+"')")
 run.drainEvents(run);g=lua.globals();p=g.particles;total=0
 inputs=json.loads((root/'validation'/folder/f'{name}-inputs.json').read_text())
 for i,(control,refs) in enumerate(zip(inputs,expected)):
  g.calls=lua.table();run.update(run,1/60,lua.table_from(control),0,lambda:.7)
  for event in run.drainEvents(run).values():p.event(p,event)
  p.update(p,run.lastDt or 0)
  assert len(g.calls)==len(refs),(theme,i,len(g.calls),len(refs))
  for j,ref in enumerate(refs,1):
   want=dict(ref['pos'],count=ref['count'])
   for k,value in want.items():assert abs(g.calls[j][k]-value)<1e-8,(theme,i,j,k,g.calls[j][k],value)
   total+=1
 reports.append({'theme':theme,'frames':len(inputs),'puffCalls':total,'result':'PASS'})
report={'result':'PASS','routes':reports,'scope':'actual frozen onCabDown, rewindPuffs, hitTest/simulate/merge/unfold and main charge triggers; puff position/count/order per frame, all 11 rooms; constant effect RNG .37'}
(root/'docs/migration/puff-route-events-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report,indent=2))
