extends SceneTree
## godot --headless --path game -s tests/smoke.gd : boots the real scene and plays Wake & Snoop.

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
	if s.interact("drawer"): fails += 1; print("FAIL repeat interact counts twice")
	for id in s.items.keys():
		s.interact(id)
	if not main.state.board.evidence.has("LF-019"): fails += 1; print("FAIL evidence")
	if main.state.notes.get_note("curiosity") <= 0: fails += 1; print("FAIL notes")
	var got := {}
	s.finished.connect(func(r): got.merge(r))
	s.finish()
	await process_frame
	if got.get("found", 0) != 12 or got.get("vague_brief", true): fails += 1; print("FAIL result ", got)
	print("smoke: ", "OK" if fails == 0 else "%d failed" % fails)
	quit(fails)
