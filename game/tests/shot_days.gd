extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var out := OS.get_environment("SHOT")
	# rhythm mid-song
	main._rhythm({"song": "gig_set_one"})
	await process_frame
	var r: Control = null
	for c in main.ui.get_children():
		if c.has_method("tap_lane"): r = c
	r.clock = 4.6
	r.rhythm.update(4.6)
	r.tap_lane(0); r.tap_lane(1)
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "_rhythm.png")
	# eavesdrop
	main._eavesdrop({"map": "tobi_day"})
	await process_frame
	var e: Control = null
	for c in main.ui.get_children():
		if c.has_method("listen_spot"): e = c
	e.listen_spot("vent"); e.listen_spot("dock")
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "_eaves.png")
	quit()
