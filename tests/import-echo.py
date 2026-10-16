"""Import all six frozen prologue echo rooms; share content-addressed textures."""
import importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('scene_import',Path(__file__).with_name('import-store.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for level in range(1,7):
    m.import_scene(m.ROOT/f'validation/echo/source-level-{level}.json',f'Echo{level}','echo',f'EchoScene{level}',f'echo-{level}-export-report')
