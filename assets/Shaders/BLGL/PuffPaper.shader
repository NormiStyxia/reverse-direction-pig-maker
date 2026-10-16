shader_type spatial;
render_mode shading_model_unlit, cull_disabled;
uniform sampler2D paint_map;
// Explicit vertex stage keeps depth/cutout auxiliary passes on this runtime.
void vertex(){}
void fragment(){
  vec4 t=texture(paint_map,UV);
  if(t.a<0.4){discard;}
  // Texture is a linear-RGB derivative of frozen paintPuff/paintBurst, alpha unchanged.
  ALBEDO=t.rgb*vec3(1.4,1.3,1.1);
  ALPHA=t.a;ALPHA_SCISSOR_THRESHOLD=0.4;
}
