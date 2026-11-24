extends SubViewportContainer

const MODELS := ["cordon","iskra","vizir","shtorm","bastion"]
const PATTERNS := [0,5,2,2,4,5,0,4,1,3,1,5,0,4,1,3,2,5]
const TONES := ["#818a92","#ba9c70","#a3aeab","#93d4ed","#50e6bf","#ffc077","#8c9bd4","#bca4ea","#eacfb5","#ffdd87","#f48780","#e9e6ff","#8c9489","#77b18a","#efae88","#f4cc86","#adc8e2","#ffc679"]
# Model-space grip sockets in the imported idle pose and their baked length scales.
const GRIPS := [Vector3(.139,-.221,-.264),Vector3(.135,-.184,-.259),Vector3(.104,-.224,-.212),Vector3(.120,-.226,-.298),Vector3(.139,-.221,-.264)]
const BAKED_SCALES := [.87,1.29,.82,.84,.86]
# Support contacts are relative to the main socket in unscaled asset units.
const SUPPORTS := [Vector3(0,.099,-.280),Vector3.ZERO,Vector3(0,.042,-.325),Vector3(0,.017,-.440),Vector3(.001,.110,-.291)]

var stage := SubViewport.new()
var camera := Camera3D.new()
var mount := Node3D.new()
var model:Node3D
var animation:AnimationPlayer
var skeleton:Skeleton3D
var muzzle := -1
const WeaponGrip = preload("res://scripts/weapon_grip.gd")
var gloves: Array[WeaponGrip] = []

func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 stretch=true
 stage.own_world_3d=true
 stage.transparent_bg=true
 stage.msaa_3d=Viewport.MSAA_2X
 stage.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE
 add_child(stage)
 stage.add_child(camera)
 camera.near=.015
 camera.fov=60
 stage.add_child(mount)
 studio(stage, true)

static func studio(parent:Node, contact_shadows:bool = false)->void:
 var world:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.sky=Sky.new()
 var sky_material:=PanoramaSkyMaterial.new()
 sky_material.panorama=preload("res://assets/courtyard/clouds.webp")
 env.sky.sky_material=sky_material
 env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("#e3e9f2")
 env.ambient_light_energy=.78
 world.environment=env
 parent.add_child(world)
 for spec in [[Vector3(-38,36,0),1.3,Color("#ffead6")],[Vector3(-18,-120,0),.85,Color("#c0d6ee")]]:
  var lamp:=DirectionalLight3D.new()
  lamp.rotation_degrees=spec[0]
  lamp.light_energy=spec[1]
  lamp.light_color=spec[2]
  if contact_shadows and spec[1] > 1.0:
   lamp.shadow_enabled = true
   lamp.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
   lamp.directional_shadow_max_distance = 2.2
   lamp.shadow_bias = .025
   lamp.shadow_normal_bias = .18
  parent.add_child(lamp)

static func assemble(index:int,skin:int)->Node3D:
 var actor:Node3D=load("res://assets/armory/%s.glb"%MODELS[index]).instantiate()
 if skin<0:return actor
 for node in actor.find_children("*","MeshInstance3D",true,false):
  var original:StandardMaterial3D=node.mesh.surface_get_material(0)
  if node.name.begins_with("Scope") or original.resource_name.ends_with("_optic"): continue
  var finish:=ShaderMaterial.new()
  finish.shader=preload("res://assets/armory/enamel.gdshader")
  finish.set_shader_parameter("steel",original.albedo_texture)
  finish.set_shader_parameter("surface_detail",original.normal_texture)
  finish.set_shader_parameter("orm",original.roughness_texture if original.roughness_texture else original.get("orm_texture"))
  finish.set_shader_parameter("decal",load("res://assets/armory/finish-%d.webp"%PATTERNS[skin]))
  finish.set_shader_parameter("tone",Color(TONES[skin]))
  finish.set_shader_parameter("ink",.48 if skin<3 or skin==12 else .86)
  node.material_override=finish
 return actor

func equip(index:int,skin:int)->void:
 if model:
  mount.remove_child(model)
  model.queue_free()
 for hand in gloves:
  hand.hide()
  hand.queue_free()
 gloves.clear()
 model=assemble(index,skin)
 mount.add_child(model)
 skeleton=model.find_children("*","Skeleton3D",true,false)[0]
 muzzle=skeleton.find_bone("BarrelTip")
 animation=model.find_children("*","AnimationPlayer",true,false)[0]
 animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 animation.get_animation("idle").loop_mode=Animation.LOOP_LINEAR
 animation.play("idle")
 animation.advance(0)
 mount.position=Vector3(.126,.034,-.172)
 # Keep the main contact fixed while returning all five imports to the same
 # unit scale. This also scales animated travel and the muzzle bone together.
 var socket:Vector3 = GRIPS[index]
 var model_scale:float = 1.0 / BAKED_SCALES[index]
 model.scale = Vector3.ONE * model_scale
 model.position = socket * (1.0 - model_scale)
 var primary := model.to_global(socket)
 var pair:Node3D = load("res://assets/armory/grips/%s.glb" % MODELS[index]).instantiate()
 stage.add_child(pair)
 for left:bool in [false,true]:
  var names := ["L_palm","l_Hand"] if left and index != 1 else ["gun","r_hand"]
  var joint := skeleton.find_bone(names[0])
  if joint < 0:joint = skeleton.find_bone(names[1])
  var point := primary
  if left:
   point += mount.global_transform.basis * SUPPORTS[index]
  var contact := Transform3D(mount.global_transform.basis.orthonormalized(), point)
  var hand := WeaponGrip.new()
  stage.add_child(hand)
  hand.configure(skeleton, joint, contact, pair.get_node("Left" if left else "Right"), left, index == 1)
  gloves.append(hand)
 pair.queue_free()

func _process(delta:float)->void:
 if not animation or not is_visible_in_tree():return
 animation.advance(delta)
 var release := 0.0
 if animation.current_animation == "reload":
  var progress := animation.current_animation_position / animation.current_animation_length
  release = smoothstep(.10, .35, progress) * (1.0 - smoothstep(.60, .87, progress))
 for hand in gloves:hand.update_pose(release)

func gesture(clip:String,duration:float)->void:
 if not animation: return
 animation.stop()
 animation.play(clip,.025,animation.get_animation(clip).length/maxf(.05,duration))
 animation.queue("idle")

func pose(kick:float,phase:float)->void:
 mount.rotation.x=kick*.85
 mount.rotation.y=.060
 mount.position.y=.034+sin(phase*2.4)*.0016
 mount.position.z=-.172+kick*.22

func muzzle_pixel()->Vector2:
 var point:=skeleton.to_global(skeleton.get_bone_global_pose(muzzle).origin)
 return camera.unproject_position(point)*size/Vector2(stage.size)
