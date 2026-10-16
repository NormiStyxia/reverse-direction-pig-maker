"""Compare native presentation to frozen JS methods using actual Three transforms."""
import json,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Run=lua.eval("require('game.EchoRun')")[0];Pose=lua.eval("require('game.EchoPose')")[0]
levels=lua.eval("require('game.data.Levels')")[0]
run=Run.new(levels.prologue,'store');pose=Pose.new();current=0;checks=0

def compare(expected,actual,path):
    global checks
    if isinstance(expected,dict):
        for k,v in expected.items():compare(v,actual[k],path+'.'+k)
    elif isinstance(expected,list):
        assert len(expected)==len(actual),(path,'length')
        for i,v in enumerate(expected,1):compare(v,actual[i],path+'.'+str(i))
    elif isinstance(expected,bool):assert expected==actual,(path,expected,actual);checks+=1
    else:
        assert math.isfinite(actual) and abs(expected-actual)<1e-9,(path,expected,actual)
        checks+=1

fixtures=json.loads((ROOT/'validation/echo/source-pose.json').read_text())
for f in fixtures:
    if f['level']!=current:
        current=f['level'];run.load(run,current);pose=Pose.new()
    i=f['input'];S=run.sim;R=S.room
    run.t=i['t'];run.fold=i['fold'];S.rewinding=i['rewinding'];R.doorOpen=i['doorOpen'];R.doorTimer=i['doorTimer']
    for j,c in enumerate(i['crates'],1):R.crates[j].x=c['x'];R.crates[j].z=c['z']
    for j,c in enumerate(i['cabinets'],1):
        for key,v in c.items():R.cabinets[j][key]=v
    for j,pressed in enumerate(i['pressed'],1):R.plates[j].pressed=pressed
    pose.update(pose,run,i['dt']);compare(f['out'],pose,'level'+str(current))
report={'result':'PASS','levels':6,'frames':len(fixtures),'scalarChecks':checks,'tolerance':1e-9,
        'source':'frozen RewindLevels.unfold/applyRoom, real Three.js transforms',
        'notCovered':['GPU appearance','rain','world/sky','postprocessing','chapter1 presentation']}
(ROOT/'docs/migration/echo-pose-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
