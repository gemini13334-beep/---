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
	var cfg := ConfigFile.new()
	if cfg.load("user://records.cfg") == OK:
		best = int(cfg.get_value("records","best",0))
	update_hud()

func start() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
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
	if not running:
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
	if not running:
		return
	elapsed += dt
	var move := direction
	if finger == -1:
		move = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	hero.position += Vector3(move.x,0,move.y)*dt*6.0
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
		enemies.append(model(mesh,Color("#ff7865"),p))
	var nearest: MeshInstance3D = null
	var distance := 4.0+level*0.3
	for e in enemies:
		var offset := hero.position-e.position
		var d := offset.length()
		e.position += offset.normalized()*dt*(2.0+minf(elapsed/90.0,2.0))
		if d < 0.9:
			hp -= dt*12
		if d < distance:
			distance = d
			nearest = e
	attack_timer -= dt
	if nearest != null and attack_timer <= 0:
		attack_timer = maxf(0.18,0.7-level*0.035)
		enemies.erase(nearest)
		nearest.queue_free()
		score += 100
		level = 1+int(score/500.0)
		hero.scale = Vector3.ONE*(1.0+minf(level*0.07,1.5))
	if hp <= 0:
		running = false
		best = maxi(best,score)
		var cfg := ConfigFile.new()
		cfg.set_value("records","best",best)
		cfg.save("user://records.cfg")
		retry.text = "ONE MORE • RETRY"
		retry.show()
	update_hud()

func update_hud() -> void:
	hud.text = "ONE MORE\nSCORE %d  |  BEST %d\nHP %d  |  LV %d  |  %ds" % [score,best,maxi(0,int(hp)),level,int(elapsed)]
