shader_type spatial;
render_mode shading_model_unlit, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D paint_map;
varying vec3 steam_color;
void vertex(){
    // Unlit geometry carries exact Float32 RGB in its unused normal stream.
    // Packed vertex colors would quantize this subtle effect to 8 bits.
    steam_color=NORMAL;NORMAL=vec3(0.0,0.0,-1.0);
}
void fragment(){
    vec4 t=texture(paint_map,UV);
    // Native ONE/ONE versus source SRC_ALPHA/ONE. Decode RGB only once.
    ALBEDO=t.rgb*steam_color*t.a;ALPHA=t.a;
}
