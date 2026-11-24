extends Control

signal navigate(section: String)
signal deploy(endless: bool, mission: int)

const Story = preload("res://scripts/story.gd")
const FACE = preload("res://assets/type/interface.tres")
const GOLD := Color("#f1b455")
const INK := Color("#1c2328ee")
const ART := ["mission-0","mission-1","mission-2","mission-3","mission-4"]
const RUST := Color("#be5137")
const CHARCOAL := Color("#181d21")
const PAPER := Color("#f1ede4")
var frontier: int
var selected: int
var infinite := false
var experience: int
var balance: int
var idle_portrait: ShaderMaterial
var idle_time := 0.0

var backdrop: ColorRect
var portrait: TextureRect
var navigation_bar: ColorRect

func fit_background() -> void:
 var bounds := get_global_transform().affine_inverse() * get_viewport_rect()
 if backdrop:
  backdrop.position = bounds.position
  backdrop.size = bounds.size
 if portrait:
  portrait.position = Vector2(bounds.position.x,64)
  portrait.size = Vector2(bounds.size.x,maxf(1,bounds.end.y-64))
  if idle_portrait:
   var relative_aspect := portrait.size.aspect() / portrait.texture.get_size().aspect()
   var crop := Vector2(minf(1,relative_aspect),minf(1,1.0/relative_aspect))
   idle_portrait.set_shader_parameter("crop_scale",crop)
 if navigation_bar:
  navigation_bar.position = Vector2(bounds.position.x, -1)
  navigation_bar.size = Vector2(bounds.size.x, 65)

func _ready() -> void:
 backdrop = panel(Vector2.ZERO,Vector2(1280,720),CHARCOAL)
 fit_background()
 modulate.a = 0.0
 create_tween().tween_property(self,"modulate:a",1.0,0.18)

func enter_art(art: Control, offset: float) -> void:
 var destination := art.position.x
 art.position.x += offset
 art.create_tween().tween_property(art,"position:x",destination,0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func panel(at:Vector2, extent:Vector2, color:Color)->ColorRect:
 var rect:=ColorRect.new()
 rect.position=at
 rect.size=extent
 rect.color=color
 rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(rect)
 return rect

func picture(asset:String, at:Vector2, extent:Vector2)->TextureRect:
 var rect:=TextureRect.new()
 rect.texture=load("res://assets/briefing/"+asset+".webp")
 rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 rect.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 rect.position=at
 rect.size=extent
 rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(rect)
 return rect

func caption(value:String, at:Vector2, pixels:int, color:=Color.WHITE, width:=0)->Label:
 var label:=Label.new()
 label.text=value
 label.position=at
 label.add_theme_font_override("font", FACE)
 label.add_theme_font_size_override("font_size",pixels)
 label.add_theme_color_override("font_color",color)
 if width>0:
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  label.set_deferred("size",Vector2(width,0))
 add_child(label)
 return label

func button(value:String, at:Vector2, extent:Vector2, action:Callable, primary:=false)->Button:
 var b:=Button.new()
 b.text=value
 b.accessibility_name=value
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 b.position=at
 b.size=extent
 b.add_theme_font_override("font", FACE)
 b.add_theme_font_size_override("font_size",25 if primary else 20)
 for state in ["normal","hover","pressed","focus","disabled"]:
  var style:=StyleBoxFlat.new()
  style.bg_color=GOLD if primary else Color("#252c31f5")
  if state in ["hover","pressed"]: style.bg_color=style.bg_color.lightened(0.15)
  if state=="disabled": style.bg_color=Color("#393630")
  if state=="focus":
   style.draw_center=false
   style.set_border_width_all(2)
   style.border_color=GOLD
  b.add_theme_stylebox_override(state,style)
 if primary:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
   b.add_theme_color_override(state,Color("#181c20"))
 b.pressed.connect(action)
 add_child(b)
 return b

func chrome(active:String)->void:
 navigation_bar = panel(Vector2.ZERO,Vector2(1280,64),Color("#161b20fa"))
 fit_background()
 var insignia := TextureRect.new()
 insignia.texture = preload("res://icon.svg")
 insignia.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 insignia.position = Vector2(26,13)
 insignia.size = Vector2(38,38)
 insignia.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(insignia)
 caption(Story.TITLE,Vector2(75,14),25,PAPER)
 var tabs := ["ЛОББИ","ИГРАТЬ","ИНВЕНТАРЬ","СНАРЯЖЕНИЕ","МАГАЗИН","ПРОФИЛЬ","НАСТРОЙКИ"]
 for i in tabs.size():
  var key: String = tabs[i]
  var x := 266 + i * 141
  var tab := button(key,Vector2(x,4),Vector2(137,56),func(): navigate.emit(key))
  tab.flat = true
  tab.add_theme_font_size_override("font_size",20)
  tab.add_theme_color_override("font_color",GOLD if active==key else Color("#d3d8d9"))
  if active == key:
   panel(Vector2(x+18,59),Vector2(101,3),GOLD)

func card_link(at: Vector2, extent: Vector2, title: String, action: Callable) -> void:
 var link := Button.new()
 link.flat = true
 link.accessibility_name = title
 link.tooltip_text = title
 link.position = at
 link.size = extent
 link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 var outline := StyleBoxFlat.new()
 outline.draw_center = false
 outline.set_border_width_all(2)
 outline.border_color = GOLD
 for state in ["hover","pressed","focus"]:
  link.add_theme_stylebox_override(state,outline)
 link.pressed.connect(action)
 add_child(link)

func _process(delta: float) -> void:
 if idle_portrait != null:
  idle_time = fmod(idle_time + delta, 3600.0)
  idle_portrait.set_shader_parameter("phase", idle_time)

func lobby()->void:
 portrait = picture("lobby",Vector2.ZERO,Vector2(1280,720))
 fit_background()
 idle_portrait = ShaderMaterial.new()
 idle_portrait.shader = preload("res://assets/briefing/lobby-idle.gdshader")
 idle_portrait.set_shader_parameter("silhouette",preload("res://assets/briefing/lobby-mask.png"))
 idle_portrait.set_shader_parameter("grip",preload("res://assets/briefing/lobby-grip.png"))
 idle_portrait.set_shader_parameter("underlay",preload("res://assets/briefing/lobby-underlay.webp"))
 portrait.stretch_mode = TextureRect.STRETCH_SCALE
 portrait.material = idle_portrait
 fit_background()
 chrome("ЛОББИ")
 var mission := Story.mission(frontier)
 var corner := Vector2(32,362)
 var card := Vector2(332,320)
 panel(corner,card,INK)
 picture(ART[frontier],corner,Vector2(card.x,124))
 panel(Vector2(32,485),Vector2(card.x,3),GOLD)
 caption("КАМПАНИЯ   /   %02d ИЗ %02d" % [frontier+1,Story.MISSIONS.size()],Vector2(50,497),17,GOLD)
 caption(mission.name,Vector2(50,524),29,PAPER)
 caption(mission.brief,Vector2(50,568),19,Color("#d7dddf"),296)
 for i in Story.MISSIONS.size():
  panel(Vector2(50+i*60,663),Vector2(51,3),GOLD if i<=frontier else Color("#596268"))
 card_link(corner,card,"Текущая операция · "+mission.name,func(): navigate.emit("ИГРАТЬ"))

 panel(Vector2(982,86),Vector2(266,79),INK)
 picture("dossier",Vector2(982,86),Vector2(66,79))
 caption("ЛИЧНОЕ ДЕЛО",Vector2(1060,91),15,GOLD)
 caption("%d ОПЫТА   ·   ◈ %d" % [experience,balance],Vector2(1060,120),19,PAPER,178)
 card_link(Vector2(982,86),Vector2(266,79),"Открыть профиль",func(): navigate.emit("ПРОФИЛЬ"))

 panel(Vector2(970,524),Vector2(278,74),INK)
 picture("case-elite",Vector2(970,524),Vector2(92,74))
 caption("СНАБЖЕНИЕ",Vector2(1075,530),15,GOLD)
 caption("КЕЙСЫ   ›",Vector2(1075,553),23,PAPER)
 card_link(Vector2(970,524),Vector2(278,74),"Открыть кейсы",func(): navigate.emit("МАГАЗИН"))
 var play := button("В БОЙ",Vector2(970,614),Vector2(278,68),func(): navigate.emit("ИГРАТЬ"),true)
 play.add_theme_font_size_override("font_size",32)
 play.accessibility_name = "В бой · выбрать операцию"

func operations()->void:
 picture("lobby",Vector2.ZERO,Vector2(1280,720))
 panel(Vector2.ZERO,Vector2(1280,720),Color("#211e1bf4"))
 chrome("ИГРАТЬ")
 caption("ВЫБОР ОПЕРАЦИИ",Vector2(38,87),36)
 button("КАМПАНИЯ",Vector2(730,90),Vector2(220,45),func(): navigate.emit("ИГРАТЬ"),not infinite)
 button("БЕСКОНЕЧНЫЙ РЕЖИМ",Vector2(956,90),Vector2(286,45),func(): navigate.emit("БЕСКОНЕЧНЫЙ"),infinite)
 for i in Story.MISSIONS.size():
  var x:=38+i*243
  var chosen:=i==selected
  panel(Vector2(x,163),Vector2(230,349),GOLD if chosen else Color("#564d40"))
  var art:=picture(ART[i],Vector2(x+3,166),Vector2(224,343))
  if i>frontier or infinite: art.modulate=Color("#978d80")
  if chosen and not infinite: enter_art(art,3)
  panel(Vector2(x+3,426),Vector2(224,83),INK)
  caption("ЭТАП %02d"%[i+1],Vector2(x+16,434),15,GOLD)
  caption(Story.mission(i).name,Vector2(x+16,461),25)
  if not infinite:
   var pick:=Button.new()
   pick.flat=true
   pick.accessibility_name=Story.mission(i).name
   pick.tooltip_text=Story.mission(i).name
   pick.position=Vector2(x,163)
   pick.size=Vector2(230,349)
   pick.pressed.connect(func(): navigate.emit("этап%d"%i))
   add_child(pick)
 var locked:=selected>frontier and not infinite
 var title:String="БЕСКОНЕЧНАЯ СМЕНА" if infinite else Story.mission(selected).name
 caption(title,Vector2(39,547),30)
 var desc:String=Story.mission(selected).brief
 if locked: desc="Чтобы открыть этап, завершите операцию «%s»."%Story.mission(selected-1).name
 if infinite: desc="Выживайте во дворе проходной и ведите счёт побеждённым клеркам."
 caption(desc,Vector2(40,597),20,Color("#d0d6d9"),840)
 var start:=button("ЗАКРЫТО" if locked else "НАЧАТЬ    ›",Vector2(975,573),Vector2(266,70),func(): deploy.emit(infinite,selected),not locked)
 start.disabled=locked
