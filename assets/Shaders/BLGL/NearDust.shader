shader_type spatial;
// Frozen Three opaque_fragment sets surviving alpha to ONE after alphaTest.
// Preserve binary coverage, not the PNG's fractional alpha after the cutout.
render_mode shading_model_unlit, cull_disabled, fog_disabled;
uniform sampler2D paint_map;
uniform float diameter=0.01;
uniform float pixel_world=0.0004;
void vertex(){
  float size=max(diameter,VERTEX.z*pixel_world);
  VERTEX.xy+=vec2(UV.x-.5,.5-UV.y)*size;
}
void fragment(){
  vec4 t=texture(paint_map,UV);
  if(t.a<.35){discard;}
  ALBEDO=t.rgb*vec3(1.6,1.3,.9);
}
