"""Fixed-camera regional evidence, not a whole-game similarity score."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'validation/store'
names = ['h5-shadow-both', 'native-halo-packed', 'native-hedge-mipmap', 'native-source-sampling']
images = [Image.open(FOLDER / (n + '.png')).convert('RGB') for n in names]
assert all(im.size == (1920, 1080) for im in images)
regions = {
    'hedge': (470, 437, 1140, 507),
    'canopy': (790, 393, 1150, 413),
    'character': (1360, 415, 1435, 653),
    'floor': (600, 900, 1200, 1000),
    'right_wall': (1720, 180, 1850, 420),
    'lamp_halo': (690, 215, 750, 270),
    'left_wall_shadow': (0, 145, 210, 740),
    'leaf_floor_shadow': (585, 740, 815, 860),
    'leaf_back_shadow': (235, 145, 435, 375),
    'table_shadow': (680, 520, 820, 565),
}
report = {
    'source': 'Frozen StoreChapter raw HDR scene, source ACES/sRGB, no full post',
    'images': names,
    'candidate': json.loads((FOLDER / (names[-1] + '.json')).read_text()),
    'visualAccepted': False, 'wholeGameSimilarity': None, 'regions': {},
    'limitations': [
        'Regional raw-scene comparison only; no aggregate score.',
        'Left wall occlusion and shadow projection/filter still differ.',
        'Native mip generation and sRGB filtering need further source calibration.',
        'Full post, audio, adaptation and remaining playthrough acceptance pending.',
    ],
}
for name, rect in regions.items():
    arrays = [np.array(im.crop(rect)).astype(float) for im in images]
    report['regions'][name] = {'rect': rect, 'MAE255': {
        n: float(np.abs(arrays[0] - a).mean()) for n, a in zip(names[1:], arrays[1:])
    }}
broken = Image.open(FOLDER / 'native-night-halos.png').convert('RGB')
rect = regions['lamp_halo']
ref = np.array(images[0].crop(rect)).astype(float)
report['spriteGeometryCorrection'] = {
    'beforeMAE255': float(np.abs(ref - np.array(broken.crop(rect))).mean()),
    'afterMAE255': report['regions']['lamp_halo']['MAE255']['native-halo-packed'],
    'note': 'Before subsequent sampler changes; isolated corrected quad evidence.',
}
sheet = Image.new('RGB', (730, 155 * len(images)), (24, 24, 24))
draw = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate(zip(names, images)):
    draw.text((5, i * 155 + 3), name, fill='white')
    sheet.paste(im.crop((460, 380, 1190, 515)), (0, i * 155 + 20))
sheet.save(FOLDER / 'source-sampling-stages.png')
(ROOT / 'docs/migration/store-sampling-comparison.json').write_text(json.dumps(report, indent=2) + chr(10))
for name, result in report['regions'].items():
    values = result['MAE255']
    print(f'{name}: {values[names[1]]:.3f} -> {values[names[-1]]:.3f} / 255')
