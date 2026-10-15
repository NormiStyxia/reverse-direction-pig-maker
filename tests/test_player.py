"""Player/pose/ghost differential against frozen Pig using real Three.js vectors."""
import json,math,random,subprocess
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
Pig=lua.execute((ROOT/'scripts/game/PigController.lua').read_text());p=Pig.new()
rng=random.Random(16016);ops=[]
for i in range(1800):
    ops.append({'dt':rng.choice([1/60,1/30,.05,.007]),'input':{'x':rng.choice([-1,0,1,.25]),'y':rng.choice([-1,0,1,.75]),'spin':i%120>40},
        'yaw':rng.choice([0,.2,1.3,-2.1,math.pi/2]),'enabled':i%190<160,'charge':i%31==0,'nudge':i%137==0,
        'spinDir':-1 if i>800 else 1,'spinFrame':.05 if i>800 else 0,'random':rng.random()})
expected=json.loads(subprocess.check_output(['node','tests/pig-oracle.mjs'],input=json.dumps(ops).encode(),cwd=ROOT))
def vec(v):return {k:v[k] for k in ('x','y','z')}
def compare(a,b,path):
    if isinstance(a,dict):
        assert a.keys()==b.keys(),(path,a.keys(),b.keys())
        for k in a:compare(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        assert len(a)==len(b),path
        for i,(x,y) in enumerate(zip(a,b)):compare(x,y,path+f'/{i}')
    elif isinstance(a,(int,float)) and not isinstance(a,bool):assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-8),(path,a,b)
    else: assert a==b,(path,a,b)
for i,(op,want) in enumerate(zip(ops,expected)):
    if op['charge']:p.tryCharge(p)
    if op['nudge']:p.nudge(p)
    p.spinDir=op['spinDir'];p.spinFrame=op['spinFrame']
    p.update(p,op['dt'],lua.table_from(op['input']),op['yaw'],op['enabled'])
    p.updateGhosts(p,op['dt'],op['yaw'],lambda:op['random'])
    got={k:p[k] for k in ('facing','frame','charge','cooldown','ghostTimer','spinning','spinT','spinSpeed','stop','squash','bob','ghostIndex')}
    got.update({k:vec(p[k]) for k in ('pos','vel','dir','chargeDir')})
    got['pose']={'position':vec(p.pose.position),'yaw':p.pose.yaw,'roll':p.pose.roll,'scale':vec(p.pose.scale)}
    ghosts=[]
    for g in p.ghosts.values():
        d={'life':g.life,'visible':g.visible}
        if g.max is not None:d.update(max=g.max,opacity=g.opacity,position=vec(g.position),yaw=g.yaw,roll=g.roll,scale=vec(g.scale))
        ghosts.append(d)
    got['ghosts']=ghosts
    compare(got,want,str(i))
report={'result':'PASS','differentialFrames':len(ops),'source':'frozen src/pig.js with actual Three.js vector math',
        'covers':['camera-relative movement','diagonal normalization','charge and cooldown','input-disabled deceleration',
                  'reverse spin and eight-way frames','squash and walking pose','ghost spawn/lifetime/pose'],
        'notCovered':['engine rendering','device input','full playthrough']}
(ROOT/'docs/migration/player-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
