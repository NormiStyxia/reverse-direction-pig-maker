// MeshBasicMaterial override equivalent. Only explicitly marked non-cutout
// geometry is submitted. The linked depth texture is the useful output.
shader_type spatial;
render_mode shading_model_unlit, cull_back, fog_disabled;
void vertex() {}
void fragment() { ALBEDO=vec3(0.0); }
