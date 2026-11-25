extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.save_png(path) != OK:
		push_error("Screenshot failed: "+path)
		quit(1)

func capture() -> void:
	seed(42)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var out: String = OS.get_cmdline_user_args()[0]
	await create_timer(0.5).timeout
	await shot(out+"/menu.png")
	scene.start()
	await create_timer(6.0).timeout
	await shot(out+"/gameplay.png")
	quit()
