extends Control

const GOLD := Color("#ffbb54")
const STEEL := Color("#9fb7ca")
const TEXT := Color("#f1f4f6")
const SOFT := Color("#b1c3cf")
const BLUE := Color("#79dcff")
const GREEN := Color("#91ec77")
const RED := Color("#ff7667")
const MODES := ["БЕСКОНЕЧНЫЙ","НА ВРЕМЯ","ВРАТА"]
const BOSSES := {"boss_overlord":"ВЛАДЫКА","boss_crystal":"ЛЕДЯНОЙ ГОЛЕМ","boss_inferno":"ПЛАВИЛЬЩИК"}
const TASKS := ["Победить врагов","Завершить забеги","Набрать очки"]
const KIT_ART := [0,1,2,5]
const KIT_NAMES := ["КАРАБИН","БОЕВЫЕ БОТИНКИ","МАГНИТ","БРОНЕПЛАСТИНЫ"]
const GLYPHS := ["ϟ","↑","∩","✦","⊕","◇","⌖","+","◇","♦","ϟ","↑","∩","ϟ","✦","◇"]

class Plate extends Control:
	var border: Color
	var cut: float
	var flash := 0.0:
		set(value):
			flash = value
			queue_redraw()

	func outline(inset: float) -> PackedVector2Array:
		var x := size.x-inset
		var y := size.y-inset
		var bevel := maxf(2.0,cut-inset*0.54)
		return PackedVector2Array([
			Vector2(inset+bevel,inset),Vector2(x-bevel,inset),Vector2(x,inset+bevel),Vector2(x,y-bevel),
			Vector2(x-bevel,y),Vector2(inset+bevel,y),Vector2(inset,y-bevel),Vector2(inset,inset+bevel)
		])

	func _draw() -> void:
		var shape := outline(0)
		var bright := border.lightened(flash*0.4)
		draw_polygon(shape,PackedColorArray([
			Color("#485665"),Color("#263440"),Color("#121b24"),Color("#141b25"),
			Color("#243140"),Color("#182230"),Color("#0a1119"),Color("#364653")
		]))
		var inside := outline(4)
		draw_polygon(inside,PackedColorArray([
			Color("#182936ef"),Color("#101923f5"),Color("#0c141df5"),Color("#111d29f0"),
			Color("#162735f3"),Color("#0c141bec"),Color("#0c131bec"),Color("#1d2c38ef")
		]))
		shape.append(shape[0])
		inside.append(inside[0])
		draw_polyline(shape,Color(bright,0.68+flash*0.26),1.3,true)
		draw_polyline(inside,Color(bright,0.36+flash*0.40),1.0,true)
		if size.x > 94 and size.y > 35:
			draw_line(Vector2(cut,1),Vector2(size.x*0.48,1),Color(bright,0.68),2,true)
			draw_line(Vector2(size.x*0.56,size.y-2),Vector2(size.x-cut+1,size.y-2),Color(bright,0.57),1.5,true)
			draw_line(Vector2(size.x*0.54,size.y-5),Vector2(size.x-cut,size.y-5),Color("#60c7fe1a"),2,true)

class StickGuide extends Control:
	func _draw() -> void:
		var middle := size*0.5
		var radius := size.x*0.5
		draw_arc(middle,radius-6,0,TAU,48,Color("#889daf88"),1.5,true)
		draw_arc(middle,radius-4,PI*.07,PI*.49,18,Color("#ffb651c4"),3,true)
		draw_arc(middle,radius-4,PI*1.08,PI*1.52,18,Color("#708ea7b6"),2,true)
		for i in 4:
			var forward := Vector2.from_angle(i*TAU/4)
			var side := forward.orthogonal()
			var p := middle+forward*(radius-18)
			draw_colored_polygon(PackedVector2Array([p+forward*7,p-forward*4+side*7,p-forward*4-side*7]),Color("#afc0caaa"))

class Reticle extends Control:
	var active := false
	var sweep := 0.0

	func _ready() -> void:
		set_process(false)

	func _process(dt: float) -> void:
		if is_visible_in_tree():
			sweep = fposmod(sweep+dt*2.4,TAU)
			queue_redraw()

	func _draw() -> void:
		var center := size*0.5
		draw_circle(center,50,Color("#171b24ed") if not active else Color("#3d2a18ed"),true,-1,true)
		draw_circle(center,49,Color("#7c643e"),false,2,true)
		draw_arc(center,48,0.0,PI*0.92,26,Color("#ffb652"),3,true)
		draw_arc(center,48,PI,PI*1.53,18,Color("#6d7e8e"),2,true)
		draw_circle(center,23,Color("#ffb95335"),false,7,true)
		draw_circle(center,21,Color("#ffbf5a"),false,2,true)
		draw_circle(center,3,Color("#ffffff"),true,-1,true)
		if active:
			draw_arc(center,43,sweep,sweep+0.54,12,Color("#fff0b1"),3,true)
		for i in 4:
			var axis := Vector2.from_angle(i*PI/2)
			draw_line(center+axis*14,center+axis*28,Color("#ffeac2"),3,true)

class Radar extends Control:
	var arena
	var zoom := false
	var zoom_blend := 0.0:
		set(value):
			zoom_blend = value
			queue_redraw()

	func project_point(world: Vector3, focus: Vector3, radius: float) -> Vector2:
		return size*0.5+Vector2(world.x-focus.x,world.z-focus.z)/radius*(size.x*0.5-9.0)

	func marker(actor: Node3D, kind: String, focus: Vector3, radius: float) -> void:
		var p := project_point(actor.position,focus,radius)
		if not Rect2(Vector2(6,6),size-Vector2(12,12)).has_point(p):
			return
		match kind:
			"boss":
				draw_circle(p,5.5,Color("#ff7953"),false,2,true)
			"peer":
				draw_circle(p,4,Color("#79dcff"),true,-1,true)
			"gem":
				draw_circle(p,1.8,Color("#bd9bff"),true,-1,true)
			"crate":
				draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color("#c3a064"),false,1)
			_:
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-3),p+Vector2(3,0),p+Vector2(0,3),p+Vector2(-3,0)]),Color("#ff705d"))

	func _draw() -> void:
		if not is_instance_valid(arena.hero):
			return
		var focus: Vector3 = Vector3.ZERO.lerp(arena.hero.position,zoom_blend)
		var radius := lerpf(23.0,11.0,zoom_blend)
		var top_left := project_point(Vector3(-23,0,-23),focus,radius)
		var bottom_right := project_point(Vector3(23,0,23),focus,radius)
		var map_rect := Rect2(top_left,bottom_right-top_left)
		if is_instance_valid(arena.map_viewport):
			draw_texture_rect(arena.map_viewport.get_texture(),map_rect,false,Color("#82a3a9"))
		var grid := Color(0.72,0.95,0.92,0.16)
		for i in range(1,6):
			var offset := size.x*i/6.0
			draw_line(Vector2(offset,7),Vector2(offset,size.y-7),grid,1)
			draw_line(Vector2(7,offset),Vector2(size.x-7,offset),grid,1)
		if arena.coop.live and not arena.coop.hosting:
			for actor in arena.coop.objects.values():
				var asset := str(actor.get_meta("model_asset",""))
				if asset in ["gem","crate"]:
					marker(actor,asset,focus,radius)
				elif asset.begins_with("enemy") or asset.begins_with("boss_"):
					marker(actor,"boss" if asset.begins_with("boss_") else "enemy",focus,radius)
		else:
			for enemy in arena.enemies:
				marker(enemy,"boss" if enemy.get_meta("boss",false) else "enemy",focus,radius)
			for crate in arena.crates:
				marker(crate,"crate",focus,radius)
			for i in mini(64,arena.gems.size()):
				marker(arena.gems[i],"gem",focus,radius)
		if arena.coop.live and is_instance_valid(arena.coop.partner) and arena.coop.partner_hp > 0:
			marker(arena.coop.partner,"peer",focus,radius)
		var p := project_point(arena.hero.position,focus,radius)
		var forward := Vector2(sin(arena.hero.rotation.y),cos(arena.hero.rotation.y))
		var side := forward.orthogonal()
		var player := Color("#91ec77") if arena.hp > 0 else Color("#a0a8ad")
		draw_circle(p,9,Color(player,0.22),true,-1,true)
		draw_colored_polygon(PackedVector2Array([p+forward*8,p-forward*4+side*4,p-forward*2,p-forward*4-side*4]),player)

var arena
var fps: Label
var score_panel: Plate
var xp_frame: Plate
var operator_frame: Plate
var score_flash: Tween
var damage_flash: Tween
var experience_flash: Tween
var level_pop: Tween
var map_motion: Tween
var objective_motion: Tween
var pause_motion: Tween
var badge: Label
var last_score := -1
var last_hp := -1.0
var last_pickups := -1
var last_level := -1
var textures: Dictionary = {}
var clock: Label
var context: Label
var level_label: Label
var counters: Array[Label] = []
var boss_frame: Plate
var boss_name: Label
var boss_health: ProgressBar
var task_toggle: Button
var tasks: Control
var task_text: Array[Label] = []
var radar: Radar
var radar_frame: Control
var zoom_button: Button
var range_button: Button
var hero_name: Label
var hero_badge: TextureRect
var portrait_id := -1
var hero_stats: Label
var status_text: Label
var slots: Array[Button] = []
var slot_icons: Array[Label] = []
var slot_frames: Array[Plate] = []
var slot_art: Array[TextureRect] = []
var slot_ranks: Array[Label] = []
var stat_card: Plate
var kills_label: Label
var record_label: Label
var ability_page := 0
var page_button: Button
var active_abilities: Array[int] = []
var inspected := -1
var inspected_slot := -1
var health_text: Label
var xp_text: Label
var health: ProgressBar
var xp: ProgressBar
var bottom_xp: ProgressBar
var overlay: ColorRect
var pause_modal: Plate
var pause_title: Label
var pause_hint: Label
var exit_button: Button
var touch_blocks: Array[Control] = []

func configure(owner_arena) -> void:
	arena = owner_arena
	size = Vector2(720,1280)
	mouse_filter = MOUSE_FILTER_IGNORE
	var top := plate(self,Rect2(12,12,696,52),STEEL,13)
	button(top,Rect2(2,2,58,48),"Ⅱ","Меню забега",arena.toggle_hud_pause)
	button(top,Rect2(62,2,58,48),"⚙","Настройки",arena.open_hud_settings)
	display(top,Rect2(132,0,168,52),"ONE MORE",26,Color("#ffeed3"))
	var timer := plate(top,Rect2(304,0,101,52),GOLD)
	clock = display(timer,Rect2(0,0,101,52),"00:00",24,TEXT,true)
	context = display(top,Rect2(409,0,198,52),"",16,SOFT,true)
	fps = display(top,Rect2(607,0,78,52),"",15,GREEN,true)
	touch_blocks.append(top)

	var rank := plate(self,Rect2(12,76,226,66),GOLD)
	xp_frame = rank
	picture(rank,Rect2(9,7,44,48)).texture = art_texture(13)
	level_label = display(rank,Rect2(62,4,156,30),"",20,TEXT)
	xp = meter(rank,Rect2(62,43,149,9),GOLD)
	touch_blocks.append(rank)

	var count_frame := plate(self,Rect2(519,76,189,106),GOLD)
	score_panel = count_frame
	for i in 3:
		var art := picture(count_frame,Rect2(9,4+i*33,31,31))
		art.texture = art_texture([9,2,3][i])
		var tint: Color = [GOLD,BLUE,Color("#ffb47a")][i]
		counters.append(display(count_frame,Rect2(43,4+i*33,140,30),"",17,tint))
	touch_blocks.append(count_frame)

	boss_frame = plate(self,Rect2(486,190,222,54),Color("#ab5347"))
	boss_name = display(boss_frame,Rect2(8,2,206,25),"",15,TEXT,true)
	boss_health = meter(boss_frame,Rect2(12,33,198,9),RED)
	boss_frame.hide()

	var task_frame := plate(self,Rect2(12,152,226,38),GOLD)
	task_toggle = button(task_frame,Rect2(0,0,226,38),"","Свернуть или открыть задания",Callable())
	task_toggle.toggle_mode = true
	task_toggle.add_theme_font_size_override("font_size",17)
	tasks = plate(self,Rect2(12,192,226,88),STEEL)
	for i in TASKS.size():
		task_text.append(display(tasks,Rect2(9,4+i*26,208,25),"",14,TEXT))
	touch_blocks.append(tasks)

	radar_frame = plate(self,Rect2(12,292,150,168),STEEL)
	radar = Radar.new()
	radar.arena = arena
	radar.clip_contents = true
	place(radar_frame,radar,Rect2(4,4,142,142))
	display(radar_frame,Rect2(12,143,82,22),"КАРТА",13,SOFT)
	zoom_button = button(radar_frame,Rect2(102,124,44,40),"+","Приблизить карту",toggle_radar)
	touch_blocks.append(radar_frame)
	task_toggle.toggled.connect(toggle_tasks)
	task_toggle.set_pressed_no_signal(true)

	var right := Control.new()
	place(self,right,Rect2(581,946,127,136))
	var aiming := Reticle.new()
	place(right,aiming,Rect2(10,0,106,106))
	range_button = button(right,Rect2(10,0,106,106),"","Показать дальность автоогня",arena.toggle_attack_range)
	range_button.toggle_mode = true
	for state in ["normal","hover","pressed","hover_pressed"]:
		range_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	range_button.toggled.connect(func(active: bool):
		aiming.active = active
		aiming.set_process(active)
		aiming.queue_redraw()
	)
	var range_caption := plate(right,Rect2(5,106,117,26),STEEL,8)
	display(range_caption,Rect2(0,0,117,26),"ДАЛЬНОСТЬ",14,TEXT,true)

	var bottom := plate(self,Rect2(12,1108,696,160),STEEL,15)
	touch_blocks.append(bottom)
	var operator := plate(bottom,Rect2(7,8,211,144),GOLD)
	operator_frame = operator
	var portrait_frame := plate(operator,Rect2(6,7,68,76),GOLD,8)
	hero_badge = picture(portrait_frame,Rect2(3,3,62,69))
	hero_name = display(operator,Rect2(10,88,191,47),"",18,TEXT)
	hero_stats = display(operator,Rect2(75,8,130,77),"",15,SOFT)
	for i in 4:
		var slot := plate(bottom,Rect2(227+i*76,8,69,60),GOLD)
		slot_frames.append(slot)
		slot_art.append(picture(slot,Rect2(4,4,61,52)))
		var face := button(slot,Rect2(0,0,69,60),"","",inspect_ability.bind(i))
		for state in ["normal","hover","pressed","disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color.TRANSPARENT if state == "normal" else Color("#dbeaff18")
			box.set_corner_radius_all(7)
			face.add_theme_stylebox_override(state,box)
		slots.append(face)
		slot_icons.append(display(slot,Rect2(6,5,57,48),"",31,GOLD,true))
		var pip := plate(slot,Rect2(45,36,18,20),GOLD,4)
		slot_ranks.append(display(pip,Rect2(0,-1,18,20),"",12,TEXT,true))
	stat_card = plate(bottom,Rect2(536,8,143,60),STEEL)
	kills_label = display(stat_card,Rect2(6,2,131,27),"",15,GOLD,true)
	record_label = display(stat_card,Rect2(6,28,131,27),"",14,SOFT,true)
	page_button = button(bottom,Rect2(536,8,143,60),"","Другие усиления",next_ability_page)
	page_button.add_theme_font_size_override("font_size",15)
	status_text = display(bottom,Rect2(228,68,451,20),"",15,SOFT)
	health = meter(bottom,Rect2(228,95,454,22),GREEN)
	health_text = display(bottom,Rect2(228,95,454,22),"",16,TEXT,true)
	xp_text = display(bottom,Rect2(228,119,454,23),"",16,BLUE,true)
	bottom_xp = meter(bottom,Rect2(228,145,454,5),BLUE)
	badge = display(self,Rect2(241,244,236,39),"",20,GOLD,true)
	badge.hide()
	build_pause()

func build_pause() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.02,0.035,0.055,0.82)
	overlay.size = size
	add_child(overlay)
	var modal := plate(overlay,Rect2(110,400,500,428),GOLD,24)
	pause_modal = modal
	modal.pivot_offset = modal.size*0.5
	pause_title = display(modal,Rect2(20,29,460,42),"ПАУЗА",32,TEXT,true)
	pause_hint = display(modal,Rect2(20,78,460,38),"",17,SOFT,true)
	button(modal,Rect2(40,142,420,65),"ПРОДОЛЖИТЬ","Вернуться в бой",arena.toggle_hud_pause)
	button(modal,Rect2(40,224,420,65),"НАСТРОЙКИ","Настройки игры",arena.open_hud_settings)
	exit_button = button(modal,Rect2(40,306,420,65),"","Выйти из боя",arena.exit_hud_run)
	overlay.hide()

func place(parent: Control, child: Control, rect: Rect2) -> void:
	child.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size

func plate(parent: Control, rect: Rect2, tint: Color, cut := 10.0) -> Plate:
	var panel := Plate.new()
	panel.border = tint
	panel.cut = cut
	place(parent,panel,rect)
	return panel

func display(parent: Control, rect: Rect2, title: String, font_size: int, tint: Color, centered := false) -> Label:
	var item := Label.new()
	item.text = title
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",tint)
	item.add_theme_color_override("font_shadow_color",Color("#05080b"))
	item.add_theme_constant_override("shadow_offset_y",1)
	place(parent,item,rect)
	return item

func picture(parent: Control, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = TEXTURE_FILTER_LINEAR
	place(parent,image,rect)
	return image

func art_texture(id: int) -> Texture2D:
	if not textures.has(id):
		var path := "res://assets/hud/%02d.webp" % id
		textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[id] as Texture2D

func button(parent: Control, rect: Rect2, title: String, tip: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = title
	item.tooltip_text = tip
	item.focus_mode = FOCUS_NONE
	item.add_theme_font_size_override("font_size",22)
	item.add_theme_color_override("font_color",TEXT)
	for state in ["normal","hover","pressed","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal":Color("#23334671"),"hover":Color("#ac743c62"),"pressed":Color("#bb773c96"),"disabled":Color("#0d141d90")}[state]
		box.border_color = GOLD if state == "pressed" else Color("#516474")
		box.border_width_bottom = 1
		box.set_corner_radius_all(7)
		item.add_theme_stylebox_override(state,box)
	place(parent,item,rect)
	item.mouse_filter = MOUSE_FILTER_STOP
	if action.is_valid():
		item.pressed.connect(action)
	touch_blocks.append(item)
	return item

func meter(parent: Control, rect: Rect2, tint: Color) -> ProgressBar:
	var item := ProgressBar.new()
	item.show_percentage = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#050b13")
	box.border_color = Color("#465b6f")
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.set_corner_radius_all(3)
	item.add_theme_stylebox_override("background",box)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.12,0.55,1.0])
	gradient.colors = PackedColorArray([tint.lightened(0.4),tint,tint.darkened(0.43),tint.darkened(0.20)])
	var stripe := GradientTexture2D.new()
	stripe.gradient = gradient
	stripe.width = 4
	stripe.height = 24
	stripe.fill_to = Vector2(0,1)
	var fill := StyleBoxTexture.new()
	fill.texture = stripe
	item.add_theme_stylebox_override("fill",fill)
	place(parent,item,rect)
	return item

func toggle_tasks(expanded: bool) -> void:
	if objective_motion != null:
		objective_motion.kill()
	tasks.visible = expanded
	radar_frame.position.y = 292 if expanded else 204
	if expanded:
		tasks.modulate.a = 0.07
		objective_motion = create_tween()
		objective_motion.tween_property(tasks,"modulate:a",1.0,0.23).set_trans(Tween.TRANS_CUBIC)
	refresh_tasks()

func toggle_radar() -> void:
	radar.zoom = not radar.zoom
	zoom_button.text = "−" if radar.zoom else "+"
	zoom_button.tooltip_text = "Вся арена" if radar.zoom else "Приблизить карту"
	if map_motion != null:
		map_motion.kill()
	map_motion = create_tween()
	map_motion.tween_property(radar,"zoom_blend",1.0 if radar.zoom else 0.0,0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func blocks_at(point: Vector2) -> bool:
	for panel in touch_blocks:
		if panel.is_visible_in_tree() and Rect2(Vector2.ZERO,panel.size).has_point(panel.get_global_transform_with_canvas().affine_inverse()*point):
			return true
	return false

func set_paused(paused: bool) -> void:
	if pause_motion != null:
		pause_motion.kill()
	overlay.visible = paused
	if paused:
		overlay.modulate.a = 0.18
		pause_modal.scale = Vector2.ONE*0.92
		pause_motion = create_tween().set_parallel()
		pause_motion.tween_property(overlay,"modulate:a",1.0,0.18)
		pause_motion.tween_property(pause_modal,"scale",Vector2.ONE,0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pause_title.text = "МЕНЮ ЗАБЕГА" if arena.coop.live else "ПАУЗА"
	pause_hint.text = "Совместный бой продолжается" if arena.coop.live else "Бой приостановлен"
	exit_button.text = "ПОКИНУТЬ КООПЕРАТИВ" if arena.coop.live else "ЗАВЕРШИТЬ ЗАБЕГ"

func reset_run() -> void:
	range_button.button_pressed = false
	ability_page = 0
	inspected = -1
	inspected_slot = -1
	last_score = -1
	last_pickups = -1
	last_hp = -1.0
	last_level = -1
	badge.hide()
	for ongoing in [score_flash,damage_flash,experience_flash,level_pop]:
		if ongoing != null:
			ongoing.kill()
	for panel in [score_panel,xp_frame,operator_frame]:
		panel.flash = 0.0
	set_paused(false)

func refresh_tasks() -> void:
	var count := 0
	for i in TASKS.size():
		var target: int = arena.quest_target(i)
		var current: int = arena.quest_progress[i]
		if not arena.coop.live:
			if i == 0:
				current += arena.kills
			elif i == 2:
				current += maxi(0,arena.score)
		var claimed: bool = arena.quest_tiers[i] >= 1000
		var ready := current >= target or claimed
		count += int(ready)
		task_text[i].modulate = GREEN if ready else TEXT
		task_text[i].text = "%s  %s  %s" % ["✓" if ready else "□",TASKS[i],"макс." if claimed else "%d/%d" % [mini(current,target),target]]
	task_toggle.text = "ЗАДАНИЯ %d/%d   %s" % [count,TASKS.size(),"⌃" if task_toggle.button_pressed else "⌄"]

func inspect_ability(slot: int) -> void:
	if slot < active_abilities.size():
		var id := active_abilities[slot]
		inspected = -1 if inspected == id else id
		inspected_slot = -1
	else:
		inspected = -1
		inspected_slot = -1 if inspected_slot == slot else slot
	refresh_abilities()

func next_ability_page() -> void:
	var pages := maxi(1,ceili(float(arena.ranks.size())/slots.size()))
	ability_page = (ability_page+1)%pages
	inspected = -1
	inspected_slot = -1
	refresh_abilities()

func refresh_abilities() -> void:
	var ids: Array = arena.ranks.keys()
	ids.sort_custom(func(a: int,b: int): return arena.ranks[a] > arena.ranks[b] or (arena.ranks[a] == arena.ranks[b] and a < b))
	var pages := maxi(1,ceili(float(ids.size())/slots.size()))
	ability_page = mini(ability_page,pages-1)
	page_button.visible = pages > 1
	stat_card.visible = pages == 1
	page_button.text = "УСИЛЕНИЯ %d/%d ›" % [ability_page+1,pages]
	var first := ability_page*slots.size()
	active_abilities.assign(ids.slice(first,first+slots.size()))
	for i in slots.size():
		var active := i < active_abilities.size()
		var id: int = active_abilities[i] if active else KIT_ART[i]
		var art_id: int = 3 if id == 100 else (12 if id == 101 else id)
		var icon := slot_art[i]
		icon.texture = art_texture(art_id)
		icon.modulate = Color.WHITE if active else Color("#c0d5e6")
		var data: Array = arena.ability_data(id)
		slots[i].tooltip_text = data[0] if active else KIT_NAMES[i]
		var has_rank := active
		slot_ranks[i].get_parent().visible = has_rank
		slot_ranks[i].text = str(arena.ranks[id]) if has_rank else ""
		slot_frames[i].border = [GOLD,BLUE,Color("#ca96ff")][data[2]] if active else STEEL
		slot_frames[i].flash = 0.85 if (active and inspected == id) or (not active and inspected_slot == i) else 0.0
		slot_icons[i].text = GLYPHS[art_id] if icon.texture == null else ""
	if inspected in active_abilities:
		var ability: Array = arena.ability_data(inspected)
		status_text.text = "%s · %s" % [ability[0],ability[1]]
	elif inspected_slot >= active_abilities.size():
		var current: Array = [
			"%d урон за попадание" % arena.damage,
			"%.1f скорость" % arena.move_speed(),
			"%.1f радиус подбора" % arena.magnet,
			"%d%% снижение урона" % roundi(arena.armor*100),
		]
		status_text.text = "%s · %s" % [KIT_NAMES[inspected_slot],current[inspected_slot]]
	elif arena.coop.live:
		status_text.text = arena.coop.partner_status()
	else:
		status_text.text = "АВТООГОНЬ   /   СНАРЯЖЕНИЕ" if ids.is_empty() else "АВТООГОНЬ   /   УСИЛЕНИЯ"

func animate_panel(panel: Plate, tween: Tween, strength: float) -> Tween:
	if tween != null:
		tween.kill()
	panel.flash = strength
	var animation := create_tween()
	animation.tween_property(panel,"flash",0.0,0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return animation

func animate_events() -> void:
	if last_score >= 0 and arena.score > last_score:
		score_flash = animate_panel(score_panel,score_flash,0.95)
	if last_pickups >= 0 and arena.run_pickups > last_pickups:
		experience_flash = animate_panel(xp_frame,experience_flash,1.0)
	if last_hp >= 0 and arena.hp < last_hp:
		damage_flash = animate_panel(operator_frame,damage_flash,1.0)
	if last_level >= 0 and arena.level > last_level:
		if level_pop != null:
			level_pop.kill()
		badge.text = "НОВЫЙ УРОВЕНЬ %d" % arena.level
		badge.position.y = 262.0
		badge.modulate.a = 1.0
		badge.show()
		level_pop = create_tween()
		level_pop.tween_property(badge,"position:y",239.0,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		level_pop.tween_interval(0.74)
		level_pop.tween_property(badge,"modulate:a",0.0,0.30)
		level_pop.tween_callback(badge.hide)
	last_score = arena.score
	last_hp = arena.hp
	last_pickups = arena.run_pickups
	last_level = arena.level

func refresh_boss() -> void:
	var actors: Array = arena.coop.objects.values() if arena.coop.live and not arena.coop.hosting else arena.enemies
	boss_frame.hide()
	for actor in actors:
		var asset := str(actor.get_meta("model_asset",""))
		if not BOSSES.has(asset) or not actor.has_meta("max_health"):
			continue
		boss_name.text = BOSSES[asset]
		boss_health.max_value = int(actor.get_meta("max_health"))
		boss_health.value = int(actor.get_meta("health"))
		boss_frame.show()
		return

func refresh() -> void:
	animate_events()
	var seconds := maxi(0,60-int(arena.elapsed)) if arena.mode == 1 else int(arena.elapsed)
	clock.text = "%02d:%02d" % [int(seconds/60.0),seconds%60]
	context.text = "BLUETOOTH · 2 ИГРОКА" if arena.coop.live else MODES[arena.mode]
	level_label.text = "Ур. %d" % arena.level
	counters[0].text = "Счёт %d" % arena.score
	counters[1].text = "Осколки %d" % arena.run_pickups
	counters[2].text = "Комбо ×%d" % arena.combo
	kills_label.text = "Устранено %d" % arena.kills
	var best: int = arena.best_sprint if arena.mode == 1 else arena.best
	record_label.text = "Закрыто врат %d" % arena.gate_wins[arena.gate_rank] if arena.mode == 2 else "Рекорд %d" % best
	hero_name.text = arena.HERO_NAMES[arena.selected]
	if portrait_id != arena.selected:
		portrait_id = arena.selected
		var path := "res://assets/portraits/%s.png" % arena.HERO_ART[portrait_id]
		hero_badge.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	hero_stats.text = "Урон %d\nБроня %d%%\nСкорость %.1f" % [arena.damage,roundi(arena.armor*100),arena.move_speed()]
	health_text.text = "%d / %d  ЗДОРОВЬЕ" % [maxi(0,int(arena.hp)),int(arena.max_hp)]
	health.max_value = arena.max_hp
	health.value = arena.hp
	health.modulate = RED if arena.hp < arena.max_hp*0.25 else Color.WHITE
	xp_text.text = "%d / %d  ОПЫТ" % [arena.xp,arena.level*3]
	for bar in [xp,bottom_xp]:
		bar.max_value = arena.level*3
		bar.value = arena.xp
	refresh_tasks()
	refresh_abilities()
	refresh_boss()
	radar.queue_redraw()
