// Only used by preview/dust-check.lua; no player-facing debug controls.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D tColor : filter_nearest, repeat_disable;
uniform float coverage=0.0;
vec3 srgb(vec3 c){return mix(12.92*c,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-.055,step(vec3(.0031308),c));}
void fragment(){vec4 c=texture(tColor,UV);ALBEDO=mix(srgb(c.rgb),vec3(c.a),coverage);}
