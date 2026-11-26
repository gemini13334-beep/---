extends SceneTree

const ModelGallery = preload("res://tests/model_gallery.gd")

var arena
var output: String
var failed := false

func _initialize() -> void:
	call_deferred("capture")

func shot(name: String, panel: Control = null) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if panel != null and not root.get_visible_rect().encloses(panel.get_global_rect()):
		push_error("Panel exceeds viewport: " + name)
		failed = true
	if frame == null or frame.is_empty() or frame.save_png(output.path_join(name + ".png")) != OK:
		push_error("Screenshot failed: " + name)
		failed = true

func click(position: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)

func advance(ticks: int) -> void:
	for tick in ticks:
		arena._physics_process(1.0 / 60.0)

func check_animation(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true

func motion_folder(name: String) -> bool:
	var created := DirAccess.make_dir_recursive_absolute(output.path_join(name))
	check_animation(created == OK,"Could not create the motion capture directory: "+name)
	return created == OK

func record_combat_motion() -> void:
	if not motion_folder("motion-combat"):
		return
	arena.credits = 1000
	arena.select_hero(1)
	arena.start(false)
	arena.spawn_timer = 30.0
	var enemy: MeshInstance3D = arena.create_coop_visual("enemy_armored",Vector3(2.5,0.5,-2.35))
	enemy.set_meta("health",4)
	enemy.set_meta("speed",0.85)
	arena.enemies.append(enemy)
	var pose = arena.actor_pose(arena.hero)
	if pose == null or pose.leg_left == null or pose.leg_right == null or pose.weapon == null:
		check_animation(false,"Cyborg is missing one of its imported joints")
		arena.finish_run()
		return
	var stride_visible := false
	var recoil_visible := false
	var stagger_visible := false
	arena.finger = 0
	arena.direction = Vector2(0.15,-0.12)
	for frame in 36:
		if frame == 24:
			arena.clear_touch()
		advance(4)
		await shot("motion-combat/%03d" % frame)
		stride_visible = stride_visible or absf(pose.leg_left.rotation.x-pose.leg_right.rotation.x) > 0.15
		recoil_visible = recoil_visible or pose.weapon.position.z < pose.weapon_position.z-0.02
		if is_instance_valid(enemy):
			var enemy_pose = arena.actor_pose(enemy)
			stagger_visible = stagger_visible or (enemy_pose != null and enemy_pose.hit > 0.0)
	check_animation(stride_visible and recoil_visible and stagger_visible and arena.kills == 1,
		"Combat capture did not show walking, recoil, stagger and a defeat")
	arena.finish_run()

func record_vega_motion() -> void:
	if not motion_folder("motion-vega"):
		return
	arena.select_hero(arena.DEFAULT_HERO)
	arena.start(false)
	arena.spawn_timer = 30.0
	var pose = arena.actor_pose(arena.hero)
	if pose == null or pose.animation == null or pose.muzzle_bone < 0:
		check_animation(false,"Vega is missing her imported skeleton, animation player or muzzle bone")
		arena.finish_run()
		return
	var states := {}
	arena.finger = 0
	arena.direction = Vector2(0.22,0.0)
	for frame in 36:
		if frame == 8:
			arena.clear_touch()
			arena.fire_visual(arena.hero,arena.hero.position+Vector3(2,0,2))
		elif frame == 14:
			arena.damage_hero(20,arena.hero.position+Vector3(1,0,1))
		elif frame == 23:
			arena.damage_hero(arena.hp,arena.hero.position+Vector3(1,0,1))
		advance(4)
		await shot("motion-vega/%03d" % frame)
		states[str(pose.animation.current_animation)] = true
	for animation in ["Run","Fire","Hit","Idle","Fall"]:
		check_animation(states.has(animation),"Vega combat did not play "+animation)
	arena.finish_run()


func record_hud_motion() -> void:
	if not motion_folder("motion-hud"):
		return
	arena.select_hero(arena.DEFAULT_HERO)
	arena.start(false)
	arena.spawn_timer = 30.0
	for frame in 33:
		if frame == 2:
			var point: Vector2 = arena.hud_panel.zoom_button.get_global_rect().get_center()
			click(point)
		elif frame == 7:
			arena.finger = 0
			arena.direction = Vector2(0.25,-0.12)
			arena.drop_gem(arena.hero.position)
		elif frame == 12:
			arena.clear_touch()
			arena.damage_hero(30,arena.hero.position+Vector3.RIGHT)
		elif frame == 17:
			for gem in 2:
				arena.drop_gem(arena.hero.position)
		elif frame == 21:
			arena.choose_upgrade(0)
		elif frame == 25:
			click(Vector2(42,36))
		elif frame == 31:
			arena.toggle_hud_pause()
		advance(4)
		arena.update_hud()
		await shot("motion-hud/%03d" % frame)
	arena.finish_run()

func record_boss_motion(boss: MeshInstance3D) -> void:
	if not motion_folder("motion-boss"):
		return
	var deadline := float(boss.get_meta("next_pulse"))
	var pose = arena.actor_pose(boss)
	if pose == null or pose.panel_left == null or pose.panel_right == null:
		check_animation(false,"Ice boss is missing its imported shoulder joints")
		return
	var charged := false
	var released := false
	for frame in 30:
		advance(4)
		await shot("motion-boss/%03d" % frame)
		charged = charged or pose.windup > 0.62
		released = released or pose.strike > 0.0
	check_animation(charged and released and float(boss.get_meta("next_pulse")) > deadline,
		"Boss capture did not include the preparation and release")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not DirAccess.dir_exists_absolute(args[0]):
		push_error("Pass an existing screenshots directory after --.")
		quit(1)
		return
	output = args[0]
	seed(42)
	arena = load("res://main.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	await shot("menu",arena.menu)
	var button_rects: Array[Rect2] = []
	for control in arena.menu.get_children():
		if control is Button:
			var rect: Rect2 = control.get_global_rect()
			for existing in button_rects:
				if rect.intersects(existing):
					push_error("Hangar buttons overlap: "+control.text)
					failed = true
			button_rects.append(rect)
	arena.choose_menu_action("coop")
	await shot("coop-lobby",arena.coop.lobby)
	arena.coop.leave_lobby()
	arena.start()
	advance(285)
	arena.choosing = true
	arena.offers.assign([0,3,6])
	arena.choose_upgrade(1)
	arena.choosing = true
	arena.offers.assign([1,5,6])
	arena.choose_upgrade(2)
	arena.hud_panel.range_button.button_pressed = true
	arena.update_hud()
	await shot("gameplay",arena.hud_panel)
	click(Vector2(52,168))
	var zoom_position: Vector2 = arena.hud_panel.zoom_button.get_global_rect().get_center()
	click(zoom_position)
	check_animation(arena.hud_panel.radar.zoom and not arena.hud_panel.tasks.visible,"HUD buttons did not receive graphical input")
	for blend_frame in 5:
		await process_frame
	await shot("hud-minimap",arena.hud_panel)
	click(zoom_position)
	click(Vector2(52,168))
	click(Vector2(42,36))
	check_animation(arena.hud_paused,"The graphical pause button did not pause the run")
	for fade_frame in 4:
		await process_frame
	await shot("hud-pause",arena.hud_panel)
	arena.toggle_hud_pause()
	arena.finger = 0
	arena.direction = Vector2(0.85,-0.53)
	advance(48)
	arena.clear_touch()
	await shot("forest-ruins",arena.hud_panel)
	arena.xp = arena.level * 3
	advance(1)
	for fade_frame in 5:
		await process_frame
	check_animation(not arena.upgrades.get_global_rect().intersects(arena.hud_panel.radar_frame.get_global_rect()),
		"The upgrade picker overlaps the minimap")
	check_animation(arena.offer_art.all(func(card: TextureRect) -> bool: return card.texture != null),
		"The upgrade picker lacks illustrated offers")
	await shot("upgrade",arena.upgrades)
	arena.choose_upgrade(0)
	arena.finish_run()
	await record_combat_motion()
	await record_vega_motion()
	await record_hud_motion()
	arena.show_collection()
	await shot("collection",arena.collection)
	for hero_id in arena.HEROES.size():
		arena.credits = 1000
		arena.select_hero(hero_id)
		var pose = arena.actor_pose(arena.hero)
		if hero_id < arena.DEFAULT_HERO:
			var muzzle := arena.hero.get_meta("shot_origin") as Node3D if arena.hero.has_meta("shot_origin") else null
			check_animation(pose != null and pose.weapon != null and muzzle != null and pose.weapon.is_ancestor_of(muzzle),
				"Hero is missing its mounted shot origin: "+str(arena.HERO_ART[hero_id]))
		else:
			check_animation(pose != null and pose.muzzle_bone >= 0 and pose.animation != null and pose.animation.has_animation("Fall"),
				"Operator is missing skeletal clips or muzzle: "+str(arena.HERO_ART[hero_id]))
		arena.show_hero_preview()
		await shot("hero-" + str(arena.HEROES[hero_id][0]).to_lower(),arena.hero_preview)
	arena.show_menu()
	arena.show_awakening()
	await shot("awakening",arena.awakening_panel)
	arena.show_quests()
	await shot("quests",arena.quest_panel)
	arena.show_awakening()
	arena.show_gates()
	await shot("gates",arena.gate_panel)
	arena.show_menu()
	arena.show_settings()
	await shot("settings",arena.settings_panel)
	arena.settings_tabs.current_tab = 1
	await shot("settings-video",arena.settings_panel)
	arena.settings_tabs.current_tab = 2
	await shot("settings-audio",arena.settings_panel)
	for map_id in range(1, arena.BIOMES.size()):
		arena.show_menu()
		arena.cycle_biome()
		arena.start()
		var boss: MeshInstance3D
		if map_id >= 3:
			arena.elapsed = 45.0
			advance(1)
			boss = arena.enemies.back()
			boss.position = Vector3(2.8,0.5,-3.0)
			arena.elapsed = float(boss.get_meta("next_pulse")) - (1.18 if map_id == 3 else 0.65)
			advance(1)
		else:
			advance(365)
		arena.update_hud()
		if is_instance_valid(boss):
			check_animation(arena.hud_panel.boss_frame.visible,"A spawned boss didn't update the health readout")
		var notice: Rect2 = arena.event_label.get_global_rect()
		var score_panel: Rect2 = arena.hud_panel.counters[0].get_parent().get_global_rect()
		var task_panel: Rect2 = arena.hud_panel.tasks.get_global_rect()
		check_animation(not notice.intersects(score_panel) and not notice.intersects(task_panel),"A run notification overlaps another HUD readout")
		await shot(str(arena.BIOMES[map_id]).to_lower(),arena.hud_panel)
		if map_id == 3:
			await record_boss_motion(boss)
		arena.finish_run()
	arena.audio_enabled = false
	arena.apply_settings()
	await create_timer(0.15).timeout
	arena.queue_free()
	await process_frame
	var gallery_names := ["models-heroes","models-enemies","models-equipment","models-operators"]
	for index in gallery_names.size():
		var gallery := ModelGallery.new()
		gallery.size = Vector2(720,1280)
		root.add_child(gallery)
		gallery.populate(index)
		await shot(gallery_names[index],gallery)
		failed = failed or not gallery.valid
		gallery.queue_free()
		await process_frame
	quit(1 if failed else 0)
