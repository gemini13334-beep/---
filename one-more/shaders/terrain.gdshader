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
 float broad=noise2(p*0.19);
 float patches=noise2(p*0.85);
 float grain=noise2(p*9.0);
 float edge=noise2(p*1.8)*0.65;
 float path=1.0-smoothstep(0.85+edge,1.9+edge,abs(p.x-sin(p.y*0.18)*3.0));
 vec3 ground=base_color.rgb*(0.68+0.38*broad+0.24*patches+0.09*grain);
 ground=mix(ground,ground*vec3(1.16,1.08,0.76),smoothstep(0.45,0.8,patches)*forest*0.45);
 vec3 dirt=vec3(0.30,0.24,0.15)*(0.72+0.35*patches+0.15*grain);
 vec2 cell=floor(p*2.7);
 vec2 local=fract(p*2.7)-vec2(0.5);
 local-=vec2(hash(cell),hash(cell+vec2(4,9)))*0.36-0.18;
 float stone=(1.0-smoothstep(0.09,0.20,length(local*vec2(1.0,1.4))))*step(0.78,hash(cell+vec2(8,3)));
 vec3 surface=mix(ground,dirt,path*forest*0.83);
 ALBEDO=mix(surface,surface*1.35+vec3(0.025),stone*0.65);
 ROUGHNESS=mix(0.94,0.72,stone);
}
