shader_type spatial;
uniform sampler2D steel : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_detail : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D decal : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tone : source_color;
uniform float ink = .8;
void fragment() {
 vec3 metal=texture(steel,UV).rgb;
 vec3 surface=texture(orm,UV).rgb;
 vec3 illustration=texture(decal,clamp(UV2,vec2(.002),vec2(.998))).rgb;
 float grain=clamp(.57+dot(metal,vec3(.58,1.1,.22)),.52,1.2);
 float panel=smoothstep(.15,.29,UV2.x)*(1.0-smoothstep(.77,.90,UV2.x))*smoothstep(.02,.15,UV2.y)*(1.0-smoothstep(.70,.89,UV2.y));
 float paint=panel*ink;
 ALBEDO=mix(metal,illustration*tone.rgb*grain+.09*metal,paint);
 NORMAL_MAP=texture(surface_detail,UV).xyz;
 AO=surface.r;
 ROUGHNESS=mix(clamp(surface.g,.28,.90),.40,paint);
 METALLIC=mix(surface.b,.32,paint);
}
