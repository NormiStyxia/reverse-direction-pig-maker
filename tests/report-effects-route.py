"""Verify archived current-pipeline native route evidence, not model-only completion."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1];out=root/'validation/effects/full-route'
observed=json.loads((out/'observed-route.json').read_text())
rows=[json.loads(line) for line in (out/'runtime-lua.log').read_text().splitlines()]
messages=[r.get('m','') for r in rows]
stages=[m.split('FULL_ROUTE_STAGE: ')[1].strip() for m in messages if 'FULL_ROUTE_STAGE:' in m]
exits=[int(re.search(r'level=([0-9]+)',m)[1]) for m in messages if 'ECHO_FLOW: exitReached' in m]
assert stages==['store','echo-store','meeting','echo-meeting','morning'],stages
assert exits==[1,2,3,4,5,6,1,2,3,4,5],exits
assert any('FULL_ROUTE: PASS;' in m and 'answer=done' in m for m in messages)
for theme,frames in [('store',6452),('meeting',5692)]:
 assert any(f'ECHO_NATIVE_ROUTE: PASS; theme={theme}; {frames} frames' in m for m in messages)
assert not any('stack traceback' in m or 'LUA ERROR' in m for m in messages)
official=json.loads((out/'official-check.json').read_text())
report={'sessionId':observed['sessionId'],'reloadId':observed['reloadId'],'runtimePid':observed['runtimePid'],
 'nativeRoute':'PASS','answer':'done','stageOrder':stages,'exitLevels':exits,'sourceVerifiedInputFrames':[6452,5692],
 'pipeline':'consumer-first owned color/depth, ink/DOF, bloom/frost, blue/present mask, dust/near composite, event flash/shake',
 'save':'same-process isolated file readback; not restart persistence','officialCheck':official.get('result'),
 'runtimeErrors':official.get('errors',[]),'visualAcceptance':False,'similarityPercentage':None,
 'notCovered':['native same/late answers','optional interactions','all-scene source pixel parity','full resolution/touch route','cross-restart persistence','audio and remaining particles']}
(root/'docs/migration/effects-full-route-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
