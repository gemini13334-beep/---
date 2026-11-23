extends Node3D

const MODEL = preload("res://assets/patrol/unit.glb")
const AimSurface = preload("res://scripts/aim_surface.gd")
const HEAVY_PLATES = preload("res://assets/patrol/heavy.jpg")
const HEAVY_HELMET = preload("res://assets/patrol/heavy-helmet.jpg")
const BODY_BOUNDS := AABB(Vector3(-0.95,-0.25,-1.0), Vector3(1.9,2.65,2.0))
const STRIDE_METRES := [1.48, 2.07, 1.62]
static var surfaces := {}
var kind := 0
var skeleton: Skeleton3D
var animator: AnimationPlayer
var pieces: Array[MeshInstance3D] = []
var bind_indices := PackedInt32Array()
var inverse_bind: Array[Transform3D] = []
var locomotion: StringName
var moving := false

func _ready() -> void:
 var model := MODEL.instantiate()
 add_child(model)
 skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
 animator = model.find_children("*", "AnimationPlayer", true, false)[0]
 animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 scale = [Vector3.ONE,Vector3(.92,.97,.92),Vector3(1.10,1.055,1.10)][kind]
 for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
  if kind == 1 and part.name in [&"Helmet", &"Plates"]:
   part.hide()
   continue
  if kind == 2 and part.name in [&"Vest", &"Plates", &"Helmet"]:
   var material: StandardMaterial3D = part.get_active_material(0).duplicate()
   material.albedo_texture = HEAVY_HELMET if part.name == &"Helmet" else HEAVY_PLATES
   part.material_override = material
  pieces.append(part)
  if not surfaces.has(part.mesh):
   surfaces[part.mesh] = AimSurface.new(part.mesh)
 var skin := pieces[0].skin
 for i in skin.get_bind_count():
  var name_in_skin := skin.get_bind_name(i)
  bind_indices.append(skeleton.find_bone(name_in_skin) if name_in_skin != &"" else skin.get_bind_bone(i))
  inverse_bind.append(skin.get_bind_pose(i))
 locomotion = &"run" if kind == 1 else &"walk"
 for clip in [&"walk", &"run", &"idle"]:
  animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
 animator.play(&"idle")
 animator.seek(randf() * animator.current_animation_length, true)

func advance(delta: float, distance: float) -> void:
 var walking := distance > 0.0001
 if walking != moving:
  moving = walking
  animator.play(locomotion if moving else &"idle", 0.12)
 var step: float = distance * animator.current_animation_length / STRIDE_METRES[kind] if moving else delta
 animator.advance(step)

func intersect_shot(origin: Vector3, end: Vector3) -> Variant:
 var start := skeleton.to_local(origin)
 var finish := skeleton.to_local(end)
 if BODY_BOUNDS.intersects_segment(start, finish) == null: return null
 var pose: Array[Transform3D] = []
 for i in bind_indices.size():
  pose.append(skeleton.get_bone_global_pose(bind_indices[i]) * inverse_bind[i])
 var nearest = null
 for part in pieces:
  var point = surfaces[part.mesh].intersect(start, finish, pose)
  if point != null:
   nearest = point
   finish = point
 return skeleton.to_global(nearest) if nearest != null else null
