// Ported from frozen title-screen.js; all authored noise/transition formulas retained.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;

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


uniform sampler2D uFlat : filter_linear_mipmap, repeat_disable;
uniform sampler2D uSketch : filter_linear_mipmap, repeat_disable;
uniform sampler2D uFx : filter_linear_mipmap, repeat_disable;
uniform float uZoom;
uniform float uReveal;
uniform float uRewind;
uniform float uWash;
uniform float uMotion;
uniform float uSil;
uniform float uFlash;
uniform float uGlitch;
uniform float uGSil;
uniform vec2 uPar;
uniform vec2 uCam;
// 剪影态(开场最先出现的)：网格纸 + 诺米 / 鸽子 / 羽毛的剪影(fx 的 A 通道，边缘是清楚的)。
// 平时是白剪影 + 蓝描边，flash 时整块填满钴蓝

void fragment() {
  vec2 uv = (UV - .5) / uZoom + uCam;
  // 倒带时整行轻微错位，像磁带回卷
  uv.x += (noise(vec2(uv.y * 46., uTime * 18.)) - .5) * .006 * uRewind;
  // 闲置久了的扰动：一条条横块随机错开(每秒换 22 次)
  if (uGlitch > 0.) {
    float row = floor(uv.y * 34.), tk = floor(uTime * 22.);
    uv.x += step(.62, hash(vec2(row, tk))) * (hash(vec2(row * 1.7, tk + 3.)) - .5) * .05 * uGlitch;
  }

  vec3 sil_paper = vec3(.93, .945, .972);
  vec2 sil_g = abs(fract(uv * vec2(uAspect, 1.) * 16.) - .5);
  sil_paper = mix(sil_paper, vec3(.82, .87, .96), (1. - smoothstep(.0, .025, min(sil_g.x, sil_g.y))) * .55);
  float sil_m = smoothstep(.3, .7, texture(uFx, uv).a);
  // 描边：往外扩几个像素取最大值，推近了也是同样粗细
  vec2 sil_d = vec2(3.2 / 2560., 3.2 / 1152.) / uZoom;
  float sil_md = max(max(smoothstep(.3, .7, texture(uFx, uv + vec2(sil_d.x, 0.)).a), smoothstep(.3, .7, texture(uFx, uv - vec2(sil_d.x, 0.)).a)), max(smoothstep(.3, .7, texture(uFx, uv + vec2(0., sil_d.y)).a), smoothstep(.3, .7, texture(uFx, uv - vec2(0., sil_d.y)).a)));
  float sil_edge = clamp(sil_md - sil_m, 0., 1.) * uSil;
  sil_m *= uSil;
  vec3 sil_ink = vec3(.004, .25, .77);
  vec3 sil_col = mix(sil_paper, vec3(1.), sil_m);
  sil_col = mix(sil_col, sil_ink, sil_m * uFlash);
  vec3 silhouetteColor = mix(sil_col, sil_ink, sil_edge * .9);
  vec3 fx = texture(uFx, uv).rgb;
  vec2 off = uPar * vec2(-.004, -.003) + uPar * vec2(-.007, -.005) * fx.r; // 人物在前，视差更大
  float w = uWorld;
  // 头发、飘带：从发根往发梢传的波；羽毛、鸽子：按位置错开相位原地飘
  off += uMotion * fx.g * vec2(.0011 * sin(w * 1.1 - uv.x * 11.), .0034 * sin(w * 1.6 - uv.x * 16. + 1.2) + .0013 * sin(w * 2.7 - uv.x * 31.));
  float ph = uv.x * 9. + uv.y * 5.;
  off += uMotion * fx.b * vec2(.0018 * sin(w * 1.3 + ph), .0034 * sin(w * .9 + ph * 1.7));
  vec2 suv = uv + off;
  // 稳定在某一态时跳过噪声场，省 GPU
  float m = uProg >= 1. ? 1. : uProg <= 0. ? 0. : stateMix(field(suv));
  float e = 1. - abs(m * 2. - 1.);
  vec2 d = (suv - uC) * vec2(uAspect, 1.);
  vec2 wuv = suv + vec2(d.y, -d.x) / max(length(d), 1e-4) / vec2(uAspect, 1.) * e * e * .008; // 边缘被逆时针的风卷一下
  vec3 a = texture(uSketch, wuv).rgb;
  float split = .0025 * e + .008 * uGlitch;
  vec3 b = vec3(texture(uFlat, wuv + vec2(split, 0)).r, texture(uFlat, wuv).g, texture(uFlat, wuv - vec2(split, 0)).b);
  vec3 col = mix(a, b, m);
  if (e > 0.) {
    float wisp = fbm(suv * vec2(uAspect, 1.) * 2.6 + vec2(-uTime * .22, uTime * .1));
    col = mix(col, vec3(.985, .99, 1.), clamp(smoothstep(.0, .9, e) * (.55 + wisp * .7), 0., 1.) * .9); // 过曝烟雾
  }
  col = mix(col, col * vec3(1.04, .98, .9), e * e * .5); // 前沿带一点暖色(不要窄亮线，会像闪电)
  // 开场：从剪影态里显影成铅笔稿，前沿带一道墨色
  if (uReveal < 1.) {
    float rf = uReveal * 1.45 - fbm(uv * vec2(uAspect, 1.) * 2.2) * .55 - (1. - uv.x) * .25 - .1;
    col = mix(silhouetteColor, col, smoothstep(0., .18, rf));
    col = mix(col, vec3(.06, .2, .62), smoothstep(0., .05, rf) * (1. - smoothstep(.05, .2, rf)) * .55 * (1. - uReveal * .6));
  }
  col = mix(col, col * vec3(.92, .96, 1.08), uRewind * .5);
  // 扰动中间闪几帧钴蓝剪影(和开场是同一个剪影)
  if (uGSil > 0.) col = mix(col, silhouetteColor, uGSil);
  col = mix(col, col * vec3(.9, .96, 1.1), uGlitch * .4);
  col = mix(col, vec3(.972, .98, .992), uWash);
  ALBEDO = col;
}
