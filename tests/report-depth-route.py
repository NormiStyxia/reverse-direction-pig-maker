"""Verify the native full route after owned-depth post-processing was enabled.

Uses archived native evidence; does not launch a runtime or modify game state.
"""
import json,re
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'validation/depth-full-route'
observed=json.loads((OUT/'observed-route.json').read_text())
rows=[json.loads(line) for line in (OUT/'runtime-lua-19.log').read_text().splitlines()]
messages=[r.get('m','') for r in rows]
stages=[m.split('FULL_ROUTE_STAGE: ')[1].strip() for m in messages if 'FULL_ROUTE_STAGE:' in m]
exits=[int(re.search(r'level=(\d+)',m)[1]) for m in messages if 'ECHO_FLOW: exitReached' in m]
assert stages==['store','echo-store','meeting','echo-meeting','morning'],stages
assert exits==[1,2,3,4,5,6,1,2,3,4,5],exits
assert any('FULL_ROUTE: PASS;' in m and 'answer=done' in m for m in messages)
for theme,frames in [('store',6452),('meeting',5692)]:
    assert any(f'ECHO_NATIVE_ROUTE: PASS; theme={theme}; {frames} frames' in m for m in messages)
assert any('CHAPTER_REPLAY: disposed chapter state, returned to fresh title' in m for m in messages)
assert not any('stack traceback' in m or 'LUA ERROR' in m for m in messages)
sizes=[]
for size in ['1280x720','900x1000','1920x1080']:
    receipt=json.loads((OUT/f'resize-{size}.json').read_text())
    assert receipt['pid']==observed['runtimePid'] and receipt['reload']==observed['reloadId']
    assert Image.open(OUT/f'resize-{size}.png').size==tuple(receipt['graphicsDimensions'])
    w,h=receipt['graphicsDimensions'];sizes.append([w,h])
    assert any(f'SCENE_POST_TARGETS: {w}.0x{h}.0' in m for m in messages)
official=json.loads((OUT/'official-check.json').read_text())
errors=official.get('errors',[])
report={
    'date':'2026-10-16','sessionId':observed['sessionId'],'reloadId':observed['reloadId'],
    'runtimePid':observed['runtimePid'],'nativeRoute':'PASS','answer':'done',
    'stageOrder':stages,'exitLevels':exits,'sourceVerifiedInputFrames':[6452,5692],
    'post':'owned scene color/depth, separate stylize and 32-tap DOF enabled',
    'pipelineOrder':'route ran before consumer-first target registration fix; later native scene-switch regression is separate',
    'resizeAtEnding':sizes,'mouseReplayToTitle':'PASS; native pointer down/up then CHAPTER_REPLAY',
    'resourceLifetime':'no crash across 11 exits, chapter changes, resize, and replay',
    'save':'same-process isolated file readback; NOT restart persistence',
    'officialCheck':official.get('verdict',official.get('status','FAIL' if errors else 'UNDETERMINED')),
    'runtimeErrors':errors,'visualAcceptance':False,'similarityPercentage':None,
    'notCovered':['other answer branches','optional interactions','all-scene dynamic pixel parity',
                  'full resolution/touch playthrough','cross-restart persistence','audio completeness']}
(ROOT/'docs/migration/owned-depth-route-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
