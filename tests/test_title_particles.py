import json,math,subprocess,struct
from pathlib import Path
from lupa.lua54 import LuaRuntime
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
P=lua.execute((ROOT/'scripts/game/TitleParticles.lua').read_text())
w,h=Image.open(ROOT/'assets/title/pig.png').size
ops=[dict(world=-200+i*.731,t=i*.031,pigA=.35+i*.013,pigSpin=0 if i%5==0 else -i*.177,pigSpinV=0 if i%5==0 else -3,aspect=w/h) for i in range(600)]
expected=json.loads(subprocess.check_output(['node','tests/title-particles-oracle.mjs'],input=json.dumps(ops).encode(),cwd=ROOT))
largest=0
for i,(op,want) in enumerate(zip(ops,expected)):
    quads=list(P.build(op['world']).values())+[P.pig(lua.table_from(op),op['aspect'])]
    got=[]
    for q in quads:
        for index in [1,2,3,1,3,4]:
            v=q.vertices[index]
            got += [v[1],v[2],v[3],v[4],q.alpha,q.depth,q.occlude]
    assert len(got)==len(want)
    for j,(a,b) in enumerate(zip(got,want)):
        # H5 uploads Float32Array; compare after the same quantization.
        a=struct.unpack('f',struct.pack('f',a))[0]
        largest=max(largest,abs(a-b))
        assert math.isclose(a,b,abs_tol=3e-7,rel_tol=1e-6),(i,j,a,b)
report={'result':'PASS','frames':len(ops),'quadsPerFrame':11,'vertexComponentsCompared':len(ops)*11*6*7,'maxFloat32Difference':largest,'source':'frozen particle/quad/pig builders executed verbatim','notCovered':['texture filtering','alpha blending','GPU rendering']}
(ROOT/'docs/migration/title-particles-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
