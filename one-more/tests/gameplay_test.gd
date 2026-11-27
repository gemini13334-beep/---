extends SceneTree

const Landscape = preload("res://landscape.gd")

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
	check(scene.graphics_preset_name() == "MEDIUM","Default settings match the visible medium preset")
	scene.cycle_preset()
	check(scene.graphics_preset_name() == "HIGH" and root.msaa_3d == Viewport.MSAA_2X and scene.world_light.shadow_enabled,"High preset applies MSAA and shadows")
	scene.advanced_sliders["particles"].value = 0.55
	check(scene.graphics_preset_name() == "CUSTOM","Edited preset reports custom graphics")
	scene.reset_settings()
	scene.advanced_sliders["sensitivity"].value = 1.5
	scene.advanced_sliders["weapons"].value = 0.0
	scene.save_settings()
	scene.advanced_sliders["sensitivity"].value = 0.5
	scene.load_settings()
	check(is_equal_approx(float(scene.advanced["sensitivity"]),1.5),"Sensitivity persistence")
	check(scene.fx_volume("shot") <= -79.0,"Weapon channel mute")
	var hits := scene.sounds["hit"] as AudioStreamRandomizer
	var pickups := scene.sounds["pickup"] as AudioStreamRandomizer
	check(hits != null and hits.get_streams_count() == 3 and pickups != null and pickups.get_streams_count() == 2,
		"The live sound table selects bundled hit and pickup variations")
	var interface_font: Font = scene.hud_panel.theme.default_font
	check(interface_font.has_char("Я".unicode_at(0)) and interface_font.has_char("Ё".unicode_at(0)),
		"The bundled interface font supports Russian glyphs")
	scene.reset_settings()
	# Physics is advanced directly below, outside the real-time audio mixer.
	scene.audio_enabled = false
	scene.apply_settings()
	check(scene.selected == scene.DEFAULT_HERO and scene.owned.has(scene.DEFAULT_HERO),"New profile begins with Vega unlocked and selected")
	scene.start()
	check(scene.running and scene.hp == scene.max_hp and scene.level == 1,"Start initializes run")
	check(scene.crates.size() == Landscape.STARTING_CRATES,"Arena populated")
	var hud = scene.hud_panel
	var ui_input := InputEventScreenTouch.new()
	ui_input.pressed = true
	ui_input.position = Vector2(37,37)
	scene._input(ui_input)
	check(scene.finger == -1 and hud.blocks_at(ui_input.position),"HUD buttons do not capture the movement finger")
	hud.task_toggle.button_pressed = false
	check(not hud.tasks.visible and hud.radar_frame.position.y < 292,"Task toggle collapses the list and moves the minimap")
	hud.task_toggle.button_pressed = true
	var radar_position: Vector2 = hud.radar.project_point(Vector3(4,0,-5),Vector3.ZERO,23.0)
	check(radar_position.x > 71.0 and radar_position.y < 71.0,"Minimap projects real arena positions")
	hud.zoom_button.pressed.emit()
	check(hud.radar.zoom and hud.zoom_button.text == "−" and hud.map_motion.is_running(),"Minimap zoom animates through its button")
	hud.range_button.button_pressed = true
	hud.range_button.pressed.emit()
	check(scene.range_marker.visible and is_equal_approx(scene.range_marker.scale.x,scene.attack_distance()),"Range control displays the real attack radius")
	var before_pause: float = scene.elapsed
	scene.toggle_hud_pause()
	scene._physics_process(0.2)
	check(scene.elapsed == before_pause and hud.overlay.visible and not scene.stick_base.visible,"Solo pause freezes simulation and clears movement")
	scene.open_hud_settings()
	check(scene.settings_panel.visible and not hud.visible,"Settings open over the current run")
	scene.close_settings()
	check(hud.visible and hud.overlay.visible and scene.running and scene.elapsed == before_pause,"Returning from settings restores the same paused run")
	scene.toggle_hud_pause()
	check(not hud.overlay.visible and scene.running,"Continue returns to combat")

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
	scene.drop_gem(scene.hero.position)
	scene._physics_process(0.016)
	scene.update_hud()
	check(scene.run_pickups > 0 and str(scene.run_pickups) in hud.counters[1].text and str(scene.score) in hud.counters[0].text,"Score and collected shard counters use actual run events")
	check(hud.score_panel.flash > 0.0 and hud.xp_frame.flash > 0.0,"Run events animate their score and shard panels")
	scene.damage_hero(2.0,scene.hero.position+Vector3.RIGHT)
	scene.update_hud()
	check(hud.operator_frame.flash > 0.0,"Taking damage animates the operator panel")
	scene.xp = 3
	scene._physics_process(0.016)
	check(scene.level == 2 and scene.choosing and scene.offers.size() == 3,"Level up offers")
	scene.update_hud()
	check(hud.badge.visible and hud.level_pop.is_running(),"Level up animates the notification")
	check(scene.offers[0] != scene.offers[1] and scene.offers[1] != scene.offers[2] and scene.offers[0] != scene.offers[2],"Distinct upgrade offers")
	scene.choose_upgrade(0)
	check(not scene.choosing and scene.ranks.size() > 0,"Upgrade selection")
	scene.update_hud()
	check(hud.slot_art[0].texture != null and hud.slot_art[1].texture != null and not hud.slots[1].disabled,"Acquired abilities and base equipment have live illustrated cards")
	hud.slots[1].pressed.emit()
	check("скорость" in hud.status_text.text,"Equipment inspection shows a live stat")
	hud.slots[0].pressed.emit()
	check(scene.ABILITIES[hud.active_abilities[0]][1] in hud.status_text.text,"Ranked slot displays its real description")
	for id in scene.ABILITIES.size():
		scene.ranks[id] = 2
	scene.ranks[100] = 1
	scene.update_hud()
	hud.page_button.pressed.emit()
	check(hud.ability_page == 1 and hud.active_abilities[0] == 4,"Ability pages reveal acquired upgrades beyond the first four")
	for i in 3:
		hud.page_button.pressed.emit()
	hud.slots[0].pressed.emit()
	check(hud.active_abilities.has(100) and "ФОРСИРОВАННАЯ НОВА" in hud.status_text.text,"Combined upgrades can be inspected on the HUD")
	scene.roll_offers()
	check(scene.offer_buttons.all(func(button: Button) -> bool: return "РАНГ 3" in button.text),"Upgrade offers show the stored rank")
	scene.elapsed = 45.0
	scene._physics_process(0.016)
	check(scene.boss_spawned,"Boss spawns")
	scene.update_hud()
	check(hud.boss_frame.visible and hud.boss_health.value > 0,"Boss health appears from the spawned boss")
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
	check_boundaries(scene)
	scene.set_biome(1)
	var scenery_ids := {}
	var weathered_factory := false
	for prop in scene.scenery:
		if prop.has_meta("model_asset") and prop is MeshInstance3D and prop.mesh == null:
			var asset: String = prop.get_meta("model_asset")
			scenery_ids[asset] = true
			if asset == "building-a":
				for shape in prop.find_children("*","MeshInstance3D",true,false):
					var finish := shape.get_active_material(0) as ShaderMaterial
					weathered_factory = weathered_factory or (finish != null and finish.get_shader_parameter("worn_concrete") != null)
	check(weathered_factory,"The city factories use the bundled concrete texture in the weathering shader")
	check(scene.INDUSTRIAL_MODELS.all(func(asset: String) -> bool: return scenery_ids.has(asset)),
		"The city displays all five imported industrial models")
	scene.queue_free()
	await process_frame
	print("Gameplay tests: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)


func check_boundaries(scene) -> void:
	scene.set_biome(2)
	scene.start(false)
	scene.hero.position = scene.grounded(Vector3(46,0,-46))
	scene.finger = 0
	scene.direction = Vector2(1,-1).normalized()
	scene.spawn_timer = 30.0
	scene._physics_process(2.0)
	check(is_equal_approx(scene.hero.position.x,Landscape.PLAY_HALF) and is_equal_approx(scene.hero.position.z,-Landscape.PLAY_HALF),
		"Movement crosses the old arena and stops only at the expanded boundary")
	check(is_equal_approx(scene.hero.position.y,scene.grounded(scene.hero.position).y),
		"The player follows the new terrain height")
	var footprint: Vector3 = scene.ground.mesh.get_aabb().size
	check(footprint.x > 160.0 and footprint.y > 4.0,"Terrain mesh provides relief and extends past the playable camera bounds")
	scene.camera.size = 28.0
	var display_size := root.get_visible_rect().size
	var stays_inside := true
	for corner in [Vector3(48,0,-48),Vector3(48,0,48),Vector3(-48,0,-48),Vector3(-48,0,48)]:
		scene.hero.position = scene.grounded(corner)
		scene.camera.position = scene.hero.position+scene.COMBAT_CAMERA_OFFSET
		scene.camera.look_at(scene.hero.position)
		for pixel in [Vector2.ZERO,Vector2(display_size.x,0),Vector2(0,display_size.y),display_size]:
			var origin: Vector3 = scene.camera.project_ray_origin(pixel)
			var direction: Vector3 = scene.camera.project_ray_normal(pixel)
			var lowest := origin+direction*((-2.0-origin.y)/direction.y)
			stays_inside = stays_inside and maxf(absf(lowest.x),absf(lowest.z)) < Landscape.FLOOR_HALF
	check(stays_inside,"All camera corners at maximum zoom remain over terrain at the four world corners")
