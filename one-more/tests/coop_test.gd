extends SceneTree

class MemoryLink extends RefCounted:
	var other: WeakRef
	var state := "idle"
	var frames: Array[String] = []

	func status() -> String:
		return state

	func pairedDevices() -> String:
		return '[{"name":"Test phone","address":"00:00:00:00:00:01"}]'

	func host() -> bool:
		state = "listening"
		return true

	func connectTo(_address: String) -> bool:
		var peer = other.get_ref()
		if peer.state != "listening":
			return false
		state = "connected"
		peer.state = "connected"
		return true

	func send(message: String) -> bool:
		if state != "connected":
			return false
		other.get_ref().frames.append(message)
		return true

	func poll() -> String:
		return "" if frames.is_empty() else frames.pop_front()

	func stop() -> void:
		var peer = other.get_ref()
		if peer != null and peer.state == "connected":
			peer.state = "disconnected"
		state = "idle"
		frames.clear()

var failures := 0

func check(condition: bool, note: String) -> void:
	if condition:
		print("PASS: ",note)
	else:
		failures += 1
		push_error("FAIL: "+note)

func _initialize() -> void:
	call_deferred("run_tests")

func exchange(host, guest, ticks: int = 4) -> void:
	for tick in ticks:
		host.coop._process(0.1)
		guest.coop._process(0.1)

func run_tests() -> void:
	var project := load("res://main.tscn") as PackedScene
	var host = project.instantiate()
	var guest = project.instantiate()
	root.add_child(host)
	root.add_child(guest)
	for arena in [host,guest]:
		arena.set_physics_process(false)
		arena.coop.set_process(false)
		arena.audio_enabled = false
		arena.apply_settings()
	var host_link := MemoryLink.new()
	var guest_link := MemoryLink.new()
	host_link.other = weakref(guest_link)
	guest_link.other = weakref(host_link)
	host.coop.link = host_link
	guest.coop.link = guest_link
	host.set_biome(3)
	guest.selected = 5
	host.choose_menu_action("coop")
	guest.choose_menu_action("coop")
	host.coop.begin_host()
	guest.coop.begin_join()
	exchange(host,guest)
	check(host.coop.live and guest.coop.live and host.running and guest.running,"Host and guest negotiate a shared run")
	check(guest.biome == 3 and host.coop.partner_hero == 5,"Map and hero are synchronized")
	check(guest.crates.is_empty() and guest.coop.objects.size() == 22,"Only host creates the authoritative layout")
	var old_position: Vector3 = host.coop.partner.position
	guest.finger = 1
	guest.direction = Vector2.RIGHT
	exchange(host,guest,2)
	host._physics_process(0.1)
	exchange(host,guest,3)
	check(host.coop.partner.position.x > old_position.x,"Guest input moves the authoritative partner")
	check(absf(guest.hero.position.x-host.coop.partner.position.x) < 0.04,"Guest displays the synchronized partner position")
	check(guest.coop.objects.size() == 23,"Spawned enemy appears in the guest scene")
	var old_elapsed: float = guest.elapsed
	guest._physics_process(0.5)
	check(guest.elapsed == old_elapsed,"Guest cannot advance the shared simulation")
	var before_hp: float = host.coop.partner_hp
	host.coop.damage_partner(host.coop.partner.position,2.0,18.0)
	exchange(host,guest,3)
	check(guest.hp == before_hp-18.0,"Partner damage updates the guest HUD")
	host.xp = 3
	host._physics_process(0.016)
	exchange(host,guest,3)
	check(host.choosing and "ВЕДУЩИЙ" in guest.coop.partner_label.text,"Team waits while the host selects an upgrade")
	host.choose_upgrade(0)
	var record: int = guest.best
	host.score = 876
	host.finish_run()
	exchange(host,guest,2)
	check(not host.running and not guest.running and guest.score == 876,"Host result reaches both phones")
	check(guest.best == record,"Cooperative result leaves solo records intact")
	host.coop._process(0.5)
	guest.coop._process(0.5)
	host.choose_menu_action("coop")
	guest.choose_menu_action("coop")
	host.coop.begin_host()
	guest.coop.begin_join()
	exchange(host,guest)
	guest_link.stop()
	exchange(host,guest,2)
	check(not host.running and not guest.running and not host.coop.live and not guest.coop.live,"Disconnect closes both cooperative arenas")
	host.queue_free()
	guest.queue_free()
	await process_frame
	print("Cooperative tests: ",failures," failures")
	quit(0 if failures == 0 else 1)
