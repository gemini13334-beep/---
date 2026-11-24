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
 game.set_physics_process(false)
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
 game._physics_process(.02)
 check(float(enemy.get_meta("windup"))>0 and game.hp==100,"ranged shot has a warning")
 for i in 64:game._physics_process(.02)
 check(game.hp<100 and game.hp>80,"stationary player takes damage at nine metres")
 var before:float=game.hp
 var cover=game._box(game.world_root,"Test cover",Vector3(0,1,0),Vector3(3,2,.6),Color.GRAY,true)
 await physics_frame
 await physics_frame
 enemy.set_meta("attack_wait",0.0)
 for i in 200:game._physics_process(.02)
 check(game.hp==before and game.bolts.is_empty(),"cover blocks enemy fire")
 cover.queue_free()
 await physics_frame
 await physics_frame
 enemy.set_meta("attack_wait",0.0)
 game._physics_process(.02)
 game.hero.position.x=2
 await physics_frame
 for i in 65:game._physics_process(.02)
 check(game.hp==before,"sidestep after warning evades locked shot")
 for i in game.WEAPONS.size():
  game._select_slot(i)
  check(game.foreground.muzzle>=0 and game.foreground.animation.has_animation("reload"),"animated weapon and muzzle %d"%i)
  check(game.foreground.gloves.size()==(1 if i==1 else 2),"one or two glove grips per weapon")
  for glove in game.foreground.gloves:
   check(glove.finger>=0 and glove.wrist>=0 and glove.global_position.is_finite(),"valid wrist and finger attachments")
  game.fire_timer=0
  game.fire_requested=true
  game._physics_process(.016)
  check(game.magazine_rounds[i]==game.MAGAZINE_CAPACITIES[i]-1 and game.camera_kick>=.02,"shot and camera recoil %d"%i)
  var recoil:float=game.camera_kick
  game._physics_process(.04)
  check(game.cam.rotation.x>game.pitch and game.camera_kick<recoil,"recoil moves sight and recovers")
  game._start_reload()
  check(game.foreground.animation.current_animation=="reload","reload clip %d"%i)
  game._physics_process(game.reload_duration)
  check(game.magazine_rounds[i]==game.MAGAZINE_CAPACITIES[i],"reload restores selected magazine")
 game._start(true)
 check(game.bolts.is_empty(),"mission restart clears incoming shots")
 game.set_physics_process(false)
 var player:CharacterBody3D=game.hero
 await physics_frame
 for frame in 5:player.step(Vector2.ZERO,1.0/60)
 var floor_y:=player.position.y
 check(player.grounded,"spawn settles onto floor")
 player.step(Vector2.RIGHT,1.0/60)
 var initial_speed:=player.velocity.x
 for frame in 35:player.step(Vector2.RIGHT,1.0/60)
 check(initial_speed>0 and initial_speed<player.velocity.x and absf(player.velocity.x-6)<.01,"accelerates to movement speed")
 for frame in 18:player.step(Vector2.ZERO,1.0/60)
 check(player.velocity.x<.01,"brakes at rest")
 player.queue_jump()
 var apex:=floor_y
 for frame in 95:
  player.step(Vector2.ZERO,1.0/60)
  apex=maxf(apex,player.position.y)
 check(apex>floor_y+.70 and absf(player.position.y-floor_y)<.02 and player.grounded,"jump arc and landing")
 player.toggle_stance()
 for frame in 30:player.step(Vector2.ZERO,1.0/60)
 check(player.crouching and player.eye_height<1.08,"crouch lowers camera and collision shape")
 var ceiling=game._box(game.arena,"Low ceiling",player.position+Vector3.UP*1.50,Vector3(1,.18,1),Color.GRAY,true)
 await physics_frame
 await physics_frame
 player.toggle_stance()
 check(player.crouching,"standing blocked by low ceiling")
 ceiling.queue_free()
 await physics_frame
 await physics_frame
 player.toggle_stance()
 check(not player.crouching,"can stand after leaving cover")
 for i in 30:game._impact_at(Vector3(i*.04,.2,0),Vector3.UP)
 check(game.marks.size()==24,"bounded impact pool")
 game.queue_free()
 await process_frame
 print("Firefight checks failed: ",failures)
 quit(failures)
