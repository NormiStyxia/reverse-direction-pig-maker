import importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('scene_import',Path(__file__).with_name('import-store.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for mode in ['meeting','morning']:
    name='Chapter1'+mode.title()
    m.import_scene(m.ROOT/f'validation/chapter1/source-{mode}.json',name,'ch1',name+'Scene',f'chapter1-{mode}-export-report')
