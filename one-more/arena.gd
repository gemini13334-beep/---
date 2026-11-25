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
	var health := int(enemy.get_meta("health",1))-1
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
	score += points * (1 + int(combo / 5.0))

func drop_gem(pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var gem := model(mesh, Color("#ffd65a"), Vector3(pos.x,0.3,pos.z))
	gems.append(gem)

func choose_upgrade(index: int) -> void:
	if not choosing:
		return
	match index:
		0: power += 1
		1: speed_bonus += 0.65
		2:
			magnet += 0.65
			hp = minf(100,hp+20)
		3: blast += 1
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
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(44, 0.2, 44)
	model(floor_mesh, Color("#243d46"), Vector3(0,-0.2,0))
	for i in range(-20,21,4):
		var line := BoxMesh.new()
		line.size = Vector3(0.035,0.02,44)
		model(line,Color("#36535a"),Vector3(i,-0.08,0))
		var cross := BoxMesh.new()
		cross.size = Vector3(44,0.02,0.035)
		model(cross,Color("#36535a"),Vector3(0,-0.08,i))
	var sphere := SphereMesh.new()
	hero = model(sphere,Color("#62f5c5"),Vector3(0,0.5,0))
	attach_art(hero,"hero")
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
	retry = Button.new()
	layer.add_child(retry)
	retry.position = Vector2(110,550)
	retry.size = Vector2(500,110)
	retry.add_theme_font_size_override("font_size",34)
	retry.text = "PLAY • ONE MORE"
	retry.pressed.connect(start)
	upgrades = VBoxContainer.new()
	layer.add_child(upgrades)
	upgrades.position = Vector2(90,430)
	upgrades.size = Vector2(540,320)
	upgrades.add_theme_constant_override("separation",16)
	var heading := Label.new()
	heading.text = "EVOLUTION • CHOOSE ONE"
	heading.add_theme_font_size_override("font_size",28)
	upgrades.add_child(heading)
	for i in range(4):
		var btn := Button.new()
		btn.text = ["OVERDRIVE • Faster attacks","DASH • Movement speed","MAGNET • Pickup + heal","NOVA • Chain blast"][i]
		btn.custom_minimum_size = Vector2(540,85)
		btn.add_theme_font_size_override("font_size",24)
		upgrades.add_child(btn)
		btn.pressed.connect(choose_upgrade.bind(i))
	upgrades.hide()
	var cfg := ConfigFile.new()
	if cfg.load("user://records.cfg") == OK:
		best = int(cfg.get_value("records","best",0))
		credits = int(cfg.get_value("records","credits",0))
	update_hud()

func start() -> void:
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
	hp = 100
	level = 1
	spawn_timer = 0
	attack_timer = 0
	finger = -1
	direction = Vector2.ZERO
	running = true
	retry.hide()

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
	combo_time -= dt
	if combo_time <= 0:
		combo = 0
	var move := direction
	if finger == -1:
		move = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	hero.position += Vector3(move.x,0,move.y)*dt*(6.0+speed_bonus)
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
	var distance := 4.0+level*0.3
	for e in enemies:
		var offset := hero.position-e.position
		var d := offset.length()
		e.position += offset.normalized()*dt*(float(e.get_meta("speed",2.0))+minf(elapsed/90.0,2.0))
		if d < 0.9*e.scale.x:
			hp -= dt*(24 if e.get_meta("boss",false) else 12)
		if d < distance:
			distance = d
			nearest = e
	attack_timer -= dt
	if nearest != null and attack_timer <= 0:
		attack_timer = maxf(0.15,0.7-power*0.08)
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
			award(20)
	if xp >= level*3:
		xp -= level*3
		level += 1
		hero.scale = Vector3.ONE*(1.0+minf((level-1)*0.12,1.5))
		choosing = true
		upgrades.show()
	if hp <= 0:
		running = false
		choosing = false
		upgrades.hide()
		best = maxi(best,score)
		credits += int(score/100.0)
		var cfg := ConfigFile.new()
		cfg.set_value("records","best",best)
		cfg.set_value("records","credits",credits)
		cfg.save("user://records.cfg")
		retry.text = "ONE MORE • RETRY"
		retry.show()
	update_hud()

func update_hud() -> void:
	hud.text = "ONE MORE\nSCORE %d  |  BEST %d\nHP %d  |  LV %d  |  %ds\nXP %d/%d  |  COMBO %d\nKILLS %d  |  CREDITS %d" % [score,best,maxi(0,int(hp)),level,int(elapsed),xp,level*3,combo,kills,credits]
