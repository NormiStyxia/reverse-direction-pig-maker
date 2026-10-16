"""Export snapshots produced by the native story model for frozen DOM UI comparison."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True);lua.execute("package.path='scripts/?.lua;'..package.path")
Fixtures=lua.eval("require('preview.PanelFixtures')")[0]
def value(v):
    if hasattr(v,'items'):
        items=list(v.items())
        if not items or all(isinstance(k,int) for k,_ in items):return [value(v[i]) for i in range(1,len(v)+1)]
        return {k:value(x) for k,x in items}
    return v
out=[]
for i in range(1,len(Fixtures.names)+1):
    story=Fixtures.make(i)
    out.append({'name':Fixtures.names[i],'phone':value(story.phone),'browse':{k:value(story.browse[k]) for k in ['open','entries','choices','title','sub','closeLabel','clock']}})
p=Path('validation/panels');p.mkdir(parents=True,exist_ok=True)
(p/'fixtures.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(f'Exported {len(out)} actual story snapshots for DOM/NVG panel comparison')
