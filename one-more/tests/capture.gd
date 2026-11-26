extends SceneTree

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

func advance(ticks: int) -> void:
	for tick in ticks:
		arena._physics_process(1.0 / 60.0)

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
	advance(365)
	await shot("gameplay",arena.hud_panel)
	arena.finger = 0
	arena.direction = Vector2(0.85,-0.53)
	advance(48)
	arena.clear_touch()
	await shot("forest-ruins",arena.hud_panel)
	arena.xp = arena.level * 3
	advance(1)
	await shot("upgrade",arena.upgrades)
	arena.choose_upgrade(0)
	arena.finish_run()
	arena.show_collection()
	await shot("collection",arena.collection)
	for hero_id in [4,5]:
		arena.credits = 1000
		arena.select_hero(hero_id)
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
		if map_id >= 3:
			arena.elapsed = 45.0
			advance(1)
			var boss: MeshInstance3D = arena.enemies.back()
			boss.position = Vector3(2.8,0.5,-3.0)
			arena.elapsed = float(boss.get_meta("next_pulse")) - 0.65
			advance(1)
		else:
			advance(365)
		await shot(str(arena.BIOMES[map_id]).to_lower(),arena.hud_panel)
		arena.finish_run()
	arena.audio_enabled = false
	arena.apply_settings()
	await create_timer(0.15).timeout
	arena.queue_free()
	await process_frame
	quit(1 if failed else 0)
