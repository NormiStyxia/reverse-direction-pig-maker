// Isolated alpha/depth verification only; never referenced by main.lua.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D tColor : filter_nearest, repeat_disable;
uniform float reverse_depth=1.0;
void fragment(){
  float d=texture(tColor,UV).r;
  ALBEDO=vec3(reverse_depth>0.5?step(0.00001,d):1.0-step(0.99999,d));
}
