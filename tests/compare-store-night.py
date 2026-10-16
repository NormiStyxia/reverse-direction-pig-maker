"""Regional raw-scene comparison; never reports whole-game visual acceptance."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'validation/store'
names = ['h5-shadow-both', 'native-bias-baseline', 'native-night-halos']
images = [Image.open(FOLDER / (name + '.png')).convert('RGB') for name in names]
assert all(im.size == (1920, 1080) for im in images)
arrays = [np.array(im).astype(float) for im in images]
regions = {
    'outside_road': [756, 418, 910, 434],
    'outside_right_road': [1000, 419, 1160, 432],
    'lamp_halo': [690, 215, 750, 270],
    'interior_floor_control': [600, 900, 1200, 1000],
    'right_wall_control': [1720, 180, 1850, 420],
}
metadata = json.loads((FOLDER / 'native-night-halos.json').read_text())
report = {
    'source': 'Frozen StoreChapter; linear HDR target then source FINAL ACES/sRGB, without full post',
    'candidate': {k: metadata[k] for k in ['sessionId', 'reloadId', 'runtimePid']},
    'images': names, 'visualAccepted': False, 'wholeGameSimilarity': None, 'regions': {},
    'limitations': ['Raw-scene regional evidence only.',
                    'Shadow offset/filter, texture filtering and full post still differ.'],
}
for name, rect in regions.items():
    x, y, r, b = rect
    source, old, new = [a[y:b, x:r] for a in arrays]
    changed = int((np.max(np.abs(old - new), 2) > 0).sum())
    report['regions'][name] = {
        'rect': rect, 'beforeMAE255': float(np.abs(source - old).mean()),
        'afterMAE255': float(np.abs(source - new).mean()), 'changedPixels': changed,
    }
    if name.endswith('_control'):
        assert changed == 0, (name, 'Unrelated interior shading changed')
sheet = Image.new('RGB', (480 * 3, 300), (24, 24, 24))
draw = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(zip(names, images)):
    draw.text((480 * i + 4, 5), name, fill='white')
    sheet.paste(im.crop((630, 190, 1110, 460)), (480 * i, 25))
sheet.save(FOLDER / 'night-regions.png')
(ROOT / 'docs/migration/store-night-comparison.json').write_text(json.dumps(report, indent=2) + chr(10))
print(json.dumps(report, indent=2))
