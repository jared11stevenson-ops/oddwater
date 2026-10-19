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
	# Perform: play every conversation through the real UI, always taking the first choice;
	# when Silas's crown triggers the X-ray overlay, flag the true matches and stamp the Seal.
	var saw_overlay := false
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
		for c in main.ui.get_children():
			if c.has_method("flag_tooth"):
				saw_overlay = true
				if c.flag_tooth(8) != "miss": fails += 1; print("FAIL tooth 8 should miss")
				for t2 in c.dental.true_matches(): c.flag_tooth(t2)
				c.finish()
				await process_frame
				if not main.state.board.seals.has("S25"): fails += 1; print("FAIL S25 not sealed")
				for b in main.ui.get_children():
					if b is Button: b.pressed.emit()
	if not saw_overlay: fails += 1; print("FAIL the overlay never appeared")
	await process_frame
	await process_frame
	if not main.state.remnants.has_remnant("mags"): fails += 1; print("FAIL remnant not formed")
	if main.state.phase != 3: fails += 1; print("FAIL not at NIGHT: ", main.state.phase)
	if main.state.board.evidence.size() < 6: fails += 1; print("FAIL evidence ", main.state.board.evidence.size())
	print("smoke: ", "OK" if fails == 0 else "%d failed" % fails, " evidence=", main.state.board.evidence.size())
	quit(fails)
