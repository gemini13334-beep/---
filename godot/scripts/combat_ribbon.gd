extends Control
const FACE=preload("res://assets/type/interface.tres")
const GOLD=Color("#f3cd82")
const PALE=Color("#f4eee1")
const DARK=Color("#10171fd6")
var game
var emblem:=preload("res://icon.svg")
var slots:Array[Texture2D]=[]
var portraits:Array[Texture2D]=[]
var feed:=""
var feed_weapon:=0
var feed_time:=0.0

func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 for i in 5: slots.append(load("res://assets/armory/catalog/slot-%d.png"%i))
 for i in 4: portraits.append(load("res://assets/armory/catalog/portrait-%d.webp"%i))

func record(kind:int)->void:
 feed=["Инспектор","Курьер","Броневик"][kind]
 feed_weapon=game.weapon_index
 feed_time=2.45

func _process(delta:float)->void:
 if not is_visible_in_tree(): return
 feed_time=maxf(0,feed_time-delta)
 queue_redraw()

func _text(at:Vector2,message:String,pixels:int,color:Color)->void:
 draw_string_outline(FACE,at,message,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,4,Color("#171615ab"))
 draw_string(FACE,at,message,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _plate(area:Rect2,color:Color)->void:
 draw_rect(area,color)
 draw_rect(Rect2(area.position+Vector2(0,area.size.y-2),Vector2(area.size.x,2)),GOLD*.76)

func _draw()->void:
 if not game or not game.playing:return
 var mid:=size.x*.5
 var bottom:=size.y
 draw_polygon(PackedVector2Array([Vector2(0,bottom-98),Vector2(size.x,bottom-98),size,Vector2(0,bottom)]),PackedColorArray([Color("#10131400"),Color("#10131400"),Color("#101314a8"),Color("#101314a8")]))
 var y:=size.y-28
 draw_line(Vector2(125,y),Vector2(mid-26,y),Color("#ffe4ab72"),1,true)
 draw_line(Vector2(mid+26,y),Vector2(size.x-125,y),Color("#ffe4ab72"),1,true)
 draw_circle(Vector2(mid,y),22,Color("#19202be3"))
 draw_arc(Vector2(mid,y),21,0,TAU,48,GOLD,1.5,true)
 draw_texture_rect(emblem,Rect2(mid-15,y-15,30,30),false)
 _plate(Rect2(mid-48,10,96,54),DARK)
 _plate(Rect2(mid-98,10,45,45),Color("#364955f5"))
 draw_texture_rect(portraits[0],Rect2(mid-98,10,45,45),false)
 var counts:=[0,0,0]
 for enemy in game.enemies: counts[enemy.get_child(0).kind]+=1
 for i in 3:
  var x:=mid+53+i*39
  var alive:bool=counts[i]>0
  _plate(Rect2(x,10,36,40),Color("#593d31e6") if alive else Color("#19222bc7"))
  draw_texture_rect(portraits[i+1],Rect2(x,11,36,36),false,Color.WHITE if alive else Color("#797978"))
  if counts[i]>1:_text(Vector2(x+21,47),str(counts[i]),13,PALE)
 if feed_time>0:
  var x:=size.x-256
  _plate(Rect2(x,77,233,34),DARK)
  _text(Vector2(x+12,100),"ВЫ",17,GOLD)
  draw_texture_rect(slots[feed_weapon],Rect2(x+49,83,62,20),false,PALE)
  _text(Vector2(x+120,100),feed,18,PALE)
