shader_type canvas_item;
render_mode unshaded;
uniform sampler2D silhouette : filter_linear, repeat_disable;
uniform sampler2D grip : filter_linear, repeat_disable;
uniform sampler2D underlay : source_color, filter_linear, repeat_disable;
uniform float phase = 0.0;

vec2 rotated(vec2 p,float a){
 float s=sin(a),c=cos(a);return vec2(c*p.x-s*p.y,s*p.x+c*p.y);
}
void fragment(){
 vec2 ratio=vec2(760.0,428.0);
 vec2 p=UV*ratio;
 float t=mod(phase,10.8);
 float lift=smoothstep(.9,2.35,t)*(1.0-smoothstep(4.75,6.2,t));
 float roll=lift*(.177+.033*sin((t-2.2)*2.1));
 vec2 pivot=vec2(375.0,241.0);
 vec2 travel=vec2(1.7,-4.7)*lift;
 // Both hands and all parts of the rifle share one rigid transform.
 vec2 gun=pivot+rotated(p-pivot-travel,roll);
 vec2 delta=gun-p;
 float breathing=sin(phase*1.53);
 float chest=(1.0-smoothstep(155.0,372.0,p.y));
 vec2 drift=vec2(.66*sin(phase*.8),-.9*breathing)*chest;
 vec2 glove_uv=(gun-drift)/ratio;
 float arm_right=1.0-smoothstep(8.0,54.0,length((p-vec2(341,220))*vec2(.88,1.21)));
 float arm_left=1.0-smoothstep(10.0,74.0,length((p-vec2(487,268))*vec2(1.03,.91)));
 vec2 body=p+delta*max(arm_right,arm_left)-drift;
 float head=1.0-smoothstep(73.0,122.0,p.y);
 body=mix(body,vec2(411,101)+rotated(body-vec2(411,101),-.045*lift)-vec2(.1,2.3)*lift,head);
 vec2 uv=body/ratio;
 vec3 mask=texture(silhouette,UV).rgb;
 vec2 edge=(mask.gb*255.0-128.0)*.25/vec2(800,450);
 vec4 back=texture(TEXTURE,UV+edge*mask.r);
 vec4 torso=texture(underlay,uv);
 vec4 result=mix(back,torso,texture(silhouette,uv).r);
 result=mix(result,texture(TEXTURE,glove_uv),texture(grip,glove_uv).r);
 // Preserve the original portrait's lobby grade.
 float luma=dot(result.rgb,vec3(.299,.587,.114));
 result.rgb=mix(vec3(luma),result.rgb,.86)*vec3(1.025,.97,.89);
 COLOR=result;
}
