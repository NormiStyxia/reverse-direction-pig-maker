"""Import exact five-room geometry for each of the three story answers."""
import importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('scene_import',Path(__file__).with_name('import-store.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for answer in ['same','late','done']:
    for level in range(1,6):
        m.import_scene(m.ROOT/f'validation/ch1-echo/source-{answer}-{level}.json',f'Ch1Echo{answer}{level}','ch1-echo',f'Ch1Echo{answer}{level}',f'ch1-echo-{answer}-{level}-export-report')
