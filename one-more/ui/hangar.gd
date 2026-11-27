extends Control

signal action_requested(action: String)

const PORTRAIT := Vector2(720,1280)
const IVORY := Color("#ebddc7")
const BRASS := Color("#d3a06a")
const SEPARATOR := Color("#4b3732")

var map_button: Button
var summary: Label
var badges: Label
var fps: Label
var hero_caption: Label
var scrim: TextureRect
var mode_buttons: Array[Button] = []
var selected_mode := 0
var panel_styles: Dictionary[String,StyleBoxFlat] = {}
var design_positions: Dictionary[Control,Vector2] = {}

func _ready() -> void:
	size = PORTRAIT
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = preload("res://assets/vendor/fonts/Exo2-Variable.ttf")
	add_scrim()
	var title := label("ONE MORE",Rect2(32,21,470,72),55,IVORY)
	title.add_theme_font_override("font",preload("res://assets/vendor/fonts/Cinzel-Variable.ttf"))
	title.add_theme_color_override("font_shadow_color",Color("#0c0808"))
	title.add_theme_constant_override("shadow_offset_y",4)
	fps = label("",Rect2(535,28,72,46),15,Color("#afc190"))
	var settings := button("⚙",Rect2(624,23,64,58),"settings")
	settings.tooltip_text = "Настройки"
	summary = label("",Rect2(37,96,642,68),19,Color("#baaa9e"))
	var top_rule := ColorRect.new()
	top_rule.color = Color("#745349")
	top_rule.position = Vector2(37,91)
	top_rule.size = Vector2(572,1)
	top_rule.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(top_rule)

	hero_caption = label("",Rect2(37,496,510,49),31,IVORY)
	hero_caption.add_theme_font_override("font",preload("res://assets/vendor/fonts/Exo2-Variable.ttf"))
	hero_caption.add_theme_color_override("font_shadow_color",Color("#0a0606"))
	hero_caption.add_theme_constant_override("shadow_offset_y",3)
	button("СМЕНИТЬ ГЕРОЯ",Rect2(498,490,190,58),"heroes").add_theme_font_size_override("font_size",17)

	var play := button("ИГРАТЬ",Rect2(36,614,648,86),"play",true)
	play.add_theme_font_size_override("font_size",34)
	mode_buttons.append(button("БЕСКОНЕЧНЫЙ",Rect2(36,716,318,62),"endless"))
	mode_buttons.append(button("60 СЕКУНД",Rect2(366,716,318,62),"sprint"))
	map_button = button("",Rect2(36,796,648,66),"map")
	map_button.tooltip_text = "Выбрать следующую арену"
	button("ПРОБУЖДЕНИЕ",Rect2(36,889,318,75),"awakening")
	button("КООПЕРАТИВ",Rect2(366,889,318,75),"coop").tooltip_text = "Bluetooth-кооператив"
	button("СИСТЕМНЫЕ ЗАДАНИЯ",Rect2(36,979,318,75),"quests").add_theme_font_size_override("font_size",20)
	button("ВРАТА",Rect2(366,979,318,75),"gates")
	badges = label("",Rect2(42,1105,550,34),17,BRASS)
	select_mode(0)
	for child in get_children():
		var control := child as Control
		if control != null and control != scrim:
			design_positions[control] = control.position

func fit_viewport(extent: Vector2) -> void:
	size = extent
	scrim.size = extent
	var spare := (extent-PORTRAIT).max(Vector2.ZERO)
	for child in design_positions:
		var anchor: Vector2 = design_positions[child]
		child.position = anchor+Vector2(spare.x*0.5,spare.y*anchor.y/PORTRAIT.y)

func show_biome(caption: String) -> void:
	map_button.text = "КАРТА     ·     %s     ›" % caption

func add_scrim() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.12,0.25,0.39,0.49,0.64,1.0])
	gradient.colors = PackedColorArray([
		Color("#14100ff2"),Color("#17100ec8"),Color("#160d0e16"),Color("#1b0e0d08"),
		Color("#1f1413b0"),Color("#171212f3"),Color("#110e0efa"),
	])
	var texture := GradientTexture2D.new()
	texture.width = 2
	texture.height = 256
	texture.gradient = gradient
	texture.fill_to = Vector2.DOWN
	scrim = TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.size = PORTRAIT
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

func label(caption: String, rect: Rect2, points: int, tint: Color) -> Label:
	var node := Label.new()
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_size_override("font_size",points)
	node.add_theme_color_override("font_color",tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func button(caption: String, rect: Rect2, action: String, primary := false) -> Button:
	var node := Button.new()
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",22)
	node.add_theme_color_override("font_color",IVORY)
	node.add_theme_stylebox_override("normal",plate("primary" if primary else "normal"))
	node.add_theme_stylebox_override("hover",plate("primary_hover" if primary else "hover"))
	node.add_theme_stylebox_override("pressed",plate("pressed"))
	node.pressed.connect(func(): action_requested.emit(action))
	add_child(node)
	return node

func select_mode(index: int) -> void:
	selected_mode = index
	for i in mode_buttons.size():
		mode_buttons[i].add_theme_stylebox_override("normal",plate("selected" if i == index else "normal"))
		mode_buttons[i].add_theme_color_override("font_color",IVORY if i == index else Color("#a59790"))

func plate(state: String) -> StyleBoxFlat:
	if not panel_styles.has(state):
		var primary := state.begins_with("primary")
		var pressed := state == "pressed"
		var selected := state == "selected"
		var hovered := state in ["hover","primary_hover"]
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#40221c") if primary else Color("#262021")
		if hovered:
			box.bg_color = box.bg_color.lightened(0.10)
		if pressed:
			box.bg_color = Color("#171211")
		box.set_border_width_all(1)
		box.border_width_bottom = 3 if primary or selected else 1
		box.border_color = BRASS if primary or selected else SEPARATOR
		box.shadow_color = Color("#080606ad")
		box.shadow_size = 4
		box.shadow_offset = Vector2(0,4)
		panel_styles[state] = box
	return panel_styles[state]
