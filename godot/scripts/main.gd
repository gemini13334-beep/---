extends Node3D

const Story = preload("res://scripts/story.gd")
const SAVE_PATH := "user://vacation_save.json"
var stage := 0
var endless := false
var kills := 0
var hp := 100.0
var xp := 0
var playing := false
var enemies: Array[Node3D] = []
var enemy_timer := 0.0
var fire_timer := 0.0
var joystick := Vector2.ZERO
var touch_origin := Vector2.ZERO
var touch_id := -1
var hud: Control
var menu_layer: Control
var status_label: Label
var hp_label: Label
var kills_label: Label
var hero: Node3D
var cam: Camera3D
var world_root: Node3D
var weapon_index := 0
const WEAPONS := [
 {"name":"КАНЦЕЛЯРСКИЙ АВТОМАТ", "damage":26.0, "cooldown":0.22, "range":17.0},
 {"name":"СТЕПЛЕР", "damage":46.0, "cooldown":0.65, "range":11.0},
 {"name":"ПАПКА С ГРИФОМ", "damage":70.0, "cooldown":1.15, "range":21.0}
]

func _ready() -> void:
 _load()
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
  var x := float((i*13)%31)-15.0
  var z := float((i*17)%33)-16.0
  if Vector2(x,z).length() < 5.0:
   continue
  _box(world_root,"Filing cabinet %d"%i,Vector3(x,0.9,z),Vector3(2.1,1.8,1.2),Color("#52616a") if i%3==0 else Color("#aa9c80"),true)
  _box(world_root,"Cabinet trim %d"%i,Vector3(x,1.75,z),Vector3(2.15,0.1,1.25),Color("#303f47"))
 hero = Node3D.new()
 hero.name = "Player"
 add_child(hero)
 _make_operator(hero,Color("#475c63"),true)
 cam = Camera3D.new()
 cam.current = true
 cam.fov = 52
 add_child(cam)
 _update_camera(1.0)

func _make_operator(root: Node3D, uniform: Color, player: bool) -> void:
 _box(root,"Boots",Vector3(0,0.18,0),Vector3(0.55,0.35,0.37),Color("#222b2b"))
 _box(root,"Legs",Vector3(0,0.62,0),Vector3(0.64,0.65,0.40),uniform)
 _box(root,"Vest",Vector3(0,1.25,0),Vector3(0.9,0.75,0.52),Color("#303c40"))
 _box(root,"Shoulders",Vector3(0,1.45,0),Vector3(1.14,0.22,0.42),uniform)
 _box(root,"Helmet",Vector3(0,1.93,0),Vector3(0.63,0.45,0.65),Color("#28373b"))
 _box(root,"Visor",Vector3(0,1.95,-0.34),Vector3(0.52,0.19,0.08),Color("#151f26"))
 _box(root,"Weapon",Vector3(0.33,1.24,-0.52),Vector3(0.16,0.18,1.05),Color("#1d252b"))
 if not player:
  _box(root,"Clerk badge",Vector3(0,1.42,-0.3),Vector3(0.35,0.22,0.05),Color("#e7d3a0"))

func _spawn_enemy() -> void:
 if enemies.size() >= 20:
  return
 var e := Node3D.new()
 e.name = "Zombie Clerk"
 var angle := randf()*TAU
 e.position = Vector3(cos(angle)*15.0,0,sin(angle)*16.0)
 add_child(e)
 _make_operator(e,Color("#737467"),false)
 e.set_meta("hp",70.0+stage*10.0)
 enemies.append(e)

func _process(delta: float) -> void:
 if not playing:
  if is_instance_valid(hero):
   hero.rotation.y = sin(Time.get_ticks_msec()*0.0005)*0.12
  _update_camera(delta)
  return
 var move := joystick
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
 for e in enemies.duplicate():
  if not is_instance_valid(e): continue
  var diff := hero.position-e.position
  diff.y = 0
  if diff.length()>1.4:
   e.position += diff.normalized()*delta*(1.6+stage*0.08)
  else:
   hp -= delta*12.0
  e.look_at(Vector3(hero.position.x,e.position.y,hero.position.z),Vector3.UP)
 fire_timer -= delta
 if fire_timer<=0:
  var nearest: Node3D = null
  var distance := float(WEAPONS[weapon_index]["range"])
  for e in enemies:
   if not is_instance_valid(e): continue
   var d := hero.position.distance_to(e.position)
   if d<distance:
    distance=d
    nearest=e
  if nearest != null:
   fire_timer=float(WEAPONS[weapon_index]["cooldown"])
   hero.look_at(Vector3(nearest.position.x,hero.position.y,nearest.position.z),Vector3.UP)
   var remaining := float(nearest.get_meta("hp"))-float(WEAPONS[weapon_index]["damage"])
   nearest.set_meta("hp",remaining)
   if remaining<=0:
    enemies.erase(nearest)
    nearest.queue_free()
    kills+=1
    xp+=10
    kills_label.text="%d / %d"%[kills,_target()]
    if not endless and kills>=_target():
     _win()
 if hp<=0:
  playing=false
  _show_result(false)
 hp_label.text="✚ %d"%ceili(maxf(hp,0))
 _update_camera(delta)

func _target()->int:
 return int(Story.mission(stage)["kills"])

func _update_camera(delta: float)->void:
 if not is_instance_valid(hero) or not is_instance_valid(cam): return
 var distance := 10.5 if playing else 8.0
 var desired := hero.position+Vector3(0,distance*0.85,distance)
 cam.position=cam.position.lerp(desired,clampf(delta*5,0,1))
 cam.look_at(hero.position+Vector3(0,1.0,0),Vector3.UP)

func _build_ui()->void:
 var layer := CanvasLayer.new()
 layer.name="Interface"
 add_child(layer)
 hud=Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(hud)
 var bar:=HBoxContainer.new()
 bar.position=Vector2(18,12)
 hud.add_child(bar)
 hp_label=_label("✚ 100",27)
 bar.add_child(hp_label)
 kills_label=_label("0 / %d"%_target(),22)
 bar.add_child(kills_label)
 status_label=_label("ОПЕРАЦИЯ",17)
 status_label.position=Vector2(470,12)
 hud.add_child(status_label)
 var pause:=_button("Ⅱ  МЕНЮ")
 pause.position=Vector2(1110,12)
 pause.pressed.connect(_show_menu)
 hud.add_child(pause)
 var weapon:=_button("↻ ОРУЖИЕ")
 weapon.position=Vector2(1090,610)
 weapon.pressed.connect(func(): weapon_index=(weapon_index+1)%WEAPONS.size();weapon.text="↻ "+str(WEAPONS[weapon_index]["name"]))
 hud.add_child(weapon)
 var stick:=_button("◉  ДВИЖЕНИЕ")
 stick.position=Vector2(28,610)
 stick.disabled=true
 hud.add_child(stick)
 menu_layer=Control.new()
 menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(menu_layer)

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
 return b

func _clear_menu()->void:
 for child in menu_layer.get_children():
  child.queue_free()

func _show_menu()->void:
 playing=false
 _clear_menu()
 var shade:=ColorRect.new()
 shade.color=Color(0.04,0.09,0.13,0.88)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 menu_layer.add_child(shade)
 var title:=_label("ОТПУСК / TACTICAL",37)
 title.position=Vector2(55,42)
 menu_layer.add_child(title)
 var story:=_label(Story.INTRO,16)
 story.position=Vector2(55,112)
 story.custom_minimum_size=Vector2(820,60)
 story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 menu_layer.add_child(story)
 var labels:=["▶ КАМПАНИЯ: "+str(Story.mission(stage)["name"]),"∞ БЕСКОНЕЧНЫЙ РЕЖИМ","◈ СНАРЯЖЕНИЕ","▤ ЛИЧНОЕ ДЕЛО","⚙ НАСТРОЙКИ"]
 for i in range(labels.size()):
  var b:=_button(labels[i])
  b.position=Vector2(55,215+i*62)
  b.custom_minimum_size=Vector2(360,49)
  menu_layer.add_child(b)
  match i:
   0: b.pressed.connect(func(): _start(false))
   1: b.pressed.connect(func(): _start(true))
   2: b.pressed.connect(_show_loadout)
   3: b.pressed.connect(_show_file)
   4: b.pressed.connect(_show_settings)
 var briefing:=_label(str(Story.mission(stage)["brief"]),17)
 briefing.position=Vector2(475,220)
 briefing.custom_minimum_size=Vector2(500,100)
 briefing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 menu_layer.add_child(briefing)

func _show_loadout()->void:
 _show_menu()
 var b:=_button("ОРУЖИЕ: "+str(WEAPONS[weapon_index]["name"]))
 b.position=Vector2(475,370)
 b.custom_minimum_size=Vector2(450,50)
 b.pressed.connect(func(): weapon_index=(weapon_index+1)%WEAPONS.size();_show_loadout())
 menu_layer.add_child(b)

func _show_file()->void:
 _show_menu()
 var l:=_label("ЛИЧНОЕ ДЕЛО  ·  ОПЫТ: %d  ·  ЭТАП: %d\n%s"%[xp,stage+1,Story.BASE],18)
 l.position=Vector2(475,360)
 menu_layer.add_child(l)

func _show_settings()->void:
 _show_menu()
 var l:=_label("ГРАФИКА: COMPATIBILITY / ANDROID\nУПРАВЛЕНИЕ: СЕНСОРНЫЙ ДЖОЙСТИК + АВТОСТРЕЛЬБА",17)
 l.position=Vector2(475,360)
 menu_layer.add_child(l)

func _start(is_endless:bool)->void:
 endless=is_endless
 kills=0
 hp=100
 enemy_timer=0
 for e in enemies:
  if is_instance_valid(e): e.queue_free()
 enemies.clear()
 _clear_menu()
 playing=true
 status_label.text="∞ БЕСКОНЕЧНЫЙ" if endless else str(Story.mission(stage)["name"])
 kills_label.text="0 / ∞" if endless else "0 / %d"%_target()

func _win()->void:
 playing=false
 stage=min(stage+1,Story.MISSIONS.size()-1)
 _save()
 _show_result(true)

func _show_result(won:bool)->void:
 _show_menu()
 var l:=_label("МИССИЯ ВЫПОЛНЕНА" if won else "ОПЕРАЦИЯ ПРОВАЛЕНА",30)
 l.position=Vector2(475,480)
 menu_layer.add_child(l)

func _input(event:InputEvent)->void:
 if not playing: return
 if event is InputEventScreenTouch:
  if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x*0.45:
   touch_id=event.index
   touch_origin=event.position
  elif not event.pressed and event.index==touch_id:
   touch_id=-1
   joystick=Vector2.ZERO
 if event is InputEventScreenDrag and event.index==touch_id:
  var diff:Vector2=(event.position-touch_origin)/85.0
  joystick=diff.limit_length()
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  _show_menu()

func _load()->void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var file:=FileAccess.open(SAVE_PATH,FileAccess.READ)
 var data=JSON.parse_string(file.get_as_text())
 if data is Dictionary:
  stage=clampi(int(data.get("stage",0)),0,Story.MISSIONS.size()-1)
  xp=int(data.get("xp",0))

func _save()->void:
 var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
 file.store_string(JSON.stringify({"stage":stage,"xp":xp}))
