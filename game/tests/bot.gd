extends RefCounted
## A robot player: finds whichever screen is up and plays it sensibly. Drives the real UI.

var main: Control
var tree: SceneTree
var log: Array = []


func _init(m: Control, t: SceneTree) -> void:
	main = m
	tree = t


func screen() -> Control:
	for c in main.ui.get_children():
		for method in ["interact", "pick", "flag_tooth", "tap_lane", "listen_spot", "tie_selected", "next_line"]:
			if c.has_method(method):
				return c
	return null


## Play until the main state reaches `day` at WAKE. Returns false if it gets stuck.
func play_until_day(day: int, max_steps: int = 400) -> bool:
	var steps := 0
	while steps < max_steps:
		steps += 1
		await tree.process_frame
		if main.state.day >= day and main.state.phase == 0:
			return true
		var s := screen()
		if s == null:
			var pressed := false
			for c in main.ui.get_children():
				if c is Button:
					c.pressed.emit(); pressed = true; break
			if not pressed:
				log.append("stuck: no screen, no button")
				return false
			continue
		if s.has_method("interact"):
			for id in s.items.keys():
				s.interact(id)
			s.finish(); log.append("snoop")
		elif s.has_method("flag_tooth"):
			for t in s.dental.true_matches(): s.flag_tooth(t)
			s.finish(); log.append("dental")
		elif s.has_method("tap_lane"):
			s.auto_play(0.02); log.append("rhythm")
		elif s.has_method("listen_spot"):
			var n := 0
			for sp in s.core.map["spots"]:
				if s.core.block_reason(sp["id"]) == "":
					s.listen_spot(sp["id"]); n += 1
			# 'porch' unlocks only after 'vent': try again for anything newly open
			for sp in s.core.map["spots"]:
				if s.core.block_reason(sp["id"]) == "":
					s.listen_spot(sp["id"])
			s.finish(); log.append("eavesdrop")
		elif s.has_method("tie_selected"):
			var ids: Array = main.state.board.evidence.keys()
			ids.sort()
			for id in ids:
				main.state.board.pin(id, "what")
			for i in ids.size() - 1:
				main.state.board.link(ids[i], ids[i + 1])
			for sid in main.state.board.testable():
				main.state.board.try_link_test(sid, main.state.day)
			s.finished.emit(); log.append("board")
		elif s.has_method("next_line"):
			var g := 0
			while s.idx < s.lines.size() - 1 and g < 30:
				s.next_line(); g += 1
			s.next_line(); log.append("slack")
		elif s.has_method("pick"):
			var g2 := 0
			while not s.dlg.finished and g2 < 30:
				s.pick(0); g2 += 1
			s.finished.emit(s.npc); log.append("convo:" + s.npc)
	log.append("max steps")
	return false
