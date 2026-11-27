extends Control

const Landscape = preload("res://landscape.gd")

const GOLD := Color("#ffbb54")
const STEEL := Color("#a7a8b5")
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
const MAP_OPEN_TOP := 269.0
const MAP_CLOSED_TOP := 186.0
const DESIGN_SIZE := Vector2(720,1280)

class Plate extends Control:
	static var ember: GradientTexture2D
	var border: Color
	var cut: float
	var light := 0.0
	var flash := 0.0:
		set(value):
			flash = value
			queue_redraw()

	static func ember_texture() -> GradientTexture2D:
		if ember == null:
			var bloom := Gradient.new()
			bloom.offsets = PackedFloat32Array([0.0,0.17,0.46,1.0])
			bloom.colors = PackedColorArray([Color("#fff5c8e0"),Color("#ffb4558e"),Color("#f6792c40"),Color("#c73d1800")])
			ember = GradientTexture2D.new()
			ember.width = 96
			ember.height = 48
			ember.fill = GradientTexture2D.FILL_RADIAL
			ember.fill_from = Vector2(.5,.5)
			ember.fill_to = Vector2(1.0,.5)
			ember.gradient = bloom
		return ember

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
		var bright := border.lightened(flash*0.34)
		var warm := border.r > border.b*1.25
		draw_polygon(shape,PackedColorArray([
			Color("#595660"),Color("#2c2a34"),Color("#171620"),Color("#302634"),
			Color("#15111a"),Color("#2e2530"),Color("#100d16"),Color("#42404a")
		]))
		var inside := outline(5)
		draw_polygon(inside,PackedColorArray([
			Color("#181720f0"),Color("#0b0b11f8"),Color("#11101af7"),Color("#090810f6"),
			Color("#171420f7"),Color("#0c0c12f7"),Color("#08090eec"),Color("#211c24ef")
		]))
		shape.append(shape[0])
		inside.append(inside[0])
		draw_polyline(shape,Color("#040309"),4.3,true)
		draw_polyline(shape,Color(bright,0.53+flash*0.37),1.7,true)
		draw_polyline(inside,Color(bright,0.49+flash*0.34),1.1,true)
		var corner_light := Color("#ffe3aa") if warm else Color("#d6d8e8")
		draw_line(shape[7],shape[0],Color(corner_light,0.77),2.0,true)
		draw_line(shape[3],shape[4],Color(corner_light,0.48),1.8,true)
		if size.x > 94 and size.y > 35:
			var lower_glow := Color("#f7892e") if warm else Color("#a96743")
			draw_line(Vector2(cut+3,1),Vector2(size.x*0.48,1),Color(corner_light,0.46),1.6,true)
			var edge_start := Vector2(size.x*0.27,size.y-2)
			var edge_end := Vector2(size.x*0.73,size.y-2)
			draw_line(edge_start,edge_end,Color(lower_glow,0.14+flash*0.16),8.0,true)
			draw_line(edge_start,edge_end,Color(lower_glow,0.34+flash*0.30),3.8,true)
			draw_line(edge_start.lerp(edge_end,.28),edge_end.lerp(edge_start,.28),Color(corner_light,0.62),1.15,true)
		if light > 0.0:
			var width := minf(size.x*0.94,185.0)
			draw_texture_rect(ember_texture(),Rect2((size.x-width)*0.5,size.y-20,width,36),false,Color(1,1,1,light))

class StickGuide extends Control:
	func _draw() -> void:
		var middle := size*0.5
		var radius := size.x*0.5
		draw_texture_rect(Plate.ember_texture(),Rect2(middle.x-radius*.54,size.y-25,radius*1.08,42),false,Color(1,1,1,0.54))
		draw_arc(middle,radius-8,0,TAU,60,Color("#544557b3"),1.25,true)
		draw_arc(middle,radius-3,0,TAU,60,Color("#a08b6e"),2.2,true)
		draw_arc(middle,radius-4,PI*.21,PI*.74,24,Color("#f2832c50"),9,true)
		draw_arc(middle,radius-4,PI*.25,PI*.71,22,Color("#ffa953"),3,true)
		draw_arc(middle,radius-3,PI*1.14,PI*1.61,22,Color("#eee0bd"),1.55,true)
		for i in 4:
			var forward := Vector2.from_angle(i*TAU/4)
			var side := forward.orthogonal()
			var p := middle+forward*(radius-18)
			draw_circle(p,9,Color("#f083333c"),true,-1,true)
			draw_polygon(PackedVector2Array([p+forward*7,p-forward*4+side*7,p-forward*4-side*7]),
				PackedColorArray([Color("#fff4ca"),Color("#f9ae54"),Color("#b96528")]))

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
		draw_circle(center,50,Color("#13121aee") if not active else Color("#26190dee"),true,-1,true)
		draw_texture_rect(Plate.ember_texture(),Rect2(12,78,82,38),false,Color(1,1,1,0.46))
		draw_circle(center,49,Color("#ab8b69"),false,2,true)
		draw_arc(center,48,PI*0.13,PI*0.86,26,Color("#fb8d3d53"),9,true)
		draw_arc(center,48,PI*0.21,PI*0.74,23,Color("#ffbb63"),3,true)
		draw_arc(center,48,PI*1.12,PI*1.69,20,Color("#ede4cb"),1.6,true)
		draw_circle(center,23,Color("#ffa63754"),false,7,true)
		draw_circle(center,21,Color("#ffc971"),false,2.5,true)
		draw_circle(center,3,Color("#ffffff"),true,-1,true)
		if active:
			draw_arc(center,43,sweep,sweep+0.54,12,Color("#fff0b1"),3,true)
		for i in 4:
			var axis := Vector2.from_angle(i*PI/2)
			draw_line(center+axis*14,center+axis*29,Color("#ffe0a0"),3,true)

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
		var radius := lerpf(Landscape.MAP_HALF,15.0,zoom_blend)
		var top_left := project_point(Vector3(-Landscape.MAP_HALF,0,-Landscape.MAP_HALF),focus,radius)
		var bottom_right := project_point(Vector3(Landscape.MAP_HALF,0,Landscape.MAP_HALF),focus,radius)
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
var pause_button: Button
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
var fusion_anchor: Plate
var fusion_button: Button
var fusion_overlay: ColorRect
var fusion_balance: Label
var fusion_feedback: Label
var fusion_confirm: Button
var fusion_cards: Dictionary = {}
var selected_recipe := -1
var pause_modal: Plate
var fusion_modal: Plate
var pause_title: Label
var pause_hint: Label
var exit_button: Button
var touch_blocks: Array[Control] = []
var loadout_frame: Plate
var bottom_positions: Dictionary[Control,float] = {}

func configure(owner_arena) -> void:
	arena = owner_arena
	size = DESIGN_SIZE
	var typeface := FontVariation.new()
	typeface.base_font = preload("res://assets/vendor/fonts/Exo2-Variable.ttf")
	typeface.fallbacks = [ThemeDB.fallback_font]
	var hud_colors := Theme.new()
	hud_colors.default_font = typeface
	theme = hud_colors
	mouse_filter = MOUSE_FILTER_IGNORE
	var top := plate(self,Rect2(0,11,720,54),STEEL,16)
	pause_button = button(top,Rect2(7,5,53,45),"Ⅱ","Меню забега",arena.toggle_hud_pause)
	button(top,Rect2(62,5,53,45),"⚙","Настройки",arena.open_hud_settings)
	var brand := display(top,Rect2(137,0,164,54),"ONE MORE",27,Color("#fff0c9"))
	brand.add_theme_font_override("font",preload("res://assets/vendor/fonts/Cinzel-Variable.ttf"))
	var timer := plate(top,Rect2(308,-5,122,64),GOLD,21)
	timer.light = 0.98
	clock = display(timer,Rect2(0,0,122,64),"00:00",27,TEXT,true)
	context = display(top,Rect2(437,0,181,54),"",16,TEXT,true)
	fps = display(top,Rect2(632,0,80,54),"",16,GREEN,true)
	touch_blocks.append(top)

	var rank := plate(self,Rect2(11,78,226,64),STEEL)
	xp_frame = rank
	picture(rank,Rect2(9,7,44,48)).texture = art_texture(13)
	level_label = display(rank,Rect2(62,4,156,30),"",20,TEXT)
	xp = meter(rank,Rect2(62,43,149,9),GOLD)
	touch_blocks.append(rank)

	var count_frame := plate(self,Rect2(516,76,192,105),GOLD,14)
	count_frame.light = 0.52
	score_panel = count_frame
	for i in 3:
		var art := picture(count_frame,Rect2(9,4+i*33,31,31))
		art.texture = art_texture([9,2,3][i])
		var tint: Color = [GOLD,BLUE,Color("#ffb47a")][i]
		counters.append(display(count_frame,Rect2(43,4+i*33,140,30),"",17,tint))
	touch_blocks.append(count_frame)

	boss_frame = plate(self,Rect2(486,191,222,54),Color("#ab5347"))
	boss_name = display(boss_frame,Rect2(8,2,206,25),"",15,TEXT,true)
	boss_health = meter(boss_frame,Rect2(12,33,198,9),RED)
	boss_frame.hide()

	var task_frame := plate(self,Rect2(11,147,226,38),GOLD)
	task_toggle = button(task_frame,Rect2(0,0,226,38),"","Свернуть или открыть задания",Callable())
	task_toggle.toggle_mode = true
	task_toggle.add_theme_font_size_override("font_size",17)
	var task_brass := StyleBoxFlat.new()
	task_brass.bg_color = Color("#98633382")
	task_brass.set_corner_radius_all(8)
	task_toggle.add_theme_stylebox_override("normal",task_brass)
	task_toggle.add_theme_stylebox_override("pressed",task_brass)
	tasks = plate(self,Rect2(11,187,226,76),GOLD)
	for i in TASKS.size():
		task_text.append(display(tasks,Rect2(10,5+i*22,207,21),"",14,TEXT))
	touch_blocks.append(tasks)

	var radar_shell := plate(self,Rect2(11,MAP_OPEN_TOP,178,184),GOLD,16)
	radar_shell.light = 0.48
	radar_frame = radar_shell
	radar = Radar.new()
	radar.arena = arena
	radar.clip_contents = true
	place(radar_frame,radar,Rect2(8,8,162,158))
	display(radar_frame,Rect2(16,158,89,21),"КАРТА",15,TEXT)
	zoom_button = button(radar_frame,Rect2(129,139,40,37),"+","Приблизить карту",toggle_radar)
	touch_blocks.append(radar_frame)
	task_toggle.toggled.connect(toggle_tasks)
	task_toggle.set_pressed_no_signal(true)

	var right := Control.new()
	place(self,right,Rect2(583,972,127,136))
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
	var range_caption := plate(right,Rect2(5,103,117,26),STEEL,8)
	display(range_caption,Rect2(0,0,117,26),"ДАЛЬНОСТЬ",14,TEXT,true)

	var bottom := plate(self,Rect2(4,1113,712,160),STEEL,18)
	loadout_frame = bottom
	bottom.light = 0.88
	touch_blocks.append(bottom)
	var operator := plate(bottom,Rect2(7,8,218,144),GOLD,15)
	operator_frame = operator
	var portrait_frame := plate(operator,Rect2(6,7,68,76),GOLD,8)
	hero_badge = picture(portrait_frame,Rect2(3,3,62,69))
	hero_name = display(operator,Rect2(14,88,192,47),"",21,Color("#fff0cc"))
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
	build_fusion()
	for anchored in [right,bottom,fusion_anchor]:
		bottom_positions[anchored] = anchored.position.y

func fit_viewport(extent: Vector2) -> void:
	var spare := (extent-DESIGN_SIZE).max(Vector2.ZERO)
	position.x = spare.x*0.5
	size = Vector2(DESIGN_SIZE.x,extent.y)
	for anchored in bottom_positions:
		anchored.position.y = bottom_positions[anchored]+spare.y
	for panel in [overlay,fusion_overlay]:
		panel.position.x = -position.x
		panel.size.x = extent.x
	for veil in [overlay,fusion_overlay]:
		veil.size.y = extent.y
	pause_modal.position = (extent-pause_modal.size)*0.5
	fusion_modal.position = (extent-fusion_modal.size)*0.5

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

func build_fusion() -> void:
	fusion_anchor = plate(self,Rect2(354,1049,184,49),GOLD,13)
	fusion_button = button(fusion_anchor,Rect2(0,0,184,49),"СИНТЕЗ","Объединить суперспособности",arena.open_fusion)
	fusion_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	fusion_overlay = ColorRect.new()
	fusion_overlay.color = Color(0.019,0.029,0.050,0.89)
	fusion_overlay.size = size
	add_child(fusion_overlay)
	var modal := plate(fusion_overlay,Rect2(58,234,604,808),GOLD,21)
	fusion_modal = modal
	display(modal,Rect2(22,12,560,53),"СИНТЕЗ СПОСОБНОСТЕЙ",29,TEXT,true)
	fusion_balance = display(modal,Rect2(22,66,560,34),"",20,GOLD,true)
	display(modal,Rect2(18,100,568,22),"Сохраняет эффекты компонентов и добавляет бонус",17,SOFT,true)
	display(modal,Rect2(18,122,568,22),"По одному рангу · действует до конца забега",17,SOFT,true)
	var row := 0
	for id in arena.FUSION_RECIPES:
		var recipe: Dictionary = arena.FUSION_RECIPES[id]
		var card := plate(modal,Rect2(20,146+float(row)*139,564,126),STEEL,12)
		var pick := button(card,Rect2(0,0,564,126),"",str(recipe["name"]),select_fusion.bind(id))
		pick.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		var glyph := picture(card,Rect2(14,24,78,78))
		glyph.texture = art_texture(int(recipe["art"]))
		display(card,Rect2(109,6,446,31),str(recipe["name"]),22,TEXT)
		var ingredients := display(card,Rect2(109,37,446,24),"",16,SOFT)
		display(card,Rect2(109,62,446,23),str(recipe["bonus"]),16,BLUE)
		var status := display(card,Rect2(109,89,446,25),"",16,GOLD)
		fusion_cards[id] = {"plate":card,"ingredients":ingredients,"status":status}
		row += 1

	fusion_feedback = display(modal,Rect2(22,573,560,40),"Выберите рецепт",18,SOFT,true)
	fusion_confirm = button(modal,Rect2(28,627,548,65),"ОБЪЕДИНИТЬ","Подтвердить покупку",confirm_fusion)
	button(modal,Rect2(28,709,548,62),"ВЕРНУТЬСЯ В БОЙ","Закрыть синтез",arena.close_fusion)
	fusion_overlay.hide()

func set_fusion_open(open: bool) -> void:
	fusion_overlay.visible = open
	selected_recipe = -1
	if open:
		fusion_feedback.text = "Выберите рецепт" if not arena.coop.live else "Оплата из ваших кредитов · бой продолжается"
		refresh_fusion()

func select_fusion(id: int) -> void:
	selected_recipe = id
	var issue: String = arena.fusion_issue(id)
	fusion_feedback.text = "Все условия выполнены" if issue.is_empty() else issue
	refresh_fusion()

func confirm_fusion() -> void:
	var issue: String = arena.buy_fusion(selected_recipe)
	if not issue.is_empty():
		fusion_feedback.text = issue
		refresh_fusion()
		return
	ability_page = 0
	inspected = selected_recipe
	inspected_slot = -1
	arena.close_fusion()

func refresh_fusion() -> void:
	fusion_balance.text = "КРЕДИТЫ  %d" % arena.credits
	for id in arena.FUSION_RECIPES:
		var recipe: Dictionary = arena.FUSION_RECIPES[id]
		var card: Dictionary = fusion_cards[id]
		var entries := PackedStringArray()
		for ingredient in recipe["ingredients"]:
			var rank: int = arena.ranks.get(ingredient,0)
			entries.append("%s %s" % [arena.ABILITIES[ingredient][0],"✓" if rank > 0 else "—"])
		card["ingredients"].text = " + ".join(entries)
		var issue: String = arena.fusion_issue(id)
		var caption := "ГОТОВО" if issue.is_empty() else issue
		card["status"].text = "%d КР. · %s" % [recipe["credits"],caption]
		card["plate"].flash = 0.95 if id == selected_recipe else (0.32 if issue.is_empty() else 0.0)

	fusion_confirm.disabled = selected_recipe == -1 or not arena.can_open_fusion() or not arena.fusion_issue(selected_recipe).is_empty()
	fusion_confirm.text = "ОБЪЕДИНИТЬ" if selected_recipe == -1 else "ОБЪЕДИНИТЬ · %d КР." % arena.FUSION_RECIPES[selected_recipe]["credits"]

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
		box.bg_color = {"normal":Color("#1a181fb4"),"hover":Color("#604224c9"),"pressed":Color("#98602cb8"),"disabled":Color("#11101799")}[state]
		box.border_color = GOLD if state == "pressed" else Color("#554953")
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
	box.bg_color = Color("#080910")
	box.border_color = Color("#57505d")
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
	radar_frame.position.y = MAP_OPEN_TOP if expanded else MAP_CLOSED_TOP
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
	set_fusion_open(false)

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
	ids.sort_custom(func(a: int,b: int):
		var merged_a: bool = arena.FUSION_RECIPES.has(a)
		var merged_b: bool = arena.FUSION_RECIPES.has(b)
		if merged_a != merged_b:
			return merged_a
		return arena.ranks[a] > arena.ranks[b] or (arena.ranks[a] == arena.ranks[b] and a < b)
	)
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
		if arena.FUSION_RECIPES.has(id):
			art_id = int(arena.FUSION_RECIPES[id]["art"])
		var icon := slot_art[i]
		icon.texture = art_texture(art_id)
		icon.modulate = Color.WHITE if active else Color("#c0d5e6")
		var data: Array = arena.ability_data(id)
		slots[i].tooltip_text = data[0] if active else KIT_NAMES[i]
		var has_rank := active
		slot_ranks[i].get_parent().visible = has_rank
		slot_ranks[i].text = str(arena.ranks[id]) if has_rank else ""
		slot_frames[i].border = [GOLD,BLUE,Color("#ca96ff")][data[2]] if active else STEEL
		if arena.FUSION_RECIPES.has(id):
			slot_frames[i].border = Color("#eda75c")
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
		var threat: int = arena.enemy_stage(arena.level)
		var escalation: bool = threat > arena.enemy_stage(last_level)
		badge.text = ("ВРАГИ УСИЛЕНЫ · %d" % threat) if escalation else ("НОВЫЙ УРОВЕНЬ %d" % arena.level)
		badge.add_theme_color_override("font_color",Color("#ffab6b") if escalation else GOLD)
		badge.position.y = 262.0
		badge.modulate.a = 1.0
		badge.show()
		level_pop = create_tween()
		level_pop.tween_property(badge,"position:y",239.0,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		level_pop.tween_interval(2.2 if escalation else 0.74)
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
	fusion_anchor.visible = arena.can_open_fusion() and not fusion_overlay.visible
	if fusion_anchor.visible:
		var ready := 0
		for id in arena.FUSION_RECIPES:
			ready += int(arena.fusion_issue(id).is_empty())
		fusion_button.text = "СИНТЕЗ" if ready == 0 else "СИНТЕЗ · %d" % ready
		fusion_button.modulate = Color.WHITE if ready > 0 else Color("#b3c5d8")
	if fusion_overlay.visible:
		refresh_fusion()
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
