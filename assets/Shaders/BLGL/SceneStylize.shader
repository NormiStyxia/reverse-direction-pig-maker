// Frozen STYLIZE once per output pixel; DOF samples this rasterized HDR result.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform float depth_reverse=0.0;
uniform float cNear;
uniform float cFar;
float viewDepth(sampler2D t, vec2 uv){
  // H5 DepthTexture uses NearestFilter. Sample the owned main-scene attachment
  // at texel centres; never interpolate unrelated surfaces at a silhouette.
  vec2 size = vec2(textureSize(t, 0));
  vec2 nativeUV = vec2(uv.x, 1.0-uv.y);
  nativeUV = (clamp(floor(nativeUV * size), vec2(0.0), size-1.0)+0.5)/size;
  float d = texture(t, nativeUV).x;
  d=mix(d,1.0-d,depth_reverse);
  return (cNear * cFar) / (cFar - d * (cFar - cNear));
}
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1,0)), u.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}

uniform sampler2D tColor : filter_linear, repeat_disable;
uniform sampler2D tDepth : filter_nearest, repeat_disable;
uniform vec2 res;
uniform float time;
uniform float lineOn;
uniform float paperOn;
uniform float wobbleOn;
uniform float wobbleFps;
uniform float lineWidth;
uniform vec3 inkColor;
vec3 stylizedAt(sampler2D color,sampler2D depth,vec2 vUv){
  vec2 px = 1.0 / res;
  // “抖线”：线条位置每 1/wobbleFps 秒换一次噪声种子，像逐帧手绘；wobbleOn 同时是幅度
  float t = floor(time * wobbleFps) * step(0.001, wobbleOn);
  vec2 q = vUv * res / 46.0;
  vec2 n = vec2(vnoise(q + t * 7.13), vnoise(q + 17.3 - t * 3.71)) - 0.5;
  vec2 uvL = vUv + n * px * 3.0 * wobbleOn;
  float d = viewDepth(depth, uvL);
  float w = lineWidth;
  float s = 0.0;
  s += viewDepth(depth, uvL + vec2( w, 0.0) * px);
  s += viewDepth(depth, uvL + vec2(-w, 0.0) * px);
  s += viewDepth(depth, uvL + vec2(0.0,  w) * px);
  s += viewDepth(depth, uvL + vec2(0.0, -w) * px);
  s += viewDepth(depth, uvL + vec2( w,  w) * px * 0.7);
  s += viewDepth(depth, uvL + vec2(-w,  w) * px * 0.7);
  s += viewDepth(depth, uvL + vec2( w, -w) * px * 0.7);
  s += viewDepth(depth, uvL + vec2(-w, -w) * px * 0.7);
  // 深度拉普拉斯：同时抓到轮廓和折角
  float lap = abs(s - 8.0 * d) / max(d, 0.001);
  float edge = smoothstep(0.025, 0.085, lap);
  edge *= 1.0 - smoothstep(45.0, 160.0, d) * 0.75;
  edge *= 0.6 + 0.4 * vnoise(vUv * res / 10.0 + t * 3.0);
  edge *= lineOn;

  vec2 uvC = vUv + n * px * 1.6 * wobbleOn;
  vec3 col = texture(color, vec2(uvC.x,1.0-uvC.y)).rgb;
  vec3 cx = texture(color, vec2(uvC.x+px.x*2.0,1.0-uvC.y)).rgb;
  vec3 cy = texture(color, vec2(uvC.x,1.0-uvC.y-px.y*2.0)).rgb;
  float grad = length(cx - col) + length(cy - col);
  // 颜料在色块交界堆积
  col *= 1.0 - clamp(grad * 0.7, 0.0, 0.28) * paperOn;
  // 颜料颗粒感(只作用在场景颜色上，纸纹在最后一遍)
  float g = vnoise(vUv * res / 2.5) * 0.5 + vnoise(vUv * res / 7.0) * 0.5;
  col *= mix(1.0, 0.9 + 0.2 * g, paperOn);
  // 暗部铅笔排线：屏幕空间斜线，跟着抖线一起“重画”
  float lum = dot(col, vec3(0.299, 0.587, 0.114));
  vec2 sp = (vUv + n * px * 6.0) * res / lineWidth;
  // 单向斜排线，按笔划编号随机断开，像一笔一笔排出来的
  float u1 = (sp.x + sp.y) / 5.0;
  float id1 = floor(u1);
  float along1 = (sp.x - sp.y) / 26.0 + hash(vec2(id1, 1.0)) * 9.0;
  float seg1 = step(0.45, vnoise(vec2(id1 * 0.37, along1)) + 0.25 * hash(vec2(id1, t)));
  float h1 = (1.0-smoothstep(0.08, 0.32, abs(fract(u1) - 0.5))) * seg1;
  float u2 = (sp.x - sp.y * 0.6) / 6.0;
  float id2 = floor(u2);
  float seg2 = step(0.55, vnoise(vec2(id2 * 0.41, (sp.y + sp.x * 0.6) / 22.0 + hash(vec2(id2, 2.0)) * 9.0)));
  float h2 = (1.0-smoothstep(0.1, 0.3, abs(fract(u2) - 0.5))) * seg2;
  // lum 是线性 HDR 值：0.06 大约是 sRGB 的 0.27
  float hatch = h1 * (1.0-smoothstep(0.025, 0.07, lum)) + h2 * (1.0-smoothstep(0.008, 0.025, lum));
  hatch *= (1.0 - smoothstep(30.0, 90.0, d)) * paperOn;
  col = mix(col, col * 0.55 + inkColor * 0.12, clamp(hatch, 0.0, 1.0) * 0.55);
  col = mix(col, inkColor * (0.35 + 0.4 * col), clamp(edge, 0.0, 1.0) * 0.92);
  return col;
}
void fragment(){
  vec2 vUv=vec2(UV.x,1.0-UV.y);
  ALBEDO=stylizedAt(tColor,tDepth,vUv);
  ALPHA=1.0;
}
