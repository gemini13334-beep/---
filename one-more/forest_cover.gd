extends MultiMeshInstance3D

const Landscape = preload("res://landscape.gd")
const FERN := preload("res://assets/art/forest-fern.png")
const STONE := preload("res://assets/art/forest-slate.jpg")
const STONE_SHADER := preload("res://shaders/forest_stone.gdshader")

var stone_materials: Dictionary = {}

func _ready() -> void:
	var fern := PlaneMesh.new()
	fern.size = Vector2(1.38,1.38)
	var material := StandardMaterial3D.new()
	material.albedo_texture = FERN
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.39
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.91
	fern.material = material
	multimesh = MultiMesh.new()
	multimesh.mesh = fern
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = 540
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plant_ferns()

func plant_ferns() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 10423
	for index in multimesh.instance_count:
		var extent := 20.1 if index < 156 else Landscape.PLAY_HALF+5.0
		var z := random.randf_range(-extent,extent)
		var trail_x := Landscape.trail(z)
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := trail_x+side*random.randf_range(2.55,6.8)
		if index >= 98:
			x = random.randf_range(-extent,extent)
			if absf(x-trail_x) < 2.5:
				x = trail_x+side*random.randf_range(2.55,3.6)
		var width := random.randf_range(0.51,1.32)
		var pitch := Basis(Vector3.RIGHT,random.randf_range(-0.14,0.14))
		var facing := Basis(Vector3.UP,random.randf_range(0,TAU))
		var basis := (facing*pitch).scaled(Vector3(width,0.8,width))
		multimesh.set_instance_transform(index,Transform3D(basis,Landscape.positioned(0,Vector3(x,0,z),random.randf_range(0.08,0.18))))
		var tint := Color("#698570").lerp(Color("#fcf2c4"),random.randf())
		multimesh.set_instance_color(index,tint)

func dress_stone(art: Node3D) -> void:
	var meshes := art.find_children("*","MeshInstance3D",true,false)
	if art is MeshInstance3D:
		meshes.append(art)
	for geometry in meshes:
		if geometry.mesh == null:
			continue
		for surface in geometry.mesh.get_surface_count():
			var original := geometry.get_active_material(surface) as StandardMaterial3D
			if original == null or original.emission_enabled:
				continue
			var key := original.resource_name.to_lower()
			var moss := "moss" in key or "lichen" in key
			if not stone_materials.has(moss):
				var material := ShaderMaterial.new()
				material.shader = STONE_SHADER
				material.set_shader_parameter("stone_surface",STONE)
				material.set_shader_parameter("tint",Color("#95a477") if moss else Color("#c6c2b3"))
				stone_materials[moss] = material
			geometry.set_surface_override_material(surface,stone_materials[moss])

func set_density(quality: String) -> void:
	var count_fraction := 1.0
	if quality == "LOW":
		count_fraction = 0.58
	elif quality == "MEDIUM":
		count_fraction = 0.87
	multimesh.visible_instance_count = roundi(multimesh.instance_count*count_fraction)
