extends RefCounted
## A robot player: finds whichever screen is up and plays it sensibly. Drives the real UI.

var main: Control
var tree: SceneTree
var log: Array = []
var dull := false     # a comfortable player: lives the life, skips the investigating
var steer_to := ""    # if set, the bot uses the Long Night to make tomorrow's host this person
var careful := true   # a careful detective photographs evidence and presses contradictions


func _init(m: Control, t: SceneTree, careful_play: bool = true) -> void:
	main = m
	tree = t
	careful = careful_play


func screen() -> Control:
	for c in main.ui.get_children():
		for method in ["interact", "pick", "flag_tooth", "tap_lane", "listen_spot", "tie_selected", "next_line", "choose_option", "pick_option", "do_action", "night_do", "take_photo", "decide_option"]:
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
				if dull and s.items[id]["kind"] not in ["pet", "role"]:
					continue
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
		elif s.has_method("tie_selected") and dull:
			s.finished.emit(); log.append("board-skipped")
		elif s.has_method("tie_selected"):
			var ids: Array = main.state.board.evidence.keys()
			ids.sort()
			if careful:
				_photograph_what_matters()
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
		elif s.has_method("choose_option"):
			var picks := [1, 0, 1, 0]   # the bold route: truth, question, skip the lamp, resign
			var k := 0
			while not s.core.finished() and k < 8:
				s.choose_option(picks[k] if k < 4 else 0); k += 1
			s.finish(); log.append("speech")
		elif s.has_method("do_action"):
			s.do_action("work", "")
			s.do_action("eat", "")
			var cs: Array = s.contacts()
			if not cs.is_empty():
				s.do_action("socialize", cs[0])
			s.finish(); log.append("free")
		elif s.has_method("take_photo"):
			if s.mode == "photo":
				var ids: Array = main.state.board.evidence.keys()
				ids.sort()
				if careful and not ids.is_empty():
					s.take_photo(ids[0])
			else:
				s.decide_option(0)
			s.finish(); log.append("tutorial:" + s.mode)
		elif s.has_method("night_do"):
			if careful and steer_to == "" and s.has_method("predict"):
				var edges: Array = main.cause.edge_report(main.sim, main.eligible_hosts())
				if not edges.is_empty():
					s.predict(edges[0]["id"])      # a careful detective bets on whoever looks most on the edge
				elif main.eligible_hosts().has(main.state.baseline_next_id()):
					s.predict(main.state.baseline_next_id())   # nobody looks on the edge: bet on the usual order
			if steer_to != "":
				var guard := 0
				while guard < 6 and s.budget > 0:
					guard += 1
					var r: Array = main.cause.ranking(main.sim, main.eligible_hosts())
					if r.is_empty() or r[0]["id"] == steer_to:
						break
					if guard % 2 == 1:
						s.night_do("comfort", r[0]["id"])
					else:
						s.night_do("unsettle", steer_to)
			s.finish(); log.append("long-night")
		elif s.has_method("pick_option"):
			for i in s.core.slot_count():
				s.pick_option(i, s.core.def["slots"][i]["correct"])
			s.finish(); log.append("radio")
		elif s.has_method("pick"):
			var g2 := 0
			while not s.dlg.finished and g2 < 30:
				s.pick(0); g2 += 1
			if careful:
				for cid in s.dlg.open_claims():
					for eid in main.state.board.evidence.keys():
						if s.dlg.claim_defs[cid]["contradicted_by"].has(eid):
							s.dlg.present(eid)
			s.finished.emit(s.npc); log.append("convo:" + s.npc)
	log.append("max steps")
	return false


## Photograph (up to the film allowance) the cards that unsealed Seals still depend on, preferring ones the Hush can alter.
func _photograph_what_matters() -> void:
	var b: RefCounted = main.state.board
	var need := {}
	for sid in b.seal_defs:
		if b.seals.has(sid):
			continue
		for e in b.seal_defs[sid]["evidence"]:
			if b.evidence.has(e):
				need[e] = int(need.get(e, 0)) + 1
	var ids: Array = need.keys()
	ids.sort_custom(func(a, c): return need[a] > need[c])
	for id in ids:
		if not b.swap_for(b.originals.get(id, "")).is_empty() and not b.notebook.has(id) and not b.is_corrupt(id):
			b.photograph(id)
	for id in b.edited.keys():
		b.restore(id)
