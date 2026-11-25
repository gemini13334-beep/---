extends SceneTree

var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	seed(42)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.start()
	check(scene.running and scene.hp == scene.max_hp and scene.level == 1,"Start initializes run")
	check(scene.crates.size() == 22,"Arena populated")
	var before: Vector3 = scene.hero.position
	scene.finger = 0
	scene.direction = Vector2.RIGHT
	scene._physics_process(0.1)
	check(scene.hero.position.x > before.x,"Touch movement")
	scene.direction = Vector2.ZERO
	check(scene.enemies.size() > 0,"Enemy spawns")
	var enemy = scene.enemies[0]
	enemy.set_meta("health",1)
	var old_score: int = scene.score
	scene.hit_enemy(enemy)
	check(scene.kills == 1 and scene.score > old_score,"Enemy defeat and scoring")
	scene.xp = 3
	scene._physics_process(0.016)
	check(scene.level == 2 and scene.choosing and scene.offers.size() == 3,"Level up offers")
	check(scene.offers[0] != scene.offers[1] and scene.offers[1] != scene.offers[2] and scene.offers[0] != scene.offers[2],"Distinct upgrade offers")
	scene.choose_upgrade(0)
	check(not scene.choosing and scene.ranks.size() > 0,"Upgrade selection")
	scene.elapsed = 45.0
	scene._physics_process(0.016)
	check(scene.boss_spawned,"Boss spawns")
	scene.hp = 0
	scene._physics_process(0.016)
	check(not scene.running,"Death ends run")
	scene.start()
	check(scene.running and scene.level == 1 and scene.kills == 0 and scene.ranks.is_empty(),"Retry resets run")
	scene.sprint()
	scene.elapsed = 60.0
	scene._physics_process(0.016)
	check(not scene.running,"Sprint time limit")
	scene.queue_free()
	await process_frame
	print("Gameplay tests: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
