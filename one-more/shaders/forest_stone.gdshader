shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D stone_surface : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.78, 0.76, 0.70, 1.0);
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(normalize(world_normal)), vec3(5.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = world_pos * 0.73;
	vec3 stone = texture(stone_surface, p.zy).rgb * weights.x;
	stone += texture(stone_surface, p.xz).rgb * weights.y;
	stone += texture(stone_surface, p.xy).rgb * weights.z;
	ALBEDO = stone * tint.rgb;
	ROUGHNESS = 0.77;
	SPECULAR = 0.24;
}
