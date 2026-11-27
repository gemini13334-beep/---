extends Node3D
const HangarMenu = preload("res://ui/hangar.gd")
const ForestCover = preload("res://forest_cover.gd")
const CoopSession = preload("res://coop/session.gd")
const ActorPose = preload("res://actor_pose.gd")
const CombatHUD = preload("res://ui/combat_hud.gd")
const Landscape = preload("res://landscape.gd")
const ShotStyles = preload("res://shot_styles.gd")
var coop: CoopSession
var hero: MeshInstance3D
var camera: Camera3D
var enemies: Array[MeshInstance3D] = []
var retry: Button
var elapsed := 0.0
var spawn_timer := 0.0
var enemy_wave := 0
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
var offer_art: Array[TextureRect] = []
var offer_motion: Tween
const ENEMY_TYPES := [
	["enemy",1,2.0,1.0], ["enemy_fast",1,3.8,0.7], ["enemy_armored",3,1.3,1.35],
]
const ENEMY_FORMATIONS := [[2,1],[1,1],[0,2,1]]
const ENEMY_LIMIT := 100
const ABILITIES = [
	["ФОРСАЖ","Быстрее стрельба",0],["РЫВОК","Быстрее движение",0],
	["МАГНИТ","Подбор и лечение",0],["НОВА","Урон по области",1],
	["ПРОБОЙ","Больше урона",1],["БРОНЯ","Меньше входящего урона",0],
	["РАДАР","Дальше стрельба",0],["РЕГЕНЕРАЦИЯ","Восстановление здоровья",1],
	["КРЕПОСТЬ","Больше здоровья",1],["ДЖЕКПОТ","Больше очков",1],
	["ГРОМ","Урон и область атаки",2],["ФАНТОМ","Скорость и броня",2],
	["ТЯГОТЕНИЕ","Магнит и дальность",2],["БЕРСЕРК","Урон и скорострельность",2],
	["ФЕНИКС","Лечение и восстановление",2],["ЯДРО ТИТАНА","Здоровье и броня",2]
]

const COMBINATIONS := {
	100: ["ФОРСИРОВАННАЯ НОВА","Больше урона по области",2],
	101: ["ГРАВИТАЦИОННЫЙ РЫВОК","Увеличивает радиус подбора осколков",2],
}

const FUSION_RECIPES := {
	110: {
		"name":"БУРЯ ЯДРА", "ingredients":[10,13], "credits":300, "art":10,
		"bonus":"+3 урона, сильнее взрыв, быстрее автоогонь",
	},
	111: {
		"name":"СИНГУЛЯРНОСТЬ", "ingredients":[11,12], "credits":350, "art":12,
		"bonus":"+2,4 дальности, +2,1 магнит, +1,25 скорости",
	},
	112: {
		"name":"ЯДРО ВОЗРОЖДЕНИЯ", "ingredients":[14,15,11], "credits":450, "art":15,
		"bonus":"+65 здоровья, +2 ОЗ/с, до +16 п.п. брони",
	},
}

func ability_data(id: int) -> Array:
	if FUSION_RECIPES.has(id):
		var recipe: Dictionary = FUSION_RECIPES[id]
		return [recipe["name"],recipe["bonus"],2]
	return COMBINATIONS[id] if COMBINATIONS.has(id) else ABILITIES[id]

func ability_rank_ids() -> Array:
	return range(ABILITIES.size())+COMBINATIONS.keys()+FUSION_RECIPES.keys()

func can_open_fusion() -> bool:
	return running and not choosing and not hud_paused and not hud_in_settings and hp > 0.0 and (not coop.live or coop.hosting)

func fusion_issue(id: int) -> String:
	if not FUSION_RECIPES.has(id):
		return "Рецепт недоступен"
	if ranks.has(id):
		return "Уже создано в этом забеге"
	var recipe: Dictionary = FUSION_RECIPES[id]
	for ingredient in recipe["ingredients"]:
		if int(ranks.get(ingredient,0)) <= 0:
			return "Нужны все указанные суперспособности"
	if credits < int(recipe["credits"]):
		return "Недостаточно кредитов"
	return ""

func buy_fusion(id: int) -> String:
	if not hud_fusing or not can_open_fusion():
		return "Синтез недоступен"
	var issue := fusion_issue(id)
	if not issue.is_empty():
		return issue
	var recipe: Dictionary = FUSION_RECIPES[id]
	var remaining := credits-int(recipe["credits"])
	if not save_profile(remaining):
		return "Не удалось сохранить покупку"
	credits = remaining
	# The new ability inherits the effects already applied by the spent ranks.
	# Apply the extra power once, without replaying healing or losing capped stats.
	for ingredient in recipe["ingredients"]:
		var count := int(ranks[ingredient])-1
		if count == 0:
			ranks.erase(ingredient)
		else:
			ranks[ingredient] = count
	ranks[id] = 1
	match id:
		110:
			damage += 3
			blast += 2
			power += 1
		111:
			reach += 2.4
			magnet += 2.1
			speed_bonus += 1.25
		112:
			max_hp += 65.0
			hp = minf(max_hp,hp+65.0)
			regen += 2.0
			armor = minf(0.65,armor+0.16)
	event_label.text = "СИНТЕЗ · "+recipe["name"]
	play_fx("level")
	var glow := Color(ShotStyles.STYLES[id][ShotStyles.HALO])
	pulse(hero.position,3.0,glow)
	if id == 112:
		pulse(hero.position,1.6,Color(ShotStyles.STYLES[id][ShotStyles.CORE]))
	update_hud()
	return ""

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
		offer_buttons[i].text = "%s  ·  РАНГ %d\n%s\n%s" % [a[0],int(ranks.get(offers[i],0))+1,a[1],["ОБЫЧНОЕ","РЕДКОЕ","ЭПИЧЕСКОЕ"][a[2]]]
		offer_buttons[i].modulate = [Color.WHITE,Color("#85d9ff"),Color("#e2b2ff")][a[2]]
		offer_art[i].texture = hud_panel.art_texture(offers[i])

const DEFAULT_HERO := 6
var selected := DEFAULT_HERO
var owned: Array[int] = [0,DEFAULT_HERO]
var collection: VBoxContainer
var hero_list: ScrollContainer
var collection_balance: Label
var collection_buttons: Array[Button] = []
var menu: HangarMenu
var result_label: Label
var max_hp := 100.0
var mode := 0
var biome := 0
var scenery: Array[GeometryInstance3D] = []
var sound: AudioStreamPlayer
var sounds: Dictionary = {}

var ambient_player: AudioStreamPlayer
var forest_understory: ForestCover
func ambient_loop() -> AudioStreamWAV:
	var rate := 16000
	var count := rate*8
	var data := PackedByteArray()
	data.resize(count*2)
	for i in range(count):
		var t := float(i)/rate
		var pad := (sin(TAU*55.0*t)+0.4*sin(TAU*82.5*t)+0.25*sin(TAU*110.0*t))*0.25
		var swell := 0.65+0.35*cos(TAU*t/8.0)
		var beat := fmod(t,0.5)
		var bass := sin(TAU*55.0*t)*exp(-beat*14.0)*minf(1.0,beat*200.0)*0.22
		var note := sin(TAU*220.0*t)*sin(TAU*0.25*t)*0.08
		data.encode_s16(i*2,int(clampf(pad*swell+bass+note,-1.0,1.0)*24000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav

func tone(freq: float, duration: float, kind: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(22050*duration)
	data.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1927
	for i in range(count):
		var t := float(i)/22050.0
		var p := float(i)/count
		var envelope := minf(1.0,t*400.0)*pow(1.0-p,2.0)
		var wave := sin(TAU*freq*t)
		match kind:
			"shot":
				wave = 0.6*sin(TAU*(freq*t-900.0*t*t))+0.25*rng.randf_range(-1.0,1.0)+0.15*sin(TAU*freq*2.0*t)
			"destroy":
				wave = 0.65*sin(TAU*(freq*t-100.0*t*t))+0.35*rng.randf_range(-1.0,1.0)*exp(-t*18.0)
			"boss":
				wave = 0.5*sin(TAU*(freq*t-20.0*t*t))+0.25*sin(TAU*freq*1.5*t)+0.25*rng.randf_range(-1.0,1.0)*exp(-t*8.0)
			"hit":
				wave = 0.55*sin(TAU*freq*t*(1.0-0.4*p))+0.45*rng.randf_range(-1.0,1.0)
			"pickup":
				wave = 0.7*sin(TAU*freq*t*(1.0+0.5*p))+0.3*sin(TAU*freq*2.0*t)
			"level":
				wave = (sin(TAU*freq*t)+sin(TAU*freq*1.25*t)+sin(TAU*freq*1.5*t))/3.0
			"boost":
				wave = 0.7*sin(TAU*freq*t*(1.0+p))+0.3*sin(TAU*freq*3.0*t)
		data.encode_s16(i*2,int(clampf(wave*envelope,-1.0,1.0)*12000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = data
	return wav

func sampled_sounds(streams: Array[AudioStream]) -> AudioStreamRandomizer:
	var variations := AudioStreamRandomizer.new()
	variations.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	for stream in streams:
		variations.add_stream(-1,stream)
	return variations

var fx_last: Dictionary = {}
var fx_voices: Array[AudioStreamPlayer] = []
var fx_cursor := 0
func fx_volume(key: String) -> float:
	var channel := "notifications"
	match key:
		"shot": channel = "weapons"
		"hit","destroy","boss": channel = "enemies"
		"boost": channel = "vehicles"
	var gain := float(advanced["master"])*float(advanced["effects"])*float(advanced[channel])
	var base := -20.0 if key == "shot" else (-9.0 if key == "boss" else -15.0)
	return base+linear_to_db(maxf(0.0001,gain)) if gain > 0.0 else -80.0

func play_fx(key: String) -> void:
	if sound == null or not audio_enabled or not sounds.has(key):
		return
	var now := Time.get_ticks_msec()
	if now-int(fx_last.get(key,-1000)) < 45:
		return
	fx_last[key] = now
	if fx_voices.is_empty():
		return
	# Reserve two voices for important cues, avoiding interruption by rapid fire.
	var voice: AudioStreamPlayer
	if key == "boss" or key == "level":
		voice = fx_voices[7 if key == "boss" else 6]
	else:
		voice = fx_voices[fx_cursor]
		fx_cursor = (fx_cursor+1)%6
	voice.set_meta("fx_key",key)
	voice.volume_db = fx_volume(key)
	voice.stream = sounds[key]
	voice.pitch_scale = randf_range(0.94,1.06) if key == "hit" else 1.0
	voice.play()

func rebuild_scenery() -> void:
	if forest_understory != null:
		forest_understory.visible = biome == 0
	for prop in scenery:
		prop.hide()
		prop.queue_free()
	scenery.clear()
	var themes := [
		["tree","forest","rock","ruin"],["city","ruin","city","rock"],
		["desert","cactus","desert","rock"],["ice","ice_spire","ice_spire","ice"],["volcano","lava_vent","volcano","rock"],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8271+biome*147
	var cluster_count := 14 if biome == 0 else 18
	for i in cluster_count:
		var row := i/2.0
		var z := -59.0+(118.0/maxf(1.0,cluster_count*0.5-1.0))*floorf(row)+rng.randf_range(-2.7,2.7)
		var sign_x := 1.0 if i%2 == 0 else -1.0
		var x := clampf(Landscape.trail(z)+sign_x*rng.randf_range(13.0,48.0),-62.0,62.0)
		for j in range(3 if biome == 0 else 5):
			var kind: String = themes[biome][j%4]
			var point := Vector2(x+rng.randf_range(-4.8,4.8),z+rng.randf_range(-4.9,4.9))
			var size := rng.randf_range(0.69,1.25)
			if j == 0:
				size = rng.randf_range(1.35,1.85)
			place_landmark(kind,point,Vector3(size*1.18,size,size),rng.randf_range(-PI,PI))
	if biome == 0:
		place_forest_landmarks()
	else:
		place_biome_entry()
	if biome == 1:
		place_industrial_district()
	place_outer_sites()
	var color := Color(["#74806f","#8da3ac","#dba576","#a4c8ea","#98737f"][biome])
	var distant := Landscape.atmosphere_geometry(biome,GROUND_DETAILS[biome],color)
	add_child(distant)
	scenery.append(distant)
	for prop in scenery:
		mark_on_map(prop)
	map_dirty = true

func mark_on_map(node: Node) -> void:
	if node is GeometryInstance3D:
		node.set_layer_mask_value(2,true)
	for child in node.get_children():
		mark_on_map(child)

func build_minimap_camera() -> void:
	map_viewport = SubViewport.new()
	map_viewport.size = Vector2i(256,256)
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	map_viewport.gui_disable_input = true
	add_child(map_viewport)
	var map_camera := Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = Landscape.MAP_HALF*2.0
	map_camera.cull_mask = 2
	map_viewport.add_child(map_camera)
	map_camera.look_at_from_position(Vector3(0,65,0),Vector3.ZERO,Vector3.FORWARD)
	map_camera.current = true

func refresh_minimap() -> void:
	if map_dirty:
		map_dirty = false
		map_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func place_forest_landmarks() -> void:
	var layout := [
		["ruin",Vector2(4.7,-5.8),Vector3(1.60,0.75,1.45),-0.45],
		["ruin",Vector2(-4.5,7.0),Vector3(1.40,0.43,1.25),0.85],
		["ruin",Vector2(6.4,1.15),Vector3(1.35,0.50,0.95),0.85],
		["forest",Vector2(-4.15,-3.7),Vector3(1.7,0.82,1.22),0.70],
		["forest",Vector2(4.75,5.7),Vector3(1.55,0.80,1.55),-0.75],
		["forest",Vector2(4.7,-8.7),Vector3(1.42,0.45,1.15),-0.15],
		["rock",Vector2(-3.45,2.85),Vector3(1.05,0.47,1.1),-0.85],
		["rock",Vector2(4.1,2.5),Vector3(1.16,0.42,0.98),1.37],
		["rock",Vector2(-5.55,-7.0),Vector3(1.20,0.65,1.32),1.26],
		["tree",Vector2(-6.3,-2.6),Vector3(1.65,1.54,1.65),0.7],
		["tree",Vector2(-6.9,-7.1),Vector3(1.45,1.45,1.45),1.3],
		["tree",Vector2(6.7,-6.7),Vector3(1.85,1.62,1.85),-1.35],
		["tree",Vector2(6.2,6.1),Vector3(1.40,1.49,1.40),0.72],
	]
	for entry in layout:
		place_landmark(entry[0],entry[1],entry[2],entry[3])

func place_biome_entry() -> void:
	var layouts := [
		[],
		[["ruin",-4.5,-3.2,1.05],["city",5.9,-3.0,1.34],["ruin",10.2,-9.2,2.05]],
		[["desert",-4.9,-6.0,1.8],["desert",5.6,-6.0,2.4],["cactus",4.6,7.3,1.28],
		 ["desert",-7.0,6.6,2.4],["desert",12.5,-12.6,2.7]],
		[["ice_spire",5.5,-5.3,1.67],["ice",-6.7,-6.1,2.5],["ice_spire",-5.8,6.7,1.76],
		 ["ice",7.2,5.4,2.3],["ice_spire",-11.8,-11.4,2.9]],
		[["lava_vent",4.6,-6.3,1.7],["volcano",-5.5,-5.5,2.12],["lava_vent",-5.1,6.3,1.55],
		 ["volcano",6.1,5.9,2.52],["volcano",-10.8,-11.4,2.75]],
	]
	for item in layouts[biome]:
		var size := float(item[3])
		place_landmark(item[0],Vector2(item[1],item[2]),Vector3(size*1.23,size,size),float(item[1])*0.27)

const INDUSTRIAL_MODELS := ["building-a","building-r","shipping-container-b","water-tower","road-barrier"]
const FACTORY_CONCRETE := preload("res://assets/vendor/materials/concrete-color.jpg")
const OUTER_SITES := [
	[
		[Vector2(-49,-51),[["ruin",-4,0,2.75],["ruin",5,1,2.50],["forest",-4,6,2.25],["tree",5,7,2.0]]],
		[Vector2(54,39),[["tree",-5,-5,2.35],["tree",5,-3,2.1],["forest",5,5,2.4],["rock",-5,5,1.5]]],
		[Vector2(-42,58),[["ruin",6,2,1.95],["rock",-5,1,2.20],["tree",4,-6,2.2]]],
	],
	[
		[Vector2(54,34),[["shipping-container-b",-5,-7,3.4],["shipping-container-b",4,-7,3.4],["water-tower",4,6,1.70],["road-barrier",-4,4,1.4]]],
		[Vector2(-54,34),[["building-r",-6,-8,3.1],["building-a",6,7,2.65],["road-barrier",-4,5,1.3]]],
		[Vector2(-36,-54),[["building-a",-6,-2,3.2],["shipping-container-b",3,4,3.0],["water-tower",6,-5,1.5]]],
	],
	[
		[Vector2(52,-51),[["desert",-8,-2,3.4],["desert",-2,5,2.9],["desert",5,-7,3.65],["desert",7,3,3.0],["cactus",2,5,1.55]]],
		[Vector2(-49,49),[["ruin",-5,-3,2.5],["ruin",4,7,1.9],["cactus",4,-1,2.15],["rock",-5,6,2.05]]],
		[Vector2(51,52),[["desert",-4,5,3.3],["rock",5,-7,2.2],["cactus",3,4,1.7]]],
	],
	[
		[Vector2(-51,-45),[["ice_spire",-8,1,3.3],["ice",-5,7,3.5],["ice_spire",7,-7,2.65],["ice",5,-2,2.9]]],
		[Vector2(52,45),[["shipping-container-b",-5,-5,3.0],["road-barrier",4,4,1.5],["ice_spire",6,-4,2.3],["ice",5,7,2.7]]],
		[Vector2(-46,52),[["ice_spire",-6,-7,3.2],["ice_spire",5,5,2.35],["ice",4,-6,3.15]]],
	],
	[
		[Vector2(51,-48),[["volcano",-6,-3,3.3],["volcano",6,-5,3.0],["lava_vent",4,5,2.15],["lava_vent",-4,5,1.7]]],
		[Vector2(-49,54),[["volcano",-5,-6,3.35],["volcano",3,7,3.2],["lava_vent",5,-4,2.1],["rock",-6,4,2.35]]],
		[Vector2(-50,-39),[["volcano",-5,5,3.05],["lava_vent",1,-6,2.4],["rock",7,4,2.2]]],
	],
]

func place_outer_sites() -> void:
	for site in OUTER_SITES[biome]:
		var center: Vector2 = site[0]
		for item in site[1]:
			var offset := Vector2(item[1],item[2])
			var size := float(item[3])
			place_landmark(item[0],center+offset,Vector3(size*1.12,size,size),offset.angle())

func place_industrial_district() -> void:
	var layout := [
		["building-a",Vector2(-6.4,-6.75),Vector3(2.6,2.2,2.45),0.09],
		["building-r",Vector2(8.3,4.0),Vector3(2.45,2.28,2.2),-0.16],
		["water-tower",Vector2(5.9,-7.75),Vector3(1.3,1.54,1.3),0.12],
		["shipping-container-b",Vector2(-4.6,5.3),Vector3(3.3,3.0,3.65),1.18],
		["road-barrier",Vector2(-2.3,-0.4),Vector3.ONE*1.12,1.39],
		["road-barrier",Vector2(3.7,7.7),Vector3.ONE*1.1,0.82],
	]
	for depth in [-39.0,-27.0,-16.0,14.0,25.0,39.0]:
		var axis: float = -depth*0.18
		var orientation := 0.16
		var offset := 5.9 if depth > 0.0 else -6.5
		layout.append(["building-a" if depth > 0.0 else "building-r",Vector2(axis+offset,depth),Vector3.ONE*2.1,orientation])
		layout.append(["shipping-container-b",Vector2(axis-offset*0.8,depth-2.9),Vector3.ONE*3.0,orientation])
		layout.append(["road-barrier",Vector2(axis+offset*0.48,depth-1.45),Vector3.ONE,PI*0.45])
	for item in layout:
		place_landmark(item[0],item[1],item[2],item[3])

func place_landmark(asset: String,point: Vector2,scale_factor: Vector3,rotation_y: float) -> void:
	var fallback := SphereMesh.new()
	fallback.height = 0.56
	fallback.radius = 0.65
	var prop := model(fallback,Color(GROUND_COLORS[biome]).lightened(0.26),Vector3(point.x,0,point.y))
	var art := attach_art(prop,asset)
	if art != null:
		if biome == 0 and asset in ["forest","rock","ruin"]:
			forest_understory.dress_stone(art)
		elif asset in INDUSTRIAL_MODELS:
			if asset != "road-barrier":
				dress_industrial_paint(art,asset)
		elif biome > 0 and asset != "cactus":
			dress_biome_stone(art)
	prop.rotation.y = rotation_y
	prop.scale = scale_factor
	prop.position = grounded(prop.position,(0.50 if art != null else 0.26)*scale_factor.y)
	add_contact_shadow(prop,2.1)
	scenery.append(prop)

var landmark_materials: Dictionary = {}

func dress_industrial_paint(art: Node3D,asset: String) -> void:
	var geometries := art.find_children("*","MeshInstance3D",true,false)
	if art is MeshInstance3D:
		geometries.append(art)
	for node in geometries:
		var shape := node as MeshInstance3D
		if shape.mesh == null:
			continue
		for index in shape.mesh.get_surface_count():
			var source := shape.get_active_material(index) as StandardMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			var key := "%s:%s" % [asset,source.resource_name]
			if not landmark_materials.has(key):
				var finish := ShaderMaterial.new()
				finish.shader = preload("res://shaders/industrial_finish.gdshader")
				finish.set_shader_parameter("worn_concrete",FACTORY_CONCRETE)
				finish.set_shader_parameter("palette",source.albedo_texture)
				finish.set_shader_parameter("wear_amount",0.47 if asset == "shipping-container-b" else 0.63)
				landmark_materials[key] = finish
			shape.set_surface_override_material(index,landmark_materials[key])

func dress_biome_stone(art: Node3D) -> void:
	var geometries := art.find_children("*","MeshInstance3D",true,false)
	if art is MeshInstance3D:
		geometries.append(art)
	for node in geometries:
		var shape := node as MeshInstance3D
		if shape.mesh == null:
			continue
		for index in shape.mesh.get_surface_count():
			var original := shape.get_active_material(index) as StandardMaterial3D
			if original == null or original.emission_enabled:
				continue
			var key := "%d:%s" % [biome,original.resource_name]
			if not landmark_materials.has(key):
				var tint := original.albedo_color.lerp(Color.WHITE,0.46)
				if biome == 1:
					var concrete := StandardMaterial3D.new()
					concrete.albedo_color = tint
					concrete.albedo_texture = FACTORY_CONCRETE
					concrete.normal_enabled = true
					concrete.normal_scale = 0.76
					concrete.normal_texture = preload("res://assets/vendor/materials/concrete-normal.jpg")
					concrete.roughness_texture = preload("res://assets/vendor/materials/concrete-roughness.jpg")
					concrete.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
					concrete.uv1_triplanar = true
					concrete.uv1_world_triplanar = true
					concrete.uv1_scale = Vector3.ONE*0.44
					landmark_materials[key] = concrete
				else:
					var stone := ShaderMaterial.new()
					stone.shader = preload("res://shaders/forest_stone.gdshader")
					stone.set_shader_parameter("stone_surface",GROUND_DETAILS[biome] if biome == 4 else ground_texture())
					stone.set_shader_parameter("tint",tint)
					landmark_materials[key] = stone
			shape.set_surface_override_material(index,landmark_materials[key])


func grounded(position: Vector3,offset: float = 0.5) -> Vector3:
	return Landscape.positioned(biome,position,offset)

func seat_actor(actor: Node3D) -> void:
	actor.position = grounded(actor.position,0.5*actor.scale.y)

func planar_distance(a: Vector3,b: Vector3) -> float:
	return Landscape.xz(a).distance_to(Landscape.xz(b))

var ground: MeshInstance3D
var map_viewport: SubViewport
var map_dirty := true
const BIOMES = ["FOREST","CITY","DESERT","ICE","VOLCANO"]
const BIOME_NAMES = ["ЛЕС","ГОРОД","ПУСТЫНЯ","ЛЕДНИК","ВУЛКАН"]
const GROUND_COLORS = ["#142d2d","#26323f","#674633","#2b4b68","#342732"]

const GROUND_SURFACES := [
	preload("res://assets/art/forest-ground.jpg"),preload("res://assets/art/asphalt.jpg"),
	preload("res://assets/art/sandstone.jpg"),preload("res://assets/art/glacier.jpg"),
	preload("res://assets/art/basalt.jpg"),
]
const GROUND_DETAILS := [
	preload("res://assets/art/forest-slate.jpg"),preload("res://assets/vendor/materials/road-asphalt.png"),
	preload("res://assets/vendor/materials/dune-sand.png"),preload("res://assets/vendor/materials/snow-drift.png"),
	preload("res://assets/vendor/materials/volcanic-stone.png"),
]
var terrain_meshes: Dictionary = {}

func ground_texture() -> Texture2D:
	return GROUND_SURFACES[biome]

func update_ground_material() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("biome",biome)
	mat.set_shader_parameter("ground_albedo",ground_texture())
	mat.set_shader_parameter("ground_detail",GROUND_DETAILS[biome])
	if not terrain_meshes.has(biome):
		terrain_meshes[biome] = Landscape.surface(biome)
	ground.mesh = terrain_meshes[biome]
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_forest_understory() -> void:
	forest_understory = ForestCover.new()
	add_child(forest_understory)

var biome_rim: DirectionalLight3D
var biome_environment: Environment
const BIOME_KEY_LIGHT = ["#ffe2a8","#dbeaff","#ffe0a6","#d9f3ff","#ffb58b"]
const BIOME_SUN := [Vector2(-38,-38),Vector2(-43,39),Vector2(-55,-26),Vector2(-31,43),Vector2(-33,-59)]
const BIOME_SUN_ENERGY := [1.38,1.23,1.52,1.32,1.12]
const BIOME_RIM_LIGHT = ["#80bfff","#83baff","#c2aaff","#75dfff","#ff6c48"]
const BIOME_AMBIENT = ["#b9c8af","#aabbd4","#e3c9aa","#c8dcea","#b7a8b4"]
const BIOME_SKY = ["#13242c","#172331","#3c3028","#203748","#321c28"]

func apply_biome_lighting() -> void:
	if not is_instance_valid(biome_environment):
		return
	var elevation: Vector2 = BIOME_SUN[biome]
	world_light.rotation_degrees = Vector3(elevation.x,elevation.y,0)
	world_light.light_color = Color(BIOME_KEY_LIGHT[biome])
	world_light.light_energy = BIOME_SUN_ENERGY[biome]*float(advanced["brightness"])
	biome_rim.light_color = Color(BIOME_RIM_LIGHT[biome])
	biome_environment.ambient_light_color = Color(BIOME_AMBIENT[biome])
	biome_environment.background_color = Color(BIOME_SKY[biome])
	biome_environment.fog_enabled = biome != 0
	biome_environment.fog_light_color = Color(BIOME_AMBIENT[biome]).darkened(0.30)
	biome_environment.fog_density = [0.0,0.0035,0.0055,0.0045,0.0035][biome]

func cycle_biome() -> void:
	set_biome((biome+1)%BIOMES.size())

func set_biome(index: int) -> void:
	biome = clampi(index,0,BIOMES.size()-1)
	menu.show_biome(biome,BIOME_NAMES[biome])
	apply_biome_lighting()
	update_ground_material()
	range_marker.material_override.set_shader_parameter("biome",biome)
	rebuild_scenery()

var best_sprint := 0
var runs := 0
var total_kills := 0
var vehicle: MeshInstance3D
var vehicle_time := 0.0
var vehicle_kind := 0
const VEHICLES = ["buggy","hovercraft","tank","mech"]
const VEHICLE_NAMES = ["БАГГИ","ХОВЕР","ТАНК","МЕХ"]
const VEHICLE_SPEED = [4.0,6.0,1.5,2.5]
const VEHICLE_FIRE = [0.3,0.15,0.45,0.35]
var next_event := 15.0
var event_label: Label
var achievements: Label
const COMBAT_CAMERA_OFFSET := Vector3(0,16,18)

func sprint() -> void:
	start()
	mode = 1

func finish_run() -> void:
	if not running:
		return
	if coop.live:
		if coop.hosting:
			coop.finish_host()
		return
	gain_hunter_xp(kills*5+int(score/200.0))
	running = false
	choosing = false
	clear_touch()
	upgrades.hide()
	if mode == 1:
		best_sprint = maxi(best_sprint,score)
	elif mode == 0:
		best = maxi(best,score)
	elif mode == 2 and gate_cleared:
		gate_wins[gate_rank] += 1
		gain_hunter_xp(150*(gate_rank+1))
		credits += 100*(gate_rank+1)
	credits += int(score/100.0)
	runs += 1
	total_kills += kills
	quest_progress[0] += kills
	quest_progress[1] += 1
	quest_progress[2] += maxi(0,score)
	save_profile()
	show_menu()
	if mode == 2:
		result_label.text = ("ВРАТА ПРОЙДЕНЫ" if gate_cleared else "ВРАТА НЕ ПРОЙДЕНЫ")+"\n"+result_label.text
	else:
		result_label.text += "\nПОСЛЕДНИЙ ЗАБЕГ  %d" % score

func spawn_vehicle() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.7,0.65,2.4)
	var location := Landscape.keep_inside(hero.position+Vector3(5,0,3),Landscape.PLAY_HALF-1.0)
	vehicle = model(mesh,Color("#ffc45c"),grounded(location))
	vehicle_kind = randi_range(0,3)
	attach_art(vehicle,VEHICLES[vehicle_kind])
	event_label.text = "ТРАНСПОРТ  ·  "+VEHICLE_NAMES[vehicle_kind]+"  ·  Подберите"

func update_events(dt: float) -> void:
	if elapsed >= next_event:
		next_event += 20.0
		if randf() < 0.55:
			spawn_vehicle()
		else:
			for i in range(12):
				drop_gem(Landscape.keep_inside(hero.position+Vector3(randf_range(-6,6),0,randf_range(-6,6)),Landscape.PLAY_HALF))
			event_label.text = "ЭНЕРГЕТИЧЕСКИЙ ДОЖДЬ"
	if is_instance_valid(vehicle) and not vehicle.is_queued_for_deletion():
		if planar_distance(hero.position,vehicle.position) < 1.4:
			vehicle.queue_free()
			vehicle_time = [10.0,8.0,12.0,15.0][vehicle_kind]
			play_fx("boost")
			pulse(hero.position,3.0,Color("#ffc45c"))
	if vehicle_time > 0:
		vehicle_time = maxf(0,vehicle_time-dt)
		event_label.text = "%s  ·  %.1f с" % [VEHICLE_NAMES[vehicle_kind],vehicle_time]
		if vehicle_time <= 0:
			event_label.text = ""

var hero_visual: Node3D
var hero_shadow: MeshInstance3D
const PALETTE = ["#62f5c5","#8caee9","#ff7043","#b998ff","#e2b45d","#72e5ff","#ffc179","#f1a16f","#ffc15c","#d69592"]

var hud_panel: CombatHUD
var hud_paused := false
var hud_in_settings := false
var hud_fusing := false
var run_pickups := 0
var range_marker: MeshInstance3D
var menu_scrim: ColorRect
var hero_stage: Node3D
var hero_preview: Control
var hero_preview_label: Label
var centered_ui: Dictionary[Control,Vector2] = {}
var ui_spare := Vector2.ZERO

func style_button(btn: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#203442") if state == "normal" else Color("#365b68")
		if state == "pressed":
			style.bg_color = Color("#142a34")
		if state == "disabled":
			style.bg_color = Color("#273038")
		style.border_color = Color("#476e7a") if state == "normal" else Color("#65d9c0")
		if state == "disabled":
			style.border_color = Color("#38434c")
		style.set_border_width_all(1)
		style.border_width_bottom = 2 if state == "pressed" else 4
		style.set_corner_radius_all(14)
		btn.add_theme_stylebox_override(state,style)
	btn.add_theme_color_override("font_color",Color("#edf8f5"))

func apply_hero_art() -> void:
	if is_instance_valid(hero_visual):
		hero.remove_child(hero_visual)
		hero_visual.queue_free()
	hero.mesh = SphereMesh.new()
	var mat := hero.material_override as StandardMaterial3D
	mat.albedo_color = Color(PALETTE[selected])
	hero_visual = attach_art(hero,HERO_ART[selected])

const HEROES = [
	["SLIME",0,"Универсал",100.0,0.0,2.0,0],
	["CYBORG",150,"Скорострельность",100.0,0.0,2.0,2],
	["INFERNO",300,"Взрыв по области",100.0,0.0,2.0,0],
	["GHOST",450,"Подвижность",80.0,2.0,2.0,0],
	["TITAN",600,"Тяжёлая броня",180.0,-0.5,2.0,0],
	["CRYO",800,"Сильный магнит",120.0,0.0,4.0,0],
	["VEGA",0,"Полевой разведчик",100.0,0.0,2.0,0],
	["FOX",320,"Быстрый дозор",100.0,0.45,2.0,0],
	["AMBER",520,"Стрелок прикрытия",110.0,0.0,2.0,2],
	["NORTH",680,"Щит отряда",135.0,-0.25,2.5,0],
]

const HERO_ART = ["hero","cyborg","inferno","ghost","titan","cryo","vega","fox","amber","north"]
const HERO_NAMES = ["СЛАЙМ","КИБОРГ","ИНФЕРНО","ПРИЗРАК","ТИТАН","КРИО","ВЕГА","ЛИСА","ЯНТАРЬ","СЕВЕР"]

const PROFILE_PATH = "user://records.cfg"
const PROFILE_BACKUP = "user://records.backup.cfg"
const PROFILE_TEMP = "user://records.tmp.cfg"
const PROFILE_BACKUP_TEMP = "user://records.backup.tmp.cfg"

func read_profile(path: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK and cfg.has_section_key("records","best"):
		return cfg
	return null

func save_profile(new_credit_balance: int = -1) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("records","best",best)
	cfg.set_value("records","credits",credits if new_credit_balance < 0 else new_credit_balance)
	cfg.set_value("records","sprint",best_sprint)
	cfg.set_value("records","runs",runs)
	cfg.set_value("records","kills",total_kills)
	cfg.set_value("collection","owned",owned)
	cfg.set_value("collection","selected",selected)
	cfg.set_value("awakening","level",hunter_level)
	cfg.set_value("awakening","xp",hunter_xp)
	cfg.set_value("awakening","points",stat_points)
	cfg.set_value("awakening","stats",hunter_stats)
	cfg.set_value("quests","progress",quest_progress)
	cfg.set_value("quests","tiers",quest_tiers)
	cfg.set_value("gates","wins",gate_wins)
	cfg.set_value("meta","version",4)
	if cfg.save(PROFILE_TEMP) != OK:
		push_warning("Profile temporary write failed")
		return false
	var current := read_profile(PROFILE_PATH)
	if current != null:
		if current.save(PROFILE_BACKUP_TEMP) != OK or DirAccess.rename_absolute(PROFILE_BACKUP_TEMP,PROFILE_BACKUP) != OK:
			push_warning("Profile backup failed")
			return false
	var err := DirAccess.rename_absolute(PROFILE_TEMP,PROFILE_PATH)
	if err != OK:
		push_warning("Profile replacement failed: "+str(err))
	return err == OK

func refresh_collection() -> void:
	collection_balance.text = "КРЕДИТЫ %d  ·  ОТКРЫТО %d ИЗ %d" % [credits,owned.size(),HEROES.size()]
	for i in range(HEROES.size()):
		var h: Array = HEROES[i]
		var status := "ВЫБРАН" if selected == i else ("ВЫБРАТЬ" if owned.has(i) else "%d КР." % int(h[1]))
		collection_buttons[i].text = "%s  /  %s\nЗД. %d  ·  СКОР. %.1f  ·  МАГНИТ %.1f\n%s" % [HERO_NAMES[i],h[2],int(h[3]),6.0+float(h[4]),float(h[5]),status]
		collection_buttons[i].add_theme_color_override("font_color",Color("#8df4d5") if selected == i else Color("#edf8f5"))
		collection_buttons[i].disabled = not owned.has(i) and credits < int(h[1])
	result_label.text = "РЕКОРД %d  ·  КРЕДИТЫ %d  ·  60 С  %d" % [best,credits,best_sprint]
	achievements.text = "НАГРАДЫ %d / 3" % (int(runs >= 1)+int(total_kills >= 100)+int(best >= 10000))

func select_hero(index: int) -> void:
	if index < 0 or index >= HEROES.size():
		return
	if not owned.has(index):
		var cost := int(HEROES[index][1])
		if credits < cost:
			return
		credits -= cost
		owned.append(index)
	selected = index
	save_profile()
	if not running:
		apply_hero_art()
	refresh_collection()

var settings_panel: VBoxContainer
var world_light: DirectionalLight3D
var fps_button: Button
var quality_button: Button
var audio_button: Button
const FPS_OPTIONS = [30,60,90,120,144]
var fps_limit := 60
var high_quality := true
var audio_enabled := true

const DEFAULT_ADVANCED = {"sensitivity":1.0,"deadzone":0.08,"camera_speed":10.0,"zoom":20.5,"master":1.0,"music":0.7,"effects":1.0,"particles":0.65,"brightness":1.0,"render_scale":1.0,"msaa":1.0,"stick_size":90.0,"stick_opacity":0.55,"vibration":0.0,"weapons":1.0,"enemies":1.0,"notifications":1.0,"vehicles":1.0}
var advanced: Dictionary = DEFAULT_ADVANCED.duplicate()
var advanced_sliders: Dictionary = {}
var settings_tabs: TabContainer
var preset_button: Button
var preset_index := 1
const PRESET_NAMES = ["LOW","MEDIUM","HIGH","ULTRA"]
const PRESET_LABELS = {"LOW":"НИЗКОЕ","MEDIUM":"СРЕДНЕЕ","HIGH":"ВЫСОКОЕ","ULTRA":"УЛЬТРА","CUSTOM":"СВОЁ"}
const PRESET_VALUES = {
	"render_scale": [0.65,1.0,1.0,1.0],
	"msaa": [0.0,1.0,1.0,2.0],
	"particles": [0.25,0.65,0.85,1.0],
}

func graphics_preset_name() -> String:
	for index in PRESET_NAMES.size():
		if high_quality != (index >= 1):
			continue
		if is_equal_approx(advanced["render_scale"],PRESET_VALUES["render_scale"][index]) and \
			is_equal_approx(advanced["msaa"],PRESET_VALUES["msaa"][index]) and \
			is_equal_approx(advanced["particles"],PRESET_VALUES["particles"][index]):
			return PRESET_NAMES[index]
	return "CUSTOM"

func cycle_preset() -> void:
	preset_index = (preset_index+1)%PRESET_NAMES.size()
	high_quality = preset_index >= 1
	for key in PRESET_VALUES:
		var slider := advanced_sliders[key] as HSlider
		slider.value = float(PRESET_VALUES[key][preset_index])
	save_settings()

func setting_slider(parent: Control, key: String, caption: String, low: float, high: float, step: float) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",22)
	label.text = caption+"  "+str(advanced[key])
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(advanced[key])
	slider.custom_minimum_size.y = 36
	parent.add_child(slider)
	advanced_sliders[key] = slider
	slider.value_changed.connect(func(value: float):
		advanced[key] = value
		label.text = caption+"  "+str(value)
		apply_settings()
	)
	slider.drag_ended.connect(func(_changed: bool): save_settings())

func settings_page(caption: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation",10)
	scroll.add_child(page)
	return page

func build_settings(layer: CanvasLayer) -> void:
	settings_panel = VBoxContainer.new()
	layer.add_child(settings_panel)
	settings_panel.position = Vector2(90,125)
	settings_panel.add_theme_constant_override("separation",12)
	var heading := Label.new()
	heading.text = "НАСТРОЙКИ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",40)
	settings_panel.add_child(heading)
	settings_tabs = TabContainer.new()
	settings_tabs.custom_minimum_size = Vector2(540,720)
	settings_tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	settings_tabs.add_theme_font_size_override("font_size",22)
	var settings_style := StyleBoxFlat.new()
	settings_style.bg_color = Color("#10232dfc")
	settings_style.border_color = Color("#335665")
	settings_style.set_border_width_all(1)
	settings_style.set_corner_radius_all(14)
	settings_style.content_margin_left = 18
	settings_style.content_margin_right = 18
	settings_style.content_margin_top = 14
	settings_style.content_margin_bottom = 14
	settings_tabs.add_theme_stylebox_override("panel",settings_style)
	for state in ["tab_selected","tab_unselected","tab_hovered"]:
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = Color("#244a51") if state == "tab_selected" else Color("#172d37")
		tab_style.border_color = Color("#7bd9be") if state == "tab_selected" else Color("#335665")
		tab_style.border_width_bottom = 2
		tab_style.corner_radius_top_left = 8
		tab_style.corner_radius_top_right = 8
		tab_style.content_margin_left = 16
		tab_style.content_margin_right = 16
		tab_style.content_margin_top = 8
		tab_style.content_margin_bottom = 8
		settings_tabs.add_theme_stylebox_override(state,tab_style)
	settings_panel.add_child(settings_tabs)
	var controls := settings_page("УПРАВЛЕНИЕ")
	setting_slider(controls,"sensitivity","ЧУВСТВИТЕЛЬНОСТЬ",0.25,2.5,0.05)
	setting_slider(controls,"deadzone","МЁРТВАЯ ЗОНА",0.0,0.35,0.01)
	setting_slider(controls,"camera_speed","ОТКЛИК КАМЕРЫ",2.0,20.0,0.5)
	setting_slider(controls,"zoom","ДИСТАНЦИЯ КАМЕРЫ",18.0,28.0,0.5)
	setting_slider(controls,"stick_size","РАДИУС ДЖОЙСТИКА",55.0,125.0,5.0)
	setting_slider(controls,"stick_opacity","ПРОЗРАЧНОСТЬ ДЖОЙСТИКА",0.0,1.0,0.05)
	setting_slider(controls,"vibration","ВИБРАЦИЯ (0 / 1)",0.0,1.0,1.0)
	var graphics := settings_page("ГРАФИКА")
	preset_button = menu_button(graphics,"",cycle_preset)
	preset_button.custom_minimum_size = Vector2(0,56)
	fps_button = menu_button(graphics,"",toggle_fps)
	quality_button = menu_button(graphics,"",toggle_quality)
	setting_slider(graphics,"particles","ПЛОТНОСТЬ ЭФФЕКТОВ",0.25,1.0,0.05)
	setting_slider(graphics,"brightness","ЯРКОСТЬ СВЕТА",0.65,1.35,0.05)
	setting_slider(graphics,"render_scale","РАЗРЕШЕНИЕ 3D",0.5,1.0,0.05)
	setting_slider(graphics,"msaa","СГЛАЖИВАНИЕ (0 / 2× / 4×)",0.0,2.0,1.0)
	fps_button.custom_minimum_size = Vector2(0,56)
	quality_button.custom_minimum_size = Vector2(0,56)
	var audio := settings_page("ЗВУК")
	audio_button = menu_button(audio,"",toggle_audio)
	setting_slider(audio,"master","ОБЩАЯ ГРОМКОСТЬ",0.0,1.0,0.05)
	setting_slider(audio,"music","МУЗЫКА",0.0,1.0,0.05)
	setting_slider(audio,"effects","ЭФФЕКТЫ",0.0,1.0,0.05)
	setting_slider(audio,"weapons","ОРУЖИЕ",0.0,1.0,0.05)
	setting_slider(audio,"enemies","ПРОТИВНИКИ",0.0,1.0,0.05)
	setting_slider(audio,"notifications","УВЕДОМЛЕНИЯ",0.0,1.0,0.05)
	setting_slider(audio,"vehicles","ТРАНСПОРТ",0.0,1.0,0.05)
	audio_button.custom_minimum_size = Vector2(0,56)
	var reset := menu_button(settings_panel,"СБРОСИТЬ НАСТРОЙКИ",reset_settings)
	reset.custom_minimum_size.y = 56
	menu_button(settings_panel,"НАЗАД",close_settings)
	settings_panel.hide()

func reset_settings() -> void:
	fps_limit = 60
	high_quality = true
	audio_enabled = true
	preset_index = 1
	for key in DEFAULT_ADVANCED:
		var slider := advanced_sliders[key] as HSlider
		slider.value = float(DEFAULT_ADVANCED[key])
		advanced[key] = slider.value
	save_settings()

func close_settings() -> void:
	save_settings()
	if hud_in_settings and running:
		hud_in_settings = false
		settings_panel.hide()
		menu_scrim.hide()
		hud_panel.show()
		return
	show_menu()

func show_settings() -> void:
	menu.hide()
	menu_scrim.show()
	collection.hide()
	settings_panel.show()

func apply_settings() -> void:
	get_viewport().scaling_3d_scale = float(advanced["render_scale"])
	match int(advanced["msaa"]):
		1: get_viewport().msaa_3d = Viewport.MSAA_2X
		2: get_viewport().msaa_3d = Viewport.MSAA_4X
		_: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	var preset := graphics_preset_name()
	forest_understory.set_density(preset)
	preset_button.text = "КАЧЕСТВО  ·  "+PRESET_LABELS[preset]
	if running:
		camera.size = float(advanced["zoom"])
	apply_biome_lighting()
	if is_instance_valid(ambient_player):
		ambient_player.volume_db = -26.0+linear_to_db(maxf(0.0001,float(advanced["master"])*float(advanced["music"])))
	if is_instance_valid(ambient_player):
		if audio_enabled and float(advanced["master"])*float(advanced["music"]) > 0.0 and not ambient_player.playing:
			ambient_player.play()
		elif not audio_enabled or float(advanced["master"])*float(advanced["music"]) <= 0.0:
			ambient_player.stop()
	if not audio_enabled:
		for voice in fx_voices:
			voice.stop()
	Engine.max_fps = fps_limit
	world_light.shadow_enabled = high_quality
	var long_shadows := preset in ["HIGH","ULTRA"]
	world_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if long_shadows else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	world_light.directional_shadow_max_distance = 69.0 if long_shadows else 43.0
	world_light.shadow_blur = 1.65 if long_shadows else 1.25
	if contact_shadow_material != null:
		contact_shadow_material.albedo_color.a = 0.59 if high_quality else 1.0
	for voice in fx_voices:
		voice.volume_db = fx_volume(str(voice.get_meta("fx_key","pickup"))) if audio_enabled else -80.0
		if not audio_enabled:
			voice.stop()
	fps_button.text = "ЛИМИТ КАДРОВ  ·  %d FPS" % fps_limit
	quality_button.text = "ТЕНИ  ·  "+("ВКЛ" if high_quality else "ВЫКЛ")
	audio_button.text = "ЗВУК  ·  "+("ВКЛ" if audio_enabled else "ВЫКЛ")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var saved_fps := int(cfg.get_value("video","fps",60))
		fps_limit = saved_fps if FPS_OPTIONS.has(saved_fps) else 60
		high_quality = bool(cfg.get_value("video","shadows",true))
		preset_index = clampi(int(cfg.get_value("video","preset",1)),0,3)
		audio_enabled = bool(cfg.get_value("audio","enabled",true))
		for key in advanced:
			var slider := advanced_sliders[key] as HSlider
			advanced[key] = clampf(float(cfg.get_value("advanced",key,advanced[key])),slider.min_value,slider.max_value)
			slider.value = float(advanced[key])
	apply_settings()

func save_settings() -> void:
	apply_settings()
	var cfg := ConfigFile.new()
	cfg.set_value("video","fps",fps_limit)
	cfg.set_value("video","shadows",high_quality)
	cfg.set_value("video","preset",preset_index)
	cfg.set_value("audio","enabled",audio_enabled)
	for key in advanced:
		cfg.set_value("advanced",key,advanced[key])
	if cfg.save("user://settings.cfg") != OK:
		push_warning("Settings save failed")

func toggle_fps() -> void:
	fps_limit = int(FPS_OPTIONS[(FPS_OPTIONS.find(fps_limit)+1)%FPS_OPTIONS.size()])
	save_settings()

func toggle_quality() -> void:
	high_quality = not high_quality
	save_settings()

func toggle_audio() -> void:
	audio_enabled = not audio_enabled
	save_settings()

var hunter_level := 1
var hunter_xp := 0
var stat_points := 0
var hunter_stats: Array[int] = [0,0,0,0,0]
const STAT_NAMES = ["СИЛА","ЖИВУЧЕСТЬ","ЛОВКОСТЬ","ВОСПРИЯТИЕ","ЗАЩИТА"]
var awakening_panel: VBoxContainer
var awakening_status: Label
var stat_buttons: Array[Button] = []

func hunter_rank() -> String:
	if hunter_level >= 100: return "SS"
	if hunter_level >= 75: return "S"
	if hunter_level >= 50: return "A"
	if hunter_level >= 35: return "B"
	if hunter_level >= 20: return "C"
	if hunter_level >= 10: return "D"
	return "E"

func gain_hunter_xp(amount: int) -> void:
	hunter_xp += maxi(0,amount)
	while hunter_level < 1000 and hunter_xp >= hunter_level*100:
		hunter_xp -= hunter_level*100
		hunter_level += 1
		stat_points += 3
	hunter_xp = mini(hunter_xp,hunter_level*100-1)

const SYSTEM_RANK_COLORS = ["#9daebf","#71d8ad","#65baff","#a995ff","#f2bb65","#ff7777","#f7e4ff"]
var awakening_xp_bar: ProgressBar
func system_heading(label: Label) -> void:
	label.add_theme_color_override("font_color",Color("#8edbff"))
	label.add_theme_color_override("font_shadow_color",Color("#153f6a"))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func build_awakening(layer: CanvasLayer) -> void:
	awakening_panel = VBoxContainer.new()
	layer.add_child(awakening_panel)
	awakening_panel.position = Vector2(90,150)
	awakening_panel.add_theme_constant_override("separation",12)
	awakening_status = Label.new()
	awakening_status.add_theme_font_size_override("font_size",28)
	awakening_panel.add_child(awakening_status)
	system_heading(awakening_status)
	awakening_xp_bar = ProgressBar.new()
	awakening_xp_bar.custom_minimum_size = Vector2(540,20)
	awakening_xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color("#58baff")
	xp_fill.set_corner_radius_all(5)
	awakening_xp_bar.add_theme_stylebox_override("fill",xp_fill)
	awakening_panel.add_child(awakening_xp_bar)
	for i in range(5):
		stat_buttons.append(menu_button(awakening_panel,"",spend_stat.bind(i)))
	menu_button(awakening_panel,"ВРАТА",show_gates)
	build_gates(layer)
	menu_button(awakening_panel,"СИСТЕМНЫЕ ЗАДАНИЯ",show_quests)
	menu_button(awakening_panel,"НАЗАД",show_menu)
	build_quests(layer)
	awakening_panel.hide()

func refresh_awakening() -> void:
	awakening_xp_bar.max_value = hunter_level*100
	awakening_xp_bar.value = hunter_xp
	var rank_index := GATE_RANKS.find(hunter_rank())
	awakening_status.add_theme_color_override("font_color",Color(SYSTEM_RANK_COLORS[maxi(0,rank_index)]))
	awakening_status.text = "ПРОБУЖДЕНИЕ  ·  РАНГ %s\nУРОВЕНЬ %d  ·  ОПЫТ %d/%d\nСВОБОДНЫЕ ОЧКИ  %d" % [hunter_rank(),hunter_level,hunter_xp,hunter_level*100,stat_points]
	for i in range(5):
		stat_buttons[i].text = "%s  %d   +" % [STAT_NAMES[i],hunter_stats[i]]
		stat_buttons[i].disabled = stat_points <= 0

func spend_stat(index: int) -> void:
	if index < 0 or index >= 5 or stat_points <= 0:
		return
	hunter_stats[index] += 1
	stat_points -= 1
	save_profile()
	refresh_awakening()

func show_awakening() -> void:
	gate_panel.hide()
	quest_panel.hide()
	menu.hide()
	menu_scrim.show()
	awakening_panel.show()
	refresh_awakening()

var quest_progress: Array[int] = [0,0,0]
var quest_tiers: Array[int] = [0,0,0]
const QUEST_NAMES = ["ОХОТА","ВЫЖИВАНИЕ","РЕКОРДЫ"]
const QUEST_BASE = [20,3,5000]
var quest_panel: VBoxContainer
var quest_buttons: Array[Button] = []

func quest_target(index: int) -> int:
	return int(QUEST_BASE[index])*(quest_tiers[index]+1)

func build_quests(layer: CanvasLayer) -> void:
	quest_panel = VBoxContainer.new()
	layer.add_child(quest_panel)
	quest_panel.position = Vector2(90,240)
	quest_panel.add_theme_constant_override("separation",18)
	var heading := Label.new()
	heading.text = "СИСТЕМНЫЕ ЗАДАНИЯ"
	heading.add_theme_font_size_override("font_size",36)
	system_heading(heading)
	quest_panel.add_child(heading)
	for i in range(3):
		var btn := menu_button(quest_panel,"",claim_quest.bind(i))
		btn.custom_minimum_size = Vector2(540,132)
		btn.add_theme_font_size_override("font_size",23)
		quest_buttons.append(btn)
	menu_button(quest_panel,"НАЗАД",show_awakening)
	quest_panel.hide()

func refresh_quests() -> void:
	for i in range(3):
		var tier := quest_tiers[i]+1
		var ready := quest_progress[i] >= quest_target(i) and quest_tiers[i] < 1000
		quest_buttons[i].text = "%s  ·  ЭТАП %d\n%d / %d\n+%d XP  +%d КР.  %s" % [QUEST_NAMES[i],tier,mini(quest_progress[i],quest_target(i)),quest_target(i),100*tier,50*tier,"ЗАБРАТЬ" if ready else ""]
		quest_buttons[i].disabled = not ready

func claim_quest(index: int) -> void:
	if index < 0 or index >= 3 or quest_tiers[index] >= 1000 or quest_progress[index] < quest_target(index):
		return
	var tier := quest_tiers[index]+1
	quest_progress[index] -= quest_target(index)
	quest_tiers[index] += 1
	gain_hunter_xp(100*tier)
	credits += 50*tier
	save_profile()
	refresh_quests()

func show_quests() -> void:
	menu.hide()
	menu_scrim.show()
	awakening_panel.hide()
	quest_panel.show()
	refresh_quests()

const GATE_RANKS = ["E","D","C","B","A","S","SS"]
const GATE_LEVELS = [1,10,20,35,50,75,100]
var gate_rank := 0
var gate_cleared := false
var gate_wins: Array[int] = [0,0,0,0,0,0,0]
var gate_panel: VBoxContainer
var gate_buttons: Array[Button] = []

func build_gates(layer: CanvasLayer) -> void:
	gate_panel = VBoxContainer.new()
	layer.add_child(gate_panel)
	gate_panel.position = Vector2(90,130)
	gate_panel.add_theme_constant_override("separation",10)
	var heading := Label.new()
	heading.text = "ВРАТА"
	heading.add_theme_font_size_override("font_size",32)
	system_heading(heading)
	gate_panel.add_child(heading)
	for i in range(7):
		var btn := menu_button(gate_panel,"",enter_gate.bind(i))
		btn.custom_minimum_size = Vector2(540,100)
		btn.add_theme_font_size_override("font_size",22)
		gate_buttons.append(btn)
	menu_button(gate_panel,"НАЗАД",show_awakening)
	gate_panel.hide()

func show_gates() -> void:
	menu.hide()
	menu_scrim.show()
	awakening_panel.hide()
	gate_panel.show()
	for i in range(7):
		gate_buttons[i].text = "РАНГ %s  ·  УРОВЕНЬ %d\nПОБЕДЫ %d  ·  +%d ОПЫТА" % [GATE_RANKS[i],GATE_LEVELS[i],gate_wins[i],150*(i+1)]
		gate_buttons[i].disabled = hunter_level < int(GATE_LEVELS[i])
		gate_buttons[i].add_theme_color_override("font_color",Color(SYSTEM_RANK_COLORS[i]))
		gate_buttons[i].text += "  ·  ЗАКРЫТО" if gate_buttons[i].disabled else "  ·  ВОЙТИ"

func enter_gate(index: int) -> void:
	if index < 0 or index >= 7 or hunter_level < int(GATE_LEVELS[index]):
		return
	gate_rank = index
	start()
	mode = 2
	event_label.text = "ВРАТА "+GATE_RANKS[index]+"  ·  Победите босса за 120 с"

func show_collection() -> void:
	menu.hide()
	hero_preview.hide()
	menu_scrim.show()
	collection.show()
	hero_list.scroll_vertical = 0
	refresh_collection()

func show_menu() -> void:
	hud_paused = false
	hud_in_settings = false
	hud_fusing = false
	hud_panel.set_fusion_open(false)
	range_marker.hide()
	hero_preview.hide()
	gate_panel.hide()
	quest_panel.hide()
	awakening_panel.hide()
	settings_panel.hide()
	collection.hide()
	menu_scrim.hide()
	hud_panel.hide()
	event_label.hide()
	hero_stage.show()
	hero.show()
	hero_shadow.hide()
	for actor in enemies + crates + gems:
		actor.hide()
	if is_instance_valid(vehicle):
		vehicle.hide()
	hero.position = grounded(Vector3.ZERO,0.67)
	hero.scale = Vector3.ONE
	hero.rotation.y = -0.24
	var pose := actor_pose(hero)
	if pose != null:
		pose.aiming = 0.0
		pose.recoil = 0.0
		pose.hit = 0.0
		pose.art.rotation = pose.base_rotation
		pose.reset_clips()
	var target := Vector3(0,-0.98,0.90)
	camera.position = target + Vector3(0,4.2,7.6)
	camera.look_at(target)
	camera.size = 7.25
	menu.show()
	refresh_collection()

func show_hero_preview() -> void:
	menu.hide()
	collection.hide()
	menu_scrim.hide()
	hero_preview_label.text = HERO_NAMES[selected]
	var focus := Vector3(0,0.96,0.05)
	camera.position = focus+Vector3(1.23,0.7,4)
	camera.look_at(focus)
	camera.size = 2.75
	hero_preview.show()

func build_hero_preview(layer: CanvasLayer) -> void:
	hero_preview = Control.new()
	hero_preview.size = Vector2(720,1280)
	hero_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hero_preview)
	hero_preview_label = Label.new()
	hero_preview_label.position = Vector2(80,48)
	hero_preview_label.size.x = 560
	hero_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_preview_label.add_theme_font_size_override("font_size",52)
	hero_preview.add_child(hero_preview_label)
	var back := menu_button(hero_preview,"НАЗАД К ГЕРОЯМ",show_collection)
	back.position = Vector2(90,1050)
	hero_preview.hide()

func choose_menu_action(action: String) -> void:
	match action:
		"play":
			if menu.selected_mode == 1:
				sprint()
			else:
				start()
		"endless": menu.select_mode(0)
		"sprint": menu.select_mode(1)
		"map": cycle_biome()
		"heroes": show_collection()
		"awakening": show_awakening()
		"settings": show_settings()
		"quests": show_quests()
		"gates": show_gates()
		"coop":
			menu.hide()
			menu_scrim.show()
			coop.open_lobby()

func display_coop_result(reason: String) -> void:
	running = false
	choosing = false
	clear_touch()
	upgrades.hide()
	show_menu()
	result_label.text = "%s\nСЧЁТ  %d" % [reason,score]

func menu_button(parent: Control, label: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(540,78)
	btn.add_theme_font_size_override("font_size",26)
	parent.add_child(btn)
	style_button(btn)
	btn.pressed.connect(action)
	return btn


var active_pulses := 0
func ring_ink(color: Color) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://shaders/terrain_ring.gdshader")
	ink.set_shader_parameter("biome",biome)
	ink.set_shader_parameter("play_half",Landscape.PLAY_HALF)
	ink.set_shader_parameter("floor_half",Landscape.FLOOR_HALF)
	ink.set_shader_parameter("tint",color)
	return ink

func pulse(pos: Vector3, radius: float, color: Color) -> void:
	if active_pulses >= 32:
		return
	active_pulses += 1
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.78
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 8
	var effect := model(mesh,color,grounded(pos,0.075))
	var material := ring_ink(Color(color,0.85))
	effect.material_override = material
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.scale = Vector3(0.15,0.12,0.15)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(effect,"scale",Vector3(radius,0.12,radius),0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(alpha: float): material.set_shader_parameter("tint",Color(color,alpha)),0.85,0.0,0.28)
	tween.chain().tween_callback(func(): 
		effect.queue_free()
		active_pulses -= 1
	)

func clear_boss_warning(enemy: MeshInstance3D) -> void:
	if enemy.has_meta("warning_ring"):
		var warning := enemy.get_meta("warning_ring") as MeshInstance3D
		if is_instance_valid(warning):
			warning.queue_free()
		enemy.remove_meta("warning_ring")
		var pose := actor_pose(enemy)
		if pose != null:
			pose.release()

func render_boss_warning(enemy: MeshInstance3D,radius: float) -> void:
	var ring: MeshInstance3D
	if enemy.has_meta("warning_ring"):
		ring = enemy.get_meta("warning_ring") as MeshInstance3D
	if not is_instance_valid(ring):
		var mesh := TorusMesh.new()
		mesh.inner_radius = radius-0.09
		mesh.outer_radius = radius+0.09
		ring = MeshInstance3D.new()
		ring.mesh = mesh
		ring.material_override = ring_ink(Color("#ffb34f"))
		enemy.add_child(ring)
		ring.scale = Vector3.ONE/enemy.scale.x
		ring.position.y = -0.50+0.09/enemy.scale.y
		enemy.set_meta("warning_ring",ring)
		var pose := actor_pose(enemy)
		if pose != null:
			pose.charging = true
	var intensity := 0.55+0.45*sin(elapsed*22.0)
	ring.material_override.set_shader_parameter("tint",Color("#df7042").lerp(Color("#ffdc87"),intensity))

func update_boss_attack(enemy: MeshInstance3D, damage_multiplier: float) -> void:
	var kind := int(enemy.get_meta("kind",0))
	var radius := 3.0+kind
	var deadline := float(enemy.get_meta("next_pulse",99999.0))
	if elapsed >= deadline:
		clear_boss_warning(enemy)
		pulse(enemy.position,radius,Color(["#b66aff","#6adfff","#ff7733"][kind]))
		var pulse_damage := (12.0+kind*4.0)*damage_multiplier
		if planar_distance(hero.position,enemy.position) < radius:
			damage_hero(pulse_damage*(1.0-armor),enemy.position)
		coop.damage_partner(enemy.position,radius,pulse_damage)
		enemy.set_meta("next_pulse",elapsed+4.0)
	elif deadline-elapsed <= 1.2:
		render_boss_warning(enemy,radius)

var active_tracers := 0
var fired_shots := 0

func fire_visual(shooter: Node3D, target: Vector3, fallback_origin := Vector3.INF, style := ShotStyles.AUTO) -> void:
	if style == ShotStyles.AUTO:
		style = ShotStyles.choose(ranks,fired_shots)
		fired_shots += 1
	style = ShotStyles.validated(style)
	var pose := actor_pose(shooter)
	if pose != null:
		pose.fire(target,float(ShotStyles.STYLES[style][ShotStyles.RECOIL]))
	var origin := shot_origin(shooter)
	if pose == null and fallback_origin.is_finite():
		origin = fallback_origin
	shot_tracer(origin,target,shooter,style)

func tracer_piece(beam: Node3D, dimensions: Vector3, position: Vector3, ink: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = ink
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(part)
	part.position = position
	return part

func shot_tracer(from: Vector3, to: Vector3, shooter: Node3D = null, style := ShotStyles.PLAIN) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var profile: Array = ShotStyles.STYLES[style]
	var form: int = profile[ShotStyles.SHAPE]
	var core := Color(profile[ShotStyles.CORE])
	var glow := Color(profile[ShotStyles.HALO])
	coop.record_shot(from,to,shooter,style)
	play_fx("shot")
	if active_tracers >= 24:
		return
	active_tracers += 1
	var beam := Node3D.new()
	beam.set_meta("shot_style",style)
	add_child(beam)
	beam.position = (from+to)*0.5
	var up := Vector3.RIGHT if absf((to-from).dot(Vector3.UP))/length > 0.99 else Vector3.UP
	beam.look_at(to,up)
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = core
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(glow,0.37)
	var duration := 0.14
	var width := 0.073 if style != ShotStyles.PLAIN else 0.083
	if form == ShotStyles.Form.PAIR:
		for side in [-1.0,1.0]:
			tracer_piece(beam,Vector3(0.055,0.055,length),Vector3(side*0.10,0,0),core_mat)
		duration = 0.12
	else:
		tracer_piece(beam,Vector3(width,width,length),Vector3.ZERO,core_mat)
	tracer_piece(beam,Vector3(0.26,0.20,length),Vector3.ZERO,halo_mat)
	match form:
		ShotStyles.Form.FORK:
			for side in [-1.0,1.0]:
				var branch := tracer_piece(beam,Vector3(0.055,0.06,length*0.58),Vector3(side*0.16,0,0),core_mat)
				branch.rotation.y = side*0.067
		ShotStyles.Form.NOVA:
			pulse(to,1.3 if style != 112 else 1.7,glow)
			duration = 0.17
		ShotStyles.Form.HELIX:
			var curl := ImmediateMesh.new()
			for strand in [-1.0,1.0]:
				curl.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,core_mat)
				for i in 19:
					var turn := i*TAU/9.0
					var radius: float = sin(i*PI/18.0)*0.32*strand
					curl.surface_add_vertex(Vector3(cos(turn)*radius,sin(turn)*radius,length*(0.5-i/18.0)))
				curl.surface_end()
			var coil := MeshInstance3D.new()
			coil.mesh = curl
			coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.add_child(coil)
			pulse(to,1.5,glow)
			duration = 0.20
		ShotStyles.Form.BURST:
			var flash := tracer_piece(beam,Vector3(0.249,0.20,length*0.26),Vector3(0,0,length*0.37),core_mat)
			flash.rotation.z = PI*0.25
			pulse(to,1.42,glow)
			duration = 0.18
	var tween := create_tween().set_parallel(true)
	tween.tween_property(beam,"scale",Vector3(0.1,0.1,1.0),duration)
	tween.tween_property(halo_mat,"albedo_color:a",0.0,duration)
	tween.chain().tween_callback(func():
		beam.queue_free()
		active_tracers -= 1
	)
	impact_sparks(from,core,6 if form == ShotStyles.Form.BURST else 3)
	if style != ShotStyles.PLAIN:
		impact_sparks(to,glow,4)

var active_bursts := 0
var spark_fade: Gradient
func impact_sparks(pos: Vector3, tint: Color, count: int) -> void:
	if active_bursts >= 16:
		return
	active_bursts += 1
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = maxi(1,int(count*float(advanced["particles"])))
	sparks.lifetime = 0.32
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 85.0
	sparks.gravity = Vector3(0,-8,0)
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.3
	if spark_fade == null:
		spark_fade = Gradient.new()
		spark_fade.set_color(0,Color.WHITE)
		spark_fade.set_color(1,Color(1,1,1,0))
	sparks.color_ramp = spark_fade
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.065,0.065,0.19)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	sparks.mesh = mesh
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	sparks.position = pos
	sparks.finished.connect(func():
		active_bursts -= 1
		sparks.queue_free()
	)
	sparks.emitting = true

func hit_enemy(enemy: MeshInstance3D, source: Node3D = null) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	play_fx("hit")
	var health := int(enemy.get_meta("health",1))-damage
	enemy.set_meta("health",health)
	var origin := hero.position if source == null else source.position
	show_actor_hit(enemy,origin,health <= 0)
	coop.record_hit(enemy,origin,health <= 0)
	pulse(enemy.position,0.8,Color("#ffb85a"))
	if health > 0:
		impact_sparks(enemy.position,Color("#ffc879"),4)
		return
	var boss := bool(enemy.get_meta("boss",false))
	play_fx("boss" if boss else "destroy")
	if boss and float(advanced["vibration"]) > 0.5:
		Input.vibrate_handheld(70)
	impact_sparks(enemy.position,Color("#bc8cff") if boss else Color("#ff9460"),24 if boss else 9)
	pulse(enemy.position,3.2 if boss else 1.2,Color("#bc8cff") if boss else Color("#ff9460"))
	drop_gem(enemy.position)
	if boss:
		for i in range(8):
			drop_gem(enemy.position+Vector3(randf_range(-2,2),0,randf_range(-2,2)))
	enemies.erase(enemy)
	enemy.queue_free()
	kills += 1
	award(1500 if boss else 100)
	if boss and mode == 2:
		gate_cleared = true


var art_cache: Dictionary = {}
var contact_shadow_mesh: PlaneMesh
var contact_shadow_material: StandardMaterial3D

func add_contact_shadow(host: Node3D, size: float) -> MeshInstance3D:
	if contact_shadow_mesh == null:
		contact_shadow_mesh = PlaneMesh.new()
		contact_shadow_mesh.size = Vector2.ONE
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.45,1.0])
		gradient.colors = PackedColorArray([Color(0,0,0,0.58),Color(0,0,0,0.30),Color(0,0,0,0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5)
		texture.fill_to = Vector2(1.0,0.5)
		texture.width = 32
		texture.height = 32
		contact_shadow_material = StandardMaterial3D.new()
		contact_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		contact_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		contact_shadow_material.albedo_texture = texture
	var shadow := MeshInstance3D.new()
	shadow.mesh = contact_shadow_mesh
	shadow.material_override = contact_shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.scale = Vector3(size,1,size)
	host.add_child(shadow)
	shadow.position.y = (grounded(host.position,0.028).y-host.position.y)/host.scale.y
	return shadow

func attach_art(host: MeshInstance3D, asset: String) -> Node3D:
	host.set_meta("model_asset",asset)
	if host.has_meta("shot_origin"):
		host.remove_meta("shot_origin")
	if host.has_meta("actor_pose"):
		host.remove_meta("actor_pose")
	if not art_cache.has(asset):
		var folder := "res://assets/vendor/models/" if asset in INDUSTRIAL_MODELS else "res://assets/models/"
		var path := folder + asset + ".glb"
		art_cache[asset] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var packed := art_cache[asset] as PackedScene
	if packed == null:
		return null
	var art := packed.instantiate() as Node3D
	if art != null:
		host.add_child(art)
		host.mesh = null
		art.position.y = -0.5
		var muzzle := art.find_child("ShotOrigin",true,false) as Node3D
		if muzzle != null:
			host.set_meta("shot_origin",muzzle)
		if ActorPose.GAIT.has(asset):
			var pose := ActorPose.new()
			pose.configure(host,art,asset)
			art.add_child(pose)
			host.set_meta("actor_pose",pose)
	return art

func shot_origin(host: Node3D) -> Vector3:
	if host.has_meta("shot_origin"):
		var muzzle := host.get_meta("shot_origin") as Node3D
		if is_instance_valid(muzzle):
			return muzzle.global_position
	var pose := actor_pose(host)
	if pose != null:
		var muzzle := pose.muzzle_position()
		if muzzle != Vector3.INF:
			return muzzle
	return host.position+Vector3.UP*0.45

func actor_pose(host: Node3D) -> ActorPose:
	if not is_instance_valid(host) or not host.has_meta("actor_pose"):
		return null
	return host.get_meta("actor_pose") as ActorPose

func damage_hero(amount: float, origin: Vector3) -> void:
	var alive := hp > 0
	hp -= amount
	if amount <= 0.0 or not alive:
		return
	if hp <= 0.0 and play_defeat(hero):
		if not coop.live:
			defeat_timer = 0.9
			clear_touch()
	else:
		show_actor_hit(hero,origin)

var defeat_timer := 0.0

func play_defeat(actor: Node3D) -> bool:
	var pose := actor_pose(actor)
	return pose != null and pose.fall()

var falling_models := 0

func show_actor_hit(host: Node3D, origin: Vector3, defeated := false) -> void:
	var pose := actor_pose(host)
	if pose == null:
		return
	if not defeated:
		if pose.hit < 0.62:
			pose.impact(origin)
		return
	if falling_models >= 12 or pose.art.get_parent() != host:
		return
	var art := pose.art
	pose.set_process(false)
	host.remove_meta("actor_pose")
	art.reparent(self,true)
	falling_models += 1
	var fall := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(art,"rotation:z",art.rotation.z+0.83,0.24)
	fall.tween_property(art,"position:y",art.position.y-0.26,0.24)
	fall.tween_property(art,"scale",art.scale*0.08,0.24)
	fall.chain().tween_callback(func():
		art.queue_free()
		falling_models -= 1
	)

func award(points: int) -> void:
	combo = mini(combo + 1, 20)
	combo_time = 3.0
	score += int(points * (1 + int(combo / 5.0)) * (1.0+score_bonus*0.1))

var gem_mesh: SphereMesh
var gem_material: StandardMaterial3D
func drop_gem(pos: Vector3) -> void:
	gems.append(make_gem(pos))

func make_gem(pos: Vector3) -> MeshInstance3D:
	if gem_mesh == null:
		gem_mesh = SphereMesh.new()
		gem_mesh.radius = 0.18
		gem_mesh.height = 0.36
		gem_mesh.radial_segments = 4
		gem_mesh.rings = 1
		gem_material = StandardMaterial3D.new()
		gem_material.albedo_color = Color("#ffd65a")
		gem_material.emission_enabled = true
		gem_material.emission = Color("#d48626")
		gem_material.emission_energy_multiplier = 0.45
	var gem := MeshInstance3D.new()
	gem.mesh = gem_mesh
	gem.material_override = gem_material
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gem)
	gem.position = grounded(pos,0.3)
	gem.set_meta("model_asset","gem")
	return gem

func create_coop_visual(asset: String,pos: Vector3) -> MeshInstance3D:
	if asset == "gem":
		return make_gem(pos)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9,0.9,0.9)
	var color := Color("#d49b43") if asset == "crate" else Color("#ff7865")
	if asset.begins_with("boss_"):
		mesh.size = Vector3(1.6,1.4,1.6)
		color = Color("#a56bff")
	var visual := model(mesh,color,grounded(pos))
	attach_art(visual,asset)
	add_contact_shadow(visual,2.8 if asset.begins_with("boss_") else 1.7)
	return visual

func choose_upgrade(index: int) -> void:
	if not choosing:
		return
	if index < 0 or index >= offers.size():
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
		event_label.text = "СВЯЗКА  ·  "+COMBINATIONS[100][0]
	if ranks.has(1) and ranks.has(2) and not ranks.has(101):
		ranks[101] = 1
		magnet += 2
		event_label.text = "СВЯЗКА  ·  "+COMBINATIONS[101][0]
	choosing = false
	upgrades.hide()
	clear_touch()


func model(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	n.material_override = mat
	add_child(n)
	n.position = pos
	return n

func build_hero_stage() -> void:
	var pedestal := CylinderMesh.new()
	pedestal.top_radius = 1.22
	pedestal.bottom_radius = 1.42
	pedestal.height = 0.22
	hero_stage = model(pedestal,Color("#243f47"),Vector3(0,0.01,0))
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 1.14
	rim_mesh.outer_radius = 1.2
	rim_mesh.rings = 48
	rim_mesh.ring_segments = 6
	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#61ddbf")
	rim.material_override = material
	rim.scale.y = 0.45
	rim.position.y = 0.12
	hero_stage.add_child(rim)

func _ready() -> void:
	sound = AudioStreamPlayer.new()
	add_child(sound)
	sound.volume_db = -12
	fx_voices.append(sound)
	for i in range(7):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voice.volume_db = -12
		fx_voices.append(voice)
	sounds = {
		"hit":sampled_sounds([
			preload("res://assets/vendor/audio/metalPot1.ogg"),
			preload("res://assets/vendor/audio/metalPot2.ogg"),
			preload("res://assets/vendor/audio/metalPot3.ogg"),
		]),
		"pickup":sampled_sounds([
			preload("res://assets/vendor/audio/handleCoins.ogg"),
			preload("res://assets/vendor/audio/handleCoins2.ogg"),
		]),
		"level":tone(520,0.35,"level"),"boost":tone(320,0.3,"boost"),
		"shot":tone(620,0.11,"shot"),"destroy":tone(95,0.32,"destroy"),"boss":tone(55,0.85,"boss"),
	}
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)
	ambient_player.volume_db = -26.0
	ambient_player.stream = ambient_loop()
	ground = model(Landscape.surface(0),Color(GROUND_COLORS[0]),Vector3.ZERO)
	terrain_meshes[0] = ground.mesh
	mark_on_map(ground)
	update_ground_material()
	build_forest_understory()
	mark_on_map(forest_understory)
	rebuild_scenery()
	build_minimap_camera()
	var sphere := SphereMesh.new()
	hero = model(sphere,Color("#62f5c5"),Vector3(0,0.5,0))
	hero_shadow = add_contact_shadow(hero,1.9)
	build_hero_stage()
	var light := DirectionalLight3D.new()
	world_light = light
	add_child(light)
	light.shadow_enabled = true
	light.shadow_bias = 0.075
	light.shadow_normal_bias = 0.85
	light.shadow_opacity = 0.94
	light.directional_shadow_fade_start = 0.77
	light.directional_shadow_blend_splits = true
	var rim := DirectionalLight3D.new()
	biome_rim = rim
	add_child(rim)
	rim.rotation_degrees = Vector3(-35,145,0)
	rim.light_color = Color("#80bfff")
	rim.light_energy = 0.42
	rim.shadow_enabled = false
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	biome_environment = env.environment
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#13242c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b5d3df")
	env.environment.ambient_light_energy = 0.48
	add_child(env)
	apply_biome_lighting()
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = COMBAT_CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	build_touch_stick(layer)
	hud_panel = CombatHUD.new()
	layer.add_child(hud_panel)
	hud_panel.configure(self)
	fps_label = hud_panel.fps
	build_attack_range()
	retry = Button.new()
	layer.add_child(retry)
	retry.position = Vector2(110,550)
	retry.size = Vector2(500,110)
	retry.add_theme_font_size_override("font_size",34)
	retry.text = "ИГРАТЬ"
	retry.pressed.connect(start)
	retry.hide()
	menu_scrim = ColorRect.new()
	menu_scrim.color = Color("#08141dc9")
	menu_scrim.size = Vector2(720,1280)
	menu_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(menu_scrim)
	menu = HangarMenu.new()
	layer.add_child(menu)
	menu.action_requested.connect(choose_menu_action)
	menu.show_biome(biome,BIOME_NAMES[biome])
	result_label = menu.summary
	achievements = menu.badges
	event_label = Label.new()
	layer.add_child(event_label)
	event_label.position = Vector2(248,194)
	event_label.size = Vector2(229,48)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.clip_text = true
	event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_label.add_theme_font_size_override("font_size",17)
	event_label.add_theme_color_override("font_outline_color",Color("#102029"))
	event_label.add_theme_constant_override("outline_size",6)
	build_awakening(layer)
	build_settings(layer)
	collection = VBoxContainer.new()
	layer.add_child(collection)
	collection.position = Vector2(90,80)
	collection.add_theme_constant_override("separation",10)
	var collection_title := Label.new()
	collection_title.text = "КОЛЛЕКЦИЯ ГЕРОЕВ"
	collection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_title.add_theme_font_size_override("font_size",36)
	collection.add_child(collection_title)
	collection_balance = Label.new()
	collection_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_balance.add_theme_font_size_override("font_size",24)
	collection_balance.add_theme_color_override("font_color",Color("#f9c95b"))
	collection.add_child(collection_balance)
	hero_list = ScrollContainer.new()
	hero_list.custom_minimum_size = Vector2(540,830)
	hero_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collection.add_child(hero_list)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",10)
	hero_list.add_child(rows)
	collection_buttons.resize(HEROES.size())
	for id in [6,7,8,9,0,1,2,3,4,5]:
		var card := menu_button(rows,"",select_hero.bind(id))
		card.custom_minimum_size = Vector2(516,109)
		card.add_theme_font_size_override("font_size",22)
		collection_buttons[id] = card
	menu_button(collection,"ПОКАЗАТЬ ГЕРОЯ",show_hero_preview)
	menu_button(collection,"НАЗАД",show_menu)
	collection.hide()
	build_hero_preview(layer)
	coop = CoopSession.new()
	add_child(coop)
	coop.configure(self,layer)
	upgrades = VBoxContainer.new()
	layer.add_child(upgrades)
	upgrades.position = Vector2(90,551)
	upgrades.size = Vector2(540,320)
	upgrades.add_theme_constant_override("separation",16)
	var heading := Label.new()
	heading.text = "ВЫБЕРИТЕ УСИЛЕНИЕ"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",28)
	heading.add_theme_color_override("font_outline_color",Color("#0b131e"))
	heading.add_theme_constant_override("outline_size",7)
	upgrades.add_child(heading)
	for i in range(3):
		var btn := Button.new()
		btn.text = "УСИЛЕНИЕ"
		offer_buttons.append(btn)
		btn.custom_minimum_size = Vector2(540,110)
		btn.add_theme_font_size_override("font_size",20)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		upgrades.add_child(btn)
		style_button(btn)
		for state in ["normal","hover","pressed","disabled"]:
			var box := btn.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			box.content_margin_left = 123
			box.content_margin_right = 17
			btn.add_theme_stylebox_override(state,box)
		var border := hud_panel.plate(btn,Rect2(10,10,93,90),Color("#d2a66c"),8)
		var artwork := hud_panel.picture(border,Rect2(5,5,83,80))
		offer_art.append(artwork)
		btn.pressed.connect(choose_upgrade.bind(i))
	upgrades.hide()
	for panel in [retry,collection,settings_panel,awakening_panel,quest_panel,gate_panel,coop.lobby,upgrades,hero_preview]:
		centered_ui[panel] = panel.position
	get_viewport().size_changed.connect(resize_interface)
	resize_interface()
	load_profile()
	apply_hero_art()
	load_settings()
	show_menu()
	update_hud()

func resize_interface(extent := Vector2.ZERO) -> void:
	if extent == Vector2.ZERO:
		extent = get_viewport().get_visible_rect().size
	ui_spare = (extent-CombatHUD.DESIGN_SIZE).max(Vector2.ZERO)
	hud_panel.fit_viewport(extent)
	menu.fit_viewport(extent)
	menu_scrim.size = extent
	event_label.position.x = 248.0+ui_spare.x*0.5
	for panel in centered_ui:
		panel.position = centered_ui[panel]+ui_spare*0.5
	refresh_touch_stick()

func profile_int(value: Variant, fallback: int = 0) -> int:
	if value is int or (value is float and is_finite(value)):
		return int(value)
	return fallback

func load_profile_array(target: Array[int], values: Variant, limit: int) -> void:
	target.fill(0)
	if values is Array and values.size() == target.size():
		for i in target.size():
			target[i] = clampi(profile_int(values[i]),0,limit)

func load_profile() -> void:
	var cfg := read_profile(PROFILE_PATH)
	if cfg == null:
		cfg = read_profile(PROFILE_BACKUP)
	var fresh := cfg == null
	if fresh:
		cfg = ConfigFile.new()
	load_profile_array(gate_wins,cfg.get_value("gates","wins",[]),9223372036854775807)
	load_profile_array(quest_progress,cfg.get_value("quests","progress",[]),1000000000)
	load_profile_array(quest_tiers,cfg.get_value("quests","tiers",[]),1000)
	load_profile_array(hunter_stats,cfg.get_value("awakening","stats",[]),3000)
	hunter_level = clampi(profile_int(cfg.get_value("awakening","level",1),1),1,1000)
	hunter_xp = clampi(profile_int(cfg.get_value("awakening","xp",0)),0,hunter_level*100-1)
	stat_points = clampi(profile_int(cfg.get_value("awakening","points",0)),0,3000)
	best = maxi(0,profile_int(cfg.get_value("records","best",0)))
	credits = maxi(0,profile_int(cfg.get_value("records","credits",0)))
	best_sprint = maxi(0,profile_int(cfg.get_value("records","sprint",0)))
	runs = maxi(0,profile_int(cfg.get_value("records","runs",0)))
	total_kills = maxi(0,profile_int(cfg.get_value("records","kills",0)))
	owned = [0,DEFAULT_HERO]
	var saved: Variant = cfg.get_value("collection","owned",[])
	if saved is Array:
		for id in saved:
			if id is int and id > 0 and id < HEROES.size() and not owned.has(id):
				owned.append(id)
	selected = profile_int(cfg.get_value("collection","selected",DEFAULT_HERO if fresh else 0))
	if not owned.has(selected):
		selected = 0

func start(populate := true) -> void:
	defeat_timer = 0.0
	hud_paused = false
	hud_in_settings = false
	hud_fusing = false
	run_pickups = 0
	hud_panel.reset_run()
	refresh_minimap()
	gate_panel.hide()
	gate_cleared = false
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
	var sites: Array = OUTER_SITES[biome]
	for i in range(Landscape.STARTING_CRATES if populate else 0):
		var radius := 16.0 if i < 12 else Landscape.PLAY_HALF-1.0
		var p := Vector3(randf_range(-radius,radius),0.0,randf_range(-radius,radius))
		var site_crate := i-12
		if 0 <= site_crate and site_crate < sites.size()*4:
			var site_center: Vector2 = sites[floori(site_crate/4.0)][0]
			var angle := site_center.angle()+(site_crate%4)*TAU/4.0+randf_range(-0.43,0.43)
			var point := site_center+Vector2.from_angle(angle)*randf_range(2.8,5.2)
			p = Vector3(point.x,0,point.y)
		elif p.length_squared() < 16.0:
			p.x += 6.0
		p = grounded(p)
		var mesh := BoxMesh.new()
		var crate := model(mesh,Color("#d49b43"),p)
		attach_art(crate,"crate")
		add_contact_shadow(crate,1.65)
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
	hero.show()
	hero.position = grounded(Vector3.ZERO)
	hero.rotation = Vector3.ZERO
	camera.position = hero.position + COMBAT_CAMERA_OFFSET
	camera.look_at(hero.position)
	camera.size = float(advanced["zoom"])
	hero.scale = Vector3.ONE
	hero_shadow.position.y = -0.472
	elapsed = 0
	score = 0
	apply_hero_art()
	var stats: Array = HEROES[selected]
	max_hp = float(stats[3])
	hp = max_hp
	speed_bonus = float(stats[4])
	magnet = float(stats[5])
	power = int(stats[6])
	# Permanent stats apply to both current modes.
	max_hp += hunter_stats[1]*3.0
	hp = max_hp
	damage += int(hunter_stats[0]/5.0)
	speed_bonus += minf(2.0,hunter_stats[2]*0.025)
	magnet += minf(3.0,hunter_stats[3]*0.04)
	armor += minf(0.35,hunter_stats[4]*0.005)
	if selected == 2:
		blast = 1
	level = 1
	spawn_timer = 0
	enemy_wave = 0
	fired_shots = 0
	attack_timer = 0
	clear_touch()
	running = true
	refresh_touch_stick()
	menu_scrim.hide()
	hero_stage.hide()
	hero_shadow.show()
	hud_panel.show()
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	event_label.show()
	update_hud()
	retry.hide()
	menu.hide()
	collection.hide()

var stick_base: Panel
var stick_knob: Panel
var stick_guide: CombatHUD.StickGuide
func stick_circle(parent: Node, tint: Color, edge: Color, knob: bool) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = edge
	style.set_border_width_all(2)
	style.shadow_color = Color("#071119c5")
	style.shadow_size = 4
	if knob:
		style.border_color = edge.lightened(0.24)
		style.border_width_top = 3
	style.set_corner_radius_all(256)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func build_touch_stick(layer: CanvasLayer) -> void:
	stick_base = stick_circle(layer,Color("#100f17e5"),Color("#816a53"),false)
	stick_guide = CombatHUD.StickGuide.new()
	stick_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_base.add_child(stick_guide)
	stick_knob = stick_circle(stick_base,Color("#3b3542f1"),Color("#a89286"),true)
	stick_base.hide()

func refresh_touch_stick() -> void:
	if not is_instance_valid(stick_base):
		return
	stick_base.visible = running and not choosing and not hud_paused and not hud_in_settings and not hud_fusing and defeat_timer <= 0.0
	if not stick_base.visible:
		return
	var radius := float(advanced["stick_size"])
	stick_base.size = Vector2.ONE*radius*2.0
	stick_guide.size = stick_base.size
	var center := origin if finger != -1 else Vector2(120+ui_spare.x*0.5,883+ui_spare.y)
	stick_base.position = center-Vector2.ONE*radius
	stick_base.modulate.a = float(advanced["stick_opacity"])
	stick_knob.size = Vector2.ONE*radius*0.7
	stick_knob.position = Vector2.ONE*radius-stick_knob.size*0.5+direction*radius*0.65

func clear_touch() -> void:
	finger = -1
	direction = Vector2.ZERO
	refresh_touch_stick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_touch()
		if is_instance_valid(stick_base):
			stick_base.hide()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		refresh_touch_stick()
		if is_instance_valid(coop) and coop.lobby.visible:
			coop.update_devices()
			coop.refresh_lobby()

func _input(event: InputEvent) -> void:
	if running and event.is_action_pressed("ui_cancel") and not event.is_echo():
		if hud_fusing:
			close_fusion()
		elif hud_in_settings:
			close_settings()
		elif not choosing:
			toggle_hud_pause()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == finger:
		clear_touch()
		return
	if not running or choosing or hud_paused or hud_in_settings or hud_fusing or defeat_timer > 0.0:
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			if hud_panel.blocks_at(event.position):
				return
			finger = event.index
			origin = event.position
	elif event is InputEventScreenDrag and event.index == finger:
		var raw: Vector2 = ((event.position-origin)/float(advanced["stick_size"])*float(advanced["sensitivity"])).limit_length()
		var dead := float(advanced["deadzone"])
		direction = raw.normalized()*maxf(0.0,(raw.length()-dead)/(1.0-dead))
	refresh_touch_stick()

func movement_input() -> Vector2:
	if hud_paused or hud_in_settings or hud_fusing:
		return Vector2.ZERO
	if finger != -1:
		return direction
	return Input.get_vector("ui_left","ui_right","ui_up","ui_down")

func follow_player_camera(dt: float) -> void:
	var focus := hero.position
	if hp <= 0 and coop.live and is_instance_valid(coop.partner):
		focus = coop.partner.position
	camera.position = camera.position.lerp(focus + COMBAT_CAMERA_OFFSET,1.0-exp(-float(advanced["camera_speed"])*dt))

func enemy_stage(run_level: int) -> int:
	return floori(run_level/5.0)

func reinforce_enemy(enemy: MeshInstance3D, stages: int) -> void:
	var health := int(enemy.get_meta("health",1))
	var maximum := int(enemy.get_meta("max_health",health))
	var bonus := stages*(4 if enemy.get_meta("boss",false) else 1)
	enemy.set_meta("health",health+bonus)
	enemy.set_meta("max_health",maximum+bonus)

func spawn_enemy_wave(center: Vector3, stage: int) -> void:
	enemy_wave += 1
	var types: Array = []
	if stage > 0 and enemy_wave % 4 == 0:
		var formation := (stage+floori(enemy_wave/4.0)-2) % ENEMY_FORMATIONS.size()
		types = ENEMY_FORMATIONS[formation]
	else:
		var roll := randf()
		types = [2 if roll < 0.25 else (1 if roll < 0.5125 else 0)]
	var angle := randf()*TAU
	var count := mini(types.size(),ENEMY_LIMIT-enemies.size())
	for i in count:
		var spawn_angle := angle+(i-(count-1)*0.5)*0.42
		var position := Landscape.keep_inside(center+Vector3(cos(spawn_angle),0,sin(spawn_angle))*12,Landscape.SPAWN_HALF)
		var data: Array = ENEMY_TYPES[types[i]]
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE*0.8
		var enemy := model(mesh,Color("#ff7865"),position)
		attach_art(enemy,data[0])
		enemy.scale = Vector3.ONE*float(data[3])
		enemy.set_meta("health",int(data[1])+(gate_rank if mode == 2 else 0))
		enemy.set_meta("speed",data[2])
		reinforce_enemy(enemy,stage)
		seat_actor(enemy)
		add_contact_shadow(enemy,1.72)
		enemies.append(enemy)

func _physics_process(dt: float) -> void:
	if running and defeat_timer > 0.0:
		defeat_timer -= dt
		if defeat_timer <= 0.0:
			finish_run()
		return
	if not running or choosing or ((hud_paused or hud_fusing) and not coop.live) or (coop.live and not coop.hosting):
		return
	elapsed += dt
	if not coop.live or hp > 0:
		hp = minf(max_hp,hp+regen*dt)
	update_events(dt)
	if mode == 1 and elapsed >= 60:
		finish_run()
		update_hud()
		return
	combo_time -= dt
	if combo_time <= 0:
		combo = 0
	var move := movement_input() if not coop.live or hp > 0 else Vector2.ZERO
	if move.length() > 0.05:
		hero.rotation.y = lerp_angle(hero.rotation.y,atan2(move.x,move.y),minf(dt*12,1.0))
	hero.position = Landscape.keep_inside(hero.position+Vector3(move.x,0,move.y)*dt*move_speed(),Landscape.PLAY_HALF)
	seat_actor(hero)
	follow_player_camera(dt)
	coop.tick_partner(dt)
	var stage := enemy_stage(level)
	var enemy_speed_multiplier := 1.0+minf(0.65,stage*0.065)
	var enemy_damage_multiplier := 1.0+0.16*sqrt(stage)
	spawn_timer -= dt
	if spawn_timer <= 0 and enemies.size() < ENEMY_LIMIT:
		spawn_timer = maxf(0.25,(1.1-elapsed/150.0)*pow(0.94,mini(stage,8)))
		var center: Vector3 = coop.partner.position if hp <= 0 and coop.live_partner() != null else hero.position
		spawn_enemy_wave(center,stage)
	if elapsed >= 45 and not boss_spawned:
		boss_spawned = true
		var boss_mesh := BoxMesh.new()
		var boss := model(boss_mesh,Color("#a56bff"),Landscape.keep_inside(hero.position+Vector3(9,0,0),Landscape.PLAY_HALF))
		var boss_kind := 1 if biome == 3 else (2 if biome == 4 else 0)
		attach_art(boss,["boss_overlord","boss_crystal","boss_inferno"][boss_kind])
		boss.scale = Vector3.ONE*1.35
		boss.set_meta("kind",boss_kind)
		boss.set_meta("next_pulse",elapsed+4.0)
		boss.set_meta("boss",true)
		var boss_health := 24+boss_kind*6+(gate_rank*12 if mode == 2 else 0)
		boss.set_meta("health",boss_health)
		boss.set_meta("max_health",boss_health)
		boss.set_meta("speed",1.5)
		reinforce_enemy(boss,stage)
		seat_actor(boss)
		add_contact_shadow(boss,3.35)
		enemies.append(boss)
	var nearest: MeshInstance3D = null
	var distance := attack_distance()
	for e in enemies:
		var target := coop.target_for(e.position)
		var offset: Vector3 = target.position-e.position
		offset.y = 0.0
		var d := offset.length()
		var hero_distance := d if target == hero else planar_distance(hero.position,e.position)
		if d > 0.05:
			e.rotation.y = lerp_angle(e.rotation.y,atan2(offset.x,offset.z),1.0-exp(-9.0*dt))
		e.position += offset.normalized()*dt*(float(e.get_meta("speed",2.0))+minf(elapsed/90.0,2.0))*enemy_speed_multiplier
		seat_actor(e)
		if e.get_meta("boss",false):
			update_boss_attack(e,enemy_damage_multiplier)
		var contact_damage: float = dt*(24 if e.get_meta("boss",false) else 12)*enemy_damage_multiplier
		if hero_distance < 0.9*e.scale.x:
			damage_hero(contact_damage*(1.0-armor),e.position)
		coop.damage_partner(e.position,0.9*e.scale.x,contact_damage)
		if hero_distance < distance:
			distance = hero_distance
			nearest = e
	attack_timer -= dt
	if nearest != null and attack_timer <= 0 and hp > 0:
		attack_timer = maxf(0.15,0.7-power*0.08-(VEHICLE_FIRE[vehicle_kind] if vehicle_time > 0 else 0.0))
		var impact := nearest.position
		fire_visual(hero,impact+Vector3.UP*0.2)
		hit_enemy(nearest,hero)
		if blast > 0:
			pulse(impact,1.5+blast*0.4,Color("#64cfff"))
			for other in enemies.duplicate():
				if other != nearest and planar_distance(other.position,impact) < 1.5+blast*0.4:
					hit_enemy(other)
	for crate in crates.duplicate():
		if planar_distance(coop.target_for(crate.position).position,crate.position) < 1.0+level*0.12:
			drop_gem(crate.position)
			pulse(crate.position,2.2,Color("#ff9d45"))
			for enemy in enemies.duplicate():
				if planar_distance(enemy.position,crate.position) < 2.2:
					hit_enemy(enemy,crate)
			award(50)
			crates.erase(crate)
			crate.queue_free()
	for gem in gems.duplicate():
		var offset: Vector3 = coop.target_for(gem.position).position-gem.position
		offset.y = 0
		if offset.length() < magnet:
			gem.position = grounded(gem.position+offset.normalized()*dt*9,0.3)
		if offset.length() < 0.65:
			gems.erase(gem)
			gem.queue_free()
			xp += 1
			run_pickups += 1
			play_fx("pickup")
			award(20)
	if xp >= level*3 and (hp > 0 or coop.live):
		xp -= level*3
		level += 1
		var new_stage := enemy_stage(level)
		if new_stage > stage:
			for enemy in enemies:
				reinforce_enemy(enemy,new_stage-stage)
			enemy_wave = 3
			spawn_timer = minf(spawn_timer,0.6)
		play_fx("level")
		hero.scale = Vector3.ONE*(1.0+minf((level-1)*0.12,1.5))
		seat_actor(hero)
		hero_shadow.position.y = -0.5+0.028/hero.scale.y
		choosing = true
		if hud_fusing:
			close_fusion()
		clear_touch()
		roll_offers()
		upgrades.show()
		if offer_motion != null:
			offer_motion.kill()
		upgrades.modulate.a = 0.06
		offer_motion = create_tween()
		offer_motion.tween_property(upgrades,"modulate:a",1.0,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if coop.live:
		hero.visible = hp > 0
		if hp <= 0 and coop.partner_hp <= 0:
			finish_run()
	elif defeat_timer <= 0.0 and (hp <= 0 or (mode == 2 and (gate_cleared or elapsed >= 120.0))):
		finish_run()

var hud_elapsed := 0.0
var fps_elapsed := 0.0
var fps_label: Label

func _process(dt: float) -> void:
	hud_elapsed += dt
	fps_elapsed += dt
	if hud_elapsed >= 0.1:
		hud_elapsed = 0.0
		update_hud()
	if range_marker.visible:
		range_marker.position = grounded(hero.position,0.068)
	if fps_elapsed >= 0.5:
		fps_elapsed = 0.0
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		menu.fps.text = fps_label.text

func move_speed() -> float:
	if coop.live and not coop.hosting:
		return 6.0+float(HEROES[selected][4])
	return 6.0+speed_bonus+(VEHICLE_SPEED[vehicle_kind] if vehicle_time > 0 else 0.0)

func attack_distance() -> float:
	return 4.0+level*0.3+reach

func update_hud() -> void:
	if hud_panel.visible:
		hud_panel.refresh()
	range_marker.visible = running and not choosing and not hud_paused and not hud_fusing and hud_panel.range_button.button_pressed
	if range_marker.visible:
		var radius := attack_distance()
		range_marker.position = grounded(hero.position,0.068)
		range_marker.scale = Vector3(radius,1,radius)

func build_attack_range() -> void:
	range_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.991
	ring.outer_radius = 1.0
	ring.rings = 56
	ring.ring_segments = 4
	range_marker.mesh = ring
	range_marker.material_override = ring_ink(Color("#ffbb54aa"))
	range_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(range_marker)
	range_marker.hide()

func toggle_attack_range() -> void:
	update_hud()

func open_fusion() -> void:
	if not can_open_fusion() or hud_fusing:
		return
	hud_fusing = true
	hud_panel.set_fusion_open(true)
	event_label.hide()
	clear_touch()
	update_hud()

func close_fusion() -> void:
	hud_fusing = false
	hud_panel.set_fusion_open(false)
	event_label.visible = running and not hud_paused
	clear_touch()
	update_hud()

func toggle_hud_pause() -> void:
	if not running or choosing or hud_fusing or defeat_timer > 0.0:
		return
	hud_paused = not hud_paused
	hud_panel.set_paused(hud_paused)
	event_label.visible = not hud_paused
	clear_touch()
	update_hud()

func open_hud_settings() -> void:
	if not running or choosing or hud_in_settings or hud_fusing or defeat_timer > 0.0:
		return
	if not hud_paused:
		toggle_hud_pause()
	hud_in_settings = true
	hud_panel.hide()
	show_settings()

func exit_hud_run() -> void:
	if coop.live:
		coop.leave_match()
	else:
		finish_run()
