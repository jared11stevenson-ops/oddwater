extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var b: RefCounted = main.state.board
	for id in ["LF-019", "LF-021", "LF-043", "LF-055", "LF-056", "LF-070", "LF-071"]: b.add_evidence(id)
	b.pin("LF-055", "who"); b.pin("LF-056", "who"); b.pin("LF-043", "what"); b.link("LF-055", "LF-056")
	main._board()
	await process_frame
	var bu: Control = null
	for c in main.ui.get_children():
		if c.has_method("tie_selected"): bu = c
	bu.toggle_card("LF-043")
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT") + "_board.png")
	main.state.phase = 3
	main._slack()
	await process_frame
	for c in main.ui.get_children():
		if c.has_method("next_line"):
			for i in 3: c.next_line()
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT") + "_slack.png")
	quit()
