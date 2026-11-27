shader_type spatial;
render_mode diffuse_burley;

uniform int biome = 0;
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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
		vec3 slate = texture(ground_detail,turn * p * 0.29).rgb;
		float moss = smoothstep(0.20, 0.62, broad * 0.60 + grains * 0.40);
		surface = mix(surface * 0.68,surface * vec3(0.72,1.13,0.58) + vec3(0.011,0.029,0.009),moss);
		surface = mix(surface,slate * vec3(1.18,1.14,1.11),path * 0.98);
		float canopy = noise2(p * vec2(0.27, 0.44) + vec2(11.2, 7.1));
		float sunlight = smoothstep(0.26, 0.70, canopy * 0.73 + broad * 0.27 + path * 0.10);
		surface *= mix(vec3(0.63,0.73,0.81),vec3(1.29,1.16,1.02),sunlight);
		relief = dot(mix(soil,slate,path),vec3(0.21,0.72,0.07));
	} else if (biome == 1) {
		float center = p.x + p.y * 0.18;
		float cross_street = abs(p.y-34.0);
		float street = min(abs(center),cross_street);
		float road = 1.0-smoothstep(3.15,4.3,street+grains*0.42);
		float shoulder = 1.0-smoothstep(0.12,0.46,abs(street-4.1)+grains*0.13);
		float stripe = (1.0-smoothstep(0.055,0.12,street)) * step(0.47,fract((cross_street < abs(center) ? p.x : p.y)*0.24))
			* smoothstep(0.25,0.57,grains);
		vec4 asphalt = texture(ground_detail,p*0.37+warp*0.25);
		vec3 pavement = surface*vec3(0.70,0.77,0.83);
		float clean = road*mix(0.57,0.93,broad);
		surface = mix(pavement,asphalt.rgb*vec3(0.65,0.72,0.78),clean);
		surface = mix(surface,pavement*1.38+vec3(0.018,0.024,0.026),shoulder*0.67);
		surface = mix(surface,vec3(0.50,0.34,0.11),stripe*0.74);
		relief = mix(relief,asphalt.a,clean*0.62);
		normal_strength = 0.031;
	} else if (biome == 2) {
		float wind = noise2(p*vec2(0.090,0.17)+vec2(0.2,2.8));
		float dry_wash = abs(p.x+sin(p.y*0.072)*11.3+p.y*0.24+6.4);
		float dust = smoothstep(0.29,0.63,wind*0.74+broad*0.26) * smoothstep(1.6,5.4,dry_wash);
		vec4 dune = texture(ground_detail,turn*p*vec2(0.34,0.52)+warp*0.42);
		vec3 rock = surface*vec3(0.84,0.75,0.70);
		surface = mix(rock,dune.rgb*vec3(1.24,1.03,0.77),dust);
		surface = mix(surface,rock*vec3(0.76,0.85,0.94),1.0-smoothstep(0.45,2.30,dry_wash+grains));
		relief = mix(relief,dune.a,dust*0.75);
		roughness = 0.92;
		normal_strength = 0.035;
	} else if (biome == 3) {
		float shelf = p.x-sin(p.y*0.061)*12.0-p.y*0.17+11.0;
		float wind = noise2(p*vec2(0.10,0.18)+vec2(14.0,4.0));
		float drifts = smoothstep(0.32,0.67,wind*0.66+broad*0.34) * smoothstep(2.4,9.6,abs(shelf)+grains*1.5);
		float fracture = abs(shelf+sin(p.y*0.39)*0.32+grains*0.19);
		float vein = 1.0-smoothstep(0.065,0.29,fracture);
		vec4 snow = texture(ground_detail,turn*p*0.32+warp*0.38);
		vec3 ice = surface*vec3(0.48,0.70,0.84);
		surface = mix(ice,snow.rgb*vec3(0.79,0.91,0.97),drifts*0.94);
		surface = mix(surface,vec3(0.025,0.082,0.12),vein*0.57);
		relief = mix(relief,snow.a,drifts*0.72);
		roughness = mix(0.38,0.94,drifts);
		normal_strength = 0.018;
	} else {
		float fissure = p.x-cos(p.y*0.078)*9.0+p.y*0.29-10.0;
		float channel = abs(fissure+sin(p.y*0.31)*0.88+(broad-0.5)*1.8);
		float ash = smoothstep(0.27,0.70,broad);
		vec4 basalt = texture(ground_detail,turn*p*0.20+warp*0.41);
		vec3 scorched = surface*vec3(0.73,0.52,0.49);
		surface = mix(basalt.rgb*vec3(0.69,0.71,0.78),scorched,ash*0.49);
		float seam = abs(sin(p.y*0.52+p.x*0.40)+sin(p.x*0.31-p.y*0.12)*0.51);
		float local_heat = (1.0-smoothstep(0.018,0.071,seam))*(1.0-smoothstep(1.4,7.0,channel));
		float glow = (1.0-smoothstep(0.28,0.76,channel))*(0.76+0.24*sin(p.y*1.2-TIME*0.9+grains));
		float bank = 1.0-smoothstep(0.65,2.1,channel);
		surface = mix(surface,vec3(0.35,0.050,0.013),bank*0.52);
		EMISSION = vec3(1.0,0.22,0.029)*(glow*0.83+local_heat*0.32+bank*0.10);
		relief = mix(basalt.a,relief,ash*0.49);
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
