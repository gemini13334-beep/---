extends CharacterBody3D

const STAND_HEIGHT:=1.80
const CROUCH_HEIGHT:=1.14
var hull:=CollisionShape3D.new()
var capsule:=CapsuleShape3D.new()
var standing_volume:=CapsuleShape3D.new()
var crouching:=false
var grounded:=false
var eye_height:=1.68
var landing_offset:=0.0
var jump_buffer:=0.0
var grace:=0.0

func _ready()->void:
 capsule.radius=.36
 standing_volume.radius=.36
 standing_volume.height=STAND_HEIGHT
 hull.shape=capsule
 collision_layer=2
 add_child(hull)
 reset_motion()

func reset_motion()->void:
 velocity=Vector3.ZERO
 grounded=false
 grace=0.0
 jump_buffer=0.0
 landing_offset=0.0
 crouching=false
 eye_height=1.68
 _set_height(STAND_HEIGHT)

func _set_height(height:float)->void:
 capsule.height=height
 hull.position.y=height*.5+.02

func toggle_stance()->void:
 if crouching:
  var query:=PhysicsShapeQueryParameters3D.new()
  query.shape=standing_volume
  query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3.UP*(STAND_HEIGHT*.5+.045))
  query.collision_mask=1
  query.exclude=[get_rid()]
  if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return
 crouching=not crouching
 _set_height(CROUCH_HEIGHT if crouching else STAND_HEIGHT)

func queue_jump()->void:
 jump_buffer=.12

func step(input:Vector2,dt:float)->void:
 if dt<=0:return
 var wish:=Vector3(input.x,0,input.y).rotated(Vector3.UP,rotation.y)* (2.6 if crouching else 6.0)
 var lateral:=Vector3(velocity.x,0,velocity.z)
 var accel:=34.0 if input.length_squared()>.001 else 41.0
 lateral=lateral.move_toward(wish,(accel if grounded else accel*.38)*dt)
 velocity.x=lateral.x
 velocity.z=lateral.z
 if grounded:grace=.085
 else:grace=maxf(0,grace-dt)
 if jump_buffer>0 and grace>0 and not crouching:
  velocity.y=5.8
  grace=0
  jump_buffer=0
 jump_buffer=maxf(0,jump_buffer-dt)
 velocity.y=maxf(-35,velocity.y-16.8*dt)
 var was_grounded:=grounded
 var fall_speed:=-velocity.y
 grounded=false
 var remaining:=velocity*dt
 for contact in 4:
  if remaining.length_squared()<.00000001:break
  var hit:=move_and_collide(remaining)
  if hit==null:break
  var normal:=hit.get_normal()
  if normal.y>.70:grounded=true
  remaining=hit.get_remainder().slide(normal)
  if velocity.dot(normal)<0:velocity=velocity.slide(normal)
 if grounded and not was_grounded and fall_speed>2.2:
  landing_offset=minf(.115,fall_speed*.014)
 landing_offset=move_toward(landing_offset,0,dt*.72)
 eye_height=lerpf(eye_height,1.03 if crouching else 1.68,1-exp(-dt*14.0))
