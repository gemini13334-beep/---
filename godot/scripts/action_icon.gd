extends Control
var glyph:=""
func _draw()->void:
 var c:=size*.5
 var ink:=Color("#f5eada")
 if glyph=="pause":
  for x in [-5,2]:draw_rect(Rect2(c+Vector2(x,-7),Vector2(3,14)),ink)
 elif glyph=="reload":
  draw_arc(c,12,-PI*.70,PI*1.04,32,ink,2.5,true)
  draw_colored_polygon(PackedVector2Array([c+Vector2(-17,-2),c+Vector2(-8,-3),c+Vector2(-11,5)]),ink)
 else:
  draw_arc(c,16,0,TAU,40,ink,1.6,true)
  for v in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:draw_line(c+v*9,c+v*21,ink,2,true)
  draw_circle(c,2,ink)
