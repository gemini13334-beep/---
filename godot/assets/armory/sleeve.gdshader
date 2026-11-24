shader_type spatial;
render_mode world_vertex_coords;
uniform sampler2D fabric : source_color, filter_linear_mipmap_anisotropic;
void vertex() {
 // First-person shoulder anchors stay below the near edge as the wrists animate.
 // Authored weights are zero at the wrists and fingertips.
 float elbow=COLOR.r;
 VERTEX.y-=elbow*.36;
 VERTEX.x+=mix(.034,-.045,COLOR.g)*elbow;
}
void fragment() {
 vec3 cloth=texture(fabric,UV).rgb;
 ALBEDO=cloth;
 ROUGHNESS=.83;
}
