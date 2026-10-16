shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;
uniform sampler2D input_color : filter_linear, repeat_disable;
uniform vec2 blur_dir=vec2(0.0);
uniform float flip_y=0.0;
void fragment(){
 vec2 uv=vec2(UV.x,mix(UV.y,1.0-UV.y,flip_y));
 vec3 c=texture(input_color,uv).rgb*0.227;
 c+=texture(input_color,uv+blur_dir*1.385).rgb*0.316;
 c+=texture(input_color,uv-blur_dir*1.385).rgb*0.316;
 c+=texture(input_color,uv+blur_dir*3.231).rgb*0.070;
 c+=texture(input_color,uv-blur_dir*3.231).rgb*0.070;
 ALBEDO=c;
}
