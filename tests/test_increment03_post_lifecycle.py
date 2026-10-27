"""Compare native lifecycle to settings collected from the frozen main.js in Chrome."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
m=lua.eval("require('game.PostSettings')")[0];s=m.new()
fixtures=json.loads((root/'validation/increment03/post-lifecycle/h5-settings.json').read_text())
names={'2312':'night','2338':'store','1447':'meeting','0958':'morning','0815':'dorm'}
checks=0
for row in fixtures:
    kind=row['kind'];mode='echo'if kind.startswith('echo')else names.get(kind,kind)
    actual=dict(s.enter(s,mode))
    assert actual==row['settings'],(kind,actual,row['settings']);checks+=len(actual)
# Browser home reload vs landed ending (same JS Post object, cadence is retained).
s.reset(s,True);assert s['values'].wobbleFps==4 and s['values'].paper
s.reset(s);assert s['values'].wobbleFps==8 and s['values'].bloomStrength==1
report=dict(result='PASS',source='Chrome running frozen main.js; actual Post.settings after node transitions',snapshots=len(fixtures),checks=checks,coverage='parameter lifecycle, not image similarity')
(root/'docs/migration/increment03-post-lifecycle-test.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
