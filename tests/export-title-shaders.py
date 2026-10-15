"""Mechanical frozen GLSL -> SurfaceShader port; never ships a JS runtime."""
import re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'reference/h5-source/src/title-screen.js').read_text()
def template(name):
    return re.search(r'const '+name+r' = ' + chr(96) + r'(.*?)' + chr(96) + ';',source,re.S)[1]
common=template('COMMON').replace('precision highp float;','')
def uniforms(code):
    return re.sub(r'uniform (float|vec2|sampler2D) ([^;]+);',lambda m:'\n'.join('uniform '+m[1]+' '+s.strip()+(' : filter_linear_mipmap, repeat_disable' if m[1]=='sampler2D' else '')+';' for s in m[2].split(',')),code)
header='// Ported from frozen title-screen.js; all authored noise/transition formulas retained.\nshader_type spatial;\n'
plate=template('FS_PLATE').replace('#version 300 es','').replace('$'+'{COMMON}',common)
plate=plate.replace('in vec2 vUv; out vec4 o;','').replace('vUv','UV')
plate=plate.replace('void main()', 'void fragment()').replace('o = vec4(col, 1.);','ALBEDO = col;')
plate=header+'render_mode shading_model_unlit, cull_disabled, fog_disabled;\n'+uniforms(plate)
sprite=template('FS_SPR').replace('#version 300 es','').replace('$'+'{COMMON}',common)
sprite=sprite.replace('in vec2 vWorld, vTex; in vec3 vMeta; out vec4 o;', '''uniform vec3 uMeta;
uniform float uZoom;
uniform vec2 uPar;
uniform vec2 uCam;''')
sprite=sprite.replace('void main() {', '''void fragment() {
  vec2 off = uPar * vec2(-.004, -.003) + uPar * vec2(-.007, -.005) * uMeta.y;
  vec2 screen = vec2(VERTEX.x / uAspect, -VERTEX.y) * .5 + .5;
  if (screen.x < 0. || screen.x > 1. || screen.y < 0. || screen.y > 1.) discard;
  vec2 vWorld = (screen - .5) / uZoom + uCam + off;''')
sprite=sprite.replace('vTex','UV').replace('vMeta','uMeta')
# Derivatives reproduce WebGL premultiplied upload. blend_mix wants straight output.
sprite=sprite.replace('o = vec4(col * a, a);','ALBEDO = col;\n  ALPHA = a;')
sprite=header+'render_mode shading_model_unlit, blend_mix, cull_disabled, fog_disabled, depth_draw_never;\n'+uniforms(sprite)
out=ROOT/'assets/Shaders/BLGL';out.mkdir(parents=True,exist_ok=True)
for name,body in [('TitlePlate',plate),('TitleSprite',sprite)]: (out/(name+'.shader')).write_text(body+'\n')
materials=ROOT/'assets/Materials';materials.mkdir(parents=True,exist_ok=True)
for name,shader,textures,order in [('TitlePlate','TitlePlate',{'uFlat':'plate_flat.jpg','uSketch':'plate_sketch.jpg','uFx':'fx.png'},0),('TitleParticles','TitleSprite',{'uTex':'sprites-premult.png','uFx':'fx.png'},1),('TitlePig','TitleSprite',{'uTex':'pig-premult.png','uFx':'fx.png'},2)]:
    xml=['<material>',f'  <surfaceshader name="Shaders/BLGL/{shader}.shader" />']
    xml += [f'  <surfacetexture name="{key}" texture="title/{val}" />' for key,val in textures.items()]
    xml += [f'  <renderorder value="{order}" />','</material>']
    (materials/(name+'.xml')).write_text('\n'.join(xml)+'\n')
for name in ['sprites','pig']:
    image=Image.open(ROOT/f'assets/title/{name}.png').convert('RGBA')
    image.putdata([(round(r*a/255),round(g*a/255),round(b*a/255),a) for r,g,b,a in image.getdata()])
    image.save(ROOT/f'assets/title/{name}-premult.png')
print('Exported 2 SurfaceShaders, 3 materials, 2 premultiplied texture derivatives; originals unchanged.')
