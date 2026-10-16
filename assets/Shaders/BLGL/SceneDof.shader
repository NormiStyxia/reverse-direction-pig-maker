// Frozen DOF_MAIN. No recomputation of ink at fractional blur coordinates.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D tStyled : filter_linear, repeat_disable;
uniform sampler2D tDepth : filter_nearest, repeat_disable;
uniform sampler2D tNear : filter_linear, repeat_disable;
uniform vec2 res;
uniform float cNear;
uniform float cFar;
uniform float depth_reverse;
uniform float enabled=1.0;
uniform float desat=0.0;
uniform float sat=1.0;
const int N=32;
vec3 composite(vec3 c){float l=dot(c,vec3(.299,.587,.114));return mix(max(mix(vec3(l),c,sat),vec3(0.0)),vec3(l)*vec3(.8,.82,.95),desat);}
float viewDepth(sampler2D t,vec2 uv){
  vec2 size=vec2(textureSize(t,0));
  vec2 center=(clamp(floor(uv*size),vec2(0.0),size-1.0)+0.5)/size;
  float d=texture(t,center).r;
  d=mix(d,1.0-d,depth_reverse);
  return (cNear*cFar)/(cFar-d*(cFar-cNear));
}
uniform float focus;
uniform float range;
uniform float kNear;
uniform float kFar;
uniform float maxCoc;
uniform float pxScale;
float coc(float d){
  float x = d - focus;
  float a = max(abs(x) - range, 0.0);
  // 离焦平面越远，模糊增长越快：中景基本清楚，前后两头像移轴一样迅速化开
  float c = a / max(d, 0.001) * (x > 0.0 ? kFar : kNear) * (1.0 + a * 0.12);
  return min(c, x > 0.0 ? maxCoc * 0.55 : maxCoc) * pxScale;
}


void fragment(){
  vec2 vUv=UV;
  vec2 px=1.0/res;
  vec3 center=texture(tStyled,vUv).rgb;
  float dc=viewDepth(tDepth,vUv);
  float cc=coc(dc)*enabled;
  vec3 mainColor=center;
  if(cc>=0.6){
    vec3 acc=center;float wsum=1.0;
    for(int i=0;i<N;i++){
      float fi=float(i)+0.5;
      float r=sqrt(fi/float(N))*cc;
      float a=fi*2.39996;
      vec2 uv=vUv+vec2(cos(a),-sin(a))*r*px;
      float ds=viewDepth(tDepth,uv);float cs=coc(ds);
      float w=ds<dc-0.5?clamp(cs-r+1.0,0.0,1.0):1.0;
      acc+=texture(tStyled,uv).rgb*w;wsum+=w;
    }
    mainColor=acc/wsum;
  }
  // Active frozen chapter focus proxies have no near Things: searchR=0, so
  // DOF_NEAR is an identity. Keep camera dust outside ink/main DOF and desat.
  vec4 n=texture(tNear,vUv);
  ALBEDO=n.rgb+composite(mainColor)*(1.0-clamp(n.a,0.0,1.0));
}
