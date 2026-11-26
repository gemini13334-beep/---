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
	scene.reset_settings()
	check(scene.fps_limit == 60 and scene.advanced["sensitivity"] == 1.0,"Settings defaults")
	scene.advanced_sliders["sensitivity"].value = 1.5
	scene.advanced_sliders["weapons"].value = 0.0
	scene.save_settings()
	scene.advanced_sliders["sensitivity"].value = 0.5
	scene.load_settings()
	check(is_equal_approx(float(scene.advanced["sensitivity"]),1.5),"Sensitivity persistence")
	check(scene.fx_volume("shot") <= -79.0,"Weapon channel mute")
	scene.reset_settings()
	scene.start()
	check(scene.running and scene.hp == scene.max_hp and scene.level == 1,"Start initializes run")
	check(scene.crates.size() == 22,"Arena populated")
	var before: Vector3 = scene.hero.position
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(150,960)
	scene._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.position = touch.position+Vector2(90,0)
	scene._input(drag)
	check(scene.stick_base.visible,"Joystick appears on touch")
	scene._physics_process(0.1)
	check(scene.hero.position.x > before.x,"Touch movement")
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(scene.finger == -1 and scene.direction == Vector2.ZERO and not scene.stick_base.visible,"Pausing clears active touch")
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
	for id in scene.ABILITIES.size():
		scene.ranks[id] = 2
	scene.roll_offers()
	check(scene.offer_buttons.all(func(button: Button) -> bool: return "RANK 3" in button.text),"Upgrade offers show the stored rank")
	scene.elapsed = 45.0
	scene._physics_process(0.016)
	check(scene.boss_spawned,"Boss spawns")
	var boss = scene.enemies.back()
	scene.elapsed = float(boss.get_meta("next_pulse"))-0.5
	scene.update_boss_attack(boss)
	check(boss.has_meta("warning_ring") and is_instance_valid(boss.get_meta("warning_ring")),"Boss telegraphs attack")
	scene.hero.position = boss.position + Vector3(8,0,0)
	var safe_hp: float = scene.hp
	scene.elapsed += 0.6
	scene.update_boss_attack(boss)
	check(scene.hp == safe_hp,"Boss attack can be dodged")
	scene.hero.position = boss.position
	scene.elapsed = float(boss.get_meta("next_pulse"))
	scene.update_boss_attack(boss)
	check(scene.hp < safe_hp,"Boss attack damages within radius")
	scene.hp = 0
	scene._physics_process(0.016)
	check(not scene.running,"Death ends run")
	scene.start()
	check(scene.running and scene.level == 1 and scene.kills == 0 and scene.ranks.is_empty(),"Retry resets run")
	scene.sprint()
	scene.elapsed = 60.0
	scene._physics_process(0.016)
	check(not scene.running,"Sprint time limit")
	scene.enter_gate(1)
	check(not scene.running,"Higher gate requires its hunter level")
	scene.enter_gate(0)
	check(scene.running and scene.mode == 2,"Available gate can be entered")
	scene.elapsed = 45.0
	scene._physics_process(0.016)
	boss = scene.enemies.back()
	boss.set_meta("health",1)
	scene.hit_enemy(boss)
	scene._physics_process(0.016)
	check(not scene.running and scene.gate_wins[0] == 1,"Defeating the gate boss records one clear")
	scene.quest_progress[0] = scene.quest_target(0)
	var credits_before_claim: int = scene.credits
	scene.claim_quest(0)
	scene.claim_quest(0)
	check(scene.quest_tiers[0] == 1 and scene.quest_progress[0] == 0 and scene.credits == credits_before_claim+50,"Quest reward can be claimed once per tier")
	var points_before_spend: int = scene.stat_points
	scene.spend_stat(1)
	check(scene.hunter_stats[1] == 1 and scene.stat_points == points_before_spend-1,"Awakening attribute spends one point")
	scene.credits = 1234
	scene.best = 9876
	scene.select_hero(1)
	scene.credits = 1234
	scene.save_profile()
	scene.credits = 4321
	scene.save_profile()
	scene.credits = 0
	scene.best = 0
	scene.quest_tiers[0] = 0
	scene.gate_wins[0] = 0
	scene.hunter_stats[1] = 0
	scene.load_profile()
	check(scene.credits == 4321 and scene.best == 9876,"Profile reload")
	check(scene.selected == 1 and scene.owned.has(1) and scene.gate_wins[0] == 1 and scene.quest_tiers[0] == 1 and scene.hunter_stats[1] == 1,"Profile reload restores collection, gate, quest and stat progress")
	var broken := FileAccess.open("user://records.cfg",FileAccess.WRITE)
	broken.store_string("[gates]\nwins = [99, 0, 0, 0, 0, 0, 0]\n[invalid")
	broken.close()
	scene.load_profile()
	check(scene.credits == 1234 and scene.best == 9876 and scene.gate_wins[0] == 1,"Corrupt profile backup recovery")
	var legacy := ConfigFile.new()
	legacy.set_value("records","best",777)
	check(legacy.save("user://records.cfg") == OK,"Create legacy profile fixture")
	scene.load_profile()
	check(scene.best == 777 and scene.gate_wins[0] == 0 and scene.hunter_stats[1] == 0 and scene.selected == 0,"Legacy profile keeps its score and defaults missing sections")
	scene.queue_free()
	await process_frame
	print("Gameplay tests: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
