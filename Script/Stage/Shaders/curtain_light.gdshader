shader_type canvas_item;
render_mode unshaded;
uniform vec2 focus=vec2(0.5,0.5);
uniform vec2 screen_size=vec2(1280.0,720.0);
uniform vec2 slide=vec2(0.0);
uniform float radius=0.28;
uniform float dimming=0.7;
void fragment(){
    vec4 source=texture(TEXTURE,UV);
    float d=length((UV+slide-focus)*screen_size)/screen_size.y;
    float circle=1.0-smoothstep(radius*0.82,radius,d);
    COLOR=vec4(source.rgb*mix(1.0-dimming,1.0,circle),source.a);
}
