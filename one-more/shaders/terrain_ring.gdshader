shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform int biome;
uniform float play_half;
uniform float floor_half;
uniform vec4 tint : source_color = vec4(1.0);

float elevation(vec2 p) {
	float softly = sin(p.x*0.14+p.y*0.066)*sin(p.y*0.15-p.x*0.047);
	float ridges = sin(p.y*0.081+p.x*0.13)*cos(p.x*0.057-p.y*0.08);
	float outskirts = smoothstep(play_half+3.0, floor_half-10.0, max(abs(p.x),abs(p.y))) * (4.3+2.0*ridges);
	if (biome == 0) {
		float track = sin(p.y*0.107)*5.4-p.y*0.20;
		return outskirts + (softly*0.51+ridges*0.24)*mix(0.40,1.0,smoothstep(2.4,11.0,abs(p.x-track)));
	}
	if (biome == 1) {
		float street = min(abs(p.x+p.y*0.18),abs(p.y-34.0));
		return outskirts + softly*0.56*smoothstep(2.2,8.5,street)+ridges*0.14;
	}
	if (biome == 2) {
		float dune = sin(p.y*0.094+sin(p.x*0.061)*1.33);
		return outskirts + softly*0.56+ridges*0.59+dune*1.25;
	}
	if (biome == 3) {
		float ridge = abs(p.x-sin(p.y*0.061)*12.0-p.y*0.17+11.0);
		return outskirts + softly*0.67+ridges*0.52+smoothstep(3.5,14.5,ridge)*1.25-1.25;
	}
	float fissure = abs(p.x-cos(p.y*0.078)*9.0+p.y*0.29-10.0);
	return outskirts + softly*0.87+ridges*0.62+smoothstep(1.5,10.0,fissure)*1.3-1.3;
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
