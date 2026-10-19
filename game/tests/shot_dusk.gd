extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for d in 3:
		main.sim.start_day(); main.sim.take_control("mags"); main.sim.simulate_rest_of_day(); main.sim.release_control(); main.sim.slack()
	main.sim.start_day(); main.sim.take_control("mags"); main.sim.simulate_rest_of_day()
	main._dusk_watch()
	await process_frame
	var d: Control = null
	for c in main.ui.get_children():
		if c.has_method("night_do"): d = c
	d.night_do("comfort", "jo")
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	quit()
