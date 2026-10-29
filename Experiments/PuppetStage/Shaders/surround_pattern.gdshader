shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pattern_image : source_color, repeat_enable, filter_linear;
uniform sampler2D outside_mask : filter_linear;
uniform bool use_image_mask = false;
uniform vec2 opening[16];
uniform int opening_count = 10;
uniform vec2 phase;
uniform vec2 design_size = vec2(1280.0,720.0);
uniform float tile_size = 420.0;
uniform vec4 ink : source_color = vec4(0.34,0.22,0.93,1.0);
uniform vec4 paper : source_color = vec4(0.72,0.56,0.86,1.0);
uniform vec4 stage_tint : source_color = vec4(1.0);
void fragment(){
    bool inside = false;
    int j = opening_count-1;
    for(int i=0;i<16;i++){
        if(i>=opening_count)break;
        vec2 a=opening[i]; vec2 b=opening[j];
        if((a.y>UV.y)!=(b.y>UV.y)){
            float crossing=(b.x-a.x)*(UV.y-a.y)/(b.y-a.y)+a.x;
            if(UV.x<crossing)inside=!inside;
        }
        j=i;
    }
    float mask = use_image_mask ? texture(outside_mask,UV).r : (inside ? 0.0 : 1.0);
    vec4 sample_color=texture(pattern_image,UV*design_size/max(tile_size,1.0)+phase);
    // Accept opaque white paper OR transparent PNGs without modifying source art.
    float marks=(1.0-smoothstep(0.65,0.98,dot(sample_color.rgb,vec3(0.299,0.587,0.114))))*sample_color.a;
    vec4 result=mix(paper,ink,marks);
    COLOR=vec4(result.rgb*stage_tint.rgb,result.a*mask);
}
