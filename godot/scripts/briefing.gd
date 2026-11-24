extends Control

signal navigate(section: String)
signal deploy(endless: bool, mission: int)

const Story = preload("res://scripts/story.gd")
const FACE = preload("res://assets/type/interface.tres")
const GOLD := Color("#f2a46f")
const INK := Color("#272420f5")
const ART := ["mission-0","mission-1","mission-2","mission-3","mission-4"]
const RUST := Color("#be5137")
const CHARCOAL := Color("#1c1b19")
const PAPER := Color("#f3e5cb")
var frontier: int
var selected: int
var infinite := false
var experience: int
var balance: int
var idle_portrait: ShaderMaterial
var idle_time := 0.0

func _ready() -> void:
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
 b.position=at
 b.size=extent
 b.add_theme_font_override("font", FACE)
 b.add_theme_font_size_override("font_size",25 if primary else 20)
 for state in ["normal","hover","pressed","focus","disabled"]:
  var style:=StyleBoxFlat.new()
  style.bg_color=RUST if primary else Color("#2b2925ed")
  if state in ["hover","pressed"]: style.bg_color=style.bg_color.lightened(0.15)
  if state=="disabled": style.bg_color=Color("#393630")
  if state=="focus":
   style.draw_center=false
   style.set_border_width_all(2)
   style.border_color=GOLD
  b.add_theme_stylebox_override(state,style)
 if primary:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
   b.add_theme_color_override(state,Color("#fff3df"))
 b.pressed.connect(action)
 add_child(b)
 return b

func chrome(active:String)->void:
 panel(Vector2.ZERO,Vector2(1280,64),Color("#191816fa"))
 var insignia:=TextureRect.new()
 insignia.texture=preload("res://icon.svg")
 insignia.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 insignia.position=Vector2(17,12)
 insignia.size=Vector2(40,40)
 insignia.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(insignia)
 caption(Story.TITLE,Vector2(67,11),28,PAPER)
 var tabs:=["ЛОББИ","ИГРАТЬ","ИНВЕНТАРЬ","СНАРЯЖЕНИЕ","МАГАЗИН","ПРОФИЛЬ","НАСТРОЙКИ"]
 for i in tabs.size():
  var key:String=tabs[i]
  var x:=276+i*141
  button(key,Vector2(x,0),Vector2(139,62),func(): navigate.emit(key))
  if active==key: panel(Vector2(x,59),Vector2(139,5),RUST)

func _process(delta: float) -> void:
 if idle_portrait != null:
  idle_time = fmod(idle_time + delta, 3600.0)
  idle_portrait.set_shader_parameter("phase", idle_time)

func lobby()->void:
 var portrait := picture("lobby",Vector2(0,64),Vector2(1280,720))
 idle_portrait = ShaderMaterial.new()
 idle_portrait.shader = preload("res://assets/briefing/lobby-idle.gdshader")
 idle_portrait.set_shader_parameter("silhouette",preload("res://assets/briefing/lobby-mask.png"))
 idle_portrait.set_shader_parameter("grip",preload("res://assets/briefing/lobby-grip.png"))
 idle_portrait.set_shader_parameter("underlay",preload("res://assets/briefing/lobby-underlay.webp"))
 portrait.material = idle_portrait
 chrome("ЛОББИ")
 panel(Vector2(28,315),Vector2(350,354),INK)
 var scene_photo:=picture(ART[frontier],Vector2(28,315),Vector2(350,139))
 enter_art(scene_photo,-8)
 panel(Vector2(28,451),Vector2(350,4),RUST)
 caption("ТЕКУЩАЯ ОПЕРАЦИЯ",Vector2(48,468),17,GOLD)
 caption(Story.mission(frontier).name,Vector2(48,494),32,PAPER)
 caption(Story.mission(frontier).brief,Vector2(48,546),19,Color("#d7cbb8"),306)
 for i in Story.MISSIONS.size():
  panel(Vector2(48+i*62,649),Vector2(54,4),GOLD if i<=frontier else Color("#5f5547"))
 panel(Vector2(976,89),Vector2(276,92),INK)
 picture("dossier",Vector2(976,89),Vector2(76,92))
 caption("ЛИЧНОЕ ДЕЛО",Vector2(1066,97),15,GOLD)
 caption("%d ОПЫТА"%experience,Vector2(1066,119),21,PAPER)
 caption("◈  %d"%balance,Vector2(1066,149),17,PAPER)
 var supply:=picture("case-elite",Vector2(990,485),Vector2(260,99))
 enter_art(supply,10)
 button("КЕЙСЫ   ›",Vector2(990,554),Vector2(260,49),func(): navigate.emit("МАГАЗИН"))
 button("ИГРАТЬ    ›",Vector2(990,624),Vector2(260,66),func(): navigate.emit("ИГРАТЬ"),true)

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
