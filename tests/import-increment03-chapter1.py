"""Increment 03 native scene export. Historical scene exports stay intact."""
import importlib.util,json
from pathlib import Path
spec=importlib.util.spec_from_file_location('scene_import',Path(__file__).with_name('import-store.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for mode in __import__('sys').argv[1:] or ['meeting','morning','dorm']:
    name='Chapter03'+mode.title()
    path=m.ROOT/f'validation/increment03/chapter1/source-{mode}.json'
    data=json.loads(path.read_text());data['sourceCommit']='552a6eb4a73b6be5f33ea1a7b6a17411c216eae5';path.write_text(json.dumps(data,ensure_ascii=False))
    m.import_scene(path,name,'increment03/chapter1',name+'Scene',f'increment03-{mode}',m.ROOT/'reference/increment03/h5-source')
