extends Node

# Cycles per metre, body lift, body sway and joint swing at full speed.
const GAIT := {
	"vega": Vector4(0.8,0.0,0.045,0.0),
	"fox": Vector4(0.8,0.0,0.045,0.0),
	"amber": Vector4(0.8,0.0,0.040,0.0),
	"north": Vector4(0.8,0.0,0.040,0.0),
	"hero": Vector4(0.81,0.056,0.11,0.18),
	"cyborg": Vector4(1.12,0.033,0.046,0.66),
	"inferno": Vector4(0.86,0.074,0.074,0.52),
	"ghost": Vector4(0.68,0.10,0.092,0.34),
	"titan": Vector4(0.70,0.067,0.105,0.37),
	"cryo": Vector4(0.93,0.038,0.054,0.49),
	"enemy": Vector4(1.17,0.033,0.078,0.42),
	"enemy_fast": Vector4(0.86,0.077,0.20,0.34),
	"enemy_armored": Vector4(1.75,0.018,0.036,0.12),
	"boss_overlord": Vector4(0.49,0.073,0.09,0.30),
	"boss_crystal": Vector4(0.51,0.087,0.15,0.25),
	"boss_inferno": Vector4(0.60,0.057,0.095,0.18),
	"buggy": Vector4(0.65,0.030,0.07,0.0),
	"hovercraft": Vector4(0.56,0.071,0.12,0.0),
	"tank": Vector4(0.83,0.023,0.046,0.0),
	"mech": Vector4(0.57,0.046,0.056,0.36),
}
const FLOATING := ["hero","ghost","enemy_fast","hovercraft"]

var host: Node3D
var art: Node3D
var asset: String
var gait: Vector4
var base_position: Vector3
var base_rotation: Vector3
var previous_position: Vector3
var local_motion := Vector3.ZERO
var phase := 0.0
var idle := 0.0
var stride := 0.0
var recoil := 0.0
var hit := 0.0
var hit_direction := Vector3.ZERO
var aiming := 0.0
var aim_yaw := 0.0
var charging := false
var windup := 0.0
var strike := 0.0
var floating := false
var weapon: Node3D
var weapon_position := Vector3.ZERO
var leg_left: Node3D
var leg_right: Node3D
var leg_rear_left: Node3D
var leg_rear_right: Node3D
var panel_left: Node3D
var panel_right: Node3D
var axis_top: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var muzzle_bone := -1
var one_shot := 0.0
var measured_speed := 0.0
var defeated := false

func configure(actor: Node3D, model: Node3D, model_name: String) -> void:
	host = actor
	art = model
	asset = model_name
	gait = GAIT[model_name]
	floating = model_name in FLOATING
	base_position = art.position
	base_rotation = art.rotation
	previous_position = host.position
	weapon = art.find_child("WeaponPivot",true,false) as Node3D
	if weapon != null:
		weapon_position = weapon.position
	leg_left = art.find_child("LegLeft",true,false) as Node3D
	leg_right = art.find_child("LegRight",true,false) as Node3D
	leg_rear_left = art.find_child("LegRearLeft",true,false) as Node3D
	leg_rear_right = art.find_child("LegRearRight",true,false) as Node3D
	panel_left = art.find_child("PanelLeft",true,false) as Node3D
	panel_right = art.find_child("PanelRight",true,false) as Node3D
	axis_top = art.find_child("AxisTop",true,false) as Node3D
	var players := art.find_children("*","AnimationPlayer",true,false)
	var skeletons := art.find_children("*","Skeleton3D",true,false)
	if not players.is_empty() and not skeletons.is_empty():
		animation = players[0] as AnimationPlayer
		skeleton = skeletons[0] as Skeleton3D
		muzzle_bone = skeleton.find_bone("Muzzle")
		for clip in ["Idle","Walk","Run"]:
			if animation.has_animation(clip):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		reset_clips()

func fire(target: Vector3) -> void:
	var local_target := host.to_local(target)
	if Vector2(local_target.x,local_target.z).length_squared() > 0.01:
		aim_yaw = atan2(local_target.x,local_target.z)
	aiming = 0.15
	recoil = 1.0
	art.rotation.y = base_rotation.y+aim_yaw
	apply_weapon()
	if not defeated and one_shot <= 0.10 and (animation == null or measured_speed < 0.9):
		play_event("Fire",0.20)

func muzzle_position() -> Vector3:
	if muzzle_bone == -1:
		return Vector3.INF
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle_bone).origin)

func play_event(clip: StringName, hold: float) -> void:
	if animation == null or not animation.has_animation(clip):
		return
	animation.speed_scale = 1.0
	animation.play(clip,0.06)
	one_shot = hold

func fall() -> bool:
	if animation == null or not animation.has_animation("Fall"):
		return false
	if not defeated:
		defeated = true
		play_event("Fall",1.0)
	return true

func reset_clips() -> void:
	defeated = false
	one_shot = 0.0
	stride = 0.0
	measured_speed = 0.0
	if animation != null and animation.has_animation("Idle"):
		animation.play("Idle",0.10)

func impact(from_world: Vector3) -> void:
	var direction := host.to_local(from_world)
	direction.y = 0.0
	hit_direction = -direction.normalized() if direction.length_squared() > 0.0025 else Vector3.BACK
	hit = 1.0
	if not defeated:
		play_event("Hit",0.29)

func release() -> void:
	charging = false
	strike = 1.0

func _process(dt: float) -> void:
	if not is_instance_valid(host) or dt <= 0:
		return
	var offset := host.position-previous_position
	previous_position = host.position
	if not host.is_visible_in_tree() or defeated:
		return
	offset.y = 0.0
	if offset.length_squared() > 2.25:
		offset = Vector3.ZERO
	phase = fposmod(phase + offset.length()*gait.x*TAU,TAU)
	var smoothing := 1.0-exp(-13.0*dt)
	var speed := offset.length()/dt
	measured_speed = lerpf(measured_speed,speed,smoothing)
	var velocity := (host.transform.basis.inverse()*offset/dt).limit_length(7.0)
	local_motion = local_motion.lerp(velocity/7.0,smoothing)
	stride = lerpf(stride,minf(offset.length()/dt/3.0,1.0),smoothing)
	idle = fposmod(idle + dt*2.8,TAU)
	recoil = move_toward(recoil,0.0,dt*6.5)
	hit = move_toward(hit,0.0,dt*4.4)
	aiming = maxf(0.0,aiming-dt)
	windup = move_toward(windup,1.0 if charging else 0.0,dt*(0.92 if charging else 5.0))
	strike = move_toward(strike,0.0,dt*3.8)
	one_shot = maxf(0.0,one_shot-dt)
	if animation != null and one_shot == 0.0:
		var clip := &"Idle"
		if measured_speed > 2.40:
			clip = &"Run"
		elif measured_speed > 0.42:
			clip = &"Walk"
		if animation.current_animation != clip and animation.has_animation(clip):
			animation.play(clip,0.15)
		if clip == &"Idle":
			animation.speed_scale = 1.0
		else:
			var pace := 5.5 if clip == &"Run" else 1.6
			animation.speed_scale = clampf(measured_speed/pace,0.60,1.72)

	var lift := sin(idle)*0.014
	if floating:
		lift += (0.034+sin(idle*2.0)*0.026)*(1.0-stride)
	lift += absf(sin(phase))*stride*gait.y
	var windup_lift := -windup*0.13
	var windup_pitch := -windup*0.16
	match asset:
		"boss_crystal":
			windup_lift = windup*0.055
			windup_pitch = windup*0.13
		"boss_inferno":
			windup_lift = sin(windup*PI)*0.06
			windup_pitch = -windup*0.24
	art.position = base_position+hit_direction*(hit*hit*0.10)
	art.position.y += lift+windup_lift+strike*0.052
	art.rotation.x = base_rotation.x+local_motion.z*gait.z+windup_pitch+strike*0.22+hit_direction.z*hit*0.12
	art.rotation.y = lerp_angle(art.rotation.y,base_rotation.y+(aim_yaw if aiming > 0.0 else 0.0),smoothing)
	art.rotation.z = base_rotation.z-local_motion.x*gait.z+sin(phase)*stride*gait.z*0.4-hit_direction.x*hit*0.15
	var camera := host.get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_squared_to(host.global_position) < 1225.0:
		apply_parts()

func apply_parts() -> void:
	var swing := sin(phase)*stride*gait.w
	var toe := sin(phase+PI*0.5)*stride*gait.w
	pose_leg(leg_left,swing,toe,1.0)
	pose_leg(leg_right,-swing,-toe,-1.0)
	pose_leg(leg_rear_left,-swing,-toe,1.0)
	pose_leg(leg_rear_right,swing,toe,-1.0)

	var panel_pitch := sin(idle)*0.035+strike*0.42
	var panel_flare := stride*gait.w*0.28
	match asset:
		"hero":
			panel_pitch += stride*0.21
		"ghost":
			panel_pitch -= stride*0.24
			panel_flare += sin(idle)*0.10
		"enemy_fast":
			panel_pitch += local_motion.x*0.33
		"boss_overlord":
			panel_pitch -= windup*0.79
			panel_flare += windup*0.16
		"boss_crystal":
			panel_pitch -= windup*0.40
			panel_flare += windup*0.40
		"boss_inferno":
			panel_pitch += windup*0.43
			panel_flare += windup*0.16
	if panel_left != null:
		panel_left.rotation = Vector3(panel_pitch,-panel_flare,-panel_flare*0.55)
	if panel_right != null:
		panel_right.rotation = Vector3(panel_pitch,panel_flare,panel_flare*0.55)
	if axis_top != null:
		match asset:
			"hero":
				axis_top.scale = Vector3(1.0,1.0+sin(idle)*0.036-hit*0.09,1.0)
			"boss_overlord":
				axis_top.rotation.z = windup*0.64+strike*0.25
			"boss_inferno":
				axis_top.rotation.x = windup*0.61
			"tank", "enemy_armored":
				axis_top.rotation.y = sin(idle)*0.12
	apply_weapon()

func pose_leg(leg: Node3D,swing: float,toe: float,side: float) -> void:
	if leg == null:
		return
	leg.rotation.x = swing
	if asset == "enemy":
		leg.rotation.y = swing*side*0.48
		leg.rotation.z = toe*side*0.31

func apply_weapon() -> void:
	if weapon == null:
		return
	weapon.position = weapon_position+Vector3(0,recoil*0.018,-recoil*recoil*0.13)
	weapon.rotation.x = -recoil*0.105
