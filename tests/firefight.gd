extends SceneTree
var failures:=0
var game

func check(ok:bool,label:String)->void:
 if not ok:
  failures+=1
  printerr("FAIL ",label)

func _initialize()->void:call_deferred("run")

func run()->void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game._start(true)
 game.set_process(false)
 game.auto_fire=false
 game.enemy_timer=999
 game._spawn_enemy(0)
 var enemy:Node3D=game.enemies[0]
 enemy.position=Vector3(0,0,-5)
 enemy.rotation.y=PI
 enemy.set_meta("speed",0.0)
 enemy.set_meta("attack_wait",0.0)
 await physics_frame
 await physics_frame
 game._process(.02)
 check(float(enemy.get_meta("windup"))>0 and game.hp==100,"ranged shot has a warning")
 for i in 64:game._process(.02)
 check(game.hp<100 and game.hp>80,"stationary player takes damage at nine metres")
 var before:float=game.hp
 var cover=game._box(game.world_root,"Test cover",Vector3(0,1,0),Vector3(3,2,.6),Color.GRAY,true)
 await physics_frame
 await physics_frame
 enemy.set_meta("attack_wait",0.0)
 for i in 200:game._process(.02)
 check(game.hp==before and game.bolts.is_empty(),"cover blocks enemy fire")
 cover.queue_free()
 await physics_frame
 await physics_frame
 enemy.set_meta("attack_wait",0.0)
 game._process(.02)
 game.hero.position.x=2
 await physics_frame
 for i in 65:game._process(.02)
 check(game.hp==before,"sidestep after warning evades locked shot")
 for i in game.WEAPONS.size():
  game._select_slot(i)
  check(game.foreground.muzzle>=0 and game.foreground.animation.has_animation("reload"),"animated weapon and muzzle %d"%i)
  game.fire_timer=0
  game.fire_requested=true
  game._process(.016)
  check(game.magazine_rounds[i]==game.MAGAZINE_CAPACITIES[i]-1 and game.camera_kick>=.02,"shot and camera recoil %d"%i)
  var recoil:float=game.camera_kick
  game._process(.04)
  check(game.cam.rotation.x>game.pitch and game.camera_kick<recoil,"recoil moves sight and recovers")
  game._start_reload()
  check(game.foreground.animation.current_animation=="reload","reload clip %d"%i)
  game._process(game.reload_duration)
  check(game.magazine_rounds[i]==game.MAGAZINE_CAPACITIES[i],"reload restores selected magazine")
 game._start(true)
 check(game.bolts.is_empty(),"mission restart clears incoming shots")
 game.queue_free()
 await process_frame
 print("Firefight checks failed: ",failures)
 quit(failures)
