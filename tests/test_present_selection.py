"""Compare native mask membership with actual frozen Three object layer flags."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
expected=json.loads((root/'validation/blue/present-source.json').read_text())
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
rows=[]
for row in expected:
    name=('Ch1Echo'+row['answer'] if row['theme']=='meeting' else 'EchoScene')+str(row['index']+1)
    data=lua.eval("require('game.data."+name+"')")[0]
    actual=list(lua.eval("require('render.PresentSelection').ids")(data).values())
    assert actual==row['ids'],(name,actual,row['ids'])
    rows.append({'scene':name,'markedGeometry':len(actual)})
report={'result':'PASS','scenes':rows,'scope':'source layer membership including hologram cutout exclusions and dormant merged crate; GPU occlusion checked separately'}
(root/'docs/migration/present-selection-test-report.json').write_text(json.dumps(report,indent=2)+chr(10));print(json.dumps(report))
