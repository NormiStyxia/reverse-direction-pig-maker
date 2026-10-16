// Frozen post.js FINAL. NVG is rendered after this pass.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;


uniform sampler2D tColor;
uniform sampler2D tBloomA;
uniform sampler2D tBloomB;
uniform vec2 res;
uniform float time;
uniform float bloom;
uniform float exposure;
uniform float paperOn;
uniform float vignette;
uniform float shock;
uniform float shockSeed;
uniform vec3 grade;
uniform float flash;
uniform sampler2D tFrost;
uniform float frost;
uniform float frostSide;
uniform float frostEdge;
uniform float frostFeather;
uniform float veil;
uniform float veilR;
uniform vec2 veilC;
uniform float blue;
uniform float blueLo;
uniform float blueHi;
uniform float blueSweep;
uniform vec2 blueC;
uniform float presentOn;
uniform sampler2D tPresent;
uniform sampler2D tSceneDepth;
uniform float depth_reverse;
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1,0)), u.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}
// 每一层旋转一下，避免值噪声的格子和像素网格对齐
float fbm(vec2 p){ float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { p = vec2(0.8*p.x+0.6*p.y,-0.6*p.x+0.8*p.y); v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
vec3 aces(vec3 x){ return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }
vec3 toSRGB(vec3 c){ return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
// 标题插画的颜色：深墨蓝 / 港口蓝 #0140C4 / 天空蓝 #3579F1 / 纸白
vec3 blueRamp(float x){
  vec3 c0 = vec3(0.035, 0.16, 0.55), c1 = vec3(0.004, 0.25, 0.77), c2 = vec3(0.21, 0.47, 0.945), c3 = vec3(0.973, 0.98, 0.992);
  return x < 0.34 ? mix(c0, c1, x / 0.34) : x < 0.67 ? mix(c1, c2, (x - 0.34) / 0.33) : mix(c2, c3, (x - 0.67) / 0.33);
}
// 三渲二：亮度切成四档平涂，档与档之间留一点软边
float bands(float x){ float f = x * 3.0, i = floor(f); return min(1.0, (i + smoothstep(0.78, 1.0, f - i)) / 3.0); }
void fragment(){
 vec2 vUv=vec2(UV.x,1.0-UV.y);
  vec3 c = texture(tColor, vec2(vUv.x,1.0-vUv.y)).rgb;
  // 看手机时的半屏压虚：边界一侧换成模糊过的画面，交界处平滑过渡
  if (frost > 0.001) {
    float m = frostSide > 0.0 ? smoothstep(frostEdge, frostEdge + frostFeather, vUv.x) : 1.0 - smoothstep(frostEdge - frostFeather, frostEdge, vUv.x);
    c = mix(c, texture(tFrost, vec2(vUv.x,1.0-vUv.y)).rgb, m * frost);
  }
  c += (texture(tBloomA, vec2(vUv.x,1.0-vUv.y)).rgb * 0.7 + texture(tBloomB, vec2(vUv.x,1.0-vUv.y)).rgb * 0.9) * bloom;
  c *= grade * exposure;
  c = aces(c);
  c = toSRGB(c);

  vec2 p = vUv - 0.5;
  p.x *= res.x / res.y;
  float r = length(p);
  // 水彩晕边：边缘不规则地压暗
  float edgeN = fbm(vUv * 5.0 + 3.1) * 0.22;
  float v = smoothstep(0.42 - vignette * 0.22 - edgeN * 0.6, 1.0 - vignette * 0.3, r + edgeN * 0.2);
  c = mix(c, c * vec3(0.32, 0.27, 0.33), v * (0.55 + vignette * 0.45));

  // 蓝白：亮度往纸白那头压(插画是白为主、蓝只做色块和阴影)，再按档平涂上色
  float kb = 0.0, haze = 0.0;
  if (blue > 0.001) {
    kb = blue;
    // 从 blueC(角色身上)往外、带着逆时针旋转扫回原色：0° 在正上方，先往左。
    // 扫一圈的起点和终点在正上方那条射线上碰头，这一小段只按距离走，不然会留一道笔直的硬边
    if (blueSweep > 0.0) {
      vec2 d = (vUv - blueC) * vec2(res.x / res.y, 1.0);
      float n = fract((atan(-d.x/max(abs(d.y),0.00001))*sign(d.y)+(d.y<0.0?3.14159265:0.0)) / 6.2831853 + 1.0);
      float seam = smoothstep(0.0, 0.1, n) * (1.0 - smoothstep(0.86, 1.0, n));
      float f = n * 0.38 * seam + length(d) * 0.55 + (fbm(vUv * vec2(res.x / res.y, 1.0) * 3.0) - 0.5) * 0.34;
      float m = smoothstep(f - 0.09, f + 0.09, blueSweep * 1.36 - 0.18);
      kb *= 1.0 - m;
      haze = (1.0 - abs(m * 2.0 - 1.0)) * blue;
    }
    if (presentOn > 0.5) {
      float pd = texture(tPresent, vec2(vUv.x,1.0-vUv.y)).x, sd = texture(tSceneDepth, vec2(vUv.x,1.0-vUv.y)).x;
      // Compare in Three's ordinary 0-near/1-far convention on both backends.
      if (depth_reverse > 0.5) { pd=1.0-pd; sd=1.0-sd; }
      kb *= 1.0 - step(pd, sd + 0.00002) * step(pd, 0.99999);
    }
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    c = mix(c, blueRamp(bands(smoothstep(blueLo, blueHi, l))), kb);
  }

  // 漫画集中线：FOCUS / INTRUSION 时出现，每 1/12 秒重画一次
  if (shock > 0.01) {
    float a = (atan(p.y/max(abs(p.x),0.00001))*sign(p.x)+(p.x<0.0?3.14159265:0.0));
    float frame = floor(time * 12.0);
    float lines = step(0.72, hash(vec2(floor(a * 70.0 + shockSeed), frame)));
    float reach = 0.24 + 0.24 * hash(vec2(floor(a * 70.0), frame + 3.0));
    float m = lines * smoothstep(reach, reach + 0.25, r) * shock;
    c = mix(c, vec3(0.14, 0.10, 0.11), m * 0.85);
  }

  // 纸纹：纤维 + 颗粒，乘在最上面
  float fiber = fbm(vec2(vUv.x * res.x / 16.0, vUv.y * res.y / 34.0)) * 0.5 + fbm(vUv * res / 6.0) * 0.5;
  vec3 paper = mix(mix(vec3(0.95, 0.92, 0.87), vec3(0.955, 0.965, 0.985), kb), mix(vec3(1.025, 1.01, 0.98), vec3(1.02, 1.02, 1.025), kb), fiber);
  c *= mix(vec3(1.0), paper, paperOn);
  c += (hash(floor(vUv * res) + fract(time * 0.37) * 97.0) - 0.5) * 0.03 * paperOn;
  c = mix(c, vec3(0.98, 0.95, 0.9), flash);
  // 扫场前沿：过曝的白雾
  if (haze > 0.001) c = mix(c, vec3(0.985, 0.99, 1.0), clamp(smoothstep(0.0, 0.9, haze) * (0.55 + fbm(vUv * 7.0 + vec2(-time * 0.22, time * 0.1)) * 0.7), 0.0, 1.0) * 0.9);
  // 转场的黑暗：以 veilC 为圆心、半径 veilR 以外是暗的；边缘用流动的噪波打碎，像墨在散开
  if (veil > 0.001) {
    vec2 q = (vUv - veilC) * vec2(res.x / res.y, 1.0);
    float n = fbm(vUv * 5.0 + vec2(time * 0.18, -time * 0.13)) * 0.42 + fbm(vUv * 13.0 - time * 0.3) * 0.12;
    float m = smoothstep(veilR - 0.06, veilR + 0.1, length(q) + n - 0.25);
    // 蓝白时这团「墨」也是插画里的深蓝
    c = mix(c, mix(vec3(0.025, 0.03, 0.035), vec3(0.004, 0.18, 0.62), blue), m * veil);
  }
  ALBEDO=c;
}
