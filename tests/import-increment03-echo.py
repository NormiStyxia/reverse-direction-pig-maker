"""Import current frozen geometry; keep legacy exports for historical diagnostics."""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('scene_import',Path(__file__).with_name('import-store.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for theme,answers,count in [('store',['same'],6),('meeting',['same','late','done'],5),('office',['fix','wreck','leave'],4),('dorm',['sick','pc','off'],4)]:
    for answer in answers:
        for level in range(1,count+1):
            path=m.ROOT/f'validation/increment03/echo/source-{theme}-{answer}-{level}.json'
            data=json.loads(path.read_text());data['sourceCommit']='552a6eb4a73b6be5f33ea1a7b6a17411c216eae5'
            path.write_text(json.dumps(data,ensure_ascii=False))
            name=f'Echo03{theme}{answer}{level}'
            m.import_scene(path,name,'increment03/echo',name,f'increment03-{theme}-{answer}-{level}',m.ROOT/'reference/increment03/h5-source')
