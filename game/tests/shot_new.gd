extends SceneTree
func snap(name: String) -> void:
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT") + "_" + name + ".png")
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._briefing(); await snap("brief")
	main.sim.start_day(); main.sim.take_control("mags")
	main._free()
	await process_frame
	var f: Control = null
	for c in main.ui.get_children():
		if c.has_method("do_action"): f = c
	f.choose_action("steal"); f.do_action("steal", "delphine")
	await snap("free")
	var b: RefCounted = main.state.board
	for id in ["LF-035", "LF-036", "LF-043", "LF-011"]: b.add_evidence(id)
	b.photograph("LF-036")
	b.edited["LF-036"] = true
	b.texts["LF-036"] = String(b.originals["LF-036"]).replace("Fair water", "Fair weather")
	b.edited["LF-043"] = true
	b.texts["LF-043"] = String(b.originals["LF-043"]).replace("1961", "1951")
	main._board()
	await process_frame
	for c in main.ui.get_children():
		if c.has_method("tie_selected"):
			c.toggle_card("LF-036")
	await snap("board")
	main.sim.release_control({"nerve": 30}); main.sim.simulate_rest_of_day()
	main._report(); await snap("report")
	quit()
