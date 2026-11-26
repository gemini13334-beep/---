shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.16, 0.29, 0.22, 1.0);
uniform vec4 second_color : source_color = vec4(0.24, 0.43, 0.30, 1.0);
uniform vec4 path_color : source_color = vec4(0.39, 0.33, 0.24, 1.0);
uniform int biome = 0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	vec3 q = fract(p.xyx * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = noise2(p * 0.24);
	float texture_detail = noise2(p * 2.3);
	float edge = texture_detail * 0.7;
	float track = abs(p.x - sin(p.y * 0.21) * 2.4 + p.y * 0.28);
	float path = 1.0 - smoothstep(0.58 + edge, 1.85 + edge, track);
	vec3 surface = mix(base_color.rgb, second_color.rgb, smoothstep(0.2, 0.83, broad));
	surface *= 0.78 + 0.39 * texture_detail;

	if (biome == 0) {
		float moss = smoothstep(0.32, 0.66, broad * 0.7 + texture_detail * 0.3);
		surface = mix(surface, surface * vec3(1.16, 1.44, 0.90), moss * (1.0 - path));
		surface = mix(surface, path_color.rgb * (0.73 + 0.32 * texture_detail), path * 0.85);
	} else if (biome == 1) {
		vec2 slab = abs(fract(p * vec2(0.42, 0.27) + vec2(mod(floor(p.y * 0.27), 2.0) * 0.5, 0.0)) - 0.5);
		float seam = smoothstep(0.455, 0.49, max(slab.x, slab.y));
		surface *= 1.0 - seam * 0.53;
	} else if (biome == 2) {
		float ripple = sin(p.y * 8.1 + p.x * 2.1 + texture_detail * 1.35);
		surface *= 1.0 + ripple * 0.09 * (1.0 - path);
	} else if (biome == 3) {
		float ice = smoothstep(0.42, 0.61, broad + texture_detail * 0.14);
		surface = mix(surface, path_color.rgb, 0.40 * ice);
	} else {
		float hot_cracks = 1.0 - smoothstep(0.005, 0.028, abs(broad - 0.43 + texture_detail * 0.11));
		surface = mix(surface, path_color.rgb, hot_cracks * 0.22);
	}

	vec2 cell = floor(p * 2.6);
	vec2 pebble_pos = fract(p * 2.6) - vec2(0.5);
	pebble_pos -= vec2(hash(cell), hash(cell + vec2(4, 9))) * 0.56 - 0.28;
	float stone = (1.0 - smoothstep(0.08, 0.21, length(pebble_pos * vec2(0.75, 1.4))))
		* step(0.71, hash(cell + vec2(8, 3)));
	ALBEDO = mix(surface, surface * 1.25 + vec3(0.025), stone * 0.91);
	ROUGHNESS = mix(0.90, 0.69, stone);
}
