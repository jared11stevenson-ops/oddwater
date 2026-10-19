extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.state.board.add_evidence("LF-056")
	main._after_convo("silas")
	await process_frame
	var d: Control = null
	for c in main.ui.get_children():
		if c.has_method("flag_tooth"): d = c
	for t in [19, 8, 27, 30, 5, 14]: d.flag_tooth(t)
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	quit()
