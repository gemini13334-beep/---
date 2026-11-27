shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform int biome;
uniform vec4 tint : source_color = vec4(1.0);

float elevation(vec2 p) {
	float softly = sin(p.x*0.14+p.y*0.066)*sin(p.y*0.15-p.x*0.047);
	float ridges = sin(p.y*0.081+p.x*0.13)*cos(p.x*0.057-p.y*0.08);
	if (biome == 0) {
		float track = sin(p.y*0.107)*5.4-p.y*0.20;
		return (softly*0.51+ridges*0.24)*mix(0.40,1.0,smoothstep(2.4,11.0,abs(p.x-track)));
	}
	if (biome == 1) {
		return softly*0.56*smoothstep(2.2,8.5,abs(p.x+p.y*0.18))+ridges*0.14;
	}
	if (biome == 2) {
		return softly*0.68+ridges*0.86;
	}
	if (biome == 3) {
		return softly*0.63+ridges*0.37;
	}
	return softly*0.81+ridges*0.42;
}

void vertex() {
	vec2 p = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
	vec2 center = MODEL_MATRIX[3].xz;
	VERTEX.y += (elevation(p)-elevation(center))/max(0.001,length(MODEL_MATRIX[1].xyz));
}

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
