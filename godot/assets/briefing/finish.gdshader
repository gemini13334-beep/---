shader_type canvas_item;

uniform vec4 finish : source_color = vec4(1.0);
uniform int pattern = 0;
uniform bool equipped = false;

void fragment() {
 vec4 art = texture(TEXTURE, UV);
 if (equipped) {
  // Keep the hands and the cuffs in their original colours.
  float face = 1.0 - smoothstep(0.06, 0.22, abs(UV.y - 0.61 * UV.x - 0.12));
  float line = fract(UV.x * 14.0 + UV.y * float(pattern + 1) * 3.0);
  float stripe = smoothstep(0.68, 0.73, line);
  vec3 paint = finish.rgb * (0.24 + dot(art.rgb, vec3(0.299,0.587,0.114))) * (1.0 + stripe * 0.3);
  art.rgb = mix(art.rgb, paint, face * 0.85);
 }
 COLOR = art;
}
