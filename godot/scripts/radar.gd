extends Control

var player:Node3D
var objectives:Array[Node3D]=[]
var contacts:Array[Node3D]
var buildings:Array[Rect2]=[]
const CENTER:=Vector2(77,77)
const SCALE:=2.55

func _draw()->void:
 if not is_instance_valid(player): return
 draw_circle(CENTER,76,Color("#151a20d9"))
 draw_arc(CENTER,75,0,TAU,64,Color("#efc47b"),1.5,true)
 for building in buildings:
  draw_rect(Rect2(CENTER+building.position*SCALE,building.size*SCALE),Color("#6b6962"))
 for file in objectives:
  var mark:=CENTER+Vector2(file.position.x,file.position.z)*SCALE
  draw_colored_polygon(PackedVector2Array([mark+Vector2.UP*4,mark+Vector2.RIGHT*4,mark+Vector2.DOWN*4,mark+Vector2.LEFT*4]),Color("#ffd16e"))
 for e in contacts:
  if is_instance_valid(e):
   draw_circle(CENTER+Vector2(e.position.x,e.position.z)*SCALE,3,Color("#ff795d"))
 var point:=CENTER+Vector2(player.position.x,player.position.z)*SCALE
 var arrow:=PackedVector2Array()
 for v in [Vector2(0,-8),Vector2(5,5),Vector2(0,3),Vector2(-5,5)]:
  arrow.append(point+v.rotated(-player.rotation.y))
 draw_colored_polygon(arrow,Color("#ffcc71"))
