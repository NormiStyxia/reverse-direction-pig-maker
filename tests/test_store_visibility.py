"""Check native visibility against Three ancestor visibility on the frozen scene."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/'validation/store/source-scene.json').read_text())
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path='+json.dumps(str(ROOT/'scripts/?.lua'),ensure_ascii=False)+'..";"..package.path')
renderer=lua.eval('require("render.StoreRenderer")')[0]
view=lua.table(nodes=lua.table(),children=lua.table(),visible=lua.table(),sourceDrawables=lua.table())
view.children[0]=lua.table()
own={0:True}
for n in source['nodes']:
    ident=n['id'];own[ident]=n['visible']
    view.nodes[ident]=lua.table(enabled=n['visible'])
    view.children[ident]=lua.table();view.visible[ident]=n['visible']
    children=view.children[n['parent']];children[len(children)+1]=ident
    if n['type'] in ['Mesh','Sprite','LineSegments']:
        view.sourceDrawables[ident]=lua.table_from([lua.table(enabled=n['visible']) for _ in range(len(n.get('instances',[1])))])
archive=source['handles']['archive']
parent=source['nodes'][archive-1]['parent']
child=next(n['id'] for n in source['nodes'] if n['parent']==archive)
operations=[(0,True),(archive,True),(archive,False),(archive,True),
            (parent,False),(archive,False),(archive,True),(parent,True),
            (child,False),(archive,False),(archive,True),(child,True),(archive,False)]
halo=next(n for n in source['nodes'] if n['type']=='Sprite')
operations += [(halo['parent'],False),(halo['id'],False),(halo['id'],True),(halo['parent'],True),(0,False),(0,True)]
checks=0;drawable_checks=0
for ident,enabled in operations:
    own[ident]=enabled;renderer.setSourceVisible(view,ident,enabled)
    for n in source['nodes']:
        cursor=n['id'];expected=own[0]
        while cursor:
            expected=expected and own[cursor]
            cursor=source['nodes'][cursor-1]['parent']
        actual=view.nodes[n['id']].enabled
        assert actual==expected,(ident,enabled,n['id'],actual,expected)
        checks+=1
        for drawable in (view.sourceDrawables[n['id']] or lua.table()).values():
            assert drawable.enabled==expected,(ident,n['id'],'native product drawable')
            drawable_checks+=1
report={'result':'PASS','transitions':len(operations),'nodeVisibilityChecks':checks,'drawableVisibilityChecks':drawable_checks,
        'cases':['archive initially hidden','archive revealed/hidden','hidden ancestor',
                 'revealing child under hidden parent','child visibility survives parent toggle',
                 'lamp halo respects hidden parent and whole-scene visibility'],
        'scope':'Three ancestor visibility semantics; native GPU captured separately'}
(ROOT/'docs/migration/store-visibility-test-report.json').write_text(json.dumps(report,indent=2)+chr(10))
print(json.dumps(report,indent=2))
