extends MeshInstance3D

var rig:Skeleton3D
var finger:int
var wrist:int
var base_angle:float
var center_offset:Vector2
var finger_offset:Vector3
var depth_bias:float

func configure(skeleton_node:Skeleton3D,tip:int,wrist_bone:int,left:bool,slot:int,art:Texture2D)->void:
 rig=skeleton_node
 finger=tip
 wrist=wrist_bone
 var pixel_scale:=.00069 if left else .00048
 var pivot:=Vector2(266,90) if left else Vector2(70,83)
 var dimensions:=art.get_size()
 center_offset=(dimensions*.5-pivot)*pixel_scale
 finger_offset=Vector3(-.033,-.027,.0) if left else Vector3(-.003,.014,0)
 if slot==1:finger_offset=Vector3(.005,.023,0)
 depth_bias=.036 if left else .077
 var geometry:=QuadMesh.new()
 geometry.size=dimensions*pixel_scale
 geometry.subdivide_width=10
 geometry.subdivide_depth=10
 mesh=geometry
 var textile:=ShaderMaterial.new()
 textile.shader=preload("res://assets/armory/glove.gdshader")
 textile.set_shader_parameter("leather",art)
 textile.set_shader_parameter("right_hand",not left)
 material_override=textile
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 base_angle=_hand_angle()
 update_pose()

func _joint(id:int)->Vector3:
 return rig.to_global(rig.get_bone_global_pose(id).origin)

func _hand_angle()->float:
 var delta:=_joint(finger)-_joint(wrist)
 return atan2(delta.y,delta.x)

func update_pose()->void:
 var anchor:=_joint(finger)+finger_offset
 var twist:=clampf(angle_difference(base_angle,_hand_angle()),-.65,.65)*.68
 var center:=Vector2(center_offset.x,-center_offset.y).rotated(twist)
 var in_front:=(anchor.z+depth_bias)/minf(anchor.z,-.03)
 global_position=Vector3((anchor.x+center.x)*in_front,(anchor.y+center.y)*in_front,anchor.z+depth_bias)
 rotation.z=twist
 scale=Vector3.ONE*maxf(.1,in_front)
