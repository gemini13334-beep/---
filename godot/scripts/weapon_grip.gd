extends Node3D

var skeleton: Skeleton3D
var joint: int
var socket_local: Transform3D
var glove: MeshInstance3D
var release_shape: int
var support_hand: bool
var pistol_support: bool

func configure(rig: Skeleton3D, bone: int, contact: Transform3D, surface: MeshInstance3D, elbow: Vector3, support: bool, pistol: bool) -> void:
 skeleton = rig
 joint = bone
 support_hand = support
 pistol_support = support and pistol
 socket_local = _joint_frame().affine_inverse() * contact
 glove = surface
 glove.reparent(self, false)
 glove.extra_cull_margin = .65
 for i in glove.mesh.get_surface_count():
  var original: StandardMaterial3D = glove.mesh.surface_get_material(i)
  if original.resource_name == "Ripstop":
   var sleeve := ShaderMaterial.new()
   sleeve.shader = preload("res://assets/armory/grips/sleeve.gdshader")
   sleeve.set_shader_parameter("cloth", original.albedo_texture)
   sleeve.set_shader_parameter("weave", original.normal_texture)
   sleeve.set_shader_parameter("tint", original.albedo_color)
   sleeve.set_shader_parameter("elbow_local", elbow)
   sleeve.set_shader_parameter("elbow_view", Vector3(-.15 if support else .23, -.28, .025))
   glove.set_surface_override_material(i, sleeve)
 release_shape = glove.find_blend_shape_by_name("Release")
 update_pose(0.0)

func _joint_frame() -> Transform3D:
 return skeleton.global_transform * skeleton.get_bone_global_pose(joint)

func update_pose(release: float) -> void:
 global_transform = _joint_frame() * socket_local
 if pistol_support:
  translate_object_local(Vector3(-.035, -.073, .041) * release)
 if support_hand and release_shape >= 0:
  glove.set_blend_shape_value(release_shape, release)
