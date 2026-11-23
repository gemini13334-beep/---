extends SceneTree

var game
var failures := 0

func check(ok: bool, label: String) -> void:
 if not ok:
  failures += 1
  printerr("FAIL ",label)

func _initialize() -> void:
 call_deferred("run")

func walk_to(point: Vector2) -> void:
 for step in 300:
  var offset := point-Vector2(game.hero.position.x,game.hero.position.z)
  if offset.length()<0.10: return
  game.joystick=offset.normalized()
  game._process(minf(1.0/60,offset.length()/6.0))
  if not game.playing: break
 check(false,"unreachable "+str(point))

func run() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.stage=4
 game.set_process(false)
 var names: Array[String] = []
 for stage in [2,3,4]:
  game._start(false,stage)
  game.enemy_timer=999
  game.auto_fire=false
  await physics_frame
  await physics_frame
  var world=game.registry
  names.append(world.objective_status())
  check(game.location_id==stage,"stage selects location")
  var required: int = [1,2,1][stage-2]
  check(world.files.size()==required and game.radar.objectives.size()==required,"initial markers")
  game.kills=game._target()
  game._process(0)
  check(game.playing,"defence alone cannot win")
  game.kills=0
  if stage==4:
   game.hero.position=world.SIGNATURE
   game.hero.position.y=0
   game._process(.01)
   check(world.collected==0,"cannot sign before collection")
   game.hero.position=Vector3(0,0,9)
  while not world.files.is_empty():
   var marker: Vector3=world.files.back().position
   # In HQ the centre map table divides the hall; the east service aisle bypasses it.
   if stage==3:
    walk_to(Vector2(2.9,game.hero.position.z))
    walk_to(Vector2(2.9,marker.z+1.02))
   else:
    walk_to(Vector2(0,game.hero.position.z))
    walk_to(Vector2(0,marker.z+1.02))
   walk_to(Vector2(marker.x,marker.z+1.02))
   if world.files.size()>0 and world.files.back().position==marker:
    check(false,"objective not collected")
    break
   check(game.document_label.text==world.objective_status(),"objective HUD")
  game.joystick=Vector2.ZERO
  check(game.playing and game.radar.objectives.is_empty(),"objectives alone cannot win")
  game.kills=game._target()
  game._process(.01)
  check(not game.playing,"mission completes")
  game._start(false,stage)
  check(game.registry.files.size()==required,"replay resets mission")
 check(names[0]!=names[1] and names[1]!=names[2],"distinct mission goals")
 game._start(true)
 check(game.location_id==0 and game.registry==null and game.radar.objectives.is_empty(),"endless courtyard")
 game.queue_free()
 await process_frame
 print("Story wing checks failed: ",failures)
 quit(failures)
