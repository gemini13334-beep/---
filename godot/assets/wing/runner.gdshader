shader_type spatial;

void fragment() {
 vec2 p = vec2(UV.x, UV.y*5.9);
 float edge = min(UV.x,1.0-UV.x);
 float band = 1.0-smoothstep(0.004,0.011,abs(edge-0.062));
 vec2 motif = abs(fract(p+vec2(0.0,0.5))-0.5);
 float diamond = abs(motif.x+motif.y-0.28);
 float thread = (1.0-smoothstep(0.006,0.02,diamond))*smoothstep(0.08,0.13,edge);
 float fiber = 0.93+0.07*sin(p.x*490.0)*sin(p.y*465.0);
 ALBEDO = mix(vec3(0.28,0.064,0.044),vec3(0.59,0.34,0.15),max(band,thread*0.76))*fiber;
 ROUGHNESS = 0.97;
}
