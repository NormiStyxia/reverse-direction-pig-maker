// Generated from StoreLit.shader.
shader_type spatial;
render_mode cull_back, blend_add, depth_draw_never;
// Keep the base/AMBIENT pass: this runtime adds EMISSION only in that pass.
// Zone ambient is black; the source hemisphere is evaluated explicitly below.
// Source texture samples decode exactly once; material tints are already linear.
uniform sampler2D paint_map;
uniform sampler2D alpha_map;
uniform sampler2D emit_map;
uniform vec4 tint=vec4(1.0);
uniform vec3 instance_tint=vec3(1.0);
uniform vec4 map_uv=vec4(1.0,1.0,0.0,0.0);
uniform vec4 alpha_uv=vec4(1.0,1.0,0.0,0.0);
uniform vec4 emit_uv=vec4(1.0,1.0,0.0,0.0);
uniform float map_srgb=1.0;
uniform float emit_srgb=1.0;
uniform float alpha_cutoff=0.0;
uniform vec3 emissive_color=vec3(0.0);
uniform float is_toon=1.0;
uniform float shadow_step=0.08;
uniform float receive_shadow=1.0;
uniform vec3 toon_bands=vec3(-1.0);
uniform float paper_figure=0.0;
uniform float night_kind=0.0;
varying vec3 source_night_world;
uniform vec3 hemi_sky=vec3(0.323143,0.401978,0.496933);
uniform vec3 hemi_ground=vec3(0.03434,0.042312,0.045186);
uniform float hemi_intensity=0.72;
uniform vec4 point_position_0=vec4(0.0);
uniform vec4 point_color_0=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_1=vec4(0.0);
uniform vec4 point_color_1=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_2=vec4(0.0);
uniform vec4 point_color_2=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_3=vec4(0.0);
uniform vec4 point_color_3=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_4=vec4(0.0);
uniform vec4 point_color_4=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_5=vec4(0.0);
uniform vec4 point_color_5=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_6=vec4(0.0);
uniform vec4 point_color_6=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_7=vec4(0.0);
uniform vec4 point_color_7=vec4(0.0,0.0,0.0,2.0);
uniform vec4 point_position_8=vec4(0.0);
uniform vec4 point_color_8=vec4(0.0,0.0,0.0,2.0);
float sourceBand(float ndl){
 float band=ndl<(-1.0/3.0)?shadow_step:(ndl<(1.0/3.0)?(shadow_step+1.0)*0.5+0.04:1.0);
 if(toon_bands.x>=0.0){band=ndl<(-1.0/3.0)?toon_bands.x:(ndl<(1.0/3.0)?toon_bands.y:toon_bands.z);}
 return mix(max(ndl,0.0),band,is_toon);
}
vec3 sourcePoint(vec3 p,vec3 n,vec4 position_range,vec4 color_decay){
 vec3 delta=position_range.xyz-p;float d=length(delta);
 float falloff=1.0/max(pow(d,color_decay.w),0.01);
 if(position_range.w>0.0){float cutoff=clamp(1.0-pow(d/position_range.w,4.0),0.0,1.0);falloff*=cutoff*cutoff;}
 return color_decay.rgb*falloff*sourceBand(dot(n,delta/max(d,0.00001)));
}
vec3 linearize(vec3 c){return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));}
// night.js applies this linear color transform after lighting. Applying it to
// each additive light term preserves that order across the native base/light passes.
vec3 sourceNightGround(vec3 c){
 if(night_kind<3.5){return c;}
 vec3 w=source_night_world;
 float lum=dot(c,vec3(0.299,0.587,0.114));
 vec3 base=mix(vec3(lum)*vec3(0.045,0.07,0.125)*1.6,c*0.05,0.3);
 float glow=0.0;
 for(int i=0;i<4;i++){
  float lx=i==0?-3.6:(i==1?4.0:(i==2?-12.0:12.0));
  vec2 d=w.xz-vec2(lx,-9.3)-vec2(0.75,0.0);
  glow+=1.3/(1.0+dot(d,d)*1.2);
 }
 float mx=smoothstep(-5.7,-4.7,w.x)*(1.0-smoothstep(1.9,2.9,w.x))+smoothstep(2.6,3.5,w.x)*(1.0-smoothstep(5.1,6.0,w.x));
 float spill=clamp(mx,0.0,1.0)*exp(-max(0.0,-5.75-w.z)*0.42)*(1.0-smoothstep(0.4,2.6,w.y));
 return base+c*vec3(1.0,0.72,0.38)*glow*0.9+c*vec3(0.78,0.92,0.86)*spill*1.2;
}
// Required for matching alpha-discard auxiliary depth/shadow programs.
void vertex(){
 VERTEX=VERTEX;
 vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 source_night_world=vec3(w.x,w.y,-w.z);
}
void fragment(){
 vec4 tex=texture(paint_map,UV*map_uv.xy+map_uv.zw);
 tex.rgb=mix(tex.rgb,linearize(tex.rgb),map_srgb);
 float alpha=tex.a*tint.a*texture(alpha_map,UV*alpha_uv.xy+alpha_uv.zw).g;
 if(alpha<alpha_cutoff){discard;}
 ALBEDO=tex.rgb*tint.rgb*COLOR.rgb*instance_tint;ROUGHNESS=1.0;SPECULAR=0.0;
 vec3 emit=texture(emit_map,UV*emit_uv.xy+emit_uv.zw).rgb;
 emit=mix(emit,linearize(emit),emit_srgb);
 vec3 irradiance=mix(hemi_ground,hemi_sky,NORMAL.y*0.5+0.5)*hemi_intensity;
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_0,point_color_0);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_1,point_color_1);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_2,point_color_2);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_3,point_color_3);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_4,point_color_4);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_5,point_color_5);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_6,point_color_6);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_7,point_color_7);
 irradiance+=sourcePoint(VERTEX,NORMAL,point_position_8,point_color_8);
 // The frozen Three Toon/Lambert indirect and point terms both use BRDF_Lambert.
 EMISSION=sourceNightGround(emit*emissive_color+ALBEDO*irradiance*0.318309886);
 ALPHA=alpha;
}
void light(){
 float strength=sourceBand(dot(NORMAL,LIGHT));
 // The only native light is directional; point attenuation is evaluated above.
 // Installed runtime accepts shadows_disabled but does not apply it to light().
 float sourceShadow=mix(1.0,ATTENUATION,receive_shadow);
 DIFFUSE_LIGHT+=sourceNightGround(ALBEDO*LIGHT_COLOR*sourceShadow*strength*0.318309886);
}
