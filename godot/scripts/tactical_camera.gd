extends RefCounted
# Lightweight 4.3-compatible follow/damping inspired by Phantom Camera.
# Independent of the editor plugin; safe for Android Compatibility renderer.
static func follow(camera:Camera3D, target:Node3D, delta:float, combat:bool, recoil:float)->void:
 if not is_instance_valid(camera) or not is_instance_valid(target): return
 var distance:float=10.5 if combat else 8.0
 var desired:Vector3=target.global_position+Vector3(0.0,distance*0.85,distance)
 var alpha:float=1.0-exp(-5.0*maxf(delta,0.0))
 camera.global_position=camera.global_position.lerp(desired,alpha)
 if recoil>0.0:
  camera.global_position+=Vector3(randf_range(-1.0,1.0),randf_range(-0.4,0.4),0.0)*recoil
 camera.look_at(target.global_position+Vector3(0.0,1.0,0.0),Vector3.UP)
