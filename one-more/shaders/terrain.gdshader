shader_type spatial;
render_mode diffuse_burley;

uniform int biome = 0;
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_slate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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

vec2 mirrored(vec2 uv) {
	return 1.0 - abs(fract(uv * 0.5) * 2.0 - 1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = noise2(p * 0.19);
	float grains = noise2(p * 2.3);
	float trail = abs(p.x - sin(p.y * 0.107) * 5.4 + p.y * 0.20);
	float path = 1.0 - smoothstep(1.05 + grains * 0.63, 2.28 + grains * 0.63, trail);
	mat2 turn = mat2(vec2(0.86,0.51),vec2(-0.51,0.86));
	vec2 warp = vec2(broad,noise2(p*0.17+vec2(7.2,2.6)))*0.31;
	vec3 soil = texture(ground_albedo,mirrored(turn*p*0.27+warp+vec2(0.37,0.25))).rgb;
	vec3 alternate = texture(ground_albedo,mirrored(p*0.184-warp+vec2(0.14,0.71))).rgb;
	vec3 surface = mix(soil,alternate,mix(0.27,0.73,smoothstep(0.22,0.80,broad)));
	float roughness = 0.81;
	float relief = dot(surface,vec3(0.2126,0.7152,0.0722));
	float normal_strength = 0.030;
	EMISSION = vec3(0.0);

	if (biome == 0) {
		vec3 slate = texture(forest_slate,turn * p * 0.29).rgb;
		float moss = smoothstep(0.20, 0.62, broad * 0.60 + grains * 0.40);
		surface = mix(surface * 0.68,surface * vec3(0.72,1.13,0.58) + vec3(0.011,0.029,0.009),moss);
		surface = mix(surface,slate * vec3(1.18,1.14,1.11),path * 0.98);
		float canopy = noise2(p * vec2(0.27, 0.44) + vec2(11.2, 7.1));
		float sunlight = smoothstep(0.26, 0.70, canopy * 0.73 + broad * 0.27 + path * 0.10);
		surface *= mix(vec3(0.63,0.73,0.81),vec3(1.29,1.16,1.02),sunlight);
		relief = dot(mix(soil,slate,path),vec3(0.21,0.72,0.07));
	} else if (biome == 1) {
		float center = p.x + p.y * 0.18;
		float road = 1.0 - smoothstep(2.4,4.7,abs(center)+grains*0.56);
		float shoulder = 1.0 - smoothstep(0.11,0.31,abs(abs(center)-3.30+grains*0.15));
		float stripe = (1.0-smoothstep(0.06,0.15,abs(center)))
			* step(0.50,fract(p.y*0.26)) * smoothstep(0.31,0.57,grains);
		surface *= mix(vec3(0.79,0.87,0.96),vec3(0.53,0.57,0.61),road);
		surface = mix(surface,surface*1.51+vec3(0.019,0.026,0.028),shoulder*0.52);
		surface = mix(surface,vec3(0.35,0.25,0.10),stripe*0.60);
		normal_strength = 0.031;
	} else if (biome == 2) {
		float erosion = noise2(p * vec2(0.23,0.10) + vec2(0.2,2.8));
		float dust = smoothstep(0.43,0.80,erosion+path*0.14);
		float ripples = sin(p.y*7.1+p.x*2.4 + grains*1.8);
		surface *= mix(vec3(0.83,0.71,0.63),vec3(1.19,1.14,1.03),dust);
		surface *= 1.0+ripples*dust*0.075;
		roughness = 0.92;
		normal_strength = 0.039;
	} else if (biome == 3) {
		float drifts = smoothstep(0.55,0.84,noise2(p * vec2(0.12,0.24) + vec2(14.0,4.0)));
		float ice = smoothstep(0.26,0.58,broad);
		float fracture = abs(p.x+sin(p.y*0.19)*2.1+p.y*0.35-8.0+grains*0.35);
		float vein = 1.0-smoothstep(0.046,0.25,fracture);
		surface *= mix(vec3(0.78,0.93,1.05),vec3(0.60,0.83,1.09),ice);
		surface = mix(surface,vec3(0.53,0.67,0.72),drifts*0.46);
		surface = mix(surface,vec3(0.035,0.10,0.16),vein*0.56);
		roughness = mix(0.70,0.33,ice*(1.0-drifts));
		normal_strength = 0.018;
	} else {
		float crust = sin(p.y*0.14+p.x*0.22)+sin(p.x*0.11-p.y*0.10)*0.75;
		float seam = abs(crust+noise2(p*0.47)*0.26-0.24);
		float heat = (1.0-smoothstep(0.020,0.087,seam)) * smoothstep(0.36,0.64,broad);
		float ember = (1.0-smoothstep(0.003,0.028,seam)) * step(0.62,grains);
		surface *= mix(vec3(0.68,0.72,0.82),vec3(1.12,0.76,0.55),broad);
		surface = mix(surface,vec3(0.28,0.064,0.017),heat*0.53);
		EMISSION = vec3(0.90,0.16,0.018)*(heat*0.17+ember*0.13);
		normal_strength = 0.044;
	}
	vec3 dp_x = dFdx(VERTEX);
	vec3 dp_y = dFdy(VERTEX);
	vec3 perpendicular_y = cross(dp_y,NORMAL);
	vec3 perpendicular_x = cross(NORMAL,dp_x);
	float determinant = dot(dp_x,perpendicular_y);
	vec3 gradient = sign(determinant) * (dFdx(relief)*perpendicular_y + dFdy(relief)*perpendicular_x);
	NORMAL = normalize(max(abs(determinant),0.000001)*NORMAL - normal_strength*gradient);
	ALBEDO = surface;
	ROUGHNESS = roughness;
}
