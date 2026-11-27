shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D palette : source_color, filter_linear_mipmap;
uniform sampler2D worn_concrete : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float wear_amount : hint_range(0.0,1.0) = 0.55;
varying vec3 world_position;
varying vec3 world_normal;
varying float object_height;

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
	object_height = VERTEX.y;
}

void fragment() {
	vec3 paint = texture(palette,UV).rgb;
	vec3 weights = abs(world_normal);
	weights = weights*weights;
	weights /= max(dot(weights,vec3(1.0)),0.001);
	vec3 p = world_position*0.39;
	vec3 texture_value = texture(worn_concrete,p.zy).rgb*weights.x;
	texture_value += texture(worn_concrete,p.xz).rgb*weights.y;
	texture_value += texture(worn_concrete,p.xy).rgb*weights.z;
	float value = dot(paint,vec3(0.21,0.72,0.07));
	float detail = dot(texture_value,vec3(0.21,0.72,0.07));
	float base_stain = 1.0-smoothstep(0.03,0.64,object_height);
	vec3 muted = mix(vec3(value),paint,0.68)*vec3(0.87,0.91,0.95);
	float coat = mix(1.0,0.43+detail*1.46,wear_amount);
	ALBEDO = (muted*coat + texture_value*wear_amount*0.13)*(1.0-base_stain*0.26);
	ROUGHNESS = mix(0.58,0.91,wear_amount*0.58+base_stain*0.32);
}
