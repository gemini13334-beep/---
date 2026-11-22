extends Node3D

const MODEL = preload("res://assets/models/inspector.glb")
var limbs:Array[Node3D]=[]
var phase:=0.0
var stride:=0.0

func _ready()->void:
 var model:=MODEL.instantiate()
 add_child(model)
 for joint in ["LeftArm","RightArm","LeftLeg","RightLeg"]:
  limbs.append(model.find_child(joint,true,false) as Node3D)

func advance(delta:float, distance:float)->void:
 phase+=distance*4.8
 stride=move_toward(stride,1.0 if distance>0.001 else 0.0,delta*7)
 var swing:=sin(phase)*stride
 limbs[0].rotation.x=swing*0.35
 limbs[1].rotation.x=-swing*0.35
 limbs[2].rotation.x=-swing*0.44
 limbs[3].rotation.x=swing*0.44
 position.y=absf(cos(phase))*0.025*stride-0.055
