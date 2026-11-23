extends Control

signal navigate(section: String)
signal deploy(endless: bool, mission: int)

const Story = preload("res://scripts/story.gd")
const FACE = preload("res://assets/type/interface.tres")
const GOLD := Color("#ffbd58")
const INK := Color("#151d24ed")
const ART := ["sector-0","sector-1","room-0","sector-2","room-1"]
var frontier: int
var selected: int
var infinite := false
var experience: int
var balance: int
var idle_portrait: ShaderMaterial
var idle_time := 0.0

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
 for state in ["normal","hover","pressed","focus"]:
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("#efab43") if primary else Color("#1b242dd9")
  if state in ["hover","pressed"]: style.bg_color=style.bg_color.lightened(0.15)
  if state=="focus":
   style.draw_center=false
   style.set_border_width_all(2)
   style.border_color=GOLD
  b.add_theme_stylebox_override(state,style)
 if primary:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
   b.add_theme_color_override(state,Color("#191d20"))
 b.pressed.connect(action)
 add_child(b)
 return b

func chrome(active:String)->void:
 panel(Vector2.ZERO,Vector2(1280,64),Color("#101820f5"))
 caption("ОТПУСК",Vector2(29,5),34)
 caption("/ TACTICAL",Vector2(144,19),19,GOLD)
 var tabs:=["ЛОББИ","ИГРАТЬ","ИНВЕНТАРЬ","СНАРЯЖЕНИЕ","МАГАЗИН","ПРОФИЛЬ","НАСТРОЙКИ"]
 for i in tabs.size():
  var key:String=tabs[i]
  var x:=276+i*141
  button(key,Vector2(x,0),Vector2(139,62),func(): navigate.emit(key))
  if active==key: panel(Vector2(x,61),Vector2(139,3),GOLD)

func _process(delta: float) -> void:
 if idle_portrait != null:
  idle_time = fmod(idle_time + delta, 3600.0)
  idle_portrait.set_shader_parameter("phase", idle_time)

func lobby()->void:
 var portrait := picture("lobby",Vector2(0,64),Vector2(1280,720))
 idle_portrait = ShaderMaterial.new()
 idle_portrait.shader = preload("res://assets/briefing/lobby-idle.gdshader")
 idle_portrait.set_shader_parameter("silhouette",preload("res://assets/briefing/lobby-mask.png"))
 portrait.material = idle_portrait
 chrome("ЛОББИ")
 panel(Vector2(32,324),Vector2(352,316),INK)
 picture(ART[frontier],Vector2(32,324),Vector2(352,118))
 panel(Vector2(32,442),Vector2(352,3),GOLD)
 caption("КАМПАНИЯ   /   ЭТАП %02d"%[frontier+1],Vector2(52,463),16,GOLD)
 caption(Story.mission(frontier).name,Vector2(52,486),34)
 caption(Story.mission(frontier).brief,Vector2(52,546),18,Color("#d2d9dc"),300)
 panel(Vector2(1010,82),Vector2(240,136),INK)
 caption("ЛИЧНОЕ ДЕЛО",Vector2(1029,95),16,GOLD)
 caption("%d   ОПЫТА"%experience,Vector2(1029,124),25)
 caption("%d   КРЕДИТОВ"%balance,Vector2(1029,164),20,Color("#ddd5c6"))
 button("ИГРАТЬ    ›",Vector2(990,624),Vector2(260,66),func(): navigate.emit("ИГРАТЬ"),true)

func operations()->void:
 picture("lobby",Vector2.ZERO,Vector2(1280,720))
 panel(Vector2.ZERO,Vector2(1280,720),Color("#14202aeb"))
 chrome("ИГРАТЬ")
 caption("ВЫБОР ОПЕРАЦИИ",Vector2(38,87),36)
 button("КАМПАНИЯ",Vector2(730,90),Vector2(220,45),func(): navigate.emit("ИГРАТЬ"),not infinite)
 button("БЕСКОНЕЧНЫЙ РЕЖИМ",Vector2(956,90),Vector2(286,45),func(): navigate.emit("БЕСКОНЕЧНЫЙ"),infinite)
 for i in Story.MISSIONS.size():
  var x:=38+i*243
  var chosen:=i==selected
  panel(Vector2(x,163),Vector2(230,349),GOLD if chosen else Color("#4b5660"))
  var art:=picture(ART[i],Vector2(x+3,166),Vector2(224,343))
  if i>frontier or infinite: art.modulate=Color("#92999e")
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
