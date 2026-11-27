extends Node

const Landscape = preload("res://landscape.gd")
const ShotStyles = preload("res://shot_styles.gd")
const PROTOCOL := 6
const UPDATE_INTERVAL := 0.085
const LINK_TIMEOUT := 3.5
const ENEMY_ART := ["enemy","enemy_fast","enemy_armored","boss_overlord","boss_crystal","boss_inferno"]
const STATUS_TEXT := {
	"idle": "Сопрягите два телефона в настройках Bluetooth. На одном создайте забег, на другом выберите его в списке.",
	"unsupported": "Bluetooth-кооператив доступен на Android.",
	"permission": "Разрешите доступ к ближайшим устройствам.",
	"disabled": "Включите Bluetooth в настройках телефона.",
	"listening": "Ожидание второго игрока…",
	"connecting": "Подключение…",
	"connected": "Устройства соединены. Запуск забега…",
	"disconnected": "Соединение прервано.",
	"connection_failed": "Соединение не установлено. Проверьте сопряжение устройств.",
}

var arena
var link: Object
var hosting := false
var live := false
var linking := false
var hello_sent := false
var frame_time := 0.0
var silent_time := 0.0
var closing_time := 0.0
var partner: MeshInstance3D
var partner_hp := 0.0
var partner_max_hp := 0.0
var partner_hero := 0
var partner_move := Vector2.ZERO
var partner_attack := 0.0
var objects: Dictionary = {}
var targets: Dictionary = {}
var shot_events: Array = []
var shot_actors: Array[int] = []
var hit_events: Array = []
var lobby: VBoxContainer
var status_label: Label
var host_button: Button
var join_button: Button
var devices: OptionButton
var access_button: Button
var settings_button: Button
var host_choosing := false
var notice := ""
var last_status := ""

func configure(owner_arena, layer: CanvasLayer) -> void:
	arena = owner_arena
	if Engine.has_singleton("OneMoreBluetooth"):
		link = Engine.get_singleton("OneMoreBluetooth")
	lobby = VBoxContainer.new()
	lobby.position = Vector2(90,190)
	lobby.add_theme_constant_override("separation",13)
	layer.add_child(lobby)
	var title := Label.new()
	title.text = "КООПЕРАТИВ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",41)
	lobby.add_child(title)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(540,104)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size",24)
	lobby.add_child(status_label)
	host_button = arena.menu_button(lobby,"СОЗДАТЬ ЗАБЕГ",begin_host)
	devices = OptionButton.new()
	devices.custom_minimum_size = Vector2(540,65)
	devices.add_theme_font_size_override("font_size",22)
	lobby.add_child(devices)
	join_button = arena.menu_button(lobby,"ПОДКЛЮЧИТЬСЯ",begin_join)
	access_button = arena.menu_button(lobby,"РАЗРЕШИТЬ ДОСТУП",request_access)
	settings_button = arena.menu_button(lobby,"НАСТРОЙКИ BLUETOOTH",open_settings)
	arena.menu_button(lobby,"НАЗАД",leave_lobby)
	devices.item_selected.connect(func(_i: int): refresh_lobby())
	lobby.hide()
func open_lobby() -> void:
	notice = ""
	update_devices()
	refresh_lobby()
	lobby.show()

func native_status() -> String:
	return "unsupported" if link == null else str(link.status())

func refresh_lobby() -> void:
	var state := native_status()
	var ready := state in ["idle","disconnected","connection_failed"] and not linking
	status_label.text = notice if not notice.is_empty() else STATUS_TEXT.get(state,"Соединение недоступно.")
	host_button.disabled = not ready
	devices.disabled = not ready or devices.item_count == 0
	join_button.disabled = devices.disabled
	access_button.visible = state == "permission"
	settings_button.disabled = state == "unsupported" or linking

func update_devices() -> void:
	devices.clear()
	if link == null:
		return
	var info: Variant = JSON.parse_string(link.pairedDevices())
	if not info is Array:
		return
	for device in info:
		if device is Dictionary and device.get("address") is String and device.get("name") is String:
			devices.add_item(str(device["name"]).left(42))
			devices.set_item_metadata(devices.item_count-1,device["address"])
	if devices.item_count > 0:
		devices.select(0)

func request_access() -> void:
	if link != null:
		link.requestAccess()

func open_settings() -> void:
	if link != null:
		link.openSettings()

func begin_host() -> void:
	if link != null and link.host():
		begin_link(true)

func begin_join() -> void:
	if link != null and devices.selected >= 0 and link.connectTo(devices.get_item_metadata(devices.selected)):
		begin_link(false)

func begin_link(as_host: bool) -> void:
	closing_time = 0.0
	hosting = as_host
	linking = true
	hello_sent = false
	silent_time = 0.0
	notice = ""
	refresh_lobby()

func leave_lobby() -> void:
	shutdown()
	arena.show_menu()

func leave_match() -> void:
	if live:
		transmit({"type":"leave"})
		end_match("ВЫ ПОКИНУЛИ КООПЕРАТИВ")

func shutdown() -> void:
	if link != null:
		link.stop()
	linking = false
	live = false
	closing_time = 0.0
	clear_world()
	lobby.hide()

func _process(dt: float) -> void:
	if link == null:
		return
	if closing_time > 0.0:
		closing_time -= dt
		if closing_time <= 0.0:
			link.stop()
	if not linking and not live and not lobby.visible:
		return
	var state := native_status()
	if lobby.visible and last_status != state:
		last_status = state
		update_devices()
		refresh_lobby()
	if state != "connected":
		if live:
			end_match("СОЕДИНЕНИЕ ПРЕРВАНО")
		elif linking and state not in ["listening","connecting"]:
			linking = false
			refresh_lobby()
		return
	silent_time += dt
	if silent_time > LINK_TIMEOUT:
		if live:
			end_match("СОЕДИНЕНИЕ ПРЕРВАНО")
		elif linking:
			link.stop()
			linking = false
			notice = "Не удалось согласовать забег. Проверьте версии игры на обоих телефонах."
			refresh_lobby()
		return
	if linking and not hosting and not hello_sent:
		hello_sent = transmit({"type":"hello","version":PROTOCOL,"hero":arena.selected})
	for index in 24:
		var frame: String = link.poll()
		if frame.is_empty():
			break
		var message: Variant = JSON.parse_string(frame)
		if message is Dictionary:
			handle_message(message)
	if not live:
		return
	if not hosting:
		smooth_world(dt)
	frame_time += dt
	if frame_time >= UPDATE_INTERVAL:
		frame_time = 0.0
		if hosting:
			send_world()
		else:
			var move: Vector2 = arena.movement_input()
			transmit({"type":"input","move":[move.x,move.y]})

func partner_status() -> String:
	if not hosting and host_choosing:
		return "ВЕДУЩИЙ ВЫБИРАЕТ УСИЛЕНИЕ"
	var status := "НАПАРНИК  %d / %d" % [maxi(0,int(partner_hp)),int(partner_max_hp)]
	return status if arena.hp > 0.0 else "ВЫ ВЫБЫЛИ  ·  "+status

func transmit(data: Dictionary) -> bool:
	return link != null and link.send(JSON.stringify(data))

func handle_message(data: Dictionary) -> void:
	match data.get("type"):
		"hello":
			if linking and hosting and data.get("version") == PROTOCOL:
				var peer_hero := clampi(int(number(data.get("hero"))),0,arena.HEROES.size()-1)
				if transmit({"type":"start","version":PROTOCOL,"hero":arena.selected,"map":arena.biome}):
					start_match(peer_hero)
		"start":
			if linking and not hosting and data.get("version") == PROTOCOL:
				var map := clampi(int(number(data.get("map"))),0,arena.BIOMES.size()-1)
				arena.set_biome(map)
				start_match(clampi(int(number(data.get("hero"))),0,arena.HEROES.size()-1))
		"input":
			var move: Variant = data.get("move")
			if live and hosting and move is Array and move.size() == 2:
				partner_move = Vector2(clampf(number(move[0]),-1,1),clampf(number(move[1]),-1,1)).limit_length()
				silent_time = 0.0
		"state":
			if live and not hosting and apply_world(data):
				silent_time = 0.0
		"leave":
			if live:
				end_match("НАПАРНИК ПОКИНУЛ ЗАБЕГ")
		"end":
			if live and not hosting:
				arena.score = clampi(int(number(data.get("score"))),0,1000000000)
				end_match("СОВМЕСТНЫЙ ЗАБЕГ ЗАВЕРШЁН")

func number(value: Variant) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else 0.0

func start_match(peer_hero: int) -> void:
	clear_world()
	live = true
	host_choosing = false
	linking = false
	frame_time = UPDATE_INTERVAL
	silent_time = 0.0
	partner_move = Vector2.ZERO
	partner_attack = 0.0
	partner_hero = peer_hero
	partner_max_hp = float(arena.HEROES[partner_hero][3])
	partner_hp = partner_max_hp
	lobby.hide()
	arena.start(hosting)
	partner = arena.model(SphereMesh.new(),Color(arena.PALETTE[partner_hero]),Vector3(1.6,0.5,0))
	arena.attach_art(partner,arena.HERO_ART[partner_hero])
	arena.seat_actor(partner)
	arena.add_contact_shadow(partner,1.9)

func end_match(reason: String) -> void:
	live = false
	linking = false
	closing_time = 0.4
	clear_world()
	arena.display_coop_result(reason)

func finish_host() -> void:
	transmit({"type":"end","score":arena.score})
	end_match("СОВМЕСТНЫЙ ЗАБЕГ ЗАВЕРШЁН")

func clear_world() -> void:
	if is_instance_valid(partner):
		partner.queue_free()
	partner = null
	for object in objects.values():
		object.queue_free()
	objects.clear()
	targets.clear()
	shot_events.clear()
	shot_actors.clear()
	hit_events.clear()

func live_partner() -> MeshInstance3D:
	return partner if live and hosting and partner_hp > 0.0 else null

func target_for(position: Vector3) -> MeshInstance3D:
	var peer := live_partner()
	if peer != null and (arena.hp <= 0.0 or Landscape.xz(position).distance_squared_to(Landscape.xz(peer.position)) < Landscape.xz(position).distance_squared_to(Landscape.xz(arena.hero.position))):
		return peer
	return arena.hero

func tick_partner(dt: float) -> void:
	var peer := live_partner()
	if peer == null:
		return
	var speed: float = 6.0+float(arena.HEROES[partner_hero][4])
	if partner_move.length_squared() > 0.0025:
		peer.rotation.y = lerp_angle(peer.rotation.y,atan2(partner_move.x,partner_move.y),1.0-exp(-12.0*dt))
	peer.position += Vector3(partner_move.x,0,partner_move.y)*dt*speed
	peer.position = Landscape.keep_inside(peer.position,Landscape.PLAY_HALF)
	arena.seat_actor(peer)
	partner_attack -= dt
	if partner_attack > 0.0:
		return
	var nearest: MeshInstance3D
	var range_squared: float = pow(arena.attack_distance(),2.0)
	for enemy in arena.enemies:
		var distance: float = Landscape.xz(peer.position).distance_squared_to(Landscape.xz(enemy.position))
		if distance < range_squared:
			range_squared = distance
			nearest = enemy
	if nearest != null:
		partner_attack = maxf(0.15,0.7-arena.power*0.08)
		arena.fire_visual(peer,nearest.position+Vector3.UP*0.2)
		arena.hit_enemy(nearest,peer)

func damage_partner(position: Vector3, radius: float, amount: float) -> void:
	var peer := live_partner()
	if peer != null and Landscape.xz(peer.position).distance_squared_to(Landscape.xz(position)) < radius*radius:
		partner_hp = maxf(0.0,partner_hp-amount)
		peer.visible = partner_hp > 0.0
		if amount > 0.0:
			if partner_hp > 0.0 or not arena.play_defeat(peer):
				arena.show_actor_hit(peer,position)

func record_shot(from: Vector3,to: Vector3,shooter: Node3D,style: int) -> void:
	if live and hosting and shot_events.size() < 12:
		shot_events.append([from.x,from.y,from.z,to.x,to.y,to.z,style])
		shot_actors.append(0 if shooter == arena.hero else (1 if shooter == partner else -1))

func record_hit(actor: Node3D,origin: Vector3,fatal: bool) -> void:
	if live and hosting and hit_events.size() < 24:
		hit_events.append([actor.get_instance_id(),fatal,origin.x,origin.z])

func player_row(player: Node3D,hp: float,maximum: float) -> Array:
	return [player.position.x,player.position.z,player.rotation.y,maxf(0,hp),maximum,player.scale.x]

func send_world() -> void:
	var actors: Array = []
	var bosses: Dictionary = {}
	for enemy in arena.enemies:
		actors.append([enemy.get_instance_id(),enemy.get_meta("model_asset","enemy"),enemy.position.x,enemy.position.z,enemy.rotation.y,enemy.scale.x,enemy.has_meta("warning_ring")])
		if enemy.get_meta("boss",false):
			bosses[str(enemy.get_instance_id())] = [enemy.get_meta("health",1),enemy.get_meta("max_health",1)]
	for crate in arena.crates:
		actors.append([crate.get_instance_id(),"crate",crate.position.x,crate.position.z,0,1,false])
	var gems := 0
	for gem in arena.gems:
		if gems >= 160 or actors.size() >= 318:
			break
		if Landscape.xz(partner.position).distance_squared_to(Landscape.xz(gem.position)) < 225.0:
			actors.append([gem.get_instance_id(),"gem",gem.position.x,gem.position.z,0,1,false])
			gems += 1
	if is_instance_valid(arena.vehicle) and not arena.vehicle.is_queued_for_deletion() and arena.vehicle.visible:
		var vehicle: MeshInstance3D = arena.vehicle
		actors.append([vehicle.get_instance_id(),arena.VEHICLES[arena.vehicle_kind],vehicle.position.x,vehicle.position.z,vehicle.rotation.y,1,false])
	var upgrade_levels: Array[int] = []
	for id in arena.ability_rank_ids():
		upgrade_levels.append(int(arena.ranks.get(id,0)))
	if transmit({
		"type":"state","players":[player_row(arena.hero,arena.hp,arena.max_hp),player_row(partner,partner_hp,partner_max_hp)],
		"actors":actors,"shots":shot_events,"round":[arena.elapsed,arena.score,arena.level,arena.xp,arena.combo,arena.kills,arena.choosing],
		"shot_actors":shot_actors,"hits":hit_events,
		"hud":[arena.run_pickups,arena.damage,arena.reach,upgrade_levels,arena.magnet],"bosses":bosses,
	}):
		shot_events.clear()
		shot_actors.clear()
		hit_events.clear()

func apply_world(data: Dictionary) -> bool:
	var players: Variant = data.get("players")
	var actors: Variant = data.get("actors")
	var round_state: Variant = data.get("round")
	if not players is Array or players.size() != 2 or not actors is Array or actors.size() > 320 or not round_state is Array or round_state.size() != 7:
		return false
	for row in players:
		if not row is Array or row.size() != 6:
			return false
	update_player(partner,players[0])
	update_player(arena.hero,players[1])
	var guest_health := clampf(number(players[1][3]),0,20000)
	var host_health := clampf(number(players[0][3]),0,20000)
	if guest_health < arena.hp and (guest_health > 0.0 or not arena.play_defeat(arena.hero)):
		arena.show_actor_hit(arena.hero,arena.hero.position+arena.hero.transform.basis.z)
	if host_health < partner_hp and (host_health > 0.0 or not arena.play_defeat(partner)):
		arena.show_actor_hit(partner,partner.position+partner.transform.basis.z)
	arena.hp = guest_health
	partner_hp = host_health
	arena.max_hp = clampf(number(players[1][4]),1,20000)
	arena.elapsed = clampf(number(round_state[0]),0,86400)
	arena.score = clampi(int(number(round_state[1])),0,1000000000)
	arena.level = clampi(int(number(round_state[2])),1,1000)
	arena.xp = clampi(int(number(round_state[3])),0,3000)
	arena.combo = clampi(int(number(round_state[4])),0,20)
	arena.kills = clampi(int(number(round_state[5])),0,1000000)
	host_choosing = round_state[6] == true
	apply_hud(data.get("hud"))
	# A defeated replica still exists until the actor list below is reconciled.
	apply_hits(data.get("hits"))
	sync_actors(actors)
	apply_boss_health(data.get("bosses"))
	play_shots(data.get("shots"),data.get("shot_actors"))
	return true

func apply_boss_health(bosses: Variant) -> void:
	if not bosses is Dictionary or bosses.size() > 3:
		return
	for key in bosses:
		if not key is String or not key.is_valid_int():
			continue
		var actor := objects.get(key.to_int()) as MeshInstance3D
		var values: Variant = bosses[key]
		if actor == null or not str(actor.get_meta("model_asset","")).begins_with("boss_") or not values is Array or values.size() != 2:
			continue
		actor.set_meta("max_health",clampi(int(number(values[1])),1,1000))
		actor.set_meta("health",clampi(int(number(values[0])),0,int(actor.get_meta("max_health"))))

func apply_hud(data: Variant) -> void:
	var rank_ids: Array = arena.ability_rank_ids()
	if not data is Array or data.size() < 4 or not data[3] is Array or data[3].size() != rank_ids.size():
		return
	arena.run_pickups = clampi(int(number(data[0])),0,1000000)
	arena.damage = clampi(int(number(data[1])),1,1000000)
	arena.reach = clampf(number(data[2]),0,1000)
	if data.size() >= 5:
		arena.magnet = clampf(number(data[4]),0,1000)
	# Guest contact damage is calculated by the host without the host's personal armor.
	arena.armor = 0.0
	arena.ranks.clear()
	for i in rank_ids.size():
		var rank := clampi(int(number(data[3][i])),0,1000)
		if rank > 0:
			arena.ranks[rank_ids[i]] = rank

func apply_hits(hits: Variant) -> void:
	if not hits is Array or hits.size() > 24:
		return
	for row in hits:
		if not row is Array or row.size() != 4 or not row[1] is bool:
			continue
		var id := int(clampf(number(row[0]),1,9007199254740991.0))
		var actor := objects.get(id) as MeshInstance3D
		if actor != null:
			var origin := Vector3(clampf(number(row[2]),-Landscape.SPAWN_HALF,Landscape.SPAWN_HALF),0.5,clampf(number(row[3]),-Landscape.SPAWN_HALF,Landscape.SPAWN_HALF))
			arena.show_actor_hit(actor,origin,row[1])

func play_shots(shots: Variant, shooters: Variant) -> void:
	if not shots is Array or shots.size() > 12:
		return
	var has_shooters: bool = shooters is Array and shooters.size() == shots.size()
	for index in shots.size():
		var row: Variant = shots[index]
		if not row is Array or row.size() != 7:
			continue
		var from := Vector3(clampf(number(row[0]),-Landscape.FLOOR_HALF,Landscape.FLOOR_HALF),clampf(number(row[1]),-5,12),clampf(number(row[2]),-Landscape.FLOOR_HALF,Landscape.FLOOR_HALF))
		var to := Vector3(clampf(number(row[3]),-Landscape.FLOOR_HALF,Landscape.FLOOR_HALF),clampf(number(row[4]),-5,12),clampf(number(row[5]),-Landscape.FLOOR_HALF,Landscape.FLOOR_HALF))
		var style := ShotStyles.validated(int(number(row[6])))
		var role: Variant = shooters[index] if has_shooters else null
		if role == 0 or role == 1:
			arena.fire_visual(partner if role == 0 else arena.hero,to,from,style)
		else:
			arena.shot_tracer(from,to,null,style)

func update_player(player: MeshInstance3D,row: Array) -> void:
	var scale_factor := clampf(number(row[5]),0.5,3.0)
	targets[player] = Vector4(clampf(number(row[0]),-Landscape.PLAY_HALF,Landscape.PLAY_HALF),0.5,clampf(number(row[1]),-Landscape.PLAY_HALF,Landscape.PLAY_HALF),clampf(number(row[2]),-TAU,TAU))
	player.scale = Vector3.ONE * scale_factor
	player.visible = number(row[3]) > 0.0

func sync_actors(actors: Array) -> void:
	var visible_ids: Dictionary = {}
	for row in actors:
		if not row is Array or row.size() != 7 or not row[1] is String:
			continue
		var art: String = row[1]
		if art not in ENEMY_ART and art not in ["crate","gem"] and art not in arena.VEHICLES:
			continue
		var id := int(clampf(number(row[0]),1,9007199254740991.0))
		var y := 0.3 if art == "gem" else 0.5
		var position := Vector3(clampf(number(row[2]),-Landscape.SPAWN_HALF,Landscape.SPAWN_HALF),y,clampf(number(row[3]),-Landscape.SPAWN_HALF,Landscape.SPAWN_HALF))
		if not objects.has(id):
			objects[id] = arena.create_coop_visual(art,position)
		var actor := objects[id] as MeshInstance3D
		actor.scale = Vector3.ONE * clampf(number(row[5]),0.5,3.0)
		targets[actor] = Vector4(position.x,position.y,position.z,clampf(number(row[4]),-TAU,TAU))
		if art.begins_with("boss_"):
			if row[6] == true:
				arena.render_boss_warning(actor,3.0+ENEMY_ART.find(art)-3)
			else:
				arena.clear_boss_warning(actor)
		visible_ids[id] = true
	for id in objects.keys():
		if not visible_ids.has(id):
			var actor: MeshInstance3D = objects[id]
			targets.erase(actor)
			actor.queue_free()
			objects.erase(id)

func smooth_world(dt: float) -> void:
	var blend := 1.0-exp(-18.0*dt)
	for actor in targets:
		var pose: Vector4 = targets[actor]
		var next: Vector3 = actor.position.lerp(Vector3(pose.x,pose.y,pose.z),blend)
		var lift: float = 0.3 if actor.get_meta("model_asset","") == "gem" else 0.5*actor.scale.y
		actor.position = arena.grounded(next,lift)
		actor.rotation.y = lerp_angle(actor.rotation.y,pose.w,blend)
	arena.follow_player_camera(dt)
