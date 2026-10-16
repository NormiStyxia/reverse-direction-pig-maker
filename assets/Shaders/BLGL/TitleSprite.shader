// Ported from frozen title-screen.js; all authored noise/transition formulas retained.
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, fog_disabled, depth_draw_never;

float titleAtan2(float y, float x) {
  if (x == 0.) return y == 0. ? 0. : (y > 0. ? 1.5707963267948966 : -1.5707963267948966);
  float a = atan(y / x);
  return x < 0. ? a + (y < 0. ? -3.141592653589793 : 3.141592653589793) : a;
}


uniform float uTime;
uniform float uWorld;
uniform float uProg;
uniform float uAspect;
uniform vec2 uC;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0., a = .5; for (int i = 0; i < 5; i++) { s += a * noise(p); p = p * 2.03 + 17.1; a *= .5; } return s; }
// 转场场：以表盘圆心为原点，从 0°(正上)逆时针扫一圈 —— 和原画的刻度方向一致(270° 在右)
float field(vec2 uv) {
  vec2 d = (uv - uC) * vec2(uAspect, 1.);
  float n = fract(titleAtan2(-d.x, -d.y) / 6.2831853 + 1.);
  float smoke = fbm(uv * vec2(uAspect, 1.) * 3. + vec2(uWorld * .04, 0.));
  return n * .72 + length(d) * .16 + (smoke - .5) * .34;
}
float stateMix(float f) { return smoothstep(f - .09, f + .09, uProg * 1.36 - .18); }
// 反色版(look=invert)扰动后切到的那一态：原稿亮度反过来，再落回插画的几种蓝 —— 白纸变钴蓝底，蓝色块变浅，角色的深色线条变白
// (按住 K 和开场照样是铅笔稿；uInvert 只在自动切过去的那几秒是 1)
uniform float uInvert;
float lum(vec3 c) { return dot(c, vec3(.3, .59, .11)); }
vec3 invertMap(float x) {
  vec3 c0 = vec3(.004, .25, .77), c1 = vec3(.16, .39, .88), c2 = vec3(.43, .61, .94), c3 = vec3(.8, .86, .98), c4 = vec3(.99, .995, 1.);
  return x < .4 ? mix(c0, c1, x / .4) : x < .62 ? mix(c1, c2, (x - .4) / .22) : x < .8 ? mix(c2, c3, (x - .62) / .18) : mix(c3, c4, (x - .8) / .2);
}
vec3 invertBlue(vec3 c) { return invertMap(smoothstep(.04, .86, 1. - lum(c))); }

uniform vec3 uMeta;
uniform float uZoom;
uniform vec2 uPar;
uniform vec2 uCam;
uniform sampler2D uTex : filter_linear_mipmap, repeat_disable;
uniform sampler2D uFx : filter_linear_mipmap, repeat_disable;
uniform float uWash;
uniform float uShow;
void fragment() {
  vec2 off = uPar * vec2(-.004, -.003) + uPar * vec2(-.007, -.005) * uMeta.y;
  vec2 screen = vec2(VERTEX.x / uAspect, -VERTEX.y) * .5 + .5;
  if (screen.x < 0. || screen.x > 1. || screen.y < 0. || screen.y > 1.) discard;
  vec2 vWorld = (screen - .5) / uZoom + uCam + off;
  vec4 c = texture(uTex, UV);
  vec3 rgb = c.a > 0. ? c.rgb / c.a : vec3(0.); // 纹理按预乘上传，先还原
  float m = uProg >= 1. ? 1. : uProg <= 0. ? 0. : stateMix(field(vWorld));
  // 草稿态：偏纸色 + 斜排线，像铅笔版里的同一根羽毛
  float hatch = .5 + .5 * sin((vWorld.x * uAspect + vWorld.y) * 900.);
  vec3 alt = uInvert > .5 ? invertBlue(rgb) : mix(vec3(.80, .86, 1.), vec3(1.), .55 + .45 * hatch);
  vec3 col = mix(alt, rgb, m);
  float a = c.a * uMeta.x * mix(.8, 1., m);
  a *= 1. - uMeta.z * smoothstep(.42, .72, texture(uFx, vWorld).r); // 被诺米挡住
  a *= (1. - uWash) * uShow;
  ALBEDO = col;
  ALPHA = a;
}
