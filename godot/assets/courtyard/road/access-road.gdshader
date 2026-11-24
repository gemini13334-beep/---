shader_type spatial;

uniform sampler2D paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D masks : filter_linear_mipmap, repeat_enable;

varying vec2 ground;

void vertex() {
 ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
 vec2 stones_uv = ground * .26;
 vec2 road_uv = ground * .37;
 vec2 patch = texture(masks, ground * .074).rg;
 float grain = texture(masks, road_uv).r;
 float edge = abs(ground.x) + (patch.y - .5) * .65;
 float road = 1.0 - smoothstep(3.32, 3.52, edge);
 float wet = smoothstep(.57, .78, patch.y) * road;
 vec3 stone = texture(paving, stones_uv).rgb * vec3(.57,.52,.45);
 vec3 tar = texture(asphalt, road_uv).rgb * mix(.67, .37, wet);
 // Faded lane edges and the stop bar at the checkpoint share the wear mask.
 float stripe = 1.0 - smoothstep(.043, .067, abs(abs(ground.x) - 3.04));
 float stop_bar = (1.0 - smoothstep(.105, .125, abs(ground.y + 14.8))) * (1.0 - smoothstep(2.91,2.95,abs(ground.x)));
 float paint = max(stripe, stop_bar) * smoothstep(.22,.74,grain) * .69;
 tar = mix(tar, vec3(.63,.49,.28), paint);
 ALBEDO = mix(stone, tar, road);
 NORMAL_MAP = mix(texture(paving_normal, stones_uv).rgb, texture(asphalt_normal, road_uv).rgb, road);
 NORMAL_MAP_DEPTH = mix(.61, .14, wet);
 SPECULAR = mix(.18, .24, wet);
 ROUGHNESS = mix(.9, mix(clamp(grain,.72,.96), .45, wet), road);
}
