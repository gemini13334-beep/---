extends SceneTree

var game
var failures := 0

func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  printerr("FAIL ", message)

func _initialize() -> void:
 call_deferred("run")

func aim_at(point: Vector3) -> void:
 game.cam.look_at(point, Vector3.UP)

func run() -> void:
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 var lobby = game.menu_layer.get_child(0)
 lobby._process(2.6)
 check(lobby.idle_portrait.get_shader_parameter("phase") >= 2.6, "inspection clock")
 check(lobby.idle_portrait.get_shader_parameter("grip") != null, "original operator's grip layer")
 game.weapon_index = 1
 game._start(true)
 check(game.weapon_index == 1, "deployment retains selected equipment")
 game.weapon_index = 0
 game.set_physics_process(false)
 game.enemy_timer = 999.0
 var actors: Array[Node3D] = []
 for kind in 3:
  game._spawn_enemy(kind)
  var enemy: Node3D = game.enemies.back()
  var actor = enemy.get_child(0)
  check(actor.kind == kind and actor.pieces.size() >= 4, "visible equipment")
  enemy.rotation.y = PI
  enemy.position = Vector3(kind*4.0, 0, -3)
  enemy.set_meta("speed", 0.0)
  var ankle: int = actor.skeleton.find_bone("shin_L")
  if ankle == -1: ankle = actor.skeleton.find_bone("shin.L")
  check(ankle >= 0, "lower leg bone")
  var before: Transform3D = actor.skeleton.get_bone_global_pose(ankle)
  actor.advance(0.18,0.39)
  actor.advance(0.12,0.25)
  check(not before.is_equal_approx(actor.skeleton.get_bone_global_pose(ankle)), "moving skeleton")
  check(actor.animator.current_animation == actor.locomotion, "walking or running")
  actor.advance(0.30,0.0)
  check(actor.animator.current_animation == &"idle", "standing settles into idle")
  actors.append(enemy)
 await physics_frame
 for enemy in actors:
  aim_at(enemy.position+Vector3.UP*1.35)
  check(game._aim_hit(17).target == enemy, "visible torso is hittable for variant %d"%enemy.get_child(0).kind)
 var front := actors[0]
 var rear := actors[1]
 rear.position = front.position + Vector3.FORWARD * 3
 aim_at(front.position + Vector3.UP * 1.35)
 game.enemies.reverse()
 check(game._aim_hit(17).target == front, "nearest silhouette wins regardless of array order")
 check(game._aim_hit(2).target == null, "weapon range")
 rear.position.x = 6
 aim_at(front.position + Vector3(.68,1.48,0))
 check(game._aim_hit(17).target == null, "beside shoulder")
 aim_at(front.position + Vector3(0,2.05,0))
 check(game._aim_hit(17).target == null, "above helmet")
 var cover = game._box(game.world_root,"Cover",Vector3(0,0.88,0),Vector3(3,1.76,0.5),Color.GRAY,true)
 await physics_frame
 await physics_frame
 aim_at(front.position + Vector3.UP * 1.35)
 check(game._aim_hit(17).target == null, "body behind cover")
 cover.position.y = 0.40
 await physics_frame
 await physics_frame
 check(game._aim_hit(17).target == front, "visible upper body over low cover")
 game.hero.rotation.y = 0.28
 game.auto_fire = true
 game._physics_process(0.02)
 check(game.magazine_rounds[0] == 30, "auto miss leaves magazine intact")
 game.auto_fire = false
 game.fire_requested = true
 game._physics_process(0.02)
 check(game.magazine_rounds[0] == 29, "one manual miss consumes one round")
 game.hero.rotation.y = 0
 game.pitch = atan2(1.35-1.68, 7)
 game.auto_fire = true
 game.fire_timer = 0
 game._physics_process(0.02)
 check(game.magazine_rounds[0] == 28, "auto fires at visible body")
 game._physics_process(0.01)
 check(game.magazine_rounds[0] == 28, "cooldown")
 game.queue_free()
 await process_frame
 print("Patrol checks failed: ", failures)
 quit(failures)
