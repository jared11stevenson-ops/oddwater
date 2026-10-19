extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_day(); await process_frame
	for id in main.snoop.items.keys(): main.snoop.interact(id)
	main.snoop.finish(); await process_frame; await process_frame
	var ui: Control = null
	for c in main.ui.get_children():
		if c.has_method("pick"): ui = c
	ui.pick(1); ui.pick(0)
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	quit()
