extends Node3D

var skeleton: Skeleton3D
var joint: int
var socket_local: Transform3D
var glove: MeshInstance3D
var release_shape: int
var support_hand: bool
var pistol_support: bool

func configure(rig: Skeleton3D, bone: int, contact: Transform3D, surface: MeshInstance3D, support: bool, pistol: bool) -> void:
 skeleton = rig
 joint = bone
 support_hand = support
 pistol_support = support and pistol
 socket_local = _joint_frame().affine_inverse() * contact
 glove = surface
 glove.reparent(self, false)
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
