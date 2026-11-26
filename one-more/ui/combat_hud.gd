extends Control

const GOLD := Color("#ffbb54")
const STEEL := Color("#849bac")
const TEXT := Color("#f1f4f6")
const SOFT := Color("#b1c3cf")
const BLUE := Color("#79dcff")
const GREEN := Color("#91ec77")
const RED := Color("#ff7667")
const MODES := ["БЕСКОНЕЧНЫЙ","НА ВРЕМЯ","ВРАТА"]
const BOSSES := {"boss_overlord":"ВЛАДЫКА","boss_crystal":"ЛЕДЯНОЙ ГОЛЕМ","boss_inferno":"ПЛАВИЛЬЩИК"}
const TASKS := ["Победить врагов","Завершить забеги","Набрать очки"]
const GLYPHS := ["ϟ","↑","∩","✦","⊕","◇","⌖","+","◇","♦","ϟ","↑","∩","ϟ","✦","◇"]

class Plate extends Control:
	var border: Color
	var cut: float

	func _draw() -> void:
		var shape := PackedVector2Array([
			Vector2(cut,0),Vector2(size.x-cut,0),Vector2(size.x,cut),Vector2(size.x,size.y-cut),
			Vector2(size.x-cut,size.y),Vector2(cut,size.y),Vector2(0,size.y-cut),Vector2(0,cut)
		])
		draw_colored_polygon(shape,Color("#101922eb"))
		shape.append(shape[0])
		draw_polyline(shape,Color("#050a0f"),4,true)
		draw_polyline(shape,Color(border,0.8),1,true)
		draw_line(Vector2(cut+1,2),Vector2(size.x*0.56,2),Color(border,0.5),2,true)
		draw_line(Vector2(size.x*0.48,size.y-3),Vector2(size.x-cut-1,size.y-3),Color(border,0.32),1,true)

class Reticle extends Control:
	var active := false

	func _draw() -> void:
		var center := size*0.5
		draw_circle(center,50,Color("#171b24ed") if not active else Color("#3d2a18ed"),true,-1,true)
		draw_circle(center,49,Color("#7c643e"),false,2,true)
		draw_arc(center,48,0.0,PI*0.92,26,Color("#ffb652"),3,true)
		draw_arc(center,48,PI,PI*1.53,18,Color("#6d7e8e"),2,true)
		draw_circle(center,23,Color("#ffb95335"),false,7,true)
		draw_circle(center,21,Color("#ffbf5a"),false,2,true)
		draw_circle(center,3,Color("#ffffff"),true,-1,true)
		for i in 4:
			var axis := Vector2.from_angle(i*PI/2)
			draw_line(center+axis*14,center+axis*28,Color("#ffeac2"),3,true)

class Radar extends Control:
	var arena
	var zoom := false

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
		var focus: Vector3 = arena.hero.position if zoom else Vector3.ZERO
		var radius := 11.0 if zoom else 23.0
		var grid := Color(0.54,0.74,0.68,0.18)
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
var ability_page := 0
var page_button: Button
var active_abilities: Array[int] = []
var inspected := -1
var health_text: Label
var xp_text: Label
var health: ProgressBar
var xp: ProgressBar
var bottom_xp: ProgressBar
var overlay: ColorRect
var pause_title: Label
var pause_hint: Label
var exit_button: Button
var touch_blocks: Array[Control] = []

func configure(owner_arena) -> void:
	arena = owner_arena
	size = Vector2(720,1280)
	mouse_filter = MOUSE_FILTER_IGNORE
	var top := plate(self,Rect2(12,12,696,52),STEEL)
	button(top,Rect2(2,2,58,48),"Ⅱ","Меню забега",arena.toggle_hud_pause)
	button(top,Rect2(62,2,58,48),"⚙","Настройки",arena.open_hud_settings)
	display(top,Rect2(135,0,165,52),"ONE MORE",25,TEXT)
	var timer := plate(top,Rect2(304,0,101,52),GOLD)
	clock = display(timer,Rect2(0,0,101,52),"00:00",24,TEXT,true)
	context = display(top,Rect2(409,0,198,52),"",16,SOFT,true)
	fps = display(top,Rect2(607,0,78,52),"",15,GREEN,true)
	touch_blocks.append(top)

	var rank := plate(self,Rect2(12,76,226,66),STEEL)
	display(rank,Rect2(7,6,49,51),"⬡",37,GOLD,true)
	level_label = display(rank,Rect2(62,4,156,30),"",20,TEXT)
	xp = meter(rank,Rect2(62,43,149,9),GOLD)
	touch_blocks.append(rank)

	var count_frame := plate(self,Rect2(519,76,189,106),STEEL)
	for i in 3:
		var tint: Color = [GOLD,BLUE,GOLD][i]
		display(count_frame,Rect2(6,4+i*33,28,30),["✦","◆","ϟ"][i],22,tint,true)
		counters.append(display(count_frame,Rect2(38,4+i*33,146,30),"",17,TEXT))
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
		aiming.queue_redraw()
	)
	var range_caption := plate(right,Rect2(5,106,117,26),STEEL,8)
	display(range_caption,Rect2(0,0,117,26),"ДАЛЬНОСТЬ",14,TEXT,true)

	var bottom := plate(self,Rect2(12,1108,696,160),STEEL,15)
	touch_blocks.append(bottom)
	var operator := plate(bottom,Rect2(7,8,211,144),GOLD)
	var portrait_frame := plate(operator,Rect2(6,7,68,76),GOLD,8)
	hero_badge = TextureRect.new()
	hero_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	place(portrait_frame,hero_badge,Rect2(3,3,62,69))
	hero_name = display(operator,Rect2(10,88,191,47),"",18,TEXT)
	hero_stats = display(operator,Rect2(75,8,130,77),"",15,SOFT)
	for i in 4:
		var slot := plate(bottom,Rect2(228+i*75,9,66,57),STEEL)
		var face := button(slot,Rect2(0,0,66,57),"","",inspect_ability.bind(i))
		face.add_theme_font_size_override("font_size",15)
		face.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slots.append(face)
		slot_icons.append(display(slot,Rect2(6,4,40,49),"",31,GOLD,true))
	page_button = button(bottom,Rect2(534,9,145,57),"","Другие усиления",next_ability_page)
	page_button.add_theme_font_size_override("font_size",15)
	status_text = display(bottom,Rect2(228,68,451,20),"",15,SOFT)
	health = meter(bottom,Rect2(228,95,454,22),GREEN)
	health_text = display(bottom,Rect2(228,95,454,22),"",16,TEXT,true)
	xp_text = display(bottom,Rect2(228,119,454,23),"",16,BLUE,true)
	bottom_xp = meter(bottom,Rect2(228,145,454,5),BLUE)
	build_pause()

func build_pause() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.02,0.035,0.055,0.82)
	overlay.size = size
	add_child(overlay)
	var modal := plate(overlay,Rect2(110,400,500,428),GOLD,24)
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
	for state in ["background","fill"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#080f18") if state == "background" else tint.darkened(0.37)
		box.border_color = Color("#394c58") if state == "background" else tint
		box.border_width_top = 1
		box.border_width_bottom = 1
		box.set_corner_radius_all(3)
		item.add_theme_stylebox_override(state,box)
	place(parent,item,rect)
	return item

func toggle_tasks(expanded: bool) -> void:
	tasks.visible = expanded
	radar_frame.position.y = 292 if expanded else 204
	refresh_tasks()

func toggle_radar() -> void:
	radar.zoom = not radar.zoom
	zoom_button.text = "−" if radar.zoom else "+"
	zoom_button.tooltip_text = "Вся арена" if radar.zoom else "Приблизить карту"
	radar.queue_redraw()

func blocks_at(point: Vector2) -> bool:
	for panel in touch_blocks:
		if panel.is_visible_in_tree() and Rect2(Vector2.ZERO,panel.size).has_point(panel.get_global_transform_with_canvas().affine_inverse()*point):
			return true
	return false

func set_paused(paused: bool) -> void:
	overlay.visible = paused
	pause_title.text = "МЕНЮ ЗАБЕГА" if arena.coop.live else "ПАУЗА"
	pause_hint.text = "Совместный бой продолжается" if arena.coop.live else "Бой приостановлен"
	exit_button.text = "ПОКИНУТЬ КООПЕРАТИВ" if arena.coop.live else "ЗАВЕРШИТЬ ЗАБЕГ"

func reset_run() -> void:
	range_button.button_pressed = false
	ability_page = 0
	inspected = -1
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
		refresh_abilities()

func next_ability_page() -> void:
	var pages := maxi(1,ceili(float(arena.ranks.size())/slots.size()))
	ability_page = (ability_page+1)%pages
	inspected = -1
	refresh_abilities()

func refresh_abilities() -> void:
	var ids: Array = arena.ranks.keys()
	ids.sort_custom(func(a: int,b: int): return arena.ranks[a] > arena.ranks[b] or (arena.ranks[a] == arena.ranks[b] and a < b))
	var pages := maxi(1,ceili(float(ids.size())/slots.size()))
	ability_page = mini(ability_page,pages-1)
	page_button.visible = pages > 1
	page_button.text = "УСИЛЕНИЯ %d/%d ›" % [ability_page+1,pages]
	var first := ability_page*slots.size()
	active_abilities.assign(ids.slice(first,first+slots.size()))
	for i in slots.size():
		var slot := slots[i]
		var icon := slot_icons[i]
		slot.disabled = i >= active_abilities.size()
		if slot.disabled:
			slot.text = ""
			slot.tooltip_text = ""
			icon.text = "·"
			icon.modulate = STEEL
		else:
			var id := active_abilities[i]
			var ability: Array = arena.ability_data(id)
			slot.text = str(arena.ranks[id])
			slot.tooltip_text = ability[0]
			icon.text = "✦" if arena.COMBINATIONS.has(id) else GLYPHS[id]
			icon.modulate = [GOLD,BLUE,Color("#c8a1ff")][ability[2]]
	if inspected in active_abilities:
		var ability: Array = arena.ability_data(inspected)
		status_text.text = "%s · %s" % [ability[0],ability[1]]
	elif arena.coop.live:
		status_text.text = arena.coop.partner_status()
	else:
		status_text.text = "АВТООГОНЬ · %s" % ("УСИЛЕНИЯ ЗА УРОВЕНЬ" if active_abilities.is_empty() else "НАЖМИТЕ НА ЯЧЕЙКУ")

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
	var seconds := maxi(0,60-int(arena.elapsed)) if arena.mode == 1 else int(arena.elapsed)
	clock.text = "%02d:%02d" % [int(seconds/60.0),seconds%60]
	context.text = "BLUETOOTH · 2 ИГРОКА" if arena.coop.live else MODES[arena.mode]
	level_label.text = "Ур. %d" % arena.level
	counters[0].text = "Счёт %d" % arena.score
	counters[1].text = "Осколки %d" % arena.run_pickups
	counters[2].text = "Комбо ×%d" % arena.combo
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
