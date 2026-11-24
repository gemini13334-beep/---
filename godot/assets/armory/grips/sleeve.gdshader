shader_type spatial;
render_mode cull_disabled;

uniform sampler2D cloth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D weave : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color;
uniform vec3 elbow_local;
uniform vec3 elbow_view;

void vertex() {
 // UV.y runs from the tailored cuff to the upper, open end of the sleeve.
 // The wrist follows the hand animation; the upper arm belongs to the body.
 vec3 resting_end = (MODELVIEW_MATRIX * vec4(elbow_local, 1.)).xyz;
 vec3 pull = inverse(mat3(MODELVIEW_MATRIX)) * (elbow_view - resting_end);
 VERTEX += pull * smoothstep(0., .96, UV.y);
}
void fragment() {
 ALBEDO = texture(cloth, UV).rgb * tint.rgb;
 NORMAL_MAP = texture(weave, UV).rgb;
 NORMAL_MAP_DEPTH = .35;
 ROUGHNESS = .85;
}
