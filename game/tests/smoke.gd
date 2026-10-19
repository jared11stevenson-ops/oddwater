extends SceneTree
## godot --headless --path game -s tests/smoke.gd : boots the real scene and plays Day 1 through to dusk.

func _initialize() -> void:
	var fails := 0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_day()
	await process_frame
	var s: Control = main.snoop
	if s.items.size() != 12: fails += 1; print("FAIL items ", s.items.size())
	if not s.interact("drawer"): fails += 1; print("FAIL first interact")
	if s.interact("drawer"): fails += 1; print("FAIL repeat counts twice")
	for id in s.items.keys():
		s.interact(id)
	s.finish()
	await process_frame
	# Perform: play all three conversations through the real UI, always taking the first choice
	for i in 3:
		await process_frame
		var ui: Control = null
		for c in main.ui.get_children():
			if c.has_method("pick"): ui = c
		if ui == null: fails += 1; print("FAIL no dialogue UI for patient ", i); break
		var guard := 0
		while not ui.dlg.finished and guard < 20:
			ui.pick(0); guard += 1
		ui.finished.emit(ui.npc)
	await process_frame
	await process_frame
	if not main.state.remnants.has_remnant("mags"): fails += 1; print("FAIL remnant not formed")
	if main.state.phase != 3: fails += 1; print("FAIL not at NIGHT: ", main.state.phase)
	if main.state.board.evidence.size() < 6: fails += 1; print("FAIL evidence ", main.state.board.evidence.size())
	print("smoke: ", "OK" if fails == 0 else "%d failed" % fails, " evidence=", main.state.board.evidence.size())
	quit(fails)
