shader_type canvas_item;
render_mode unshaded;

uniform sampler2D silhouette : filter_linear, repeat_disable;
uniform float phase = 0.0;

void fragment() {
 vec2 uv = UV;
 float chest = 1.0 - smoothstep(0.35, 0.92, uv.y);
 float head = 1.0 - smoothstep(0.19, 0.34, uv.y);
 float breath = sin(phase * 1.62);
 float shift = sin(phase * 0.79);
 vec2 motion = vec2(0.0036 * shift * chest + 0.0014 * sin(phase * 0.51) * head,
                    -0.0052 * breath * chest);
 motion.x += (uv.x - 0.533) * breath * 0.016 * chest;
 // A slow head turn leads the shoulders, with a small lift at the visor.
 float glance = sin(phase * 0.66) * sin(phase * 0.32);
 motion.x += head * (0.0032 * glance + (uv.y - 0.15) * 0.014 * glance);
 motion.y += head * (uv.x - 0.536) * 0.038 * glance;
 vec2 source = uv - motion;
 vec3 background_sample = texture(silhouette, uv).rgb;
 vec2 edge = (background_sample.gb * 255.0 - 128.0) * 0.25 / vec2(800.0, 450.0);
 vec4 background = texture(TEXTURE, uv + edge * background_sample.r);
 float foreground = texture(silhouette, source).r;
 vec4 portrait = mix(background, texture(TEXTURE, source), foreground);
 float luma = dot(portrait.rgb, vec3(0.299,0.587,0.114));
 portrait.rgb = mix(vec3(luma),portrait.rgb,0.86) * vec3(1.025,0.97,0.89);
 COLOR = portrait;
}
