"""Compare actual Lua sampler configuration to every frozen scene texture."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
files = [ROOT / 'validation/store/source-scene.json']
files += [ROOT / f'validation/echo/source-level-{i}.json' for i in range(1, 7)]
files += [ROOT / f'validation/chapter1/source-{mode}.json' for mode in ['meeting', 'morning']]
files += [ROOT / f'validation/ch1-echo/source-{answer}-{i}.json'
          for answer in ['same', 'late', 'done'] for i in range(1, 6)]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path=' + json.dumps(str(ROOT / 'scripts/?.lua'), ensure_ascii=False) + '..";"..package.path')
lua.execute('ADDRESS_WRAP=0;ADDRESS_MIRROR=1;ADDRESS_CLAMP=2;COORD_U=0;COORD_V=1;FILTER_NEAREST=0;FILTER_TRILINEAR=2')
renderer = lua.eval("require('render.StoreRenderer')")[0]
mock = lua.eval('function() return {address={}, SetAddressMode=function(self,axis,mode) self.address[axis]=mode end} end')
checked = 0
for file in files:
    data = json.loads(file.read_text())
    for source in data['textures']:
        texture = mock()
        renderer.configureTexture(texture, lua.table_from(source))
        assert texture.address[0] == {1000: 0, 1001: 2, 1002: 1}[source['wrapS']]
        assert texture.address[1] == {1000: 0, 1001: 2, 1002: 1}[source['wrapT']]
        expected = {(1008, 1006): 2, (1003, 1003): 0}[(source['minFilter'], source['magFilter'])]
        assert texture.filterMode == expected, (str(file), source['id'])
        assert texture.sRGB is False  # Existing shaders perform one source-color decode.
        checked += 1
report = {'result': 'PASS', 'scenes': len(files), 'textures': checked,
          'checks': ['actual Lua configuration versus frozen min/mag filter',
                     'repeat, mirrored repeat and clamp on both axes', 'no double sRGB decode'],
          'notCovered': ['GPU mip generation and interpolation color space', 'visual similarity']}
(ROOT / 'docs/migration/texture-sampling-test-report.json').write_text(json.dumps(report, indent=2) + chr(10))
print(json.dumps(report, indent=2))
