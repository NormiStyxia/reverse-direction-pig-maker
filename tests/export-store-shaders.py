"""Generate explicit transparent variants; keep cutout materials in opaque queue."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets/Shaders/BLGL'
for kind in ['Lit','Unlit']:
    source=(root/('Store'+kind+'.shader')).read_text()
    cutout=source.replace('// BLEND_ALPHA_INSERT','ALPHA=alpha; ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;')
    (root/('Store'+kind+'Cutout.shader')).write_text('// Generated from Store'+kind+'.shader; explicit cutout auxiliary passes.\n'+cutout)
    for suffix,mode in [('Blend','blend_mix'),('Add','blend_add')]:
        text=source.replace('cull_back;', 'cull_back, '+mode+', depth_draw_never;')
        text=text.replace('// BLEND_ALPHA_INSERT','ALPHA=alpha;')
        # UrhoX blend_add uses ONE,ONE; Three AdditiveBlending uses SRC_ALPHA,ONE.
        if suffix=='Add':text=text.replace('ALBEDO=c;','ALBEDO=c*alpha;')
        (root/('Store'+kind+suffix+'.shader')).write_text('// Generated from Store'+kind+'.shader.\n'+text)
