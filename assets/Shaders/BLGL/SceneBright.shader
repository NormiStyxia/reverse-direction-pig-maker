shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;


uniform sampler2D tColor;
uniform float threshold;
void fragment(){
  vec3 c = texture(tColor, UV).rgb;
  float l = max(c.r, max(c.g, c.b));
  float k = clamp((l - threshold) / max(l, 0.0001), 0.0, 1.0);
  ALBEDO=c*k;
}
