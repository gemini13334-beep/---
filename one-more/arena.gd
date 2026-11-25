extends Node3D
var hero: MeshInstance3D
var camera: Camera3D
var enemies: Array[MeshInstance3D] = []
var hud: Label
var retry: Button
var elapsed := 0.0
var spawn_timer := 0.0
var attack_timer := 0.0
var score := 0
var best := 0
var hp := 100.0
var level := 1
var running := false
var finger := -1
var origin := Vector2.ZERO
var direction := Vector2.ZERO
var gems: Array[MeshInstance3D] = []
var crates: Array[MeshInstance3D] = []
var xp := 0
var combo := 0
var combo_time := 0.0
var power := 0
var speed_bonus := 0.0
var magnet := 2.0
var choosing := false
var upgrades: VBoxContainer
var boss_spawned := false
var kills := 0
var credits := 0
var blast := 0
var damage := 1
var armor := 0.0
var reach := 0.0
var regen := 0.0
var score_bonus := 0
var ranks: Dictionary = {}
var offers: Array[int] = []
var offer_buttons: Array[Button] = []
const ABILITIES = [
	["OVERDRIVE","Faster attacks",0],["DASH","Movement speed",0],
	["MAGNET","Pickup + heal",0],["NOVA","Area attack",1],
	["PIERCER","Extra damage",1],["ARMOR","Damage resistance",0],
	["RADAR","Attack range",0],["REGEN","Health recovery",1],
	["FORTRESS","Maximum health",1],["JACKPOT","Extra score",1],
	["THUNDER","Damage + area",2],["PHANTOM","Speed + armor",2],
	["GRAVITY","Magnet + range",2],["BERSERK","Damage + attack speed",2],
	["PHOENIX","Heal + regeneration",2],["TITAN CORE","Health + armor",2]
]

func roll_offers() -> void:
	offers.clear()
	while offers.size() < 3:
		var id := randi_range(0,ABILITIES.size()-1)
		var rarity := int(ABILITIES[id][2])
		if offers.has(id) or (rarity == 2 and randf() > 0.35):
			continue
		offers.append(id)
	for i in range(3):
		var a: Array = ABILITIES[offers[i]]
		offer_buttons[i].text = "%s • %s\n%s" % [["COMMON","RARE","EPIC"][a[2]],a[0],a[1]]
		offer_buttons[i].modulate = [Color.WHITE,Color("#85d9ff"),Color("#e2b2ff")][a[2]]

var selected := 0
var owned: Array[int] = [0]
var collection: VBoxContainer
var collection_buttons: Array[Button] = []
var menu: VBoxContainer
var result_label: Label
var max_hp := 100.0
var mode := 0
var biome := 0
var scenery: Array[MeshInstance3D] = []
var sound: AudioStreamPlayer
var sounds: Dictionary = {}

func tone(freq: float, duration: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(22050*duration)
	data.resize(count*2)
	for i in range(count):
		var t := float(i)/22050.0
		var envelope := pow(1.0-float(i)/count,2.0)
		var sample := int(sin(TAU*freq*t)*envelope*6500)
		data.encode_s16(i*2,sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = data
	return wav

func play_fx(key: String) -> void:
	if sound != null and sounds.has(key):
		sound.stream = sounds[key]
		sound.play()

func rebuild_scenery() -> void:
	for prop in scenery:
		prop.queue_free()
	scenery.clear()
	for i in range(24):
		var angle := TAU*float(i)/24.0
		var radius := 20.5 if i%2 == 0 else 17.5
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.1,1.4,1.1)
		var prop := model(mesh,Color(GROUND_COLORS[biome]).lightened(0.25),Vector3(cos(angle)*radius,0.5,sin(angle)*radius))
		attach_art(prop,BIOMES[biome].to_lower())
		prop.rotation.y = angle
		scenery.append(prop)

var ground: MeshInstance3D
var biome_button: Button
const BIOMES = ["FOREST","CITY","DESERT","ICE","VOLCANO"]
const GROUND_COLORS = ["#294a37","#34404c","#82613d","#426c80","#4d292c"]

func cycle_biome() -> void:
	biome = (biome+1)%BIOMES.size()
	biome_button.text = "MAP • "+BIOMES[biome]
	var mat := ground.material_override as StandardMaterial3D
	mat.albedo_color = Color(GROUND_COLORS[biome])
	rebuild_scenery()

var best_sprint := 0
var runs := 0
var total_kills := 0
var vehicle: MeshInstance3D
var vehicle_time := 0.0
var next_event := 15.0
var event_label: Label
var achievements: Label

func sprint() -> void:
	start()
	mode = 1

func finish_run() -> void:
	running = false
	choosing = false
	upgrades.hide()
	if mode == 1:
		best_sprint = maxi(best_sprint,score)
	else:
		best = maxi(best,score)
	credits += int(score/100.0)
	runs += 1
	total_kills += kills
	save_profile()
	show_menu()

func spawn_vehicle() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.7,0.65,2.4)
	vehicle = model(mesh,Color("#ffc45c"),Vector3(clampf(hero.position.x+5,-19,19),0.5,clampf(hero.position.z+3,-19,19)))
	attach_art(vehicle,"buggy")
	event_label.text = "BOOST BUGGY • Collect the gold vehicle"

func update_events(dt: float) -> void:
	if elapsed >= next_event:
		next_event += 20.0
		if randf() < 0.55:
			spawn_vehicle()
		else:
			for i in range(12):
				drop_gem(Vector3(clampf(hero.position.x+randf_range(-6,6),-20,20),0.3,clampf(hero.position.z+randf_range(-6,6),-20,20)))
			event_label.text = "ENERGY RAIN"
	if is_instance_valid(vehicle) and not vehicle.is_queued_for_deletion():
		if hero.position.distance_to(vehicle.position) < 1.4:
			vehicle.queue_free()
			vehicle_time = 10.0
			play_fx("boost")
			pulse(hero.position,3.0,Color("#ffc45c"))
	if vehicle_time > 0:
		vehicle_time = maxf(0,vehicle_time-dt)
		event_label.text = "BUGGY BOOST • %.1fs" % vehicle_time
		if vehicle_time <= 0:
			event_label.text = ""

var hp_bar: ProgressBar
var xp_bar: ProgressBar
var hero_visual: Node3D
const PALETTE = ["#62f5c5","#8caee9","#ff7043","#b998ff","#e2b45d","#72e5ff"]

func style_button(btn: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#203743") if state == "normal" else Color("#365b68")
		if state == "disabled":
			style.bg_color = Color("#273038")
		style.border_color = Color("#65d9c0")
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		btn.add_theme_stylebox_override(state,style)

func apply_hero_art() -> void:
	for child in hero.get_children():
		hero.remove_child(child)
		child.queue_free()
	hero.mesh = SphereMesh.new()
	var mat := hero.material_override as StandardMaterial3D
	mat.albedo_color = Color(PALETTE[selected])
	attach_art(hero,["hero","cyborg","inferno","ghost","titan","cryo"][selected])

func make_bar(layer: CanvasLayer, y: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	layer.add_child(bar)
	bar.position = Vector2(24,y)
	bar.size = Vector2(672,18)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#182b36")
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background",bg)
	bar.add_theme_stylebox_override("fill",fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

const HEROES = [
	["SLIME",0,"Balanced",100.0,0.0,2.0,0],
	["CYBORG",150,"Rapid fire",100.0,0.0,2.0,2],
	["INFERNO",300,"Area blast",100.0,0.0,2.0,0],
	["GHOST",450,"Fast movement",80.0,2.0,2.0,0],
	["TITAN",600,"Heavy armor",180.0,-0.5,2.0,0],
	["CRYO",800,"Energy magnet",120.0,0.0,4.0,0]
]

func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records","best",best)
	cfg.set_value("records","credits",credits)
	cfg.set_value("records","sprint",best_sprint)
	cfg.set_value("records","runs",runs)
	cfg.set_value("records","kills",total_kills)
	cfg.set_value("collection","owned",owned)
	cfg.set_value("collection","selected",selected)
	cfg.save("user://records.cfg")

func refresh_collection() -> void:
	for i in range(HEROES.size()):
		var h: Array = HEROES[i]
		var status := "SELECTED" if selected == i else ("SELECT" if owned.has(i) else "%d CR" % int(h[1]))
		collection_buttons[i].text = "%s  •  %s\n%s" % [h[0],h[2],status]
		collection_buttons[i].disabled = not owned.has(i) and credits < int(h[1])
	result_label.text = "BEST %d  |  CR %d\n60s BEST %d" % [best,credits,best_sprint]
	achievements.text = "BADGES: %d / 3" % (int(runs >= 1)+int(total_kills >= 100)+int(best >= 10000))

func select_hero(index: int) -> void:
	if not owned.has(index):
		var cost := int(HEROES[index][1])
		if credits < cost:
			return
		credits -= cost
		owned.append(index)
	selected = index
	save_profile()
	refresh_collection()

func show_collection() -> void:
	menu.hide()
	collection.show()
	refresh_collection()

func show_menu() -> void:
	collection.hide()
	menu.show()
	refresh_collection()

func menu_button(parent: Control, label: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(540,78)
	btn.add_theme_font_size_override("font_size",26)
	parent.add_child(btn)
	style_button(btn)
	btn.pressed.connect(action)
	return btn


func pulse(pos: Vector3, radius: float, color: Color) -> void:
	var mesh := SphereMesh.new()
	var effect := model(mesh,color,pos)
	var material := effect.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.28
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	effect.scale = Vector3.ONE*0.2
	var tween := create_tween()
	tween.tween_property(effect,"scale",Vector3.ONE*radius*2,0.22)
	tween.tween_callback(effect.queue_free)

func hit_enemy(enemy: MeshInstance3D) -> void:
	play_fx("hit")
	var health := int(enemy.get_meta("health",1))-damage
	enemy.set_meta("health",health)
	pulse(enemy.position,0.8,Color("#ffb85a"))
	if health > 0:
		return
	var boss := bool(enemy.get_meta("boss",false))
	drop_gem(enemy.position)
	if boss:
		for i in range(8):
			drop_gem(enemy.position+Vector3(randf_range(-2,2),0,randf_range(-2,2)))
	enemies.erase(enemy)
	enemy.queue_free()
	kills += 1
	award(1500 if boss else 100)


func attach_art(host: MeshInstance3D, asset: String) -> void:
	var path := "res://assets/models/" + asset + ".glb"
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var art := packed.instantiate() as Node3D
			if art != null:
				host.add_child(art)
				host.mesh = null
				art.position.y = -0.5

func award(points: int) -> void:
	combo = mini(combo + 1, 20)
	combo_time = 3.0
	score += int(points * (1 + int(combo / 5.0)) * (1.0+score_bonus*0.1))

func drop_gem(pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var gem := model(mesh, Color("#ffd65a"), Vector3(pos.x,0.3,pos.z))
	gems.append(gem)

func choose_upgrade(index: int) -> void:
	if not choosing:
		return
	if index >= offers.size():
		return
	var id := offers[index]
	ranks[id] = int(ranks.get(id,0))+1
	match id:
		0: power += 1
		1: speed_bonus += 0.65
		2:
			magnet += 0.65
			hp = minf(max_hp,hp+20)
		3: blast += 1
		4: damage += 1
		5: armor = minf(0.65,armor+0.08)
		6: reach += 0.7
		7: regen += 0.5
		8:
			max_hp += 25
			hp += 25
		9: score_bonus += 1
		10:
			damage += 1
			blast += 1
		11:
			speed_bonus += 0.7
			armor = minf(0.65,armor+0.1)
		12:
			magnet += 1.0
			reach += 0.8
		13:
			damage += 1
			power += 1
		14:
			hp = max_hp
			regen += 1.0
		15:
			max_hp += 35
			hp += 35
			armor = minf(0.65,armor+0.1)
	if ranks.has(0) and ranks.has(3) and not ranks.has(100):
		ranks[100] = 1
		blast += 2
		event_label.text = "SYNERGY • OVERDRIVE NOVA"
	if ranks.has(1) and ranks.has(2) and not ranks.has(101):
		ranks[101] = 1
		magnet += 2
		event_label.text = "SYNERGY • GRAVITY DASH"
	choosing = false
	upgrades.hide()
	finger = -1
	direction = Vector2.ZERO


func model(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	n.material_override = mat
	add_child(n)
	n.position = pos
	return n

func _ready() -> void:
	sound = AudioStreamPlayer.new()
	add_child(sound)
	sound.volume_db = -12
	sounds = {"hit":tone(180,0.09),"pickup":tone(880,0.12),"level":tone(520,0.35),"boost":tone(320,0.3)}
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(44, 0.2, 44)
	ground = model(floor_mesh, Color(GROUND_COLORS[biome]), Vector3(0,-0.2,0))
	rebuild_scenery()
	for i in range(-20,21,4):
		var line := BoxMesh.new()
		line.size = Vector3(0.035,0.02,44)
		model(line,Color("#36535a"),Vector3(i,-0.08,0))
		var cross := BoxMesh.new()
		cross.size = Vector3(44,0.02,0.035)
		model(cross,Color("#36535a"),Vector3(0,-0.08,i))
	for i in range(32):
		var angle := TAU*float(i)/32.0
		var rock := BoxMesh.new()
		rock.size = Vector3(1.3,randf_range(0.5,2.0),1.3)
		var prop := model(rock,Color("#45616a"),Vector3(cos(angle)*23,0.5,sin(angle)*23))
		prop.rotation.y = angle
	for i in range(12):
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.18
		pillar.bottom_radius = 0.35
		pillar.height = 2.4
		var angle := TAU*float(i)/12.0
		model(pillar,Color("#8cc9c1"),Vector3(cos(angle)*21,1.2,sin(angle)*21))
	var sphere := SphereMesh.new()
	hero = model(sphere,Color("#62f5c5"),Vector3(0,0.5,0))
	apply_hero_art()
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-60,-30,0)
	light.shadow_enabled = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#13242c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	camera.position = Vector3(0,19,15)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	layer.add_child(hud)
	hud.position = Vector2(24,24)
	hud.add_theme_font_size_override("font_size",28)
	hp_bar = make_bar(layer,190,Color("#65e5a5"))
	xp_bar = make_bar(layer,218,Color("#f9c95b"))
	retry = Button.new()
	layer.add_child(retry)
	retry.position = Vector2(110,550)
	retry.size = Vector2(500,110)
	retry.add_theme_font_size_override("font_size",34)
	retry.text = "PLAY • ONE MORE"
	retry.pressed.connect(start)
	retry.hide()
	menu = VBoxContainer.new()
	layer.add_child(menu)
	menu.position = Vector2(90,400)
	menu.add_theme_constant_override("separation",18)
	var title := Label.new()
	title.text = "ONE MORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",64)
	menu.add_child(title)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size",26)
	menu.add_child(result_label)
	menu_button(menu,"PLAY • ENDLESS",start)
	menu_button(menu,"SCORE ATTACK • 60s",sprint)
	biome_button = menu_button(menu,"MAP • FOREST",cycle_biome)
	achievements = Label.new()
	achievements.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievements.add_theme_font_size_override("font_size",24)
	menu.add_child(achievements)
	event_label = Label.new()
	layer.add_child(event_label)
	event_label.position = Vector2(24,245)
	event_label.add_theme_font_size_override("font_size",24)
	menu_button(menu,"HERO COLLECTION",show_collection)
	collection = VBoxContainer.new()
	layer.add_child(collection)
	collection.position = Vector2(90,270)
	collection.add_theme_constant_override("separation",10)
	for i in range(HEROES.size()):
		collection_buttons.append(menu_button(collection,"",select_hero.bind(i)))
	menu_button(collection,"BACK",show_menu)
	collection.hide()
	upgrades = VBoxContainer.new()
	layer.add_child(upgrades)
	upgrades.position = Vector2(90,430)
	upgrades.size = Vector2(540,320)
	upgrades.add_theme_constant_override("separation",16)
	var heading := Label.new()
	heading.text = "EVOLUTION • CHOOSE ONE"
	heading.add_theme_font_size_override("font_size",28)
	upgrades.add_child(heading)
	for i in range(3):
		var btn := Button.new()
		btn.text = "UPGRADE"
		offer_buttons.append(btn)
		btn.custom_minimum_size = Vector2(540,85)
		btn.add_theme_font_size_override("font_size",24)
		upgrades.add_child(btn)
		style_button(btn)
		btn.pressed.connect(choose_upgrade.bind(i))
	upgrades.hide()
	var cfg := ConfigFile.new()
	if cfg.load("user://records.cfg") == OK:
		best = int(cfg.get_value("records","best",0))
		credits = maxi(0,int(cfg.get_value("records","credits",0)))
		best_sprint = int(cfg.get_value("records","sprint",0))
		runs = int(cfg.get_value("records","runs",0))
		total_kills = int(cfg.get_value("records","kills",0))
		var saved: Variant = cfg.get_value("collection","owned",[0])
		if saved is Array:
			for id in saved:
				if id is int and id >= 0 and id < HEROES.size() and not owned.has(id):
					owned.append(id)
		selected = int(cfg.get_value("collection","selected",0))
		if not owned.has(selected):
			selected = 0
	refresh_collection()
	update_hud()

func start() -> void:
	mode = 0
	vehicle_time = 0
	next_event = 15
	event_label.text = ""
	if is_instance_valid(vehicle):
		vehicle.queue_free()
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for gem in gems:
		gem.queue_free()
	gems.clear()
	for crate in crates:
		crate.queue_free()
	crates.clear()
	for i in range(22):
		var p := Vector3(randf_range(-19,19),0.5,randf_range(-19,19))
		if p.length() < 4:
			p.x += 6
		var mesh := BoxMesh.new()
		var crate := model(mesh,Color("#d49b43"),p)
		attach_art(crate,"crate")
		crates.append(crate)
	xp = 0
	boss_spawned = false
	kills = 0
	blast = 0
	damage = 1
	armor = 0
	reach = 0
	regen = 0
	score_bonus = 0
	ranks.clear()
	combo = 0
	combo_time = 0
	power = 0
	speed_bonus = 0
	magnet = 2
	choosing = false
	upgrades.hide()
	hero.position = Vector3(0,0.5,0)
	hero.scale = Vector3.ONE
	elapsed = 0
	score = 0
	apply_hero_art()
	var stats: Array = HEROES[selected]
	max_hp = float(stats[3])
	hp = max_hp
	speed_bonus = float(stats[4])
	magnet = float(stats[5])
	power = int(stats[6])
	if selected == 2:
		blast = 1
	level = 1
	spawn_timer = 0
	attack_timer = 0
	finger = -1
	direction = Vector2.ZERO
	running = true
	retry.hide()
	menu.hide()
	collection.hide()

func _input(event: InputEvent) -> void:
	if not running or choosing:
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			origin = event.position
		elif not event.pressed and event.index == finger:
			finger = -1
			direction = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == finger:
		direction = ((event.position-origin)/90.0).limit_length()

func _physics_process(dt: float) -> void:
	if not running or choosing:
		return
	elapsed += dt
	hp = minf(max_hp,hp+regen*dt)
	update_events(dt)
	if mode == 1 and elapsed >= 60:
		finish_run()
		update_hud()
		return
	combo_time -= dt
	if combo_time <= 0:
		combo = 0
	var move := direction
	if finger == -1:
		move = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if move.length() > 0.05:
		hero.rotation.y = lerp_angle(hero.rotation.y,atan2(move.x,move.y),minf(dt*12,1.0))
	for child in hero.get_children():
		if child is Node3D:
			child.position.y = -0.5+sin(elapsed*10.0)*0.07*move.length()
	hero.position += Vector3(move.x,0,move.y)*dt*(6.0+speed_bonus+(4.0 if vehicle_time > 0 else 0.0))
	hero.position.x = clampf(hero.position.x,-20,20)
	hero.position.z = clampf(hero.position.z,-20,20)
	camera.position = hero.position + Vector3(0,19,15)
	spawn_timer -= dt
	if spawn_timer <= 0 and enemies.size() < 100:
		spawn_timer = maxf(0.25,1.1-elapsed/150.0)
		var a := randf()*TAU
		var p := hero.position+Vector3(cos(a),0,sin(a))*12
		p.x = clampf(p.x,-21,21)
		p.z = clampf(p.z,-21,21)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.8,0.8,0.8)
		var enemy := model(mesh,Color("#ff7865"),p)
		attach_art(enemy,"enemy")
		if randf() < 0.25:
			enemy.set_meta("health",3)
			enemy.set_meta("speed",1.3)
			enemy.scale = Vector3.ONE*1.35
		elif randf() < 0.35:
			enemy.set_meta("speed",3.8)
			enemy.scale = Vector3.ONE*0.7
		enemies.append(enemy)
	if elapsed >= 45 and not boss_spawned:
		boss_spawned = true
		var boss_mesh := BoxMesh.new()
		var boss := model(boss_mesh,Color("#a56bff"),Vector3(clampf(hero.position.x+9,-20,20),0.5,hero.position.z))
		attach_art(boss,"enemy")
		boss.scale = Vector3.ONE*2.7
		boss.set_meta("boss",true)
		boss.set_meta("health",18)
		boss.set_meta("speed",1.5)
		enemies.append(boss)
	var nearest: MeshInstance3D = null
	var distance := 4.0+level*0.3+reach
	for e in enemies:
		var offset := hero.position-e.position
		var d := offset.length()
		e.position += offset.normalized()*dt*(float(e.get_meta("speed",2.0))+minf(elapsed/90.0,2.0))
		if d < 0.9*e.scale.x:
			hp -= dt*(24 if e.get_meta("boss",false) else 12)*(1.0-armor)
		if d < distance:
			distance = d
			nearest = e
	attack_timer -= dt
	if nearest != null and attack_timer <= 0:
		attack_timer = maxf(0.15,0.7-power*0.08-(0.3 if vehicle_time > 0 else 0.0))
		var impact := nearest.position
		hit_enemy(nearest)
		if blast > 0:
			pulse(impact,1.5+blast*0.4,Color("#64cfff"))
			for other in enemies.duplicate():
				if other != nearest and other.position.distance_to(impact) < 1.5+blast*0.4:
					hit_enemy(other)
	for crate in crates.duplicate():
		if hero.position.distance_to(crate.position) < 1.0+level*0.12:
			drop_gem(crate.position)
			pulse(crate.position,2.2,Color("#ff9d45"))
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(crate.position) < 2.2:
					hit_enemy(enemy)
			award(50)
			crates.erase(crate)
			crate.queue_free()
	for gem in gems.duplicate():
		var offset := hero.position-gem.position
		if offset.length() < magnet:
			gem.position += offset.normalized()*dt*9
		if offset.length() < 0.65:
			gems.erase(gem)
			gem.queue_free()
			xp += 1
			play_fx("pickup")
			award(20)
	if xp >= level*3:
		xp -= level*3
		level += 1
		play_fx("level")
		hero.scale = Vector3.ONE*(1.0+minf((level-1)*0.12,1.5))
		choosing = true
		roll_offers()
		upgrades.show()
	if hp <= 0:
		finish_run()
	update_hud()

func update_hud() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	xp_bar.max_value = level*3
	xp_bar.value = xp
	hud.text = "ONE MORE\nSCORE %d  |  BEST %d\nHP %d  |  LV %d  |  %ds\nXP %d/%d  |  COMBO %d\nKILLS %d  |  CREDITS %d" % [score,best,maxi(0,int(hp)),level,int(elapsed),xp,level*3,combo,kills,credits]
