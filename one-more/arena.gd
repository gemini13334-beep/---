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
		offer_buttons[i].text = "%s  /  %s  •  RANK %d\n%s" % [["COMMON","RARE","EPIC"][a[2]],a[0],int(ranks.get(a[0],0))+1,a[1]]
		offer_buttons[i].modulate = [Color.WHITE,Color("#85d9ff"),Color("#e2b2ff")][a[2]]

var selected := 0
var owned: Array[int] = [0]
var collection: VBoxContainer
var collection_balance: Label
var collection_buttons: Array[Button] = []
var menu: VBoxContainer
var result_label: Label
var max_hp := 100.0
var mode := 0
var biome := 0
var scenery: Array[MeshInstance3D] = []
var sound: AudioStreamPlayer
var sounds: Dictionary = {}

func tone(freq: float, duration: float, kind: String = "pickup") -> AudioStreamWAV:
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

var fx_last: Dictionary = {}
var fx_voices: Array[AudioStreamPlayer] = []
var fx_cursor := 0
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
	voice.volume_db = -20.0 if key == "shot" else (-9.0 if key == "boss" else -15.0)
	voice.stream = sounds[key]
	voice.pitch_scale = randf_range(0.94,1.06) if key == "hit" else 1.0
	voice.play()

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
		attach_art(prop,BIOMES[biome].to_lower() if i%2 == 0 else ["tree","ruin","cactus","ice_spire","lava_vent"][biome])
		prop.rotation.y = angle
		prop.scale = Vector3.ONE*(0.8+0.45*abs(sin(float(i)*2.7)))
		scenery.append(prop)
	if biome == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 8271
		for i in range(30):
			var angle := rng.randf_range(0,TAU)
			var radius := rng.randf_range(21.5,23.5)
			var mesh := SphereMesh.new()
			mesh.radius = 0.45
			mesh.height = 0.65
			var prop := model(mesh,Color("#52634c"),Vector3(cos(angle)*radius,0.3,sin(angle)*radius))
			attach_art(prop,"rock" if i%3 == 0 else "tree")
			prop.scale = Vector3.ONE*rng.randf_range(0.65,1.5)
			prop.rotation.y = angle
			scenery.append(prop)

var ground: MeshInstance3D
var biome_button: Button
const BIOMES = ["FOREST","CITY","DESERT","ICE","VOLCANO"]
const GROUND_COLORS = ["#294a37","#34404c","#82613d","#426c80","#4d292c"]

func update_ground_material() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("base_color",Color(GROUND_COLORS[biome]))
	mat.set_shader_parameter("forest",1.0 if biome == 0 else 0.0)
	ground.material_override = mat

func cycle_biome() -> void:
	biome = (biome+1)%BIOMES.size()
	biome_button.text = "MAP • "+BIOMES[biome]
	update_ground_material()
	rebuild_scenery()

var best_sprint := 0
var runs := 0
var total_kills := 0
var vehicle: MeshInstance3D
var vehicle_time := 0.0
var vehicle_kind := 0
const VEHICLES = ["buggy","hovercraft","tank","mech"]
const VEHICLE_SPEED = [4.0,6.0,1.5,2.5]
const VEHICLE_FIRE = [0.3,0.15,0.45,0.35]
var next_event := 15.0
var event_label: Label
var achievements: Label

func sprint() -> void:
	start()
	mode = 1

func finish_run() -> void:
	if not running:
		return
	gain_hunter_xp(kills*5+int(score/200.0))
	running = false
	choosing = false
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
		result_label.text = ("GATE CLEARED" if gate_cleared else "GATE FAILED")+"\n"+result_label.text

func spawn_vehicle() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.7,0.65,2.4)
	vehicle = model(mesh,Color("#ffc45c"),Vector3(clampf(hero.position.x+5,-19,19),0.5,clampf(hero.position.z+3,-19,19)))
	vehicle_kind = randi_range(0,3)
	attach_art(vehicle,VEHICLES[vehicle_kind])
	event_label.text = "BOOST "+VEHICLES[vehicle_kind].to_upper()+" • Collect vehicle"

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
			vehicle_time = [10.0,8.0,12.0,15.0][vehicle_kind]
			play_fx("boost")
			pulse(hero.position,3.0,Color("#ffc45c"))
	if vehicle_time > 0:
		vehicle_time = maxf(0,vehicle_time-dt)
		event_label.text = "%s BOOST • %.1fs" % [VEHICLES[vehicle_kind].to_upper(),vehicle_time]
		if vehicle_time <= 0:
			event_label.text = ""

var hp_bar: ProgressBar
var xp_bar: ProgressBar
var hero_visual: Node3D
const PALETTE = ["#62f5c5","#8caee9","#ff7043","#b998ff","#e2b45d","#72e5ff"]

var hud_panel: Panel
var menu_scrim: ColorRect

func ui_panel(layer: CanvasLayer, pos: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14232ee8")
	style.border_color = Color("#416475")
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	return panel

func style_button(btn: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#233d4b") if state == "normal" else Color("#365b68")
		if state == "disabled":
			style.bg_color = Color("#273038")
		style.border_color = Color("#65d9c0")
		style.set_border_width_all(1)
		style.border_width_bottom = 4
		style.set_corner_radius_all(14)
		btn.add_theme_stylebox_override(state,style)
	btn.add_theme_color_override("font_color",Color("#edf8f5"))

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

const PROFILE_PATH = "user://records.cfg"
const PROFILE_BACKUP = "user://records.backup.cfg"
const PROFILE_TEMP = "user://records.tmp.cfg"

func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records","best",best)
	cfg.set_value("records","credits",credits)
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
		return
	var current := ConfigFile.new()
	if current.load(PROFILE_PATH) == OK:
		if current.save(PROFILE_BACKUP) != OK:
			push_warning("Profile backup failed")
			return
	var err := DirAccess.rename_absolute(PROFILE_TEMP,PROFILE_PATH)
	if err != OK:
		push_warning("Profile replacement failed: "+str(err))

func refresh_collection() -> void:
	collection_balance.text = "CREDITS %d  /  OWNED %d OF %d" % [credits,owned.size(),HEROES.size()]
	for i in range(HEROES.size()):
		var h: Array = HEROES[i]
		var status := "SELECTED" if selected == i else ("SELECT" if owned.has(i) else "%d CR" % int(h[1]))
		collection_buttons[i].text = "%s  /  %s\nHP %d  •  SPEED %.1f  •  MAGNET %.1f\n%s" % [h[0],h[2],int(h[3]),6.0+float(h[4]),float(h[5]),status]
		collection_buttons[i].add_theme_color_override("font_color",Color("#8df4d5") if selected == i else Color("#edf8f5"))
		collection_buttons[i].disabled = not owned.has(i) and credits < int(h[1])
	result_label.text = "BEST %d  |  CR %d\n60s BEST %d" % [best,credits,best_sprint]
	achievements.text = "BADGES: %d / 3" % (int(runs >= 1)+int(total_kills >= 100)+int(best >= 10000))

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
	refresh_collection()

var settings_panel: VBoxContainer
var world_light: DirectionalLight3D
var fps_button: Button
var quality_button: Button
var audio_button: Button
const FPS_OPTIONS = [30,60,90,120,144]
var fps_limit := 60
var high_quality := false
var audio_enabled := true

func build_settings(layer: CanvasLayer) -> void:
	settings_panel = VBoxContainer.new()
	layer.add_child(settings_panel)
	settings_panel.position = Vector2(90,320)
	settings_panel.add_theme_constant_override("separation",18)
	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",40)
	settings_panel.add_child(heading)
	fps_button = menu_button(settings_panel,"",toggle_fps)
	quality_button = menu_button(settings_panel,"",toggle_quality)
	audio_button = menu_button(settings_panel,"",toggle_audio)
	menu_button(settings_panel,"BACK",show_menu)
	settings_panel.hide()

func show_settings() -> void:
	menu.hide()
	collection.hide()
	settings_panel.show()

func apply_settings() -> void:
	Engine.max_fps = fps_limit
	world_light.shadow_enabled = high_quality
	for voice in fx_voices:
		voice.volume_db = -12.0 if audio_enabled else -80.0
		if not audio_enabled:
			voice.stop()
	fps_button.text = "FRAME LIMIT  /  %d FPS" % fps_limit
	quality_button.text = "SHADOWS  /  "+("ON" if high_quality else "OFF")
	audio_button.text = "SOUND  /  "+("ON" if audio_enabled else "OFF")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var saved_fps := int(cfg.get_value("video","fps",60))
		fps_limit = saved_fps if FPS_OPTIONS.has(saved_fps) else 60
		high_quality = bool(cfg.get_value("video","shadows",false))
		audio_enabled = bool(cfg.get_value("audio","enabled",true))
	apply_settings()

func save_settings() -> void:
	apply_settings()
	var cfg := ConfigFile.new()
	cfg.set_value("video","fps",fps_limit)
	cfg.set_value("video","shadows",high_quality)
	cfg.set_value("audio","enabled",audio_enabled)
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
const STAT_NAMES = ["STRENGTH","VITALITY","AGILITY","PERCEPTION","DEFENSE"]
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

func build_awakening(layer: CanvasLayer) -> void:
	awakening_panel = VBoxContainer.new()
	layer.add_child(awakening_panel)
	awakening_panel.position = Vector2(90,180)
	awakening_panel.add_theme_constant_override("separation",12)
	awakening_status = Label.new()
	awakening_status.add_theme_font_size_override("font_size",28)
	awakening_panel.add_child(awakening_status)
	for i in range(5):
		stat_buttons.append(menu_button(awakening_panel,"",spend_stat.bind(i)))
	menu_button(awakening_panel,"DIMENSIONAL GATES",show_gates)
	build_gates(layer)
	menu_button(awakening_panel,"SYSTEM QUESTS",show_quests)
	menu_button(awakening_panel,"BACK",show_menu)
	build_quests(layer)
	awakening_panel.hide()

func refresh_awakening() -> void:
	awakening_status.text = "AWAKENING  /  RANK %s\nLEVEL %d  /  XP %d/%d\nAVAILABLE POINTS: %d" % [hunter_rank(),hunter_level,hunter_xp,hunter_level*100,stat_points]
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
	awakening_panel.show()
	refresh_awakening()

var quest_progress: Array[int] = [0,0,0]
var quest_tiers: Array[int] = [0,0,0]
const QUEST_NAMES = ["HUNT","SURVIVE","BREAK RECORDS"]
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
	heading.text = "SYSTEM QUESTS"
	heading.add_theme_font_size_override("font_size",36)
	quest_panel.add_child(heading)
	for i in range(3):
		var btn := menu_button(quest_panel,"",claim_quest.bind(i))
		btn.custom_minimum_size = Vector2(540,132)
		btn.add_theme_font_size_override("font_size",23)
		quest_buttons.append(btn)
	menu_button(quest_panel,"BACK",show_awakening)
	quest_panel.hide()

func refresh_quests() -> void:
	for i in range(3):
		var tier := quest_tiers[i]+1
		var ready := quest_progress[i] >= quest_target(i) and quest_tiers[i] < 1000
		quest_buttons[i].text = "%s  /  TIER %d\n%d / %d\n+%d XP  +%d CR  %s" % [QUEST_NAMES[i],tier,mini(quest_progress[i],quest_target(i)),quest_target(i),100*tier,50*tier,"CLAIM" if ready else ""]
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
	heading.text = "DIMENSIONAL GATES"
	heading.add_theme_font_size_override("font_size",32)
	gate_panel.add_child(heading)
	for i in range(7):
		var btn := menu_button(gate_panel,"",enter_gate.bind(i))
		btn.custom_minimum_size = Vector2(540,100)
		btn.add_theme_font_size_override("font_size",22)
		gate_buttons.append(btn)
	menu_button(gate_panel,"BACK",show_awakening)
	gate_panel.hide()

func show_gates() -> void:
	awakening_panel.hide()
	gate_panel.show()
	for i in range(7):
		gate_buttons[i].text = "RANK %s  /  LEVEL %d\nCLEARS %d  /  +%d XP" % [GATE_RANKS[i],GATE_LEVELS[i],gate_wins[i],150*(i+1)]
		gate_buttons[i].disabled = hunter_level < int(GATE_LEVELS[i])

func enter_gate(index: int) -> void:
	if index < 0 or index >= 7 or hunter_level < int(GATE_LEVELS[index]):
		return
	gate_rank = index
	start()
	mode = 2
	event_label.text = "GATE "+GATE_RANKS[index]+" / DEFEAT BOSS IN 120s"

func show_collection() -> void:
	menu.hide()
	menu_scrim.show()
	collection.show()
	refresh_collection()

func show_menu() -> void:
	gate_panel.hide()
	quest_panel.hide()
	awakening_panel.hide()
	settings_panel.hide()
	collection.hide()
	menu_scrim.show()
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


var active_pulses := 0
func pulse(pos: Vector3, radius: float, color: Color) -> void:
	if active_pulses >= 32:
		return
	active_pulses += 1
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.78
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 8
	var effect := model(mesh,color,Vector3(pos.x,0.06,pos.z))
	var material := effect.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.scale = Vector3(0.15,0.12,0.15)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(effect,"scale",Vector3(radius,0.12,radius),0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,0.28)
	tween.chain().tween_callback(func(): 
		effect.queue_free()
		active_pulses -= 1
	)

func update_boss_attack(enemy: MeshInstance3D) -> void:
	var kind := int(enemy.get_meta("kind",0))
	var radius := 3.0+kind
	var deadline := float(enemy.get_meta("next_pulse",99999.0))
	if elapsed >= deadline:
		var warning = enemy.get_meta("warning_ring",null)
		if is_instance_valid(warning):
			warning.queue_free()
		if enemy.has_meta("warning_ring"):
			enemy.remove_meta("warning_ring")
		pulse(enemy.position,radius,Color(["#b66aff","#6adfff","#ff7733"][kind]))
		if hero.position.distance_to(enemy.position) < radius:
			hp -= (12.0+kind*4.0)*(1.0-armor)
		enemy.set_meta("next_pulse",elapsed+4.0)
	elif deadline-elapsed <= 1.2:
		var ring = enemy.get_meta("warning_ring",null)
		if not is_instance_valid(ring):
			var mesh := TorusMesh.new()
			mesh.inner_radius = radius-0.09
			mesh.outer_radius = radius+0.09
			ring = MeshInstance3D.new()
			ring.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color("#ffb34f")
			ring.material_override = mat
			enemy.add_child(ring)
			ring.scale = Vector3.ONE/enemy.scale.x
			ring.position.y = -0.42
			enemy.set_meta("warning_ring",ring)
		ring.visible = int(elapsed*8.0)%2 == 0

func shot_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	play_fx("shot")
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.085,0.085,length)
	beam.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#ffe39b")
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beam.position = (from+to)*0.5
	beam.look_at(to,Vector3.UP)
	var tween := create_tween()
	tween.tween_property(beam,"scale",Vector3(0.1,0.1,1.0),0.12)
	tween.tween_callback(beam.queue_free)

var active_bursts := 0
func impact_sparks(pos: Vector3, tint: Color, count: int) -> void:
	if active_bursts >= 16:
		return
	active_bursts += 1
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = count
	sparks.lifetime = 0.32
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 85.0
	sparks.gravity = Vector3(0,-8,0)
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.3
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.065,0.065,0.19)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
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

func hit_enemy(enemy: MeshInstance3D) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	play_fx("hit")
	var health := int(enemy.get_meta("health",1))-damage
	enemy.set_meta("health",health)
	pulse(enemy.position,0.8,Color("#ffb85a"))
	if health > 0:
		impact_sparks(enemy.position,Color("#ffc879"),4)
		return
	var boss := bool(enemy.get_meta("boss",false))
	play_fx("boss" if boss else "destroy")
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
	fx_voices.append(sound)
	for i in range(7):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voice.volume_db = -12
		fx_voices.append(voice)
	sounds = {"hit":tone(180,0.09,"hit"),"pickup":tone(880,0.12,"pickup"),"level":tone(520,0.35,"level"),"boost":tone(320,0.3,"boost"),"shot":tone(620,0.11,"shot"),"destroy":tone(95,0.32,"destroy"),"boss":tone(55,0.85,"boss")}
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(44, 0.2, 44)
	ground = model(floor_mesh, Color(GROUND_COLORS[biome]), Vector3(0,-0.2,0))
	update_ground_material()
	rebuild_scenery()
	var sphere := SphereMesh.new()
	hero = model(sphere,Color("#62f5c5"),Vector3(0,0.5,0))
	apply_hero_art()
	var light := DirectionalLight3D.new()
	world_light = light
	add_child(light)
	light.rotation_degrees = Vector3(-60,-30,0)
	light.shadow_enabled = true
	light.light_color = Color("#fff1d2")
	light.light_energy = 1.35
	var rim := DirectionalLight3D.new()
	add_child(rim)
	rim.rotation_degrees = Vector3(-35,145,0)
	rim.light_color = Color("#80bfff")
	rim.light_energy = 0.42
	rim.shadow_enabled = false
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#13242c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b5d3df")
	env.environment.ambient_light_energy = 0.48
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
	hud_panel = ui_panel(layer,Vector2(12,12),Vector2(696,236))
	fps_label = Label.new()
	fps_label.position = Vector2(560,24)
	fps_label.add_theme_font_size_override("font_size",20)
	fps_label.add_theme_color_override("font_color",Color("#8df4d5"))
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fps_label)
	hud = Label.new()
	layer.add_child(hud)
	hud.position = Vector2(24,24)
	hud.add_theme_font_size_override("font_size",26)
	hud.add_theme_color_override("font_color",Color("#eef8f5"))
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
	menu_scrim = ColorRect.new()
	menu_scrim.color = Color("#08141dc9")
	menu_scrim.size = Vector2(720,1280)
	menu_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(menu_scrim)
	menu = VBoxContainer.new()
	layer.add_child(menu)
	menu.position = Vector2(90,260)
	menu.add_theme_constant_override("separation",18)
	var title := Label.new()
	title.text = "ONE MORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",64)
	menu.add_child(title)
	title.add_theme_color_override("font_color",Color("#8df4d5"))
	var subtitle := Label.new()
	subtitle.text = "SURVIVE  /  EVOLVE  /  REPEAT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",22)
	subtitle.add_theme_color_override("font_color",Color("#a8becb"))
	menu.add_child(subtitle)
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size",26)
	menu.add_child(result_label)
	var play := menu_button(menu,"PLAY  /  ENDLESS",start)
	var primary := StyleBoxFlat.new()
	primary.bg_color = Color("#8df4d5")
	primary.set_corner_radius_all(14)
	play.add_theme_stylebox_override("normal",primary)
	play.add_theme_color_override("font_color",Color("#102b29"))
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
	menu_button(menu,"AWAKENING",show_awakening)
	build_awakening(layer)
	menu_button(menu,"SETTINGS",show_settings)
	build_settings(layer)
	collection = VBoxContainer.new()
	layer.add_child(collection)
	collection.position = Vector2(90,150)
	collection.add_theme_constant_override("separation",10)
	var collection_title := Label.new()
	collection_title.text = "HERO COLLECTION"
	collection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_title.add_theme_font_size_override("font_size",36)
	collection.add_child(collection_title)
	collection_balance = Label.new()
	collection_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_balance.add_theme_font_size_override("font_size",24)
	collection_balance.add_theme_color_override("font_color",Color("#f9c95b"))
	collection.add_child(collection_balance)
	for i in range(HEROES.size()):
		var card := menu_button(collection,"",select_hero.bind(i))
		card.custom_minimum_size = Vector2(540,112)
		card.add_theme_font_size_override("font_size",22)
		collection_buttons.append(card)
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
		btn.custom_minimum_size = Vector2(540,110)
		btn.add_theme_font_size_override("font_size",24)
		upgrades.add_child(btn)
		style_button(btn)
		btn.pressed.connect(choose_upgrade.bind(i))
	upgrades.hide()
	load_profile()
	load_settings()
	refresh_collection()
	update_hud()

func load_profile() -> void:
	owned = [0]
	selected = 0
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK or cfg.load(PROFILE_BACKUP) == OK:
		var gw: Variant = cfg.get_value("gates","wins",[])
		if gw is Array and gw.size() == 7:
			for i in range(7):
				gate_wins[i] = maxi(0,int(gw[i]))
		var qp: Variant = cfg.get_value("quests","progress",[0,0,0])
		var qt: Variant = cfg.get_value("quests","tiers",[0,0,0])
		for i in range(3):
			quest_progress[i] = clampi(int(qp[i]),0,1000000000) if qp is Array and qp.size() == 3 else 0
			quest_tiers[i] = clampi(int(qt[i]),0,1000) if qt is Array and qt.size() == 3 else 0
		hunter_level = clampi(int(cfg.get_value("awakening","level",1)),1,1000)
		hunter_xp = clampi(int(cfg.get_value("awakening","xp",0)),0,hunter_level*100-1)
		stat_points = clampi(int(cfg.get_value("awakening","points",0)),0,3000)
		var saved_stats: Variant = cfg.get_value("awakening","stats",[])
		if saved_stats is Array and saved_stats.size() == 5:
			for i in range(5):
				hunter_stats[i] = clampi(int(saved_stats[i]),0,3000)
		best = maxi(0,int(cfg.get_value("records","best",0)))
		credits = maxi(0,int(cfg.get_value("records","credits",0)))
		best_sprint = maxi(0,int(cfg.get_value("records","sprint",0)))
		runs = maxi(0,int(cfg.get_value("records","runs",0)))
		total_kills = maxi(0,int(cfg.get_value("records","kills",0)))
		var saved: Variant = cfg.get_value("collection","owned",[0])
		if saved is Array:
			for id in saved:
				if id is int and id >= 0 and id < HEROES.size() and not owned.has(id):
					owned.append(id)
		selected = int(cfg.get_value("collection","selected",0))
		if not owned.has(selected):
			selected = 0

func start() -> void:
	visual_stride = 0.0
	visual_lean = Vector2.ZERO
	visual_recoil = 0.0
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
	camera.position = hero.position + Vector3(0,19,15)
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
	attack_timer = 0
	finger = -1
	direction = Vector2.ZERO
	running = true
	menu_scrim.hide()
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

var visual_stride := 0.0
var visual_lean := Vector2.ZERO
var visual_recoil := 0.0
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
	var motion := move.length()
	visual_stride = lerpf(visual_stride,motion,1.0-exp(-12.0*dt))
	visual_lean = visual_lean.lerp(move*0.09,1.0-exp(-10.0*dt))
	visual_recoil = move_toward(visual_recoil,0.0,dt*0.8)
	var bob := -0.5+sin(elapsed*12.0)*0.065*visual_stride
	for child in hero.get_children():
		if child is Node3D:
			child.position.y = bob
			child.rotation.x = visual_lean.y+visual_recoil
			child.rotation.z = -visual_lean.x+sin(elapsed*6.0)*0.035*visual_stride
	hero.position += Vector3(move.x,0,move.y)*dt*(6.0+speed_bonus+(VEHICLE_SPEED[vehicle_kind] if vehicle_time > 0 else 0.0))
	hero.position.x = clampf(hero.position.x,-20,20)
	hero.position.z = clampf(hero.position.z,-20,20)
	camera.position = camera.position.lerp(hero.position + Vector3(0,19,15),1.0-exp(-10.0*dt))
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
		if randf() < 0.25:
			attach_art(enemy,"enemy_armored")
			enemy.set_meta("health",3)
			enemy.set_meta("speed",1.3)
			enemy.scale = Vector3.ONE*1.35
		elif randf() < 0.35:
			attach_art(enemy,"enemy_fast")
			enemy.set_meta("speed",3.8)
			enemy.scale = Vector3.ONE*0.7
		else:
			attach_art(enemy,"enemy")
		if mode == 2:
			enemy.set_meta("health",int(enemy.get_meta("health",1))+gate_rank)
		enemies.append(enemy)
	if elapsed >= 45 and not boss_spawned:
		boss_spawned = true
		var boss_mesh := BoxMesh.new()
		var boss := model(boss_mesh,Color("#a56bff"),Vector3(clampf(hero.position.x+9,-20,20),0.5,hero.position.z))
		var boss_kind := 1 if biome == 3 else (2 if biome == 4 else 0)
		attach_art(boss,["boss_overlord","boss_crystal","boss_inferno"][boss_kind])
		boss.scale = Vector3.ONE*1.35
		boss.set_meta("kind",boss_kind)
		boss.set_meta("next_pulse",elapsed+4.0)
		boss.set_meta("boss",true)
		boss.set_meta("health",24+boss_kind*6+(gate_rank*12 if mode == 2 else 0))
		boss.set_meta("speed",1.5)
		enemies.append(boss)
	var nearest: MeshInstance3D = null
	var distance := 4.0+level*0.3+reach
	for e in enemies:
		var offset: Vector3 = hero.position-e.position
		var d := offset.length()
		if d > 0.05:
			e.rotation.y = lerp_angle(e.rotation.y,atan2(offset.x,offset.z),1.0-exp(-9.0*dt))
		e.position += offset.normalized()*dt*(float(e.get_meta("speed",2.0))+minf(elapsed/90.0,2.0))
		if e.get_meta("boss",false):
			update_boss_attack(e)
		if d < 0.9*e.scale.x:
			hp -= dt*(24 if e.get_meta("boss",false) else 12)*(1.0-armor)
		if d < distance:
			distance = d
			nearest = e
	attack_timer -= dt
	if nearest != null and attack_timer <= 0:
		attack_timer = maxf(0.15,0.7-power*0.08-(VEHICLE_FIRE[vehicle_kind] if vehicle_time > 0 else 0.0))
		visual_recoil = 0.13
		var impact := nearest.position
		shot_tracer(hero.position+Vector3.UP*0.45,impact+Vector3.UP*0.2)
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
		var offset: Vector3 = hero.position-gem.position
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
	if hp <= 0 or (mode == 2 and (gate_cleared or elapsed >= 120.0)):
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
	if fps_elapsed >= 0.5:
		fps_elapsed = 0.0
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func update_hud() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	xp_bar.max_value = level*3
	xp_bar.value = xp
	hud.text = "ONE MORE\nSCORE %d  |  BEST %d\nHP %d  |  LV %d  |  %ds\nXP %d/%d  |  COMBO %d\nKILLS %d  |  CREDITS %d" % [score,best,maxi(0,int(hp)),level,int(elapsed),xp,level*3,combo,kills,credits]
