shader_type canvas_item;
render_mode unshaded;
varying vec2 point;
uniform vec2 feet;
uniform float top_y;
uniform float beam_width;
uniform vec2 pool_size;
uniform float softness;
uniform float top_softness;
uniform vec4 light_color : source_color;
uniform float beam_opacity;
uniform float pool_opacity;
uniform float shadow_opacity;
void vertex(){point=VERTEX;}
void fragment(){
 float t=clamp((point.y-top_y)/max(feet.y-top_y,1.0),0.0,1.0);
 float width=mix(beam_width*0.22,beam_width*0.5,t);
 float edge=mix(top_softness,softness,t);
 float beam=1.0-smoothstep(1.0-edge,1.0,abs(point.x-feet.x)/max(width,1.0));
 beam*=1.0-smoothstep(feet.y-20.0,feet.y+10.0,point.y);
 float pool=1.0-smoothstep(1.0-softness,1.0,length((point-feet)/max(pool_size*0.5,vec2(1.0))));
 float shadow=(1.0-smoothstep(0.2,1.0,length((point-feet)/vec2(35.0,9.0))))*shadow_opacity;
 float alpha=clamp(beam*beam_opacity+pool*pool_opacity,0.0,1.0);
 COLOR=vec4(mix(light_color.rgb,vec3(0.08,0.05,0.16),shadow/max(alpha+shadow,0.001)),clamp(alpha+shadow,0.0,1.0));
}
