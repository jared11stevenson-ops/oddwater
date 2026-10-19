extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var out := OS.get_environment("SHOT")
	main._speech({"speech": "town_hall"})
	await process_frame
	var sp: Control = null
	for c in main.ui.get_children():
		if c.has_method("choose_option"): sp = c
	sp.choose_option(1); sp.choose_option(0)
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "_speech.png")
	main._radio({"set": "dedication_hour"})
	await process_frame
	var r: Control = null
	for c in main.ui.get_children():
		if c.has_method("pick_option"): r = c
	r.pick_option(0, 0); r.pick_option(1, 1)
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "_radio.png")
	main._night()
	await process_frame
	main.snoop.interact('box61') if main.snoop.items.has('box61') else null
	main.snoop.interact(main.snoop.items.keys()[0])
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "_night.png")
	quit()
