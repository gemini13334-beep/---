extends Control

signal action_requested(action: String)

const BACKDROP := preload("res://assets/art/gate-valley.jpg")
const PORTRAIT := Vector2(720,1280)

var map_button: Button
var summary: Label
var badges: Label
var fps: Label
var coop_button: Button
var mode_buttons: Array[Button] = []
var selected_mode := 0
var panel_styles: Dictionary = {}
var display_font: FontVariation

func _ready() -> void:
	size = PORTRAIT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_font = FontVariation.new()
	display_font.base_font = ThemeDB.fallback_font
	display_font.variation_embolden = 0.45
	display_font.variation_transform = Transform2D(Vector2(1,0),Vector2(-0.12,1),Vector2.ZERO)
	var artwork := TextureRect.new()
	artwork.texture = BACKDROP
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.size = PORTRAIT
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)
	add_scrim()

	var brand := label("ONE MORE",Vector2(32,21),Vector2(222,40),27,Color("#e9eff2"))
	brand.add_theme_font_override("font",display_font)
	fps = label("FPS  —",Vector2(499,21),Vector2(110,40),18,Color("#a6e5af"))
	var settings := button("⚙",Vector2(627,17),Vector2(58,48),"settings")
	settings.tooltip_text = "Настройки"

	panel(Vector2(39,78),Vector2(642,67))
	summary = label("",Vector2(60,82),Vector2(600,55),21,Color("#edf2f5"))

	var crest := TextureRect.new()
	var emblem := Image.new()
	emblem.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="156" height="69"><defs><linearGradient id="metal" x2="0" y2="1"><stop stop-color="#fff4d4"/><stop offset="1" stop-color="#c8913f"/></linearGradient></defs><path d="M8 63 A70 57 0 0 1 54 12 M102 12 A70 57 0 0 1 148 63" fill="none" stroke="#ecb969" stroke-width="2"/><path d="M40 63 L78 7 L116 63 L99 63 L78 32 L57 63Z" fill="url(#metal)"/><path d="M70 53L78 44L86 53L78 63Z" fill="#eaaf52"/></svg>')
	crest.texture = ImageTexture.create_from_image(emblem)
	crest.position = Vector2(282,161)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crest)
	var title := label("ONE MORE",Vector2(50,222),Vector2(620,102),77,Color("#f8fafb"))
	title.add_theme_font_override("font",display_font)
	title.add_theme_color_override("font_outline_color",Color("#243745"))
	title.add_theme_constant_override("outline_size",5)
	title.add_theme_color_override("font_shadow_color",Color("#041018e8"))
	title.add_theme_constant_override("shadow_offset_y",6)
	label("ВЫЖИВАЙ  /  РАЗВИВАЙСЯ  /  ПОВТОРЯЙ",Vector2(58,334),Vector2(604,29),17,Color("#e0e7e9"))

	var play := button("▶︎    ИГРАТЬ",Vector2(55,592),Vector2(610,78),"play",true)
	play.add_theme_font_size_override("font_size",36)
	mode_buttons.append(button("∞    БЕСКОНЕЧНЫЙ РЕЖИМ",Vector2(65,681),Vector2(590,53),"endless"))
	mode_buttons.append(button("◷    НА ВРЕМЯ  ·  60 СЕКУНД",Vector2(65,742),Vector2(590,53),"sprint"))
	map_button = button("",Vector2(65,803),Vector2(590,53),"map")
	button("КОЛЛЕКЦИЯ ГЕРОЕВ",Vector2(65,864),Vector2(590,53),"heroes")
	button("ПРОБУЖДЕНИЕ",Vector2(65,925),Vector2(590,53),"awakening")
	coop_button = button("КООПЕРАТИВ  ·  BLUETOOTH",Vector2(65,986),Vector2(590,53),"coop")
	button("НАСТРОЙКИ",Vector2(65,1047),Vector2(590,53),"settings")
	button("ЗАДАНИЯ",Vector2(35,1162),Vector2(206,60),"quests")
	button("ВРАТА",Vector2(257,1162),Vector2(206,60),"gates")
	badges = label("",Vector2(476,1162),Vector2(210,60),19,Color("#e9ca9b"))
	panel(Vector2(476,1162),Vector2(210,60)).move_to_front()
	badges.move_to_front()
	select_mode(0)

func add_scrim() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.28,0.43,0.61,0.88,1.0])
	gradient.colors = PackedColorArray([Color("#03101bad"),Color("#08192410"),Color("#08192406"),Color("#03121a67"),Color("#020b13a6"),Color("#020a11df")])
	var texture := GradientTexture2D.new()
	texture.width = 2
	texture.height = 256
	texture.gradient = gradient
	texture.fill_to = Vector2.DOWN
	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.size = PORTRAIT
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

func label(text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func panel(pos: Vector2, dimensions: Vector2) -> Panel:
	var node := Panel.new()
	node.position = pos
	node.size = dimensions
	node.add_theme_stylebox_override("panel",plate("normal"))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func button(text: String, pos: Vector2, dimensions: Vector2, action: String, primary := false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",23)
	node.add_theme_color_override("font_color",Color("#fff0d8") if primary else Color("#edf2f5"))
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

func plate(state: String) -> StyleBoxTexture:
	if panel_styles.has(state):
		return panel_styles[state]
	var primary := state.begins_with("primary")
	var lit := primary or state == "selected"
	var edge := "#ffc468" if lit else "#718c9a"
	var core := "#694016" if primary else ("#243845" if state == "hover" or lit else "#13232d")
	if state == "pressed":
		core = "#0b1820"
	if state == "primary_hover":
		core = "#9a591d"
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="180" height="60" viewBox="0 0 180 60"><defs><linearGradient id="fill" x1="0" y1="0" x2="0" y2="1"><stop stop-color="%s"/><stop offset=".48" stop-color="#0a151e"/><stop offset="1" stop-color="%s"/></linearGradient></defs><path d="M15 2H165L179 16V44L165 58H15L1 44V16Z" fill="url(#fill)" fill-opacity=".96" stroke="%s" stroke-width="%s"/><path d="M19 6H161L174 19 M6 41L19 54H161" fill="none" stroke="%s" stroke-opacity=".32"/></svg>' % [core,core,edge,"2.5" if primary else "1.4",edge])
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	for side in [SIDE_LEFT,SIDE_RIGHT]:
		style.set_texture_margin(side,20)
		style.set_content_margin(side,12)
	for side in [SIDE_TOP,SIDE_BOTTOM]:
		style.set_texture_margin(side,20)
		style.set_content_margin(side,5)
	panel_styles[state] = style
	return style
