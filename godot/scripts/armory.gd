extends SubViewportContainer

const MODELS := ["cordon","iskra","vizir","shtorm","bastion"]
const PATTERNS := [0,5,2,2,4,5,0,4,1,3,1,5,0,4,1,3,2,5]
const TONES := ["#818a92","#ba9c70","#a3aeab","#93d4ed","#50e6bf","#ffc077","#8c9bd4","#bca4ea","#eacfb5","#ffdd87","#f48780","#e9e6ff","#8c9489","#77b18a","#efae88","#f4cc86","#adc8e2","#ffc679"]
var stage := SubViewport.new()
var camera := Camera3D.new()
var mount := Node3D.new()
var model:Node3D
var animation:AnimationPlayer
var skeleton:Skeleton3D
var muzzle := -1

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
 studio(stage)

static func studio(parent:Node)->void:
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
  parent.add_child(lamp)

static func assemble(index:int,skin:int,show_hands:bool)->Node3D:
 var actor:Node3D=load("res://assets/armory/%s.glb"%MODELS[index]).instantiate()
 for node in actor.find_children("*","MeshInstance3D",true,false):
  if node.name.begins_with("Sleeve"):
   node.visible=show_hands
   if show_hands:
    var sleeve:=ShaderMaterial.new()
    sleeve.shader=preload("res://assets/armory/sleeve.gdshader")
    sleeve.set_shader_parameter("fabric",node.mesh.surface_get_material(0).albedo_texture)
    node.material_override=sleeve
  elif skin>=0:
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
 model=assemble(index,skin,true)
 mount.add_child(model)
 skeleton=model.find_children("*","Skeleton3D",true,false)[0]
 muzzle=skeleton.find_bone("BarrelTip")
 animation=model.find_children("*","AnimationPlayer",true,false)[0]
 animation.get_animation("idle").loop_mode=Animation.LOOP_LINEAR
 animation.play("idle")
 animation.advance(0)
 mount.position=Vector3(.052,-.010,-.052)

func gesture(clip:String,duration:float)->void:
 if not animation: return
 animation.stop()
 animation.play(clip,.025,animation.get_animation(clip).length/maxf(.05,duration))
 animation.queue("idle")

func pose(kick:float,phase:float)->void:
 mount.rotation.x=kick*.85
 mount.position.y=-.010+sin(phase*2.4)*.0016
 mount.position.z=-.052+kick*.22

func muzzle_pixel()->Vector2:
 var point:=skeleton.to_global(skeleton.get_bone_global_pose(muzzle).origin)
 return camera.unproject_position(point)*size/Vector2(stage.size)
