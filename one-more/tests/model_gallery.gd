extends Control

const GROUPS := [
	["ГЕРОИ",[
		["hero","СЛАЙМ"],["cyborg","КИБОРГ"],["inferno","ИНФЕРНО"],
		["ghost","ПРИЗРАК"],["titan","ТИТАН"],["cryo","КРИО"],
	]],
	["ВРАГИ И БОССЫ",[
		["enemy","РАЗВЕДЧИК"],["enemy_fast","ПЕРЕХВАТЧИК"],["enemy_armored","БРОНЕВРАГ"],
		["boss_overlord","ВЛАДЫКА"],["boss_crystal","ЛЕДЯНОЙ ГОЛЕМ"],["boss_inferno","ПЛАВИЛЬЩИК"],
	]],
	["ТРАНСПОРТ И СНАРЯЖЕНИЕ",[
		["buggy","БАГГИ"],["hovercraft","ХОВЕР"],["tank","ТАНК"],
		["mech","МЕХ"],["crate","КОНТЕЙНЕР"],
	]],
]

var valid := true

func populate(group: int) -> void:
	var background := ColorRect.new()
	background.size = size
	background.color = Color("#0a141d")
	add_child(background)
	var heading := make_label(GROUPS[group][0],32,Color("#efe7d6"))
	heading.position = Vector2(32,48)
	heading.size = Vector2(656,68)
	add_child(heading)
	var entries: Array = GROUPS[group][1]
	for index in entries.size():
		add_card(entries[index],Vector2(30+float(index%2)*336,161+floorf(float(index)/2)*337))

func make_label(caption: String, points: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",tint)
	return label

func add_card(entry: Array, origin: Vector2) -> void:
	var holder := SubViewportContainer.new()
	holder.position = origin
	holder.size = Vector2(324,278)
	holder.stretch = true
	add_child(holder)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = Environment.new()
	atmosphere.environment.background_mode = Environment.BG_COLOR
	atmosphere.environment.background_color = Color("#233441")
	atmosphere.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.environment.ambient_light_color = Color("#ced9e4")
	atmosphere.environment.ambient_light_energy = 0.65
	world.add_child(atmosphere)
	studio_light(world,Color("#fff0d5"),1.38,Vector3(-43,-32,0))
	studio_light(world,Color("#a8d4ff"),0.91,Vector3(-23,141,0))

	var path := "res://assets/models/%s.glb" % entry[0]
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_error("Preview model is missing: " + path)
		valid = false
		return
	var subject := scene.instantiate() as Node3D
	world.add_child(subject)
	var bounds := model_bounds(subject)
	if bounds.size.length_squared() < 0.01:
		push_error("Preview model has no geometry: " + path)
		valid = false
		return
	subject.position = -bounds.get_center()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*1.34
	camera.position = Vector3(3.3,2.85,5.4)
	camera.look_at(Vector3.ZERO)
	camera.current = true

	var caption := make_label(entry[1],22,Color("#d5e4e8"))
	caption.position = origin+Vector2(0,279)
	caption.size = Vector2(324,52)
	add_child(caption)

func model_bounds(subject: Node3D) -> AABB:
	var geometries := subject.find_children("*","MeshInstance3D",true,false)
	if subject is MeshInstance3D:
		geometries.append(subject)
	var bounds := AABB()
	var first := true
	for geometry in geometries:
		var mesh := geometry as MeshInstance3D
		var box := mesh.transform if mesh == subject else subject.global_transform.affine_inverse()*mesh.global_transform
		var local_bounds := box*mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	return bounds

func studio_light(parent: Node3D,color: Color,energy: float,angles: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.rotation_degrees = angles
	parent.add_child(light)
