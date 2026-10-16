"""Differential presentation checks for all five chapter echo rooms and four mergers."""
import json,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Run=lua.eval("require('game.EchoRun')")[0];Pose=lua.eval("require('game.EchoPose')")[0]
levels=lua.eval("require('game.data.Levels')")[0]
run=Run.new(levels.chapter1,'meeting');pose=Pose.new();current=checks=merges=0
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
fixtures=json.loads((ROOT/'validation/ch1-echo/source-pose.json').read_text())
for f in fixtures:
    if f['level']!=current:
        current=f['level'];run.load(run,current);pose=Pose.new()
    i=f['input'];S=run.sim;R=S.room;run.t=i['t'];S.t=i['t'];run.fold=i['fold'];S.rewinding=i['rewinding'];R.doorOpen=i['doorOpen']
    if i['merge']:
        a,b=i['merge'];S.merge(S,R.crates[a],R.crates[b]);merges+=1
        for e in S.drainEvents(S).values():
            if e.kind=='merge':pose.merge(pose,e.data,run.t)
    for j,pressed in enumerate(i['pressed'],1):R.plates[j].pressed=pressed
    pose.update(pose,run,i['dt']);compare(f['out'],pose,'level'+str(current))
result={'result':'PASS','frames':len(fixtures),'scalarChecks':checks,'merges':merges,'levels':5,'tolerance':1e-9,
        'scope':'Frozen source merge/applyRoom: shrink, disappear, now-crate spawn, hologram plate alpha, curtain scale/alpha/UV',
        'notCovered':['GPU blend/light/shadows','full player route','95% visual acceptance']}
(ROOT/'docs/migration/ch1-echo-pose-test-report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
