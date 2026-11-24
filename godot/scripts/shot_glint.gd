extends Control
var rig:Control
var camera:Camera3D
var impact:=Vector3.ZERO
var life:=0.0

func shoot(point:Vector3)->void:
 impact=point
 life=.065
 queue_redraw()

func _process(delta:float)->void:
 if life<=0: return
 life=maxf(0,life-delta)
 queue_redraw()

func _draw()->void:
 if life<=0 or camera.is_position_behind(impact): return
 var start:Vector2=rig.muzzle_pixel()
 var end:=camera.unproject_position(impact)
 var axis:=start.direction_to(end)
 var side:=axis.orthogonal()
 var alpha:=life/.065
 draw_line(start,end,Color(1,.78,.44,alpha*.68),1.4,true)
 var tip:=start+axis*minf(16,start.distance_to(end))
 draw_colored_polygon(PackedVector2Array([start-side*2.5,tip,start+side*2.5]),Color(1,.85,.55,alpha))
 draw_circle(start,2.0,Color(1,.97,.84,alpha))
