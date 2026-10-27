"""Differential check against the frozen store.update executed in isolated Chrome."""
import json,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
fixture=json.loads(Path('validation/increment03/chapter1/walker-fixtures.json').read_text())
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Walker=lua.eval("require('game.StoreWalker')")[0];Dynamics=lua.eval("require('game.StoreDynamics')")[0]
callbacks=[];w=Walker.new(lambda w,i:callbacks.append(i));d=Dynamics.new(lambda:.37);checks=0
for index,f in enumerate(fixture['frames']):
 state=lua.table_from({'pos':lua.table_from([0,0,0]),'walkers':lua.table_from([w])})
 d.update(d,f['dt'],state);w.update(w,f['dt'],f['yaw'])
 actual={'p':[w.pos[i]for i in range(1,4)],'head':[w.head[k]for k in ['x','y','z']],
         'q':[w.quaternion[i]for i in range(1,5)],'scale':[w.scale,1,1],'door':d.door.open,
         **{k:w[k]for k in ['side','flip','walkPhase','sway','wait','done','castShadow']},'i':w.i-1}
 for k,v in actual.items():
  want=f[k]
  for a,b in zip(v if isinstance(v,list)else [v],want if isinstance(want,list)else [want]):
   assert math.isclose(a,b,rel_tol=1e-9,abs_tol=1e-9),(index,k,a,b);checks+=1
assert w.done and callbacks==fixture['callbacks']==list(range(11))
# Verify dynamic narrative callbacks retain the moving head reference.
s=lua.eval("require('game.PrologueState')")[0].new();s.drainEvents(s)
s.riderStep(s,5,w.head);events=s.drainEvents(s)
assert any(e.kind=='caption' and e.speaker.x==w.head.x for e in events.values())
report={'result':'PASS','frames':len(fixture['frames']),'checks':checks,'callbacks':callbacks,
 'scope':'Frozen source rider path, waits, head anchor, billboard quaternion, facing, sway, shadow cutoff, automatic door and narrative callback. GPU validation separate.'}
Path('docs/migration/increment03-walkers-test.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
