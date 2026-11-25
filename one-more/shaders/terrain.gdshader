shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.16,0.29,0.22,1.0);
uniform float forest = 1.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=world_pos.xz;
 float broad=noise2(p*0.22);
 float grain=noise2(p*9.0);
 float path=1.0-smoothstep(1.0,2.4,abs(p.x-sin(p.y*0.18)*3.0));
 vec3 ground=base_color.rgb*(0.78+0.38*broad+0.12*grain);
 vec3 dirt=vec3(0.30,0.24,0.15)*(0.85+0.25*grain);
 ALBEDO=mix(ground,dirt,path*forest*0.7);
 ROUGHNESS=0.94;
}
