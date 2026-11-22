extends Node3D

const Story = preload("res://scripts/story.gd")
const Loot = preload("res://scripts/loot.gd")
const TacticalCamera = preload("res://scripts/tactical_camera.gd")
const SAVE_PATH := "user://vacation_save.json"
const SETTINGS_PATH := "user://tactical_settings.json"
var graphics_level := 1
var fps_limit := 60
var auto_fire := true
var camera_shake := false
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
var equipped_skins := [-1,-1,-1]
var last_drop_duplicate := false
var case_spin_tween: Tween
var case_spin_finished := false
var last_case_index := 0
var collection_filter := -1
var collection_page := 0
const SKIN_PALETTE := ["#71818b","#b8a17a","#a3b4bd","#a5e5ee","#36e5ca","#ff9d43","#6178ba","#a07be8","#e1bc6d","#ffca59","#d7515e","#f6d8fa"]
var loot_rng := RandomNumberGenerator.new()
var playing := false
var enemies: Array[Node3D] = []
var enemy_timer := 0.0
var fire_timer := 0.0
var magazine_rounds := [30,12,6]
var reload_timer := 0.0
var reload_duration := 1.5
var reload_progress: ProgressBar
var ammo_label: Label
var reload_button: Button
var recoil_timer := 0.0
var joystick := Vector2.ZERO
var touch_origin := Vector2.ZERO
var touch_id := -1
var joystick_base: Panel
var joystick_knob: Panel
var hud: Control
var menu_layer: Control
var status_label: Label
var hp_label: Label
var health_bar: ProgressBar
var weapon_button: Button
var weapon_status: Label
var kills_label: Label
var hero: Node3D
var cam: Camera3D
var world_root: Node3D
var weapon_index := 0
var hit_flash_timer := 0.0
var hit_marker: Label
var damage_overlay: ColorRect
var damage_flash := 0.0
var camera_kick := 0.0
const WEAPONS := [
 {"name":"КАНЦЕЛЯРСКИЙ АВТОМАТ", "damage":26.0, "cooldown":0.22, "range":17.0},
 {"name":"СТЕПЛЕР", "damage":46.0, "cooldown":0.65, "range":11.0},
 {"name":"ПАПКА С ГРИФОМ", "damage":70.0, "cooldown":1.15, "range":21.0}
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
 var env := WorldEnvironment.new()
 var environment := Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("#9cabb1")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("#f1e4ce")
 environment.ambient_light_energy = 0.65
 env.environment = environment
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-35,0)
 sun.light_energy = 1.1
 add_child(sun)
 _box(world_root,"Concrete floor",Vector3(0,-0.2,0),Vector3(40,0.4,42),Color("#ab9b82"),true)
 for z in [-20.0,20.0]:
  _box(world_root,"Outer wall",Vector3(0,2.1,z),Vector3(40,4.2,0.65),Color("#b5aa94"),true)
 for x in [-19.7,19.7]:
  _box(world_root,"Outer wall",Vector3(x,2.1,0),Vector3(0.65,4.2,42),Color("#b5aa94"),true)
 for i in range(18):
  var x: float = float((i*13)%31)-15.0
  var z: float = float((i*17)%33)-16.0
  if Vector2(x,z).length() < 5.0:
   continue
  _box(world_root,"Filing cabinet %d"%i,Vector3(x,0.9,z),Vector3(2.1,1.8,1.2),Color("#52616a") if i%3==0 else Color("#aa9c80"),true)
  _box(world_root,"Cabinet trim %d"%i,Vector3(x,1.75,z),Vector3(2.15,0.1,1.25),Color("#303f47"))
 # Lightweight environmental dressing: checkpoint, lane markings and warning lights.
 for i in range(11):
  var lane_z:float=-17.0+float(i)*3.3
  _box(world_root,"Road stripe %d"%i,Vector3(0,-0.005,lane_z),Vector3(0.17,0.012,1.45),Color("#d9c38d"))
 for side in [-1.0,1.0]:
  _box(world_root,"Checkpoint post",Vector3(side*6.0,1.65,-12.0),Vector3(0.45,3.3,0.45),Color("#414b4d"),true)
  _box(world_root,"Warning lamp",Vector3(side*6.0,3.4,-12.0),Vector3(0.65,0.35,0.65),Color("#e6a24e"))
  _box(world_root,"Barricade",Vector3(side*10.0,0.55,-8.0),Vector3(3.3,1.1,0.55),Color("#b1a28a"),true)
  for stripe in range(3):
   _box(world_root,"Barricade marking",Vector3(side*10.0-1.0+stripe*1.0,0.8,-8.29),Vector3(0.38,0.23,0.035),Color("#d7ad52"))
 _box(world_root,"Checkpoint gate",Vector3(0,3.2,-12.0),Vector3(12.4,0.5,0.6),Color("#394a4f"))
 _box(world_root,"Checkpoint sign",Vector3(0,3.24,-12.34),Vector3(4.7,0.32,0.06),Color("#d7b667"))
 for i in range(8):
  var ix:float=-15.0+float(i%4)*10.0
  var iz:float=-13.0+float(i/4)*26.0
  _box(world_root,"Supply crate %d"%i,Vector3(ix,0.48,iz),Vector3(1.1,0.95,1.0),Color("#52625b"),true)
  _box(world_root,"Crate lid %d"%i,Vector3(ix,0.98,iz),Vector3(1.18,0.12,1.08),Color("#293c39"))
 hero = Node3D.new()
 hero.name = "Player"
 add_child(hero)
 _make_operator(hero,Color("#475c63"),true)
 _apply_weapon_skin()
 cam = Camera3D.new()
 cam.current = true
 cam.fov = 52
 add_child(cam)
 _update_camera(1.0)
 _apply_settings()

func _make_operator(root: Node3D, uniform: Color, player: bool) -> void:
 _box(root,"Boots",Vector3(0,0.18,0),Vector3(0.55,0.35,0.37),Color("#222b2b"))
 _box(root,"Legs",Vector3(0,0.62,0),Vector3(0.64,0.65,0.40),uniform)
 _box(root,"Vest",Vector3(0,1.25,0),Vector3(0.9,0.75,0.52),Color("#303c40"))
 _box(root,"Shoulders",Vector3(0,1.45,0),Vector3(1.14,0.22,0.42),uniform)
 _box(root,"Helmet",Vector3(0,1.93,0),Vector3(0.63,0.45,0.65),Color("#28373b"))
 _box(root,"Visor",Vector3(0,1.95,-0.34),Vector3(0.52,0.19,0.08),Color("#151f26"))
 _box(root,"Left arm",Vector3(-0.64,1.18,-0.08),Vector3(0.26,0.68,0.33),uniform)
 _box(root,"Right arm",Vector3(0.64,1.18,-0.08),Vector3(0.26,0.68,0.33),uniform)
 _box(root,"Left glove",Vector3(-0.64,0.77,-0.10),Vector3(0.28,0.22,0.34),Color("#202c2e"))
 _box(root,"Right glove",Vector3(0.64,0.77,-0.10),Vector3(0.28,0.22,0.34),Color("#202c2e"))
 _box(root,"Left knee guard",Vector3(-0.19,0.48,-0.23),Vector3(0.25,0.22,0.09),Color("#303b3b"))
 _box(root,"Right knee guard",Vector3(0.19,0.48,-0.23),Vector3(0.25,0.22,0.09),Color("#303b3b"))
 _box(root,"Chest armor",Vector3(0,1.26,-0.29),Vector3(0.74,0.54,0.13),Color("#36494b"))
 _box(root,"Left pouch",Vector3(-0.31,0.99,-0.39),Vector3(0.23,0.22,0.15),Color("#69705b"))
 _box(root,"Right pouch",Vector3(0.31,0.99,-0.39),Vector3(0.23,0.22,0.15),Color("#69705b"))
 _box(root,"Utility belt",Vector3(0,0.87,-0.05),Vector3(0.77,0.13,0.48),Color("#222b2b"))
 _box(root,"Helmet rim",Vector3(0,1.77,-0.01),Vector3(0.71,0.12,0.72),Color("#1e2b2d"))
 _box(root,"Weapon",Vector3(0.33,1.24,-0.52),Vector3(0.16,0.18,1.05),Color("#1d252b"))
 _box(root,"Weapon barrel",Vector3(0.33,1.24,-1.12),Vector3(0.09,0.09,0.36),Color("#111b20"))
 _box(root,"Weapon sight",Vector3(0.33,1.37,-0.55),Vector3(0.11,0.12,0.19),Color("#303b40"))
 _box(root,"Weapon magazine",Vector3(0.33,1.05,-0.44),Vector3(0.13,0.28,0.19),Color("#303b40"))
 if not player:
  _box(root,"Clerk badge",Vector3(0,1.42,-0.3),Vector3(0.35,0.22,0.05),Color("#e7d3a0"))

func _spawn_enemy() -> void:
 if enemies.size() >= 20:
  return
 var e := Node3D.new()
 var roll:=randf()
 var enemy_kind:=0
 if stage>=2 and roll<0.18:
  enemy_kind=2
 elif roll<0.42:
  enemy_kind=1
 var angle := randf()*TAU
 e.position = Vector3(cos(angle)*15.0,0,sin(angle)*16.0)
 add_child(e)
 match enemy_kind:
  1:
   e.name="Fast Courier"
   _make_operator(e,Color("#6d8068"),false)
   e.set_meta("hp",43.0+stage*6.0)
   e.set_meta("speed",2.65+stage*0.1)
   e.set_meta("damage",8.0)
  2:
   e.name="Armored Bureaucrat"
   _make_operator(e,Color("#565a67"),false)
   _box(e,"Heavy armor",Vector3(0,1.3,-0.38),Vector3(1.03,0.77,0.17),Color("#29353d"))
   e.set_meta("hp",170.0+stage*16.0)
   e.set_meta("speed",1.05+stage*0.05)
   e.set_meta("damage",20.0)
  _:
   e.name="Zombie Clerk"
   _make_operator(e,Color("#737467"),false)
   e.set_meta("hp",70.0+stage*10.0)
   e.set_meta("speed",1.6+stage*0.08)
   e.set_meta("damage",12.0)
 enemies.append(e)

func _process(delta: float) -> void:
 if not playing:
  if is_instance_valid(hero):
   hero.rotation.y = sin(Time.get_ticks_msec()*0.0005)*0.12
  _update_camera(delta)
  return
 var move: Vector2 = joystick
 if Input.is_key_pressed(KEY_A): move.x -= 1
 if Input.is_key_pressed(KEY_D): move.x += 1
 if Input.is_key_pressed(KEY_W): move.y -= 1
 if Input.is_key_pressed(KEY_S): move.y += 1
 move = move.limit_length()
 hero.position.x = clampf(hero.position.x+move.x*delta*6.0,-18,18)
 hero.position.z = clampf(hero.position.z+move.y*delta*6.0,-18,18)
 enemy_timer -= delta
 if enemy_timer <= 0:
  enemy_timer = maxf(0.6,2.0-stage*0.15)
  _spawn_enemy()
 var hp_before:=hp
 for e in enemies.duplicate():
  if not is_instance_valid(e): continue
  var diff: Vector3 = hero.position-e.position
  diff.y = 0
  var distance_to_hero:float=diff.length()
  if distance_to_hero>1.4:
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
   if e.name=="Fast Courier" and distance_to_hero<8.0:
    lateral=Vector3(-desired.z,0.0,desired.x)*sin(float(Time.get_ticks_msec())*0.0017+float(e.get_instance_id()%17))*0.35
   var steering:Vector3=desired+separation*1.2+lateral
   if steering.length_squared()>0.001:
    var next_position:Vector3=e.position+steering.normalized()*delta*float(e.get_meta("speed",1.6))
    next_position.x=clampf(next_position.x,-18.7,18.7)
    next_position.z=clampf(next_position.z,-18.7,18.7)
    e.position=_enemy_navigate(e,next_position,steering.normalized(),delta)
  else:
   hp-=delta*float(e.get_meta("damage",12.0))
  if distance_to_hero>0.01:
   e.look_at(Vector3(hero.position.x,e.position.y,hero.position.z),Vector3.UP)
 if hp<hp_before:
  damage_flash=minf(0.55,damage_flash+delta*0.9)
  camera_kick=minf(0.28,camera_kick+delta*0.5)
 damage_flash=maxf(0.0,damage_flash-delta*1.7)
 camera_kick=maxf(0.0,camera_kick-delta*1.2)
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
 if auto_fire and fire_timer<=0 and reload_timer<=0.0 and magazine_rounds[weapon_index]>0:
  var nearest: Node3D = null
  var distance: float = float(WEAPONS[weapon_index]["range"])
  for e in enemies:
   if not is_instance_valid(e): continue
   var d: float = hero.position.distance_to(e.position)
   if d<distance and _has_clear_shot(e):
    distance=d
    nearest=e
  if nearest != null:
   fire_timer=float(WEAPONS[weapon_index]["cooldown"])
   magazine_rounds[weapon_index]-=1
   _animate_weapon_recoil()
   camera_kick=minf(0.18,camera_kick+0.045)
   _refresh_ammo_ui()
   hero.look_at(Vector3(nearest.position.x,hero.position.y,nearest.position.z),Vector3.UP)
   _show_shot_feedback(nearest)
   var remaining: float = float(nearest.get_meta("hp"))-float(WEAPONS[weapon_index]["damage"])
   nearest.set_meta("hp",remaining)
   _show_hit_feedback(nearest)
   if remaining<=0:
    enemies.erase(nearest)
    _animate_enemy_defeat(nearest)
    kills+=1
    xp+=10
    kills_label.text="%d / %d"%[kills,_target()]
    if not endless and kills>=_target():
     _win()
 if playing and magazine_rounds[weapon_index]<=0 and reload_timer<=0.0:
  _start_reload()
 if hp<=0:
  playing=false
  _show_result(false)
 hp_label.text="✚ %d"%ceili(maxf(hp,0))
 if is_instance_valid(health_bar):
  health_bar.value=clampf(hp,0.0,100.0)
  health_bar.modulate=Color("#e96c62") if hp<=30.0 else Color("#68e0c1")
 _update_camera(delta)

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

func _has_clear_shot(target:Node3D)->bool:
 # OpenFPS-style hitscan visibility check; enemy health remains lightweight.
 # Props/walls are StaticBody3D and block shots; the target has no collider.
 if not is_instance_valid(target) or not is_instance_valid(hero): return false
 var from:Vector3=hero.global_position+Vector3(0.33,1.25,0.0)
 var to:Vector3=target.global_position+Vector3(0.0,1.3,0.0)
 var params:=PhysicsRayQueryParameters3D.create(from,to)
 params.collide_with_areas=false
 var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(params)
 return hit.is_empty()

func _animate_enemy_defeat(target:Node3D)->void:
 if not is_instance_valid(target): return
 # Defeated enemies stop moving immediately because they leave the active list.
 # The short collapse gives combat a readable finish without skeletal animations.
 var collapse:=create_tween()
 collapse.set_parallel(true)
 collapse.tween_property(target,"rotation_degrees:x",72.0,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 collapse.tween_property(target,"position:y",-0.55,0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 collapse.tween_property(target,"scale",Vector3(1.0,0.25,1.0),0.38)
 collapse.chain().tween_callback(func():
  if is_instance_valid(target): target.queue_free()
 )

func _animate_weapon_recoil()->void:
 if not is_instance_valid(hero): return
 var weapon:=hero.get_node_or_null("Weapon") as MeshInstance3D
 if weapon==null: return
 var baseline:Vector3=Vector3(0.33,1.24,-0.52)
 var kick:float=0.055 if weapon_index==0 else (0.10 if weapon_index==1 else 0.14)
 weapon.position=baseline+Vector3(0.0,0.035,kick)
 var tween:=create_tween()
 tween.tween_property(weapon,"position",baseline,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _show_shot_feedback(target:Node3D)->void:
 var start:=hero.global_position+Vector3(0.32,1.25,0)
 var finish:=target.global_position+Vector3(0,1.3,0)
 var distance:=start.distance_to(finish)
 if distance<0.1: return
 var direction:Vector3=(finish-start).normalized()
 var tracer:=_box(world_root,"Shot tracer",(start+finish)*0.5,Vector3(0.045,0.045,distance),Color("#ffe5a0"))
 tracer.look_at(finish,Vector3.UP)
 var muzzle:=_box(world_root,"Muzzle flash",start+direction*0.3,Vector3(0.28,0.28,0.28),Color("#ffc75c"))
 var shot_tween:=create_tween()
 shot_tween.set_parallel(true)
 shot_tween.tween_property(tracer,"scale",Vector3(0.1,0.1,1.0),0.09)
 shot_tween.tween_property(muzzle,"scale",Vector3.ZERO,0.11)
 shot_tween.chain().tween_callback(func():
  if is_instance_valid(tracer): tracer.queue_free()
  if is_instance_valid(muzzle): muzzle.queue_free()
 )

func _show_hit_feedback(target:Node3D)->void:
 hit_flash_timer=0.13
 if is_instance_valid(hit_marker):
  hit_marker.visible=true
 var flash:=_box(target,"Hit flash",Vector3(0,1.4,-0.42),Vector3(0.92,0.65,0.08),Color("#ff7759"))
 var tween:=create_tween()
 tween.tween_property(flash,"scale",Vector3(0.1,0.1,0.1),0.18)
 tween.tween_callback(flash.queue_free)
 # Floating damage is attached to the arena, so a defeated enemy can disappear.
 var popup:=Label3D.new()
 popup.text="-%d"%int(WEAPONS[weapon_index]["damage"])
 popup.font_size=44
 popup.pixel_size=0.007
 popup.modulate=Color("#ffe2a0")
 popup.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 popup.no_depth_test=true
 popup.position=target.global_position+Vector3(0.0,2.45,0.0)
 world_root.add_child(popup)
 var float_tween:=create_tween()
 float_tween.set_parallel(true)
 float_tween.tween_property(popup,"position:y",popup.position.y+0.85,0.52)
 float_tween.tween_property(popup,"modulate:a",0.0,0.52)
 float_tween.chain().tween_callback(popup.queue_free)
 # Brief body impact without a skeleton or extra textures.
 if not target.has_meta("staggering"):
  target.set_meta("staggering",true)
  var base_scale:Vector3=target.scale
  var impact:=create_tween()
  impact.tween_property(target,"scale",base_scale*Vector3(1.08,0.92,1.08),0.065)
  impact.tween_property(target,"scale",base_scale,0.14)
  impact.tween_callback(func():
   if is_instance_valid(target): target.remove_meta("staggering")
  )

func _target()->int:
 return int(Story.mission(stage)["kills"])

func _update_camera(delta: float)->void:
 if not is_instance_valid(hero) or not is_instance_valid(cam): return
 TacticalCamera.follow(cam,hero,delta,playing,camera_kick)

func _build_ui()->void:
 var layer := CanvasLayer.new()
 layer.name="Interface"
 add_child(layer)
 hud=Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(hud)
 var bar:=HBoxContainer.new()
 bar.position=Vector2(28,20)
 var hud_strip:=_panel(Vector2(18,12),Vector2(430,60),Color(0.025,0.065,0.085,0.82))
 hud.add_child(hud_strip)
 hud.move_child(hud_strip,0)
 hud.add_child(bar)
 hp_label=_label("✚ 100",27)
 bar.add_child(hp_label)
 health_bar=ProgressBar.new()
 health_bar.custom_minimum_size=Vector2(96,20)
 health_bar.max_value=100.0
 health_bar.value=100.0
 health_bar.show_percentage=false
 health_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 health_bar.modulate=Color("#68e0c1")
 bar.add_child(health_bar)
 kills_label=_label("0 / %d"%_target(),22)
 bar.add_child(kills_label)
 status_label=_label("ОПЕРАЦИЯ",17)
 status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
 status_label.position=Vector2(-125,20)
 status_label.custom_minimum_size=Vector2(250,32)
 status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 status_label.add_theme_color_override("font_color",Color("#b4e9e4"))
 hud.add_child(status_label)
 var pause:=_button("Ⅱ  МЕНЮ")
 pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 pause.position=Vector2(-190,14)
 pause.pressed.connect(_show_menu)
 hud.add_child(pause)
 weapon_button=_button("↻ "+str(WEAPONS[weapon_index]["name"]))
 weapon_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 weapon_button.position=Vector2(-290,-98)
 weapon_button.custom_minimum_size=Vector2(275,66)
 weapon_button.pressed.connect(_cycle_weapon)
 hud.add_child(weapon_button)
 reload_button=_button("↻ ПЕРЕЗАРЯДКА")
 reload_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 reload_button.position=Vector2(-290,-205)
 reload_button.custom_minimum_size=Vector2(275,45)
 reload_button.pressed.connect(_start_reload)
 hud.add_child(reload_button)
 ammo_label=_label("30 / 30",18)
 ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 ammo_label.position=Vector2(-290,-161)
 hud.add_child(ammo_label)
 reload_progress=ProgressBar.new()
 reload_progress.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 reload_progress.position=Vector2(-290,-212)
 reload_progress.size=Vector2(275,5)
 reload_progress.show_percentage=false
 reload_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
 reload_progress.modulate=Color("#59e0cf")
 hud.add_child(reload_progress)
 _refresh_ammo_ui()
 weapon_status=_label("АВТО • "+str(WEAPONS[weapon_index]["name"]),14)
 weapon_status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 weapon_status.position=Vector2(-290,-126)
 weapon_status.add_theme_color_override("font_color",Color("#83e9df"))
 hud.add_child(weapon_status)
 joystick_base=_panel(Vector2(32,-166),Vector2(132,132),Color(0.05,0.13,0.16,0.38))
 joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 joystick_base.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.add_child(joystick_base)
 joystick_knob=_panel(Vector2(42,42),Vector2(48,48),Color(0.18,0.74,0.70,0.78))
 joystick_knob.mouse_filter=Control.MOUSE_FILTER_IGNORE
 joystick_base.add_child(joystick_knob)
 hit_marker=_label("✕",38)
 hit_marker.set_anchors_preset(Control.PRESET_CENTER)
 hit_marker.position=Vector2(-16,-24)
 hit_marker.add_theme_color_override("font_color",Color("#62f2de"))
 hit_marker.visible=false
 hud.add_child(hit_marker)
 damage_overlay=ColorRect.new()
 damage_overlay.color=Color(0.82,0.09,0.07,0.0)
 damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 damage_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.add_child(damage_overlay)
 hud.move_child(damage_overlay,0)
 menu_layer=Control.new()
 menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(menu_layer)

func _cycle_weapon()->void:
 weapon_index=(weapon_index+1)%WEAPONS.size()
 reload_timer=0.0
 _refresh_ammo_ui()
 _refresh_weapon_button()
 _apply_weapon_skin()

func _magazine_capacity()->int:
 return [30,12,6][weapon_index]

func _start_reload()->void:
 if not playing or reload_timer>0.0: return
 if magazine_rounds[weapon_index]>=_magazine_capacity(): return
 reload_timer=reload_duration
 _refresh_ammo_ui()

func _refresh_ammo_ui()->void:
 if is_instance_valid(ammo_label):
  ammo_label.text="ПЕРЕЗАРЯДКА..." if reload_timer>0.0 else "ПАТРОНЫ  %d / %d"%[magazine_rounds[weapon_index],_magazine_capacity()]
 if is_instance_valid(reload_progress):
  reload_progress.visible=reload_timer>0.0
  reload_progress.value=100.0*(1.0-reload_timer/reload_duration)
 if is_instance_valid(reload_button):
  reload_button.disabled=not playing or reload_timer>0.0 or magazine_rounds[weapon_index]>=_magazine_capacity()

func _apply_weapon_skin()->void:
 if not is_instance_valid(hero): return
 var skin_id:int=equipped_skins[weapon_index]
 var tint:=Color("#1d252b") if skin_id<0 else Color(SKIN_PALETTE[skin_id])
 for part_name in ["Weapon","Weapon sight","Weapon magazine"]:
  var part:=hero.get_node_or_null(part_name) as MeshInstance3D
  if part==null: continue
  var material:=StandardMaterial3D.new()
  material.albedo_color=tint if part_name=="Weapon" else tint.darkened(0.28)
  material.metallic=0.38 if skin_id>=0 else 0.0
  material.roughness=0.38 if skin_id>=0 else 0.9
  part.material_override=material
 _update_weapon_silhouette()
 _add_skin_details(skin_id)

func _update_weapon_silhouette()->void:
 if not is_instance_valid(hero): return
 var body:=hero.get_node_or_null("Weapon") as MeshInstance3D
 var barrel:=hero.get_node_or_null("Weapon barrel") as MeshInstance3D
 var magazine:=hero.get_node_or_null("Weapon magazine") as MeshInstance3D
 var sight:=hero.get_node_or_null("Weapon sight") as MeshInstance3D
 if body==null or barrel==null or magazine==null or sight==null: return
 match weapon_index:
  0:
   body.scale=Vector3.ONE
   barrel.scale=Vector3.ONE
   magazine.visible=true
   sight.visible=true
  1:
   body.scale=Vector3(1.55,1.2,0.64)
   barrel.scale=Vector3(1.4,1.2,0.48)
   magazine.visible=false
   sight.visible=false
  2:
   body.scale=Vector3(2.7,0.5,1.15)
   barrel.scale=Vector3(1.0,0.7,0.45)
   magazine.visible=false
   sight.visible=true

func _clear_skin_details()->void:
 if not is_instance_valid(hero): return
 var old:=hero.get_node_or_null("SkinDetails")
 if old!=null:
  hero.remove_child(old)
  old.queue_free()

func _add_skin_details(skin_id:int)->void:
 _clear_skin_details()
 if skin_id<0 or not is_instance_valid(hero): return
 var details:=Node3D.new()
 details.name="SkinDetails"
 hero.add_child(details)
 var primary:=Color(SKIN_PALETTE[skin_id])
 var accent:=Color(str(Loot.RARITY_COLORS[int(Loot.ITEMS[skin_id]["rarity"])]))
 var style_id:int=skin_id%4
 for i in range(4):
  var z:float=-0.87+float(i)*0.22
  var stripe_color:=accent if i%2==0 else primary.lightened(0.36)
  match style_id:
   0:
    _box(details,"Stripe %d"%i,Vector3(0.33,1.337,z),Vector3(0.165,0.018,0.06),stripe_color)
   1:
    _box(details,"Circuit %d"%i,Vector3(0.33,1.337,z),Vector3(0.065+float(i%2)*0.08,0.018,0.025),stripe_color)
   2:
    _box(details,"Panel %d"%i,Vector3(0.33,1.337,z),Vector3(0.17,0.018,0.11),stripe_color.darkened(0.2))
   _:
    _box(details,"Gold line %d"%i,Vector3(0.33,1.337,z),Vector3(0.13,0.018,0.025),accent)
 _box(details,"Skin emblem",Vector3(0.33,1.35,-0.53),Vector3(0.12,0.02,0.1),accent)

func _refresh_weapon_button()->void:
 if is_instance_valid(weapon_button):
  weapon_button.text="↻ "+str(WEAPONS[weapon_index]["name"])
 if is_instance_valid(weapon_status):
  weapon_status.text=("АВТО • " if auto_fire else "РУЧНОЙ • ")+str(WEAPONS[weapon_index]["name"])

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
 style.border_color=Color("#35d6cb")
 p.add_theme_stylebox_override("panel",style)
 return p

func _label(value:String,size:int)->Label:
 var l:=Label.new()
 l.text=value
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",Color("#f5e6c9"))
 return l

func _button(value:String)->Button:
 var b:=Button.new()
 b.text=value
 b.custom_minimum_size=Vector2(160,45)
 b.add_theme_font_size_override("font_size",16)
 b.add_theme_color_override("font_color",Color("#e8f3f5"))
 b.add_theme_color_override("font_hover_color",Color("#ffffff"))
 var normal:=StyleBoxFlat.new()
 normal.bg_color=Color("#18303c")
 normal.set_corner_radius_all(8)
 normal.border_width_left=3
 normal.border_color=Color("#2ebcb8")
 b.add_theme_stylebox_override("normal",normal)
 var hover:=normal.duplicate()
 hover.bg_color=Color("#255363")
 b.add_theme_stylebox_override("hover",hover)
 b.add_theme_stylebox_override("pressed",hover)
 b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 return b

func _clear_menu()->void:
 for child in menu_layer.get_children():
  child.queue_free()

func _show_menu()->void:
 playing=false
 _clear_menu()
 var shade:=ColorRect.new()
 shade.color=Color(0.018,0.035,0.055,0.94)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 menu_layer.add_child(shade)
 var header_strip:=ColorRect.new()
 header_strip.color=Color(0.035,0.09,0.115,0.94)
 header_strip.position=Vector2(0,0)
 header_strip.size=Vector2(1280,36)
 header_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(header_strip)
 var nav:=_label("ОПЕРАЦИИ     /     АРСЕНАЛ     /     ПРОФИЛЬ     /     ПАРАМЕТРЫ",14)
 nav.position=Vector2(55,8)
 nav.add_theme_color_override("font_color",Color("#81cfc9"))
 menu_layer.add_child(nav)
 var build_tag:=_label("TACTICAL  •  ANDROID",13)
 build_tag.position=Vector2(1050,8)
 menu_layer.add_child(build_tag)
 var accent:=ColorRect.new()
 accent.color=Color("#36d4c6")
 accent.position=Vector2(55,93)
 accent.size=Vector2(360,3)
 menu_layer.add_child(accent)
 var title:=_label("ОТПУСК / TACTICAL",37)
 title.position=Vector2(55,42)
 menu_layer.add_child(title)
 var story:=_label(Story.INTRO,16)
 story.position=Vector2(55,112)
 story.custom_minimum_size=Vector2(820,60)
 story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 menu_layer.add_child(story)
 var labels:=["▶ "+("КАМПАНИЯ ПРОЙДЕНА — ПОВТОР" if campaign_complete else "КАМПАНИЯ: "+str(Story.mission(stage)["name"])),"∞ БЕСКОНЕЧНЫЙ РЕЖИМ","◈ СНАРЯЖЕНИЕ","▣ КЕЙСЫ / ДРОП","▤ ЛИЧНОЕ ДЕЛО","⚙ НАСТРОЙКИ"]
 for i in range(labels.size()):
  var b:=_button(labels[i])
  b.position=Vector2(55,205+i*58)
  b.custom_minimum_size=Vector2(360,49)
  menu_layer.add_child(b)
  if i==0:
   var primary:=StyleBoxFlat.new()
   primary.bg_color=Color("#258f8b")
   primary.set_corner_radius_all(8)
   primary.border_width_left=4
   primary.border_color=Color("#a7fff0")
   b.add_theme_stylebox_override("normal",primary)
  match i:
   0: b.pressed.connect(func(): _start(false))
   1: b.pressed.connect(func(): _start(true))
   2: b.pressed.connect(_show_loadout)
   3: b.pressed.connect(_show_cases)
   4: b.pressed.connect(_show_file)
   5: b.pressed.connect(_show_settings)
 var credits_label:=_label("КРЕДИТЫ  %d  ◈"%credits,17)
 credits_label.position=Vector2(800,55)
 credits_label.add_theme_color_override("font_color",Color("#ffce76"))
 menu_layer.add_child(credits_label)
 var mission_panel:=_panel(Vector2(455,198),Vector2(545,205),Color(0.065,0.13,0.16,0.88))
 menu_layer.add_child(mission_panel)
 var mission_title:=_label("ОПЕРАЦИЯ / %02d  ·  %s"%[stage+1,str(Story.mission(stage)["name"])],22)
 mission_title.position=Vector2(475,214)
 menu_layer.add_child(mission_title)
 var briefing:=_label(str(Story.mission(stage)["brief"]),17)
 briefing.position=Vector2(475,260)
 briefing.custom_minimum_size=Vector2(500,100)
 briefing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 menu_layer.add_child(briefing)
 var operator_panel:=_panel(Vector2(1030,198),Vector2(215,205),Color(0.055,0.12,0.15,0.90))
 menu_layer.add_child(operator_panel)
 var operator_title:=_label("ОПЕРАТОР",19)
 operator_title.position=Vector2(1050,216)
 menu_layer.add_child(operator_title)
 var operator_details:=_label("СТАТУС: ГОТОВ\nАРСЕНАЛ: 03\nОПЫТ: %d"%xp,15)
 operator_details.position=Vector2(1050,259)
 menu_layer.add_child(operator_details)
 var footer:=_label("ОТПУСК / TACTICAL    •    МОБИЛЬНАЯ ОПЕРАЦИЯ    •    GODOT 4",13)
 footer.position=Vector2(55,655)
 footer.add_theme_color_override("font_color",Color("#83b7b8"))
 menu_layer.add_child(footer)

func _show_cases()->void:
 _show_menu()
 var title:=_label("МАГАЗИН / КЕЙСЫ",24)
 title.position=Vector2(475,197)
 menu_layer.add_child(title)
 var details:=_label("◈ %d КРЕДИТОВ     •     ОТКРЫТО %d     •     СКИНОВ %d/%d"%[credits,cases_opened,inventory.size(),Loot.ITEMS.size()],15)
 details.position=Vector2(475,234)
 details.add_theme_color_override("font_color",Color("#ffce76"))
 menu_layer.add_child(details)
 var accents:=["#5ba8ff","#bb76ff","#ffc36b"]
 var descriptions:=["БАЗОВЫЙ НАБОР","ПОВЫШЕННЫЕ ШАНСЫ","МАКСИМАЛЬНЫЙ БОНУС"]
 for i in range(Loot.CASES.size()):
  var data:Dictionary=Loot.CASES[i]
  var x:float=475+i*176
  var card:=_panel(Vector2(x,273),Vector2(166,206),Color("#10232d"))
  card.add_theme_stylebox_override("panel",_rarity_panel_style(Color(accents[i])))
  menu_layer.add_child(card)
  var emblem:=_label(["◈","◆","✦"][i],38)
  emblem.position=Vector2(x+62,290)
  emblem.add_theme_color_override("font_color",Color(accents[i]))
  menu_layer.add_child(emblem)
  var case_name:=_label(str(data["name"]),14)
  case_name.position=Vector2(x+12,343)
  menu_layer.add_child(case_name)
  var description:=_label(descriptions[i],11)
  description.position=Vector2(x+12,367)
  description.add_theme_color_override("font_color",Color("#9bbcc5"))
  menu_layer.add_child(description)
  var button:=_button("ОТКРЫТЬ  %d ◈"%int(data["price"]))
  button.position=Vector2(x+9,412)
  button.custom_minimum_size=Vector2(148,48)
  button.disabled=credits<int(data["price"])
  button.pressed.connect(_open_case.bind(i))
  menu_layer.add_child(button)
 var guarantee:=_label("ГАРАНТИЯ: %d/20  •  ПОСЛЕ 19 НЕУДАЧ СЛЕДУЮЩИЙ ДРОП ЭПИЧЕСКИЙ+"%mini(loot_misses,19),14)
 guarantee.position=Vector2(475,491)
 menu_layer.add_child(guarantee)
 var odds:=_label("ШАНСЫ БАЗОВОГО КЕЙСА: РЕДКИЙ 27%  /  ЭПИК 12%  /  ЛЕГЕНДА 5%  /  УЛЬТРА 1%",12)
 odds.position=Vector2(475,521)
 odds.add_theme_color_override("font_color",Color("#9bbcc5"))
 menu_layer.add_child(odds)
 var collection:=_button("МОЯ КОЛЛЕКЦИЯ")
 collection.position=Vector2(475,558)
 collection.custom_minimum_size=Vector2(252,46)
 collection.pressed.connect(_show_collection)
 menu_layer.add_child(collection)
 if last_drop>=0:
  var item:Dictionary=Loot.ITEMS[last_drop]
  var last:=_label("ПОСЛЕДНИЙ: "+str(item["name"]),14)
  last.position=Vector2(743,572)
  last.add_theme_color_override("font_color",Color(str(Loot.RARITY_COLORS[int(item["rarity"])])))
  menu_layer.add_child(last)

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
 if inventory.has(item_id):
  credits+=int(Loot.DUPLICATE_CREDITS[int(drop["rarity"])])
 else:
  inventory.append(item_id)
 _save()
 _show_case_roulette(item_id)

func _show_case_roulette(item_id:int)->void:
 _show_menu()
 var title:=_label("ВСКРЫТИЕ КЕЙСА  /  СКАНИРОВАНИЕ",23)
 title.position=Vector2(475,218)
 menu_layer.add_child(title)
 var frame:=_panel(Vector2(472,280),Vector2(515,170),Color("#0b1e29"))
 menu_layer.add_child(frame)
 case_spin_finished=false
 var slots:Array[Label]=[]
 var cards:Array[Panel]=[]
 for i in range(5):
  var card:=_panel(Vector2(488+i*100,304),Vector2(92,110),Color("#20313e"))
  menu_layer.add_child(card)
  cards.append(card)
  var name_label:=_label("...",12)
  name_label.position=Vector2(494+i*100,340)
  name_label.custom_minimum_size=Vector2(80,65)
  name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  menu_layer.add_child(name_label)
  slots.append(name_label)
 var marker:=ColorRect.new()
 marker.color=Color("#65f2dd")
 marker.position=Vector2(731,290)
 marker.size=Vector2(3,140)
 marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(marker)
 var hint:=_label("ИДЁТ ВЫБОР НАГРАДЫ...",16)
 hint.position=Vector2(475,490)
 menu_layer.add_child(hint)
 var steps:=24
 var reel:Array[int]=[]
 for i in range(steps+5):
  reel.append(loot_rng.randi_range(0,Loot.ITEMS.size()-1))
 reel[steps+2]=item_id
 for j in range(5):
  _update_reel_slot(slots[j],reel[j])
 var skip:=_button("ПРОПУСТИТЬ АНИМАЦИЮ")
 skip.position=Vector2(475,537)
 skip.custom_minimum_size=Vector2(470,47)
 skip.pressed.connect(_finish_case_spin.bind(item_id))
 menu_layer.add_child(skip)
 case_spin_tween=create_tween()
 for step in range(1,steps+1):
  var delay:float=0.045+0.008*float(step*step)/float(steps)
  case_spin_tween.tween_interval(delay)
  case_spin_tween.tween_callback(_advance_case_reel.bind(frame,slots,cards,reel,step))
 case_spin_tween.tween_interval(0.45)
 case_spin_tween.tween_callback(_finish_case_spin.bind(item_id))

func _finish_case_spin(item_id:int)->void:
 if case_spin_finished: return
 case_spin_finished=true
 if case_spin_tween!=null and case_spin_tween.is_running():
  case_spin_tween.kill()
 _show_drop_reveal(item_id)

func _advance_case_reel(frame:Panel,slots:Array[Label],cards:Array[Panel],reel:Array[int],step:int)->void:
 if not is_instance_valid(frame): return
 for j in range(5):
  if is_instance_valid(slots[j]):
   _update_reel_slot(slots[j],reel[step+j])
   var rarity:int=int(Loot.ITEMS[reel[step+j]]["rarity"])
   cards[j].add_theme_stylebox_override("panel",_rarity_panel_style(Color(str(Loot.RARITY_COLORS[rarity]))))

func _update_reel_slot(slot:Label,item_id:int)->void:
 var item:Dictionary=Loot.ITEMS[item_id]
 slot.text=str(item["name"])
 slot.add_theme_color_override("font_color",Color(str(Loot.RARITY_COLORS[int(item["rarity"])])))

func _show_drop_reveal(item_id:int)->void:
 _show_menu()
 var item:Dictionary=Loot.ITEMS[item_id]
 var rarity:int=int(item["rarity"])
 var color:=Color(str(Loot.RARITY_COLORS[rarity]))
 var panel:=_panel(Vector2(470,202),Vector2(530,385),Color(0.035,0.075,0.095,0.98))
 panel.add_theme_stylebox_override("panel",_rarity_panel_style(color))
 menu_layer.add_child(panel)
 var header:=_label("ПОЛУЧЕН ПРЕДМЕТ",23)
 header.position=Vector2(502,225)
 menu_layer.add_child(header)
 var rarity_text:=_label(str(Loot.RARITY_NAMES[rarity]),17)
 rarity_text.position=Vector2(502,273)
 rarity_text.add_theme_color_override("font_color",color)
 menu_layer.add_child(rarity_text)
 var item_name:=_label(str(item["name"]),29)
 item_name.position=Vector2(502,320)
 item_name.add_theme_color_override("font_color",color)
 menu_layer.add_child(item_name)
 item_name.modulate.a=0.0
 item_name.position.y+=16.0
 var reveal:=create_tween().set_parallel(true)
 reveal.tween_property(item_name,"modulate:a",1.0,0.35).set_delay(0.18)
 reveal.tween_property(item_name,"position:y",320.0,0.42).set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 var weapon_name:=_label("ОРУЖИЕ: "+str(WEAPONS[int(item["weapon"])]["name"]),17)
 weapon_name.position=Vector2(502,375)
 menu_layer.add_child(weapon_name)
 var equip:=_button("ЭКИПИРОВАТЬ")
 equip.position=Vector2(502,444)
 equip.custom_minimum_size=Vector2(215,50)
 equip.pressed.connect(_equip_skin.bind(item_id))
 menu_layer.add_child(equip)
 var again:=_button("К КЕЙСАМ")
 again.position=Vector2(734,444)
 again.custom_minimum_size=Vector2(215,50)
 again.pressed.connect(_show_cases)
 menu_layer.add_child(again)
 var repeat_cost:int=int(Loot.CASES[last_case_index]["price"])
 var repeat:=_button("ЕЩЁ РАЗ  /  %d ◈"%repeat_cost)
 repeat.position=Vector2(502,501)
 repeat.custom_minimum_size=Vector2(447,46)
 repeat.disabled=credits<repeat_cost
 repeat.pressed.connect(_open_case.bind(last_case_index))
 menu_layer.add_child(repeat)
 var hint:=_label("Предмет сохранён в коллекции. Дубликаты возвращают часть кредитов.",14)
 hint.position=Vector2(502,560)
 menu_layer.add_child(hint)

func _rarity_panel_style(color:Color)->StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("#10232d")
 style.set_corner_radius_all(12)
 style.set_border_width_all(3)
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
 _show_menu()
 var item:Dictionary=Loot.ITEMS[item_id]
 var rarity:int=int(item["rarity"])
 var weapon:int=int(item["weapon"])
 var tint:=Color(SKIN_PALETTE[item_id])
 var rarity_color:=Color(str(Loot.RARITY_COLORS[rarity]))
 var title:=_label("АРСЕНАЛ / ПРЕДПРОСМОТР СКИНА",23)
 title.position=Vector2(475,207)
 menu_layer.add_child(title)
 var panel:=_panel(Vector2(475,255),Vector2(510,278),Color("#10232d"))
 panel.add_theme_stylebox_override("panel",_rarity_panel_style(rarity_color))
 menu_layer.add_child(panel)
 var stripe:=ColorRect.new()
 stripe.color=tint
 stripe.position=Vector2(510,327)
 stripe.size=Vector2(400,36)
 stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(stripe)
 var barrel:=ColorRect.new()
 barrel.color=tint.darkened(0.4)
 barrel.position=Vector2(810,338)
 barrel.size=Vector2(150,13)
 barrel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(barrel)
 var grip:=ColorRect.new()
 grip.color=tint.darkened(0.28)
 grip.position=Vector2(600,357)
 grip.size=Vector2(42,75)
 grip.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(grip)
 var accent:=ColorRect.new()
 accent.color=rarity_color
 accent.position=Vector2(510,316)
 accent.size=Vector2(400,5)
 accent.mouse_filter=Control.MOUSE_FILTER_IGNORE
 menu_layer.add_child(accent)
 var name_label:=_label(str(item["name"]),26)
 name_label.position=Vector2(506,270)
 name_label.add_theme_color_override("font_color",rarity_color)
 menu_layer.add_child(name_label)
 var info:=_label(str(WEAPONS[weapon]["name"])+"  /  "+str(Loot.RARITY_NAMES[rarity]),16)
 info.position=Vector2(506,464)
 menu_layer.add_child(info)
 var equipped:bool=equipped_skins[weapon]==item_id
 var equip:=_button("✓ ЭКИПИРОВАН" if equipped else "ЭКИПИРОВАТЬ")
 equip.position=Vector2(475,548)
 equip.custom_minimum_size=Vector2(244,50)
 equip.disabled=equipped
 equip.pressed.connect(_equip_skin.bind(item_id))
 menu_layer.add_child(equip)
 var back:=_button("← К КОЛЛЕКЦИИ")
 back.position=Vector2(737,548)
 back.custom_minimum_size=Vector2(248,50)
 back.pressed.connect(_show_collection)
 menu_layer.add_child(back)
 var note:=_label("СХЕМАТИЧНЫЙ ПРЕДПРОСМОТР ЦВЕТА • В ИГРЕ СКИН НА 3D-ОРУЖИИ",12)
 note.position=Vector2(475,610)
 menu_layer.add_child(note)

func _set_collection_filter(value:int)->void:
 collection_filter=value
 collection_page=0
 _show_collection()

func _set_collection_page(value:int)->void:
 collection_page=maxi(0,value)
 _show_collection()

func _show_collection()->void:
 _show_menu()
 var title:=_label("АРСЕНАЛ / КОЛЛЕКЦИЯ  %d/%d"%[inventory.size(),Loot.ITEMS.size()],22)
 title.position=Vector2(475,203)
 menu_layer.add_child(title)
 var back:=_button("← К КЕЙСАМ")
 back.position=Vector2(475,242)
 back.custom_minimum_size=Vector2(230,43)
 back.pressed.connect(_show_cases)
 menu_layer.add_child(back)
 var filters:=["ВСЕ","АВТОМАТ","СТЕПЛЕР","ПАПКА"]
 for i in range(filters.size()):
  var filter_value:int=i-1
  var filter_button:=_button(("● " if collection_filter==filter_value else "")+filters[i])
  filter_button.position=Vector2(475+i*127,297)
  filter_button.custom_minimum_size=Vector2(121,40)
  filter_button.pressed.connect(_set_collection_filter.bind(filter_value))
  menu_layer.add_child(filter_button)
 var filtered:Array[int]=[]
 for item_id in inventory:
  if collection_filter<0 or int(Loot.ITEMS[item_id]["weapon"])==collection_filter:
   filtered.append(item_id)
 filtered.sort_custom(func(a:int,b:int)->bool:
  return int(Loot.ITEMS[a]["rarity"])>int(Loot.ITEMS[b]["rarity"])
 )
 var per_page:=6
 var page_count:int=maxi(1,int(ceil(float(filtered.size())/float(per_page))))
 collection_page=clampi(collection_page,0,page_count-1)
 for i in range(collection_page*per_page,mini(filtered.size(),(collection_page+1)*per_page)):
  var item_id:int=filtered[i]
  var item:Dictionary=Loot.ITEMS[item_id]
  var index_on_page:int=i-collection_page*per_page
  var col:int=index_on_page%2
  var row_index:int=int(index_on_page/2)
  var x:float=475+col*260
  var y:float=351+row_index*75
  var rarity:int=int(item["rarity"])
  var rarity_color:=Color(str(Loot.RARITY_COLORS[rarity]))
  var card:=_panel(Vector2(x,y),Vector2(247,66),Color("#10232d"))
  card.add_theme_stylebox_override("panel",_rarity_panel_style(rarity_color))
  menu_layer.add_child(card)
  var equipped:bool=equipped_skins[int(item["weapon"])]==item_id
  var entry:=_button(("✓ " if equipped else "◈ ")+str(item["name"]))
  entry.position=Vector2(x+7,y+6)
  entry.custom_minimum_size=Vector2(233,32)
  entry.add_theme_color_override("font_color",rarity_color)
  entry.pressed.connect(_show_skin_preview.bind(item_id))
  menu_layer.add_child(entry)
  var sub:=_label(str(Loot.RARITY_NAMES[rarity])+("   /   ЭКИПИРОВАН" if equipped else "   /   НАЖМИТЕ ДЛЯ ВЫБОРА"),11)
  sub.position=Vector2(x+12,y+43)
  menu_layer.add_child(sub)
 if filtered.is_empty():
  var empty:=_label("В ЭТОЙ КАТЕГОРИИ ПОКА НЕТ СКИНОВ",17)
  empty.position=Vector2(475,408)
  menu_layer.add_child(empty)
 var page_label:=_label("СТРАНИЦА %d / %d   •   ПРЕДМЕТОВ: %d"%[collection_page+1,page_count,filtered.size()],15)
 page_label.position=Vector2(475,604)
 menu_layer.add_child(page_label)
 var prev:=_button("←")
 prev.position=Vector2(800,595)
 prev.custom_minimum_size=Vector2(72,42)
 prev.disabled=collection_page==0
 prev.pressed.connect(_set_collection_page.bind(collection_page-1))
 menu_layer.add_child(prev)
 var next:=_button("→")
 next.position=Vector2(884,595)
 next.custom_minimum_size=Vector2(72,42)
 next.disabled=collection_page>=page_count-1
 next.pressed.connect(_set_collection_page.bind(collection_page+1))
 menu_layer.add_child(next)

func _show_loadout()->void:
 _show_menu()
 var b:=_button("ОРУЖИЕ: "+str(WEAPONS[weapon_index]["name"]))
 b.position=Vector2(475,370)
 b.custom_minimum_size=Vector2(450,50)
 b.pressed.connect(func(): weapon_index=(weapon_index+1)%WEAPONS.size();_refresh_weapon_button();_apply_weapon_skin();_show_loadout())
 menu_layer.add_child(b)
 var skin_id:int=equipped_skins[weapon_index]
 var skin_text:="СТАНДАРТ" if skin_id<0 else str(Loot.ITEMS[skin_id]["name"])
 var equipped_label:=_label("СКИН: "+skin_text,17)
 equipped_label.position=Vector2(475,432)
 menu_layer.add_child(equipped_label)
 var collection_button:=_button("ВЫБРАТЬ СКИН ИЗ КОЛЛЕКЦИИ")
 collection_button.position=Vector2(475,485)
 collection_button.custom_minimum_size=Vector2(450,47)
 collection_button.pressed.connect(_show_collection)
 menu_layer.add_child(collection_button)

func _show_file()->void:
 _show_menu()
 var l:=_label("ЛИЧНОЕ ДЕЛО  ·  ОПЫТ: %d  ·  ЭТАП: %d\n%s"%[xp,stage+1,Story.BASE],18)
 l.position=Vector2(475,360)
 menu_layer.add_child(l)

func _show_settings()->void:
 _show_menu()
 var title:=_label("⚙ НАСТРОЙКИ / ANDROID",24)
 title.position=Vector2(475,290)
 menu_layer.add_child(title)
 var quality_names:=["ЭКОНОМИЯ","БАЛАНС","КАЧЕСТВО"]
 var quality:=_button("ГРАФИКА: "+quality_names[graphics_level])
 quality.position=Vector2(475,345)
 quality.custom_minimum_size=Vector2(470,48)
 quality.pressed.connect(func(): graphics_level=(graphics_level+1)%3;_apply_settings();_save_settings();_show_settings())
 menu_layer.add_child(quality)
 var frames:=_button("ЧАСТОТА КАДРОВ: %d FPS"%fps_limit)
 frames.position=Vector2(475,400)
 frames.custom_minimum_size=Vector2(470,48)
 frames.pressed.connect(func(): fps_limit=60 if fps_limit==30 else (90 if fps_limit==60 else 30);_apply_settings();_save_settings();_show_settings())
 menu_layer.add_child(frames)
 var shooting:=_button("АВТОСТРЕЛЬБА: "+("ВКЛ" if auto_fire else "ВЫКЛ"))
 shooting.position=Vector2(475,455)
 shooting.custom_minimum_size=Vector2(470,48)
 shooting.pressed.connect(func(): auto_fire=not auto_fire;_save_settings();_show_settings())
 menu_layer.add_child(shooting)
 var note:=_label("Настройки сохраняются автоматически.\n90 FPS зависит от экрана и мощности телефона.",15)
 note.position=Vector2(475,515)
 menu_layer.add_child(note)

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

func _start(is_endless:bool)->void:
 endless=is_endless
 kills=0
 hp=100
 damage_flash=0.0
 camera_kick=0.0
 enemy_timer=0
 for e in enemies:
  if is_instance_valid(e): e.queue_free()
 enemies.clear()
 _clear_menu()
 playing=true
 touch_id=-1
 joystick=Vector2.ZERO
 _update_joystick_visual()
 weapon_index=0
 _refresh_weapon_button()
 _apply_weapon_skin()
 status_label.text="∞ БЕСКОНЕЧНЫЙ" if endless else str(Story.mission(stage)["name"])
 kills_label.text="0 / ∞" if endless else "0 / %d"%_target()

func _win()->void:
 playing=false
 if stage >= Story.MISSIONS.size()-1:
  campaign_complete=true
 else:
  stage+=1
 credits+=220+stage*45
 _save()
 _show_result(true)

func _show_result(won:bool)->void:
 _show_menu()
 var result_text := "ОПЕРАЦИЯ ПРОВАЛЕНА"
 if won:
  result_text = "РАПОРТ ПОДПИСАН! ОТПУСК ДО НОВОГО ГОДА!" if campaign_complete else "МИССИЯ ВЫПОЛНЕНА — СЛЕДУЮЩИЙ ЭТАП ОТКРЫТ"
 var l:=_label(result_text,26)
 l.position=Vector2(475,480)
 menu_layer.add_child(l)

func _input(event:InputEvent)->void:
 if not playing: return
 if event is InputEventScreenTouch:
  if event.pressed and touch_id==-1 and event.position.x<get_viewport().get_visible_rect().size.x*0.45 and event.position.y>get_viewport().get_visible_rect().size.y*0.35:
   touch_id=event.index
   touch_origin=event.position
   joystick=Vector2.ZERO
   _update_joystick_visual()
  elif not event.pressed and event.index==touch_id:
   touch_id=-1
   joystick=Vector2.ZERO
   _update_joystick_visual()
 if event is InputEventScreenDrag and event.index==touch_id:
  joystick=((event.position-touch_origin)/65.0).limit_length()
  _update_joystick_visual()
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  _show_menu()

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
  equipped_skins=[-1,-1,-1]
  var saved_skins=data.get("equipped_skins",[-1,-1,-1])
  if saved_skins is Array and saved_skins.size()==3:
   for slot in range(3):
    equipped_skins[slot]=clampi(int(saved_skins[slot]),-1,Loot.ITEMS.size()-1)
  inventory.clear()
  for value in data.get("inventory",[]):
   var item_id:int=int(value)
   if item_id>=0 and item_id<Loot.ITEMS.size() and not inventory.has(item_id):
    inventory.append(item_id)
  for slot in range(3):
   if equipped_skins[slot]>=0 and (not inventory.has(equipped_skins[slot]) or int(Loot.ITEMS[equipped_skins[slot]]["weapon"])!=slot):
    equipped_skins[slot]=-1

func _save()->void:
 var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
 file.store_string(JSON.stringify({"stage":stage,"xp":xp,"campaign_complete":campaign_complete,"credits":credits,"loot_misses":loot_misses,"cases_opened":cases_opened,"last_drop":last_drop,"inventory":inventory,"equipped_skins":equipped_skins}))
