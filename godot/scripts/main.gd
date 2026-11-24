extends Node3D

const Story = preload("res://scripts/story.gd")
const Loot = preload("res://scripts/loot.gd")
const Briefing = preload("res://scripts/briefing.gd")
const Radar = preload("res://scripts/radar.gd")
var active_stage := 0
var preview_stage := 0
var look_touch_id := -1
var pitch := 0.0
var elapsed := 0.0
var timer_label:Label
var radar:Radar
const Armory = preload("res://scripts/armory.gd")
const Glint = preload("res://scripts/shot_glint.gd")
var foreground:Armory
var glint:Glint
var bolts:Array[MeshInstance3D]=[]
var bolt_mesh:=SphereMesh.new()
var bloom_ticks:Array[ColorRect]=[]
const CASE_ART := ["case-field","case-elite","case-vault"]
const SAVE_PATH := "user://vacation_save.json"
const SETTINGS_PATH := "user://tactical_settings.json"
var graphics_level := 1
var fps_limit := 60
var auto_fire := true
var fire_button: Button
var fire_touch_id := -1
var fire_requested := false
var stage := 0
var campaign_complete := false
var endless := false
var kills := 0
var hp := 100.0
var xp := 0
var credits := 350
var inventory: Array[int] = []
var loot_misses := 0
var cases_opened := 0
var last_drop := -1
var equipped_skins := [-1,-1,-1,-1,-1]
var last_drop_duplicate := false
var case_spin_tween: Tween
var case_spin_finished := false
var last_case_index := 0
var collection_filter := -1
var collection_page := 0
var loot_rng := RandomNumberGenerator.new()
var playing := false
var enemies: Array[Node3D] = []
var enemy_timer := 0.0
var fire_timer := 0.0
const MAGAZINE_CAPACITIES := [30,16,6,7,60]
var magazine_rounds := MAGAZINE_CAPACITIES.duplicate()
var reload_timer := 0.0
var reload_duration := 1.5
var reload_progress: ProgressBar
var ammo_label: Label
var reload_button: Button
var joystick := Vector2.ZERO
var touch_origin := Vector2.ZERO
var touch_id := -1
var joystick_base: Panel
var joystick_knob: Panel
var hud: Control
var menu_layer: Control
var page_body: Control
var status_label: Label
var hp_label: Label
var health_bar: ProgressBar
var slot_buttons:Array[Button]=[]
const Ribbon=preload("res://scripts/combat_ribbon.gd")
const ActionIcon=preload("res://scripts/action_icon.gd")
var ribbon:Ribbon
var weapon_status: Label
var kills_label: Label
const PlayerMotion=preload("res://scripts/player_motion.gd")
var hero:PlayerMotion
var stance_icon:Control
var cam: Camera3D
const Inspector = preload("res://scripts/inspector.gd")
const Registry = preload("res://scripts/registry.gd")
const StoryWing = preload("res://scripts/story_wing.gd")
var location_id := -1
var arena: Node3D
var registry: Registry
var document_label: Label
var world_root: Node3D
var weapon_index := 0
var hit_flash_timer := 0.0
var hit_marker: Label
var damage_overlay: ColorRect
var damage_flash := 0.0
var camera_kick := 0.0
const WEAPONS := [
 {"name":"АВТОМАТ «КОРДОН»", "damage":26.0, "cooldown":0.16, "range":27.0,"kick":.033},
 {"name":"ПИСТОЛЕТ «ИСКРА»", "damage":22.0, "cooldown":0.22, "range":21.0,"kick":.024},
 {"name":"КАРАБИН «ВИЗИР»", "damage":92.0, "cooldown":0.9, "range":40.0,"kick":.068},
 {"name":"ДРОБОВИК «ШТОРМ»", "damage":16.0, "cooldown":0.72, "range":15.0,"kick":.084},
 {"name":"ПУЛЕМЁТ «БАСТИОН»", "damage":21.0, "cooldown":0.125, "range":29.0,"kick":.027}
]

func _ready() -> void:
 loot_rng.randomize()
 _load()
 _load_settings()
 _apply_settings()
 _build_world()
 _build_ui()
 _show_menu()

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = name
 var mesh := BoxMesh.new()
 mesh.size = size
 node.mesh = mesh
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.roughness = 0.92
 node.material_override = mat
 node.position = pos
 parent.add_child(node)
 if solid:
  var body := StaticBody3D.new()
  node.add_child(body)
  var shape := CollisionShape3D.new()
  var box := BoxShape3D.new()
  box.size = size
  shape.shape = box
  body.add_child(shape)
 return node

func _build_world() -> void:
 world_root = Node3D.new()
 world_root.name = "Sector"
 add_child(world_root)
 hero = PlayerMotion.new()
 hero.name = "Player"
 add_child(hero)
 cam=Camera3D.new()
 cam.current=true
 cam.fov=69
 cam.near=0.04
 add_child(cam)
 _update_camera(0.0)
 _apply_settings()

# The four photographic surfaces tile in metres across the courtyard geometry.
var courtyard_materials:Dictionary={}
var marks:Array[MeshInstance3D]=[]
var impact_mesh:=QuadMesh.new()

func _surface(parent:Node3D, title:String, pos:Vector3, extent:Vector3, atlas:int, tint:Color, solid:=false)->MeshInstance3D:
 var id:=[atlas,tint]
 var part:=_box(parent,title,pos,extent,tint,solid)
 if not courtyard_materials.has(id):
  var mat:=StandardMaterial3D.new()
  mat.albedo_texture=preload("res://assets/courtyard/pavers.webp") if atlas==1 else load("res://assets/courtyard/surface-%d.webp"%atlas)
  if atlas in [0,1]:
   mat.normal_enabled=true
   mat.normal_scale=.64 if atlas==1 else .45
   mat.normal_texture=preload("res://assets/courtyard/pavers-normal.png") if atlas==1 else preload("res://assets/courtyard/surface-0-normal.png")
  mat.albedo_color=tint*Color("#c5c7c6")
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  mat.uv1_triplanar=true
  mat.uv1_world_triplanar=true
  mat.uv1_scale=Vector3.ONE*(0.66 if atlas==2 else 0.26)
  mat.roughness=0.88
  courtyard_materials[id]=mat
 part.material_override=courtyard_materials[id]
 return part

func _set_location(location: int)->void:
 if arena!=null and location==location_id: return
 marks.clear()
 location_id=location
 if arena!=null:
  world_root.remove_child(arena)
  arena.queue_free()
 registry=null
 if location>0:
  registry=Registry.new() if location==1 else StoryWing.new(location)
  arena=registry
  world_root.add_child(arena)
  registry.build()
 else:
  arena=Node3D.new()
  world_root.add_child(arena)
  _build_courtyard()
 radar.buildings.clear()
 for prop in arena.get_children():
  if prop is MeshInstance3D and prop.mesh is BoxMesh and prop.get_child_count()>0 and prop.position.y>0:
   var footprint:=Vector2(prop.mesh.size.x,prop.mesh.size.z)
   radar.buildings.append(Rect2(Vector2(prop.position.x,prop.position.z)-footprint/2,footprint))

func _build_courtyard()->void:
 var environment:=Environment.new()
 environment.background_mode=Environment.BG_SKY
 var atmosphere:=PanoramaSkyMaterial.new()
 atmosphere.panorama=preload("res://assets/courtyard/clouds.webp")
 environment.sky_rotation.y=1.6
 environment.sky=Sky.new()
 environment.sky.sky_material=atmosphere
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("#d5dfec")
 environment.ambient_light_energy=0.46
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 var world:=WorldEnvironment.new()
 world.environment=environment
 arena.add_child(world)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-47,-38,0)
 sun.light_color=Color("#fff0d7")
 sun.light_energy=0.53
 sun.shadow_enabled=true
 sun.directional_shadow_max_distance=45
 arena.add_child(sun)
 _surface(arena,"Paving",Vector3(0,-0.23,0),Vector3(41,0.46,42),1,Color("#e1d6c6"),true)
 for side in [-1,1]:
  _surface(arena,"Boundary",Vector3(side*20,2.7,0),Vector3(0.8,5.4,42),0,Color.WHITE,true)
  for row in 3:
   var z:float=-14+row*13
   var height:float=6.4+float((row+side+2)%3)*0.85
   var x:float=side*15.6
   _surface(arena,"Registry",Vector3(x,height/2,z),Vector3(8.4,height,10.8),0,Color("#e9dac6"),true)
   _surface(arena,"Cornice",Vector3(x,height,z),Vector3(8.8,0.28,11.1),0,Color("#e6cead"))
   var facade:Texture2D=preload("res://assets/courtyard/front-shutters.webp") if (row+side+1)%2==0 else preload("res://assets/courtyard/front-arches.webp")
   _facade(Vector3(side*11.39,height*.5,z),Vector2(10.8,height),-side*PI*.5,facade)
 for side in [-1,1]:
  _surface(arena,"Gatehouse",Vector3(side*11.9,3.85,-20),Vector3(16,7.7,1.2),0,Color.WHITE,true)
  _surface(arena,"Parapet",Vector3(side*11.9,7.8,-20),Vector3(16.3,0.34,1.65),0,Color.WHITE)
  _surface(arena,"Gate pier",Vector3(side*3.68,1.8,-19.15),Vector3(0.55,3.6,1.15),0,Color("#dec3a2"),true)
  _surface(arena,"Gate leaf",Vector3(side*1.84,2.55,-19.84),Vector3(3.65,5.1,0.45),2,Color("#b4ab8c"),true)
  for i in 4:
   _surface(arena,"Merlon",Vector3(side*(4.6+i*3.6),8.15,-20),Vector3(1,0.65,1.25),0,Color.WHITE)
 _facade(Vector3(0,3.09,-19.55),Vector2(7.28,6.18),0,preload("res://assets/courtyard/gate.webp"),true)
 _surface(arena,"Arch backing",Vector3(0,5.3,-20.27),Vector3(8,4.8,0.55),0,Color("#b7a186"),true)
 for i in 17:
  var angle:=PI*(i+0.5)/17
  var stone:=_surface(arena,"Arch stone",Vector3(cos(angle)*3.7,3.45+sin(angle)*2.75,-19.09),Vector3(0.76,0.62,1.12),0,Color("#e9d2b1"))
  stone.rotation.z=atan2(2.75*cos(angle),-3.7*sin(angle))
 _surface(arena,"South wall",Vector3(0,2.7,20),Vector3(40,5.4,0.9),0,Color.WHITE,true)
 for location in [Vector3(-8,0,-9),Vector3(7,0,-11),Vector3(9,0,4),Vector3(-9,0,7)]:
  for i in 3:
   var p:Vector3=location+Vector3((i%2)*1.55,(i/2)*1.42,0)
   _surface(arena,"Freight",p+Vector3.UP*0.71,Vector3(1.5,1.42,1.5),2,Color("#d8c7af"),true)
   for dx in [-0.61,0.61]:
    _surface(arena,"Crate slat",p+Vector3(dx,0.71,0.78),Vector3(0.13,1.42,0.09),2,Color("#dbbf93"))
 for i in 5:
  var x:float=-18+i*8.3
  var h:float=[9,10.6,9.4,11.8,9.5][i]
  var back_z:float=-24-i%2*1.8
  _surface(arena,"Annex",Vector3(x,h/2,back_z),Vector3(7.4,h,5.3),0,Color("#e6d7c3"))
  _surface(arena,"Eave",Vector3(x,h,back_z),Vector3(7.8,0.2,5.7),0,Color.WHITE)
  _facade(Vector3(x,h-2.36,back_z+2.67),Vector2(7.38,4.68),0,preload("res://assets/courtyard/front-arches.webp"))
 for i in 3:
  var z:float=-10.5+i*8.6
  var line_start:=Vector3(-11.3,5.8,z)
  for n in 12:
   var u:float=float(n+1)/12
   var end:=Vector3(lerpf(-11.3,11.3,u),5.8-sin(u*PI)*1.15,z+u*2.0)
   var wire:=_box(arena,"Cable",(line_start+end)/2,Vector3(0.025,0.025,line_start.distance_to(end)),Color("#383532"))
   wire.look_at(end,Vector3.UP)
   line_start=end
 for location in [Vector3(-6.8,0,-8),Vector3(-5.8,0,-8.5),Vector3(7,0,2.5)]:
  for band in [0,1,2]:
   var drum:=MeshInstance3D.new()
   var shell:=CylinderMesh.new()
   shell.height=1.22 if band==0 else 0.05
   shell.top_radius=0.46 if band==0 else 0.48
   shell.bottom_radius=shell.top_radius
   shell.radial_segments=18
   drum.mesh=shell
   var finish:=StandardMaterial3D.new()
   finish.albedo_texture=load("res://assets/courtyard/surface-3.webp")
   finish.albedo_color=Color("#929d9c") if band==0 else Color("#d5cbc0")
   drum.material_override=finish
   drum.position=location+Vector3.UP*[0.61,0.29,0.92][band]
   arena.add_child(drum)
   if band==0:
    var body:=StaticBody3D.new()
    var collision:=CollisionShape3D.new()
    var volume:=CylinderShape3D.new()
    volume.radius=0.46
    volume.height=1.22
    collision.shape=volume
    drum.add_child(body)
    body.add_child(collision)
 _surface(arena,"Sector plaque",Vector3(-7.4,3.85,-19.33),Vector3(4.4,0.85,0.1),3,Color("#485b58"))
 for i in 6:
  _palm(Vector3([-16,-7,8,17,-18,17][i],0,[-23,-25,-24,-23,5,8][i]),9+i%3,i)
 var sign:=Label3D.new()
 sign.text="01   /   ПРОХОДНАЯ"
 sign.font=Briefing.FACE
 sign.font_size=72
 sign.pixel_size=0.0035
 sign.modulate=Color("#f4e8ca")
 sign.outline_size=0
 sign.position=Vector3(-7.4,3.85,-19.24)
 arena.add_child(sign)

func _palm(base:Vector3, height:float, seed_index:int)->void:
 var tree:=MeshInstance3D.new()
 var mesh:=QuadMesh.new()
 var tree_height:=height+4.0+float(seed_index%2)
 mesh.size=Vector2(tree_height*.65,tree_height)
 var mat:=StandardMaterial3D.new()
 mat.albedo_texture=preload("res://assets/courtyard/date-palm.webp")
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 mat.alpha_scissor_threshold=.42
 mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh.material=mat
 tree.mesh=mesh
 tree.position=base+Vector3.UP*tree_height*.5
 arena.add_child(tree)

func _facade(at:Vector3,extent:Vector2,yaw:float,photo:Texture2D,cutout:=false)->void:
 var surface:=MeshInstance3D.new()
 var quad:=QuadMesh.new()
 quad.size=extent
 var finish:=StandardMaterial3D.new()
 finish.albedo_texture=photo
 finish.normal_enabled=true
 finish.normal_scale=.72
 finish.normal_texture=load(photo.resource_path.get_basename()+"-normal.png")
 finish.albedo_color=Color("#d8d4cb")
 finish.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 finish.roughness=.95
 if cutout:finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 quad.material=finish
 surface.mesh=quad
 surface.position=at
 surface.rotation.y=yaw
 surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.add_child(surface)

func _spawn_enemy(requested_kind := -1) -> void:
 if enemies.size() >= 20 or (not endless and kills+enemies.size()>=_target()):
  return
 var e := Node3D.new()
 var roll:=randf()
 var enemy_kind:=0
 if active_stage>=2 and roll<0.18:
  enemy_kind=2
 elif roll<0.42:
  enemy_kind=1
 if requested_kind >= 0: enemy_kind = clampi(requested_kind,0,2)
 var lanes:=Registry.SPAWN_X if registry!=null else [-7.0,-3.5,0.0,3.5,7.0]
 var spawn_z:=12.8 if registry!=null else 16.5
 e.position=Vector3(lanes.pick_random(),0,-spawn_z if hero.position.z>=0 else spawn_z)
 world_root.add_child(e)
 e.look_at(Vector3(hero.position.x,0,hero.position.z),Vector3.UP)
 var actor := Inspector.new()
 actor.kind = enemy_kind
 e.add_child(actor)
 match enemy_kind:
  1:
   e.name="Fast Courier"
   e.set_meta("hp",43.0+active_stage*6.0)
   e.set_meta("speed",2.65+active_stage*0.1)
   e.set_meta("damage",8.0)
  2:
   e.name="Armored Bureaucrat"
   e.set_meta("hp",170.0+active_stage*16.0)
   e.set_meta("speed",1.05+active_stage*0.05)
   e.set_meta("damage",20.0)
  _:
   e.name="Zombie Clerk"
   e.set_meta("hp",70.0+active_stage*10.0)
   e.set_meta("speed",1.6+active_stage*0.08)
   e.set_meta("damage",12.0)
 e.set_meta("attack_wait",randf_range(1.3,2.4))
 e.set_meta("windup",0.0)
 enemies.append(e)

func _physics_process(delta: float) -> void:
 if not playing: return
 var move: Vector2 = joystick
 if Input.is_key_pressed(KEY_A): move.x -= 1
 if Input.is_key_pressed(KEY_D): move.x += 1
 if Input.is_key_pressed(KEY_W): move.y -= 1
 if Input.is_key_pressed(KEY_S): move.y += 1
 move = move.limit_length()
 elapsed+=delta
 timer_label.text="%02d:%02d"%[int(elapsed)/60,int(elapsed)%60]
 hero.step(move,delta)
 stance_icon.modulate=Color("#ffcb72") if hero.crouching else Color.WHITE
 _update_camera(delta)
 radar.queue_redraw()
 enemy_timer -= delta
 if enemy_timer <= 0:
  enemy_timer = maxf(0.6,2.0-active_stage*0.15)
  _spawn_enemy()
 var hp_before:=hp
 for e in enemies.duplicate():
  if not is_instance_valid(e): continue
  var actor := e.get_child(0) as Inspector
  var previous_position:Vector3=e.position
  var diff: Vector3 = hero.position-e.position
  diff.y = 0
  var distance_to_hero:float=diff.length()
  var can_shoot:=distance_to_hero<([16.0,11.5,20.0][actor.kind] as float) and _wall_hit(e.position+Vector3.UP*1.38,hero.position+Vector3.UP*(.70 if hero.crouching else 1.05)).is_empty()
  _enemy_attack(e,actor.kind,delta,can_shoot)
  if distance_to_hero>([8.5,5.0,11.5][actor.kind] as float) or (not can_shoot and distance_to_hero>1.4):
   var desired:Vector3=diff.normalized()
   var separation:=Vector3.ZERO
   for other in enemies:
    if other==e or not is_instance_valid(other): continue
    var away:Vector3=e.position-other.position
    away.y=0.0
    var gap:float=away.length()
    if gap>0.01 and gap<2.2:
     separation+=away.normalized()*(2.2-gap)/2.2
   # Light lateral movement gives couriers a different approach pattern.
   var lateral:=Vector3.ZERO
   if actor.kind==1 and distance_to_hero<8.0:
    lateral=Vector3(-desired.z,0.0,desired.x)*sin(float(Time.get_ticks_msec())*0.0017+float(e.get_instance_id()%17))*0.35
   var steering:Vector3=desired+separation*1.2+lateral
   if steering.length_squared()>0.001:
    var next_position:Vector3=e.position+steering.normalized()*delta*float(e.get_meta("speed",1.6))
    next_position.x=clampf(next_position.x,-18.7,18.7)
    next_position.z=clampf(next_position.z,-18.7,18.7)
    e.position=_enemy_navigate(e,next_position,steering.normalized(),delta)
  var travel: Vector3 = e.position - previous_position
  actor.advance(delta,travel.length())
  var heading: Vector3 = travel if travel.length_squared()>0.000001 else diff
  if heading.length_squared()>0.000001:
   var angle := atan2(-heading.x,-heading.z)
   e.rotation.y = lerp_angle(e.rotation.y, angle, 1.0-exp(-delta*16.0))
 _advance_bolts(delta)
 if hp<hp_before:
  damage_flash=minf(0.55,damage_flash+.38)
 damage_flash=maxf(0.0,damage_flash-delta*1.7)
 camera_kick*=exp(-delta*8.0)
 if is_instance_valid(damage_overlay):
  damage_overlay.color=Color(0.82,0.09,0.07,damage_flash*0.5)
 if hit_flash_timer > 0.0:
  hit_flash_timer -= delta
  if hit_flash_timer <= 0.0 and is_instance_valid(hit_marker):
   hit_marker.visible=false
 fire_timer -= delta
 if reload_timer>0.0:
  reload_timer=maxf(0.0,reload_timer-delta)
  if reload_timer==0.0:
   magazine_rounds[weapon_index]=_magazine_capacity()
  _refresh_ammo_ui()
 var manual := fire_requested or fire_touch_id != -1 or fire_button.button_pressed or Input.is_key_pressed(KEY_SPACE) or (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
 fire_requested=false
 if (auto_fire or manual) and fire_timer<=0 and reload_timer<=0.0 and magazine_rounds[weapon_index]>0:
  var shot := _aim_hit(float(WEAPONS[weapon_index].range))
  var target: Node3D = shot.target
  if target != null or (manual and not auto_fire):
   fire_timer=float(WEAPONS[weapon_index].cooldown)
   magazine_rounds[weapon_index]-=1
   _refresh_ammo_ui()
   var hits:Dictionary={}
   if target!=null: hits[target]=float(WEAPONS[weapon_index].damage)
   if weapon_index==3:
    var spread:=get_viewport().get_visible_rect().size.y*.023
    for pellet in 6:
     var offset:=Vector2.RIGHT.rotated(TAU*pellet/6)*spread
     var extra:=_aim_hit(float(WEAPONS[3].range),offset)
     if extra.target!=null:
      hits[extra.target]=float(hits.get(extra.target,0))+float(WEAPONS[3].damage)
   if target==null and shot.has("normal"): _impact_at(shot.position,shot.normal)
   _show_shot_feedback(shot.position)
   foreground.gesture("fire",fire_timer)
   camera_kick=minf(.15,camera_kick+float(WEAPONS[weapon_index].kick))
   for victim:Node3D in hits:
    var remaining:=float(victim.get_meta("hp"))-float(hits[victim])
    victim.set_meta("hp",remaining)
    _show_hit_feedback(victim)
    if remaining<=0:
     ribbon.record(victim.get_child(0).kind)
     enemies.erase(victim)
     _animate_enemy_defeat(victim)
     kills+=1
     xp+=10
     kills_label.text="%d / ∞"%kills if endless else "%d / %d"%[kills,_target()]
 if registry!=null:
  if registry.collect_near(hero.position): _refresh_documents()
 if hp>0 and not endless and kills>=_target() and (registry==null or registry.files.is_empty()):
  _win()
 if playing and magazine_rounds[weapon_index]<=0 and reload_timer<=0.0:
  _start_reload()
 if playing and hp<=0:
  playing=false
  _show_result(false)
 hp_label.text="✚ %d"%ceili(maxf(hp,0))
 if is_instance_valid(health_bar):
  health_bar.value=clampf(hp,0.0,100.0)
  health_bar.modulate=Color("#e96c62") if hp<=30.0 else Color.WHITE

func _enemy_navigate(enemy:Node3D, desired_position:Vector3, direction:Vector3, delta:float)->Vector3:
 # Cheap wall/cover avoidance for the low-poly arena, no navigation bake required.
 var origin:Vector3=enemy.global_position+Vector3(0.0,0.85,0.0)
 var travel:float=enemy.global_position.distance_to(desired_position)
 if travel<0.001: return desired_position
 var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*(travel+0.65))
 query.collide_with_areas=false
 if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
  return desired_position
 # Try either tangent around an obstacle. Keep the actor away from solid props.
 var side:=Vector3(-direction.z,0.0,direction.x)
 for candidate in [side,-side]:
  var test:=PhysicsRayQueryParameters3D.create(origin,origin+candidate*(travel+0.65))
  test.collide_with_areas=false
  if get_world_3d().direct_space_state.intersect_ray(test).is_empty():
   var result:Vector3=enemy.position+candidate*travel
   result.x=clampf(result.x,-18.7,18.7)
   result.z=clampf(result.z,-18.7,18.7)
   return result
 return enemy.position

func _wall_hit(start: Vector3, end: Vector3) -> Dictionary:
 var query := PhysicsRayQueryParameters3D.create(start, end, 1)
 query.hit_from_inside = true
 return get_world_3d().direct_space_state.intersect_ray(query)

func _aim_hit(reach: float, offset:=Vector2.ZERO) -> Dictionary:
 var center := get_viewport().get_visible_rect().get_center()+offset
 var start := cam.project_ray_origin(center)
 var end := start + cam.project_ray_normal(center) * reach
 var wall := _wall_hit(start, end)
 if not wall.is_empty(): end = wall.position
 var target: Node3D = null
 for enemy in enemies:
  var actor := enemy.get_child(0) as Inspector
  var point = actor.intersect_shot(start,end)
  if point != null and start.distance_squared_to(point) < start.distance_squared_to(end):
   target = enemy
   end = point
 var result:={"target":target,"position":end}
 if target==null and not wall.is_empty(): result["normal"]=wall.normal
 return result

func _animate_enemy_defeat(target:Node3D)->void:
 if not is_instance_valid(target): return
 # Defeated enemies stop moving immediately because they leave the active list.
 var collapse:=create_tween()
 collapse.set_parallel(true)
 collapse.tween_property(target,"rotation_degrees:x",72.0,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 collapse.tween_property(target,"position:y",-0.55,0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 collapse.chain().tween_callback(func():
  if is_instance_valid(target): target.queue_free()
 )

func _impact_at(point:Vector3,normal:Vector3)->void:
 if normal.length_squared()<.8:return
 if not impact_mesh.material:
  var mat:=StandardMaterial3D.new()
  mat.albedo_texture=preload("res://assets/courtyard/impact.png")
  mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  mat.roughness=1.0
  impact_mesh.material=mat
  impact_mesh.size=Vector2(.14,.14)
 var mark:MeshInstance3D
 if marks.size()>=24:
  mark=marks.pop_front()
 else:
  mark=MeshInstance3D.new()
  mark.mesh=impact_mesh
  mark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  arena.add_child(mark)
 marks.append(mark)
 var up:=Vector3.RIGHT if absf(normal.y)>.9 else Vector3.UP
 mark.global_transform=Transform3D(Basis.looking_at(-normal,up).rotated(normal,randf()*TAU),point+normal*.004)

func _show_shot_feedback(finish:Vector3)->void:
 glint.shoot(finish)

func _show_hit_feedback(_target:Node3D)->void:
 hit_flash_timer=.13
 hit_marker.show()

func _enemy_attack(enemy:Node3D,kind:int,delta:float,clear:bool)->void:
 var wait:=float(enemy.get_meta("attack_wait"))-delta
 enemy.set_meta("attack_wait",wait)
 var windup:=float(enemy.get_meta("windup"))
 if not clear:
  enemy.set_meta("windup",0.0)
  if enemy.has_node("Charge"): enemy.get_node("Charge").hide()
  return
 var origin:=enemy.to_global(Vector3(-.20,1.38,-.38))
 if windup>0:
  enemy.set_meta("windup",maxf(0,windup-delta))
  if windup<=delta:
   enemy.get_node("Charge").hide()
   var aim:Vector3=enemy.get_meta("locked_point")
   if _wall_hit(origin,aim).is_empty():
    var bolt:=_pulse()
    world_root.add_child(bolt)
    bolt.position=origin
    bolt.scale=Vector3(.052,.052,.21)
    bolt.look_at(aim)
    bolt.set_meta("velocity",origin.direction_to(aim)*18.0)
    bolt.set_meta("damage",float(enemy.get_meta("damage"))*.65)
    bolt.set_meta("ttl",1.6)
    bolts.append(bolt)
   enemy.set_meta("attack_wait",randf_range(1.9,2.9)+kind*.15)
 elif wait<=0:
  var charge:=enemy.get_node_or_null("Charge") as MeshInstance3D
  if not charge:
   charge=_pulse()
   charge.name="Charge"
   enemy.add_child(charge)
   charge.scale=Vector3.ONE*.066
  charge.position=enemy.to_local(origin)
  charge.show()
  enemy.set_meta("locked_point",hero.position+Vector3.UP*(.70 if hero.crouching else 1.05))
  enemy.set_meta("windup",.48)

func _pulse()->MeshInstance3D:
 if not bolt_mesh.material:
  bolt_mesh.radial_segments=8
  bolt_mesh.rings=3
  var mat:=StandardMaterial3D.new()
  mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  mat.albedo_color=Color("#ff8548")
  bolt_mesh.material=mat
 var pulse:=MeshInstance3D.new()
 pulse.mesh=bolt_mesh
 pulse.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return pulse

func _advance_bolts(delta:float)->void:
 for bolt in bolts.duplicate():
  var end:Vector3=bolt.position+(bolt.get_meta("velocity") as Vector3)*delta
  var query:=PhysicsRayQueryParameters3D.create(bolt.position,end,3)
  query.hit_from_inside=true
  var hit:=get_world_3d().direct_space_state.intersect_ray(query)
  var ttl:=float(bolt.get_meta("ttl"))-delta
  if not hit.is_empty() or ttl<=0:
   if hit.get("collider")==hero: hp-=float(bolt.get_meta("damage"))
   bolts.erase(bolt)
   bolt.queue_free()
  else:
   bolt.position=end
   bolt.set_meta("ttl",ttl)

func _refresh_documents()->void:
 document_label.visible=registry!=null
 if registry==null: return
 document_label.text=registry.objective_status()

func _target()->int:
 return int(Story.mission(active_stage)["kills"])

func _update_camera(delta: float)->void:
 if not is_instance_valid(hero) or not is_instance_valid(cam): return
 cam.global_position=hero.global_position+Vector3.UP*(hero.eye_height-hero.landing_offset)
 cam.rotation=Vector3(pitch+camera_kick,hero.rotation.y,0)
 if foreground:
  foreground.pose(camera_kick,elapsed)
 for tick in bloom_ticks:
  var axis:Vector2=tick.get_meta("axis")
  tick.position=hud.size*.5+axis*(8+camera_kick*135)-tick.size*.5

func _hud_place(control:Control, anchor:Control.LayoutPreset, at:Vector2, extent:Vector2)->void:
 control.set_anchors_preset(anchor)
 control.position=at
 control.custom_minimum_size=extent
 hud.add_child(control)
 control.set_deferred("size",extent)

func _hud_text(value:String, pixels:int, anchor:Control.LayoutPreset, at:Vector2, extent:Vector2)->Label:
 var label:=_label(value,pixels)
 label.add_theme_font_override("font",Briefing.FACE)
 label.add_theme_color_override("font_color",Color("#ffdb96"))
 label.add_theme_color_override("font_outline_color",Color("#1d2022"))
 label.add_theme_constant_override("outline_size",4)
 _hud_place(label,anchor,at,extent)
 return label

func _combat_button(value:String, anchor:Control.LayoutPreset, at:Vector2, extent:Vector2, action:Callable)->Button:
 var b:=_button(value)
 for state in ["normal","hover","pressed","disabled"]:
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("#16202a94") if state!="pressed" else Color("#b68b42ab")
  style.set_border_width_all(1)
  style.border_color=Color("#e3d9c48c")
  style.set_corner_radius_all(int(extent.y/2))
  b.add_theme_stylebox_override(state,style)
 b.focus_mode=Control.FOCUS_NONE
 b.pressed.connect(action)
 _hud_place(b,anchor,at,extent)
 return b

func _icon_button(glyph:String,description:String,anchor:Control.LayoutPreset,at:Vector2,extent:Vector2,action:Callable)->Button:
 var button:=_combat_button("",anchor,at,extent,action)
 button.tooltip_text=description
 button.accessibility_name=description
 var icon:=ActionIcon.new()
 icon.glyph=glyph
 icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 button.add_child(icon)
 icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 return button

func _weapon_slots()->void:
 for i in WEAPONS.size():
  var button:=Button.new()
  button.focus_mode=Control.FOCUS_NONE
  button.tooltip_text=WEAPONS[i].name
  button.accessibility_name=WEAPONS[i].name
  button.pressed.connect(_select_slot.bind(i))
  _hud_place(button,Control.PRESET_TOP_RIGHT,Vector2(-102,135+i*45),Vector2(84,43))
  var image:=TextureRect.new()
  image.texture=load("res://assets/armory/catalog/slot-%d.png"%i)
  image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  image.position=Vector2(7,8)
  image.size=Vector2(58,25)
  image.mouse_filter=Control.MOUSE_FILTER_IGNORE
  button.add_child(image)
  var number:=_label(str(i+1),13)
  number.position=Vector2(68,1)
  number.mouse_filter=Control.MOUSE_FILTER_IGNORE
  button.add_child(number)
  slot_buttons.append(button)

func _build_ui()->void:
 var layer:=CanvasLayer.new()
 add_child(layer)
 hud=Control.new()
 layer.add_child(hud)
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 foreground=Armory.new()
 hud.add_child(foreground)
 foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 glint=Glint.new()
 glint.rig=foreground
 glint.camera=cam
 glint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.add_child(glint)
 glint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 damage_overlay=ColorRect.new()
 damage_overlay.color=Color.TRANSPARENT
 damage_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.add_child(damage_overlay)
 damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ribbon=Ribbon.new()
 ribbon.game=self
 hud.add_child(ribbon)
 ribbon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 radar=Radar.new()
 radar.player=hero
 radar.contacts=enemies
 radar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _hud_place(radar,Control.PRESET_TOP_LEFT,Vector2(18,18),Vector2(154,154))
 status_label=_hud_text("",17,Control.PRESET_TOP_LEFT,Vector2(16,174),Vector2(159,27))
 status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 timer_label=_hud_text("00:00",26,Control.PRESET_CENTER_TOP,Vector2(-48,9),Vector2(96,30))
 timer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 document_label=_hud_text("",17,Control.PRESET_CENTER_TOP,Vector2(-140,66),Vector2(280,28))
 document_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 kills_label=_hud_text("",17,Control.PRESET_CENTER_TOP,Vector2(-48,37),Vector2(96,24))
 kills_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _icon_button("pause","Меню",Control.PRESET_TOP_RIGHT,Vector2(-68,12),Vector2(51,51),_show_menu)
 fire_button=_icon_button("fire","Огонь",Control.PRESET_BOTTOM_RIGHT,Vector2(-198,-245),Vector2(86,86),func():pass)
 fire_button.button_down.connect(func():fire_requested=true)
 _weapon_slots()
 _icon_button("jump","Прыжок",Control.PRESET_BOTTOM_RIGHT,Vector2(-80,-236),Vector2(57,57),hero.queue_jump)
 var stance:=_icon_button("crouch","Присесть / встать",Control.PRESET_BOTTOM_RIGHT,Vector2(-161,-143),Vector2(62,62),hero.toggle_stance)
 stance_icon=stance.get_child(0)
 reload_button=_icon_button("reload","Перезарядить",Control.PRESET_BOTTOM_RIGHT,Vector2(-86,-143),Vector2(62,62),_start_reload)
 ammo_label=_hud_text("",31,Control.PRESET_CENTER_BOTTOM,Vector2(251,-60),Vector2(200,43))
 ammo_label.add_theme_color_override("font_color",Color("#fff3d9"))
 weapon_status=_hud_text("",15,Control.PRESET_CENTER_BOTTOM,Vector2(253,-76),Vector2(216,25))
 reload_progress=ProgressBar.new()
 reload_progress.show_percentage=false
 _hud_place(reload_progress,Control.PRESET_CENTER_BOTTOM,Vector2(251,-15),Vector2(192,4))
 hp_label=_hud_text("✚ 100",34,Control.PRESET_CENTER_BOTTOM,Vector2(-330,-66),Vector2(110,47))
 hp_label.add_theme_color_override("font_color",Color("#fff3d9"))
 health_bar=ProgressBar.new()
 health_bar.show_percentage=false
 var trough:=StyleBoxFlat.new()
 trough.bg_color=Color("#292824a6")
 var fill:=StyleBoxFlat.new()
 fill.bg_color=Color("#ffd88c")
 health_bar.add_theme_stylebox_override("background",trough)
 health_bar.add_theme_stylebox_override("fill",fill)
 _hud_place(health_bar,Control.PRESET_CENTER_BOTTOM,Vector2(-327,-19),Vector2(85,4))
 var wallet:=_hud_text("",24,Control.PRESET_BOTTOM_LEFT,Vector2(28,-51),Vector2(160,34))
 wallet.name="Balance"
 joystick_base=_panel(Vector2.ZERO,Vector2(132,132),Color("#1a20264d"))
 var ring:=StyleBoxFlat.new()
 ring.bg_color=Color("#20232a55")
 ring.set_corner_radius_all(66)
 ring.border_color=Color("#fff1ca99")
 ring.set_border_width_all(2)
 joystick_base.add_theme_stylebox_override("panel",ring)
 _hud_place(joystick_base,Control.PRESET_BOTTOM_LEFT,Vector2(57,-210),Vector2(132,132))
 joystick_knob=_panel(Vector2(42,42),Vector2(48,48),Color.TRANSPARENT)
 var knob:=ring.duplicate()
 knob.bg_color=Color("#ffefcd44")
 joystick_knob.add_theme_stylebox_override("panel",knob)
 joystick_base.add_child(joystick_knob)
 for axis in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
  var tick:=ColorRect.new()
  tick.color=Color("#eff2e5")
  tick.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var dimensions:=Vector2(2,7) if axis.x==0 else Vector2(7,2)
  _hud_place(tick,Control.PRESET_CENTER,axis*8-dimensions/2,dimensions)
  tick.set_meta("axis",axis)
  bloom_ticks.append(tick)
 hit_marker=_hud_text("×",30,Control.PRESET_CENTER,Vector2(-10,-24),Vector2(20,40))
 hit_marker.visible=false
 menu_layer=Control.new()
 layer.add_child(menu_layer)
 menu_layer.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 menu_layer.offset_left=-640
 menu_layer.offset_top=-360
 menu_layer.offset_right=640
 menu_layer.offset_bottom=360

func _cycle_weapon()->void:
 _select_slot((weapon_index+1)%WEAPONS.size())

func _select_slot(index:int)->void:
 if index==weapon_index: return
 weapon_index=index
 reload_timer=0.0
 _refresh_ammo_ui()
 _refresh_weapon_button()
 _apply_weapon_skin()

func _magazine_capacity()->int:
 return MAGAZINE_CAPACITIES[weapon_index]

func _start_reload()->void:
 if not playing or reload_timer>0.0: return
 if magazine_rounds[weapon_index]>=_magazine_capacity(): return
 reload_duration=[1.55,1.22,1.78,1.90,2.25][weapon_index]
 reload_timer=reload_duration
 foreground.gesture("reload",reload_duration)
 _refresh_ammo_ui()

func _refresh_ammo_ui()->void:
 if is_instance_valid(ammo_label):
  ammo_label.text="ПЕРЕЗАРЯДКА..." if reload_timer>0.0 else "%d  /  %d"%[magazine_rounds[weapon_index],_magazine_capacity()]
 if is_instance_valid(reload_progress):
  reload_progress.visible=reload_timer>0.0
  reload_progress.value=100.0*(1.0-reload_timer/reload_duration)
 if is_instance_valid(reload_button):
  reload_button.disabled=not playing or reload_timer>0.0 or magazine_rounds[weapon_index]>=_magazine_capacity()

func _apply_weapon_skin()->void:
 if not is_instance_valid(foreground): return
 foreground.equip(weapon_index,equipped_skins[weapon_index])

func _refresh_weapon_button()->void:
 for i in slot_buttons.size():
  var style:=StyleBoxFlat.new()
  var active:=i==weapon_index
  style.bg_color=Color("#3a3225dc") if active else Color("#18202b94")
  style.border_width_left=3 if active else 1
  style.border_color=Color("#ffd184") if active else Color("#c2beb18c")
  for state in ["normal","hover","pressed"]:slot_buttons[i].add_theme_stylebox_override(state,style)
  slot_buttons[i].get_child(0).modulate=Color("#ffce75") if active else Color("#e1dfd4")
 if is_instance_valid(weapon_status):
  weapon_status.text=str(WEAPONS[weapon_index]["name"])

func _panel(pos:Vector2,dimensions:Vector2,tint:Color)->Panel:
 var p:=Panel.new()
 p.position=pos
 p.custom_minimum_size=dimensions
 p.size=dimensions
 p.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=StyleBoxFlat.new()
 style.bg_color=tint
 style.set_corner_radius_all(12)
 style.border_width_left=2
 style.border_color=Color("#d4b47b")
 p.add_theme_stylebox_override("panel",style)
 return p

func _label(value:String,size:int)->Label:
 var l:=Label.new()
 l.add_theme_font_override("font",Briefing.FACE)
 l.text=value
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",Color("#f5e6c9"))
 return l

func _button(value:String)->Button:
 var b:=Button.new()
 b.text=value
 b.add_theme_font_override("font",Briefing.FACE)
 b.custom_minimum_size=Vector2(160,45)
 b.add_theme_font_size_override("font_size",16)
 b.add_theme_color_override("font_color",Color("#e8f3f5"))
 b.add_theme_color_override("font_hover_color",Color("#ffffff"))
 var normal:=StyleBoxFlat.new()
 normal.bg_color=Color("#37332d")
 normal.set_corner_radius_all(2)
 normal.border_width_left=3
 normal.border_color=Briefing.RUST
 b.add_theme_stylebox_override("normal",normal)
 var hover:=normal.duplicate()
 hover.bg_color=Color("#584638")
 b.add_theme_stylebox_override("hover",hover)
 b.add_theme_stylebox_override("pressed",hover)
 b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 return b

func _clear_menu()->void:
 if case_spin_tween!=null and case_spin_tween.is_running(): case_spin_tween.kill()
 for child in menu_layer.get_children():
  if child is CanvasItem: child.hide()
  child.queue_free()

func _briefing()->Briefing:
 _clear_menu()
 var screen:=Briefing.new()
 menu_layer.add_child(screen)
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.frontier=stage
 screen.selected=preview_stage
 screen.experience=xp
 screen.balance=credits
 screen.navigate.connect(_navigate)
 screen.deploy.connect(_start)
 return screen

func _show_menu()->void:
 playing=false
 world_root.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 hud.hide()
 menu_layer.show()
 preview_stage=stage
 _briefing().lobby()

func _navigate(section:String)->void:
 match section:
  "ЛОББИ": _show_menu()
  "ИНВЕНТАРЬ": _show_collection()
  "СНАРЯЖЕНИЕ": _show_loadout()
  "МАГАЗИН": _show_cases()
  "ПРОФИЛЬ": _show_file()
  "НАСТРОЙКИ": _show_settings()
  _:
   if section.begins_with("этап"):
    preview_stage=int(section.trim_prefix("этап"))
   var screen:=_briefing()
   screen.infinite=section=="БЕСКОНЕЧНЫЙ"
   screen.operations()

func _show_cases()->void:
 var screen := _show_subpage("МАГАЗИН / СНАБЖЕНИЕ")
 screen.caption("КЕЙСЫ СНАБЖЕНИЯ",Vector2(426,116),35,Briefing.PAPER)
 screen.caption("◈  %d  КРЕДИТОВ     /     ОТКРЫТО  %d"%[credits,cases_opened],Vector2(428,168),17,Briefing.GOLD)
 var descriptions := ["Базовый набор","Повышенный шанс редкостей","Высший класс снабжения"]
 for i in Loot.CASES.size():
  var data: Dictionary = Loot.CASES[i]
  var x := 426 + i*274
  screen.panel(Vector2(x,223),Vector2(258,322),Briefing.INK)
  var photo := screen.picture(CASE_ART[i],Vector2(x,223),Vector2(258,164))
  screen.enter_art(photo,5+i*2)
  screen.panel(Vector2(x,387),Vector2(258,3),Briefing.RUST)
  screen.caption(data.name,Vector2(x+14,404),25,Briefing.PAPER)
  screen.caption(descriptions[i],Vector2(x+14,447),16,Color("#d1bda5"))
  var purchase := screen.button("ОТКРЫТЬ   %d ◈"%int(data.price),Vector2(x+12,483),Vector2(234,48),_open_case.bind(i),credits>=int(data.price))
  purchase.disabled=credits<int(data.price)
 screen.caption("ГАРАНТИЯ ЭПИЧЕСКОГО ПРЕДМЕТА    %d / 20"%mini(loot_misses,19),Vector2(428,566),17,Briefing.GOLD)
 screen.caption("Базовый кейс    •    редкий 27%    /    эпический 12%    /    легендарный 5%    /    ультраредкий 1%",Vector2(428,597),15,Briefing.PAPER)
 screen.button("МОЯ КОЛЛЕКЦИЯ   ›",Vector2(428,635),Vector2(264,46),_show_collection)
 if last_drop>=0:
  screen.caption("ПОСЛЕДНИЙ ПРЕДМЕТ   /   "+str(Loot.ITEMS[last_drop].name),Vector2(712,647),16,Briefing.PAPER)

func _open_case(index:int)->void:
 var cost:int=int(Loot.CASES[index]["price"])
 if credits<cost:
  return
 credits-=cost
 last_case_index=index
 var drop:Dictionary=Loot.roll(index,loot_misses,loot_rng)
 loot_misses=int(drop["misses"])
 var item_id:int=int(drop["id"])
 last_drop=item_id
 cases_opened+=1
 last_drop_duplicate = inventory.has(item_id)
 if last_drop_duplicate:
  credits+=int(Loot.DUPLICATE_CREDITS[int(drop["rarity"])])
 else:
  inventory.append(item_id)
 _save()
 _show_case_roulette(item_id)

func _show_case_roulette(item_id:int)->void:
 var screen:=_show_subpage("МАГАЗИН / ВСКРЫТИЕ")
 screen.caption("ВСКРЫТИЕ КЕЙСА",Vector2(430,150),34,Briefing.PAPER)
 screen.caption(str(Loot.CASES[last_case_index].name),Vector2(432,207),18,Briefing.GOLD)
 var window:=Control.new()
 window.position=Vector2(436,281)
 window.size=Vector2(779,184)
 window.clip_contents=true
 window.mouse_filter=Control.MOUSE_FILTER_IGNORE
 screen.add_child(window)
 var belt:=Control.new()
 belt.mouse_filter=Control.MOUSE_FILTER_IGNORE
 window.add_child(belt)
 const SPACING := 155
 const WINNING_SLOT := 14
 for i in WINNING_SLOT+4:
  var id:=item_id if i==WINNING_SLOT else loot_rng.randi_range(0,Loot.ITEMS.size()-1)
  var item:Dictionary=Loot.ITEMS[id]
  var color:=Color(str(Loot.RARITY_COLORS[int(item.rarity)]))
  var card:=_panel(Vector2(i*SPACING,8),Vector2(148,167),Briefing.INK)
  card.add_theme_stylebox_override("panel",_rarity_panel_style(color))
  belt.add_child(card)
  var image:=_equipment_image(int(item.weapon),Vector2.ZERO,Vector2(140,104),id)
  image.reparent(card,false)
  image.position=Vector2(4,5)
  var title:=_label(str(item.name),16)
  title.position=Vector2(6,108)
  title.size=Vector2(136,49)
  title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  title.add_theme_color_override("font_color",color)
  card.add_child(title)
 var center:=window.size.x*.5
 var stop_x:=center-74.0-WINNING_SLOT*SPACING
 screen.panel(Vector2(window.position.x+center-2,268),Vector2(4,23),Briefing.GOLD)
 screen.panel(Vector2(window.position.x+center-2,450),Vector2(4,23),Briefing.GOLD)
 screen.button("ПРОПУСТИТЬ АНИМАЦИЮ",Vector2(436,539),Vector2(345,57),_finish_case_spin.bind(item_id))
 case_spin_finished=false
 case_spin_tween=belt.create_tween()
 case_spin_tween.tween_property(belt,"position:x",stop_x,2.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
 case_spin_tween.tween_interval(.46)
 case_spin_tween.tween_callback(_finish_case_spin.bind(item_id))

func _finish_case_spin(item_id:int)->void:
 if case_spin_finished: return
 case_spin_finished=true
 if case_spin_tween!=null and case_spin_tween.is_running():
  case_spin_tween.kill()
 _show_drop_reveal(item_id)

func _show_drop_reveal(item_id:int)->void:
 var screen:=_show_subpage("МАГАЗИН / НАГРАДА")
 var item:Dictionary=Loot.ITEMS[item_id]
 var rarity:int=item.rarity
 var accent:=Color(str(Loot.RARITY_COLORS[rarity]))
 screen.caption("ПОЛУЧЕН ПРЕДМЕТ",Vector2(432,117),34,Briefing.PAPER)
 screen.panel(Vector2(432,185),Vector2(788,263),Briefing.INK)
 screen.panel(Vector2(432,442),Vector2(788,6),accent)
 var image:=_equipment_image(int(item.weapon),Vector2(738,193),Vector2(445,241),item_id,screen)
 image.pivot_offset=image.size*.5
 image.scale=Vector2(.85,.85)
 image.create_tween().tween_property(image,"scale",Vector2.ONE,.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 screen.caption(Loot.RARITY_NAMES[rarity],Vector2(456,227),16,accent)
 screen.caption(item.name,Vector2(454,261),29,Briefing.PAPER,290)
 screen.caption(WEAPONS[int(item.weapon)].name,Vector2(456,373),16,Briefing.GOLD,275)
 screen.caption("Дубликат. Начислено %d кредитов."%Loot.DUPLICATE_CREDITS[rarity] if last_drop_duplicate else "Предмет добавлен в коллекцию.",Vector2(434,471),19,Briefing.PAPER)
 screen.button("ЭКИПИРОВАТЬ",Vector2(432,535),Vector2(252,57),_equip_skin.bind(item_id),true)
 screen.button("К КЕЙСАМ",Vector2(698,535),Vector2(252,57),_show_cases)
 var price:int=Loot.CASES[last_case_index].price
 var again:=screen.button("ЕЩЁ РАЗ   %d ◈"%price,Vector2(964,535),Vector2(252,57),_open_case.bind(last_case_index))
 again.disabled=credits<price

func _rarity_panel_style(color:Color)->StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("#2e2a25")
 style.set_corner_radius_all(2)
 style.border_width_bottom=3
 style.border_width_left=1
 style.border_color=color
 return style

func _equip_skin(item_id:int)->void:
 if not inventory.has(item_id): return
 var weapon:int=int(Loot.ITEMS[item_id]["weapon"])
 equipped_skins[weapon]=item_id
 if weapon_index==weapon: _apply_weapon_skin()
 _save()
 _show_collection()

func _show_skin_preview(item_id:int)->void:
 if not inventory.has(item_id): return
 _show_subpage("ИНВЕНТАРЬ / СКИН")
 var item:Dictionary=Loot.ITEMS[item_id]
 var rarity:int=int(item["rarity"])
 var weapon:int=int(item["weapon"])
 var rarity_color:=Color(str(Loot.RARITY_COLORS[rarity]))
 var title:=_label("АРСЕНАЛ / ПРЕДПРОСМОТР СКИНА",23)
 title.position=Vector2(475,207)
 page_body.add_child(title)
 var panel:=_panel(Vector2(475,255),Vector2(510,278),Color("#2e2a25"))
 panel.add_theme_stylebox_override("panel",_rarity_panel_style(rarity_color))
 page_body.add_child(panel)
 _equipment_image(weapon,Vector2(495,312),Vector2(470,146),item_id)
 var name_label:=_label(str(item["name"]),26)
 name_label.position=Vector2(506,270)
 name_label.add_theme_color_override("font_color",rarity_color)
 page_body.add_child(name_label)
 var info:=_label(str(WEAPONS[weapon]["name"])+"  /  "+str(Loot.RARITY_NAMES[rarity]),16)
 info.position=Vector2(506,464)
 page_body.add_child(info)
 var equipped:bool=equipped_skins[weapon]==item_id
 var equip:=_button("✓ ЭКИПИРОВАН" if equipped else "ЭКИПИРОВАТЬ")
 equip.position=Vector2(475,548)
 equip.custom_minimum_size=Vector2(244,50)
 equip.disabled=equipped
 equip.pressed.connect(_equip_skin.bind(item_id))
 page_body.add_child(equip)
 var back:=_button("← К КОЛЛЕКЦИИ")
 back.position=Vector2(737,548)
 back.custom_minimum_size=Vector2(248,50)
 back.pressed.connect(_show_collection)
 page_body.add_child(back)

func _set_collection_filter(value:int)->void:
 collection_filter=value
 collection_page=0
 _show_collection()

func _set_collection_page(value:int)->void:
 collection_page=maxi(0,value)
 _show_collection()

func _show_collection()->void:
 var screen:=_show_subpage("ИНВЕНТАРЬ / КОЛЛЕКЦИЯ")
 screen.caption("АРСЕНАЛ",Vector2(429,116),35,Briefing.PAPER)
 screen.caption("%d / %d   ПРЕДМЕТОВ"%[inventory.size(),Loot.ITEMS.size()],Vector2(432,170),17,Briefing.GOLD)
 screen.button("К КЕЙСАМ   ›",Vector2(1033,122),Vector2(192,48),_show_cases)
 var filters:=["ВСЕ","АВТОМАТ","ПИСТОЛЕТ","КАРАБИН","ДРОБОВИК","ПУЛЕМЁТ"]
 for i in filters.size():
  screen.button(filters[i],Vector2(432+i*132,224),Vector2(126,46),_set_collection_filter.bind(i-1),collection_filter==i-1)
 var filtered:Array[int]=[]
 for id in inventory:
  if collection_filter<0 or int(Loot.ITEMS[id].weapon)==collection_filter: filtered.append(id)
 filtered.sort_custom(func(a:int,b:int)->bool: return Loot.ITEMS[a].rarity>Loot.ITEMS[b].rarity)
 const PER_PAGE := 6
 var pages:=maxi(1,ceili(float(filtered.size())/PER_PAGE))
 collection_page=clampi(collection_page,0,pages-1)
 for i in range(collection_page*PER_PAGE,mini(filtered.size(),(collection_page+1)*PER_PAGE)):
  var id:=filtered[i]
  var item:Dictionary=Loot.ITEMS[id]
  var slot:=i%PER_PAGE
  var at:=Vector2(432+slot%3*266,294+int(slot/3)*151)
  var accent:=Color(str(Loot.RARITY_COLORS[int(item.rarity)]))
  screen.panel(at,Vector2(254,139),Briefing.INK)
  _equipment_image(int(item.weapon),at+Vector2(8,2),Vector2(238,74),id,screen)
  screen.panel(at+Vector2(0,76),Vector2(254,2),accent)
  screen.caption(item.name,at+Vector2(10,81),20,Briefing.PAPER)
  var equipped:bool=equipped_skins[int(item.weapon)]==id
  screen.caption(str(Loot.RARITY_NAMES[int(item.rarity)])+("   ✓" if equipped else ""),at+Vector2(10,112),13,accent)
  var select:=Button.new()
  select.flat=true
  select.position=at
  select.size=Vector2(254,139)
  select.tooltip_text=str(item.name)
  select.pressed.connect(_show_skin_preview.bind(id))
  screen.add_child(select)
 if filtered.is_empty():
  screen.panel(Vector2(432,294),Vector2(786,203),Briefing.INK)
  screen.caption("ПОКА ПУСТО",Vector2(455,339),27,Briefing.PAPER)
  screen.caption("Открой кейс в магазине, чтобы пополнить коллекцию." if inventory.is_empty() else "Выбери другую категорию снаряжения.",Vector2(455,391),20,Briefing.GOLD)
 screen.caption("СТРАНИЦА  %d / %d"%[collection_page+1,pages],Vector2(432,618),18,Briefing.PAPER)
 var prev:=screen.button("‹",Vector2(1040,597),Vector2(81,54),_set_collection_page.bind(collection_page-1))
 var next:=screen.button("›",Vector2(1135,597),Vector2(81,54),_set_collection_page.bind(collection_page+1))
 prev.disabled=collection_page==0
 next.disabled=collection_page>=pages-1

func _show_subpage(title_text:String)->Briefing:
 var screen:=_briefing()
 var section:=title_text.get_slice(" /",0)
 var art:String={"МАГАЗИН":"depot","ИНВЕНТАРЬ":"depot","СНАРЯЖЕНИЕ":"bench","ПРОФИЛЬ":"dossier","НАСТРОЙКИ":"bench"}.get(section,"dossier")
 if title_text in ["МАГАЗИН / ВСКРЫТИЕ","МАГАЗИН / НАГРАДА"]: art=CASE_ART[last_case_index]
 screen.panel(Vector2.ZERO,Vector2(1280,720),Briefing.CHARCOAL)
 var photo:=screen.picture(art,Vector2(28,95),Vector2(362,587))
 screen.enter_art(photo,-12)
 screen.panel(Vector2(28,550),Vector2(362,132),Briefing.INK)
 screen.panel(Vector2(28,550),Vector2(6,132),Briefing.RUST)
 screen.caption(section,Vector2(50,573),16,Briefing.GOLD)
 screen.caption(title_text.get_slice(" / ",1),Vector2(50,603),30,Briefing.PAPER)
 screen.chrome(section)
 page_body=Control.new()
 page_body.position=Vector2(90,-15)
 page_body.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(page_body)
 page_body.position.y=-5
 page_body.modulate.a=.20
 var appear:=page_body.create_tween().set_parallel(true)
 appear.tween_property(page_body,"position:y",-15.0,.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 appear.tween_property(page_body,"modulate:a",1.0,.20)
 return screen

func _equipment_image(weapon:int, at: Vector2, extent:Vector2, skin_id: int = -1, parent: Control = null) -> TextureRect:
 var image := TextureRect.new()
 var art:="base-%d"%weapon if skin_id<0 else "skin-%d"%skin_id
 image.texture=load("res://assets/armory/catalog/"+art+".webp")
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.position=at
 image.size=extent
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if parent == null: parent=page_body
 parent.add_child(image)
 return image

func _show_loadout()->void:
 var screen:=_show_subpage("СНАРЯЖЕНИЕ / ОРУЖИЕ")
 screen.caption("ТАБЕЛЬНОЕ ОРУЖИЕ",Vector2(432,110),34,Briefing.PAPER)
 for i in WEAPONS.size():
  var at:=Vector2(432+(i%3)*265,184+floori(i/3.0)*208)
  var active:=i==weapon_index
  screen.panel(at,Vector2(254,196),Briefing.INK)
  _equipment_image(i,at+Vector2(8,4),Vector2(238,94),equipped_skins[i],screen)
  screen.caption(WEAPONS[i].name,at+Vector2(10,95),21,Briefing.PAPER)
  screen.caption("%d В МАГАЗИНЕ   ·   %d М"%[MAGAZINE_CAPACITIES[i],WEAPONS[i].range],at+Vector2(11,126),15,Briefing.GOLD)
  screen.button("✓  ВЫБРАНО" if active else "ВЫБРАТЬ",at+Vector2(0,153),Vector2(254,43),_choose_weapon.bind(i),active)
 screen.button("ПОКРЫТИЯ ОРУЖИЯ  ›",Vector2(432,615),Vector2(264,52),_set_collection_filter.bind(weapon_index))

func _choose_weapon(index:int)->void:
 weapon_index=index
 _save()
 _show_loadout()

func _show_file()->void:
 var screen:=_show_subpage("ПРОФИЛЬ / ЛИЧНОЕ ДЕЛО")
 screen.caption("ПОСЛУЖНОЙ СПИСОК",Vector2(432,117),34,Briefing.PAPER)
 var values:=[str(xp),str(credits),"%d / %d"%[inventory.size(),Loot.ITEMS.size()]]
 var labels:=["ОПЫТ","КРЕДИТЫ","КОЛЛЕКЦИЯ"]
 for i in 3:
  var x:=432+i*269
  screen.panel(Vector2(x,196),Vector2(251,128),Briefing.INK)
  screen.caption(labels[i],Vector2(x+18,214),17,Briefing.GOLD)
  screen.caption(values[i],Vector2(x+18,246),36,Briefing.PAPER)
 screen.caption("КАМПАНИЯ",Vector2(433,378),17,Briefing.GOLD)
 screen.caption("ОТПУСК ОДОБРЕН" if campaign_complete else str(Story.mission(stage).name),Vector2(431,412),36,Briefing.PAPER)
 for i in 5:
  screen.panel(Vector2(432+i*153,487),Vector2(141,6),Briefing.RUST if i<=stage else Color("#554d43"))
 screen.caption("ЭТАП  %d / 5"%[stage+1],Vector2(433,512),18,Briefing.PAPER)
 screen.button("К ОПЕРАЦИЯМ   ›",Vector2(433,594),Vector2(287,62),func(): _navigate("ИГРАТЬ"),true)

func _show_settings()->void:
 var screen:=_show_subpage("НАСТРОЙКИ / ANDROID")
 screen.caption("ПАРАМЕТРЫ ИГРЫ",Vector2(432,117),34,Briefing.PAPER)
 var names:=["ГРАФИКА","ЧАСТОТА КАДРОВ","АВТОСТРЕЛЬБА"]
 var values:=[["ЭКОНОМИЯ","БАЛАНС","КАЧЕСТВО"][graphics_level],"%d FPS"%fps_limit,"ВКЛ" if auto_fire else "ВЫКЛ"]
 for i in 3:
  var y:=217+i*104
  screen.panel(Vector2(432,y),Vector2(788,87),Briefing.INK)
  screen.caption(names[i],Vector2(451,y+22),23,Briefing.PAPER)
  screen.button(str(values[i])+"    ›",Vector2(941,y+15),Vector2(259,56),_change_setting.bind(i))
 screen.caption("Настройки сохраняются автоматически. Доступная частота кадров зависит от устройства.",Vector2(434,553),17,Briefing.GOLD,767)

func _change_setting(index:int)->void:
 match index:
  0: graphics_level=(graphics_level+1)%3
  1: fps_limit=60 if fps_limit==30 else (90 if fps_limit==60 else 30)
  2: auto_fire=not auto_fire
 _apply_settings()
 _save_settings()
 _show_settings()

func _apply_settings()->void:
 Engine.max_fps=fps_limit
 var scale_values:=[0.65,0.85,1.0]
 get_viewport().scaling_3d_scale=scale_values[graphics_level]
 if is_instance_valid(cam):
  cam.far=32.0 if graphics_level==0 else (48.0 if graphics_level==1 else 65.0)

func _load_settings()->void:
 if not FileAccess.file_exists(SETTINGS_PATH): return
 var file:=FileAccess.open(SETTINGS_PATH,FileAccess.READ)
 var data=JSON.parse_string(file.get_as_text())
 if data is Dictionary:
  graphics_level=clampi(int(data.get("graphics",1)),0,2)
  fps_limit=int(data.get("fps",60))
  if fps_limit not in [30,60,90]: fps_limit=60
  auto_fire=bool(data.get("auto_fire",true))

func _save_settings()->void:
 var file:=FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
 file.store_string(JSON.stringify({"graphics":graphics_level,"fps":fps_limit,"auto_fire":auto_fire}))

func _start(is_endless:bool, mission:=-1)->void:
 active_stage=stage if is_endless or mission<0 else clampi(mission,0,stage)
 _set_location(0 if is_endless else active_stage)
 radar.objectives=[]
 if registry!=null:
  registry.reset_files()
  radar.objectives=registry.files
 _refresh_documents()
 for mark in marks:mark.queue_free()
 marks.clear()
 hero.position=Vector3(0,0,9 if registry!=null else 4)
 hero.rotation=Vector3.ZERO
 hero.reset_motion()
 pitch=0
 elapsed=0
 look_touch_id=-1
 if not DisplayServer.is_touchscreen_available() and DisplayServer.get_name()!="headless":
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 endless=is_endless
 kills=0
 hp=100
 damage_flash=0.0
 camera_kick=0.0
 _update_camera(0)
 for bolt in bolts: bolt.queue_free()
 bolts.clear()
 ribbon.feed_time=0.0
 glint.life=0.0
 glint.queue_redraw()
 enemy_timer=0
 for e in enemies:
  if is_instance_valid(e): e.queue_free()
 enemies.clear()
 _clear_menu()
 playing=true
 world_root.show()
 menu_layer.hide()
 hud.show()
 hud.get_node("Balance").text="◈  %d"%credits
 hp_label.text="✚ 100"
 health_bar.value=100
 timer_label.text="00:00"
 damage_overlay.color=Color.TRANSPARENT
 hit_marker.hide()
 fire_button.visible=not auto_fire
 fire_touch_id=-1
 fire_requested=false
 fire_timer=0.0
 reload_timer=0.0
 magazine_rounds=MAGAZINE_CAPACITIES.duplicate()
 touch_id=-1
 joystick=Vector2.ZERO
 _update_joystick_visual()
 _refresh_ammo_ui()
 _refresh_weapon_button()
 _apply_weapon_skin()
 status_label.text="∞ БЕСКОНЕЧНЫЙ" if endless else str(Story.mission(active_stage)["name"])
 kills_label.text="0 / ∞" if endless else "0 / %d"%_target()

func _win()->void:
 playing=false
 if active_stage >= Story.MISSIONS.size()-1:
  campaign_complete=true
 elif active_stage==stage:
  stage+=1
 credits+=220+stage*45
 _save()
 _show_result(true)

func _show_result(won:bool)->void:
 _show_menu()
 var result_text := "ОПЕРАЦИЯ ПРОВАЛЕНА"
 if won:
  result_text = "РАПОРТ ПОДПИСАН! ОТПУСК ДО НОВОГО ГОДА!" if active_stage==Story.MISSIONS.size()-1 else "МИССИЯ ВЫПОЛНЕНА"
 var l:=_label(result_text,26)
 l.position=Vector2(38,653)
 l.add_theme_constant_override("outline_size",5)
 menu_layer.add_child(l)

func _input(event:InputEvent)->void:
 if not playing: return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  _turn(event.relative*0.0023)
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  fire_requested=true
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_C: hero.toggle_stance()
  if event.keycode==KEY_J: hero.queue_jump()
  if event.keycode==KEY_R: _start_reload()
  if event.keycode>=KEY_1 and event.keycode<=KEY_5: _select_slot(event.keycode-KEY_1)
  if event.keycode==KEY_Q: _cycle_weapon()
 if not auto_fire and event is InputEventKey and event.keycode==KEY_SPACE:
  if event.pressed and not event.echo:
   fire_requested=true
  get_viewport().set_input_as_handled()
  return
 if event is InputEventScreenTouch:
  if not auto_fire:
   if event.pressed and fire_touch_id==-1 and fire_button.get_global_rect().has_point(event.position):
    fire_touch_id=event.index
    fire_requested=true
    get_viewport().set_input_as_handled()
    return
   if not event.pressed and event.index==fire_touch_id:
    fire_touch_id=-1
    get_viewport().set_input_as_handled()
    return
  if event.pressed and touch_id==-1 and event.position.x<get_viewport().get_visible_rect().size.x*0.45 and event.position.y>get_viewport().get_visible_rect().size.y*0.35:
   touch_id=event.index
   touch_origin=event.position
   joystick=Vector2.ZERO
   _update_joystick_visual()
  elif not event.pressed and event.index==touch_id:
   touch_id=-1
   joystick=Vector2.ZERO
   _update_joystick_visual()
  elif event.pressed and event.position.x>=get_viewport().get_visible_rect().size.x*0.45 and look_touch_id==-1:
   var over_button:=false
   for control in hud.get_children():
    if control is Button and control.visible and control.get_global_rect().has_point(event.position):
     over_button=true
   if not over_button: look_touch_id=event.index
  elif not event.pressed and event.index==look_touch_id:
   look_touch_id=-1
 if event is InputEventScreenDrag and event.index==look_touch_id:
  _turn(event.relative*0.004)
 if event is InputEventScreenDrag and event.index==touch_id:
  joystick=((event.position-touch_origin)/65.0).limit_length()
  _update_joystick_visual()
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  _show_menu()

func _turn(amount:Vector2)->void:
 hero.rotation.y-=amount.x
 pitch=clampf(pitch-amount.y,-1.18,1.18)

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  look_touch_id=-1
  fire_touch_id=-1
  fire_requested=false
  touch_id=-1
  joystick=Vector2.ZERO
  _update_joystick_visual()

func _update_joystick_visual()->void:
 if is_instance_valid(joystick_knob):
  joystick_knob.position=Vector2(42,42)+joystick*34.0

func _load()->void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var file:=FileAccess.open(SAVE_PATH,FileAccess.READ)
 var data=JSON.parse_string(file.get_as_text())
 if data is Dictionary:
  stage=clampi(int(data.get("stage",0)),0,Story.MISSIONS.size()-1)
  xp=int(data.get("xp",0))
  campaign_complete=bool(data.get("campaign_complete",false))
  credits=max(0,int(data.get("credits",350)))
  loot_misses=clampi(int(data.get("loot_misses",0)),0,19)
  cases_opened=max(0,int(data.get("cases_opened",0)))
  last_drop=clampi(int(data.get("last_drop",-1)),-1,Loot.ITEMS.size()-1)
  equipped_skins=[-1,-1,-1,-1,-1]
  var saved_skins=data.get("equipped_skins",[-1,-1,-1,-1,-1])
  weapon_index=clampi(int(data.get("weapon_index",0)),0,WEAPONS.size()-1)
  if saved_skins is Array:
   for slot in mini(saved_skins.size(),WEAPONS.size()):
    equipped_skins[slot]=clampi(int(saved_skins[slot]),-1,Loot.ITEMS.size()-1)
  inventory.clear()
  for value in data.get("inventory",[]):
   var item_id:int=int(value)
   if item_id>=0 and item_id<Loot.ITEMS.size() and not inventory.has(item_id):
    inventory.append(item_id)
  for slot in WEAPONS.size():
   if equipped_skins[slot]>=0 and (not inventory.has(equipped_skins[slot]) or int(Loot.ITEMS[equipped_skins[slot]]["weapon"])!=slot):
    equipped_skins[slot]=-1

func _save()->void:
 var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
 file.store_string(JSON.stringify({"stage":stage,"xp":xp,"campaign_complete":campaign_complete,"credits":credits,"loot_misses":loot_misses,"cases_opened":cases_opened,"last_drop":last_drop,"inventory":inventory,"equipped_skins":equipped_skins,"weapon_index":weapon_index}))
