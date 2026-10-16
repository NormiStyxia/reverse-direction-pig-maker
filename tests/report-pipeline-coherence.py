"""Compare N-update native pipeline captures, rejecting mixed DPI/size runs."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'validation/pipeline-coherence/ordered-stable'
receipt=json.loads((OUT/'receipt.json').read_text())
samples=receipt['samples']
sizes={tuple(v['captureSize']) for v in samples.values()}
assert len(sizes)==1,('Mixed viewport sizes invalidate the comparison',sizes)
files={int(name.rsplit('_',1)[1]):name for name in samples}
assert set(files)=={1,2,3,4,8,16},files
reference=np.asarray(Image.open(OUT/(files[16]+'.png')).convert('RGB')).astype('int16')
assert reference.std()>10,'Blank output is not acceptance evidence'
comparisons=[]
for count in [1,2,3,4,8]:
    frame=np.asarray(Image.open(OUT/(files[count]+'.png')).convert('RGB')).astype('int16')
    assert frame.shape==reference.shape
    delta=np.abs(frame-reference)
    comparisons.append({'queuedUpdates':count,'referenceUpdates':16,
                        'changedPixels':int(np.any(delta,axis=2).sum()),
                        'mae':float(delta.mean()),'max':int(delta.max())})
report={
    'date':'2026-10-16','sessionId':receipt['sessionId'],'reloadId':receipt['reloadId'],
    'runtimePid':receipt['runtimePid'],'dimensions':list(sizes.pop()),
    'result':'PASS' if all(r['changedPixels']==0 for r in comparisons) else 'FAIL',
    'comparisons':comparisons,
    'scope':'camera and actor jump A to B; 16 warm renders of A before each sample; N manually queued offscreen updates of B; targets held for OS capture',
    'beforeFix':'native 1920x1080 sample 2 still showed A, sample 3 showed B; mixed later sizes excluded',
    'change':'register offscreen consumers before producers, so reverse view execution consumes current-frame results',
    'notCovered':['input-to-display latency','all-scene motion quality','H5/native similarity','95% full-game acceptance']}
(OUT/'metrics.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
(ROOT/'docs/migration/pipeline-coherence-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(0 if report['result']=='PASS' else 1)
