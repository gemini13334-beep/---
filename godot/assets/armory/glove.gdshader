shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D leather : source_color, filter_linear_mipmap_anisotropic;
uniform bool right_hand;
void vertex(){
 // Carry the photographed sleeve below the viewport even during a raised wrist pose.
 VERTEX.y-=.32*smoothstep(.67,1.,UV.y);
 if(right_hand){
  float sleeve=smoothstep(.70,1.,UV.x);
  VERTEX.x+=.30*sleeve;
  VERTEX.y-=.15*sleeve;
 }
}
void fragment(){
 vec4 pixel=texture(leather,UV);
 ALBEDO=pixel.rgb;
 ALPHA=pixel.a;
 ALPHA_SCISSOR_THRESHOLD=.42;
}
