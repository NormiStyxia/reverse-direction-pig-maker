shader_type spatial;
render_mode shading_model_unlit, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D paint_map;
uniform vec3 camera_right=vec3(1.0,0.0,0.0);
uniform vec3 camera_up=vec3(0.0,1.0,0.0);
uniform vec3 camera_forward=vec3(0.0,0.0,1.0);
uniform vec3 camera_position;
uniform float spin=0.0;
uniform float diameter=0.02;
uniform float pixel_world=0.0004;
void vertex(){
  float c=cos(spin),s=sin(spin);
  VERTEX.xz=vec2(c*VERTEX.x-s*VERTEX.z,s*VERTEX.x+c*VERTEX.z);
  float d=dot(VERTEX-camera_position,camera_forward);
  float size=max(diameter,d*pixel_world);
  VERTEX+=(camera_right*(UV.x-.5)+camera_up*(.5-UV.y))*size;
}
void fragment(){
  vec4 t=texture(paint_map,UV);
  // Native additive is ONE/ONE; Three's PointsMaterial uses SRC_ALPHA/ONE.
  ALBEDO=t.rgb*vec3(1.6,1.3,.9)*t.a;
  ALPHA=t.a;
}
