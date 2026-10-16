shader_type spatial;
render_mode shading_model_unlit, cull_back;
uniform sampler2D paint_map;
uniform sampler2D alpha_map;
uniform sampler2D emit_map;
uniform vec4 tint=vec4(1.0);
uniform vec3 instance_tint=vec3(1.0);
uniform vec4 map_uv=vec4(1.0,1.0,0.0,0.0);
uniform vec4 alpha_uv=vec4(1.0,1.0,0.0,0.0);
uniform float map_srgb=1.0;
uniform float alpha_cutoff=0.0;
uniform float night_kind=0.0;
uniform float wind_amp=0.0;
uniform float wind_time=0.0;
uniform float wind_gust=1.0;
uniform float elapsed=0.0;
vec3 linearize(vec3 c){return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));}
float nHash(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float spill(vec3 w){
 float mx=smoothstep(-5.7,-4.7,w.x)*(1.0-smoothstep(1.9,2.9,w.x))+smoothstep(2.6,3.5,w.x)*(1.0-smoothstep(5.1,6.0,w.x));
 return clamp(mx,0.0,1.0)*exp(-max(0.0,-5.75-w.z)*0.42)*(1.0-smoothstep(0.4,2.6,w.y));
}
void vertex(){
 float bend=(1.0-UV.y)*(1.0-UV.y);
 float gust=0.55+0.45*sin(wind_time*0.42-VERTEX.x*0.11);
 float wave=sin(wind_time*1.25+VERTEX.x*0.33)*0.6+sin(wind_time*2.3+VERTEX.x*0.85+VERTEX.y*0.7)*0.4;
 float sy=sin(wind_time*1.7+VERTEX.x*0.6)*bend*wind_amp*0.18*wind_gust;
 VERTEX.x+=wave*bend*wind_amp*gust*wind_gust;VERTEX.y+=sy;
}
void fragment(){
 vec2 uv=UV*map_uv.xy+map_uv.zw;
 if(wind_amp>0.0){vec2 sourceUV=vec2(uv.x,1.0-uv.y);uv+=vec2(sin(wind_time*3.1+sourceUV.y*41.0+sourceUV.x*23.0),-cos(wind_time*2.7+sourceUV.x*37.0))*0.0012*wind_gust;}
 vec4 tex=texture(paint_map,uv);tex.rgb=mix(tex.rgb,linearize(tex.rgb),map_srgb);
 float alpha=tex.a*tint.a*texture(alpha_map,UV*alpha_uv.xy+alpha_uv.zw).g;
 if(alpha<alpha_cutoff){discard;}
 vec3 c=tex.rgb*tint.rgb*COLOR.rgb*instance_tint;
 if(night_kind>0.5&&night_kind<1.5){
   float h=clamp(1.0-uv.y,0.0,1.0);
   c=mix(vec3(0.03,0.022,0.028),vec3(0.004,0.007,0.02),smoothstep(0.08,0.75,h));
   c+=vec3(0.1,0.045,0.018)*exp(-h*7.0);
   float r=nHash(floor(vec2(uv.x,1.0-uv.y)*vec2(420.0,170.0)));
   float tw=0.6+0.4*sin(elapsed*(1.5+r*3.0)+r*40.0);
   c+=vec3(0.9,0.92,1.0)*step(0.9965,r)*tw*smoothstep(0.3,0.7,h)*2.5;
 }else if(night_kind>1.5){
   vec3 w=vec3(VERTEX.x,VERTEX.y,-VERTEX.z);
   float lum=dot(c,vec3(0.299,0.587,0.114));
   vec3 base=mix(vec3(lum)*vec3(0.045,0.07,0.125)*1.6,c*0.05,0.3);
   float glow=0.0;
   for(int i=0;i<4;i++){
     float lx=i==0?-3.6:(i==1?4.0:(i==2?-12.0:12.0));
     vec3 d=w-vec3(lx,3.5,-9.3);
     if(night_kind>3.5){d.x-=0.75;glow+=1.3/(1.0+dot(d.xz,d.xz)*1.2);}
     else{glow+=1.0/(1.0+dot(d,d)*0.22);}
   }
   vec3 lit=c*vec3(1.0,0.72,0.38)*glow*(night_kind>3.5?0.9:0.55);
   if(night_kind>2.5){lit+=c*vec3(0.78,0.92,0.86)*spill(w)*(night_kind>3.5?1.2:0.28);}
   c=base+lit;
 }
 ALBEDO=c;
 // BLEND_ALPHA_INSERT
}
