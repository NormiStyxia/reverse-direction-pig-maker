shader_type spatial;
render_mode cull_back;
// Game-specific: all viewports are perspective and the sole shadow camera is
// directional/orthographic. Keep geometry only in that shadow projection.
// This installed runtime does not emit a caster pass for shading_model_unlit.
uniform sampler2D paint_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D alpha_map : filter_linear_mipmap, repeat_enable;
uniform vec4 map_uv=vec4(1.0,1.0,0.0,0.0);
uniform vec4 alpha_uv=vec4(1.0,1.0,0.0,0.0);
uniform vec4 tint=vec4(1.0);
uniform float alpha_cutoff=0.0;
void vertex(){VERTEX=VERTEX;}
void fragment(){
 if(abs(PROJECTION_MATRIX[3][3])<0.5){discard;}
 float alpha=texture(paint_map,UV*map_uv.xy+map_uv.zw).a*tint.a*texture(alpha_map,UV*alpha_uv.xy+alpha_uv.zw).g;
 ALPHA=alpha;ALPHA_SCISSOR_THRESHOLD=alpha_cutoff;
 ALBEDO=vec3(0.0);ROUGHNESS=1.0;SPECULAR=0.0;
}
