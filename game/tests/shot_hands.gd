extends SceneTree
## SHOT=/path/prefix xvfb-run godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --path . -s tests/shot_hands.gd
## Screenshots of the hands-on screens: the tape scrubber, the evidence board, the chat interview.
const UiKit = preload("res://scripts/ui/ui_kit.gd")
var prefix := ""

var hud_ref: Control

func snap(name: String, frames: int = 6) -> void:
	for i in frames: await process_frame
	while hud_ref != null and hud_ref.card != null:
		hud_ref._next_beat()
		await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefix + "_" + name + ".png")

func _initialize() -> void:
	prefix = OS.get_environment("SHOT")
	UiKit.cfg_path = "user://ui_shot2.cfg"
	DirAccess.remove_absolute("user://ui_shot2.cfg")
	UiKit.loaded = false
	UiKit.data["tutorial_done"] = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	hud._after_wake() if hud.has_method("_after_wake") else null
	hud_ref = hud
	var g: RefCounted = hud.game
	var CaseBot = load("res://tests/case_bot.gd")
	var bot = CaseBot.new(g)
	bot.solve()
	# a camera with figures on tape
	var cam := ""
	var win := [18.0, 24.0]
	for c in g.cameras():
		for w in [[18.0, 24.0], [24.0, 27.0], [27.0, 30.0]]:
			if cam == "":
				g.view_camera(c["id"], w[0], w[1])
				for f in g.camera_frames(c["id"], w[0], w[1])["frames"]:
					if cam == "" and not (f["figures"] as Array).is_empty():
						cam = c["id"]
						win = w
	hud._pick_cam(cam)
	hud._watch(cam, win[0], win[1])
	await snap("cctv", 8)
	var sc: Control = hud.cam_scrub
	if sc != null:
		sc.pos = minf(sc.pos + 6.0, float(sc.frames.size() - 1))
		await snap("cctv_scrub", 4)
		if not sc._hot.is_empty():
			hud._tag_dot(sc._hot.keys()[0], sc.at_time())
			await snap("cctv_tagged", 4)
	# the board
	var fnd: String = g._truth["found_by"]
	g.det.learn({"id": "t_a", "title": "Seen out late", "text": "Someone saw them out late.", "kind": "testimony", "source": "x", "day": 1,
		"claims": [{"kind": "seen", "subject": fnd, "predicate": "seen_out_at_night", "place": "", "time": 25.0, "until": -1.0, "item": "", "certainty": 0.9, "source": "x", "text": "", "cid": "kA"}]})
	g.det.learn({"id": "t_b", "title": "At the chapel all night", "text": "They were at the chapel all night.", "kind": "testimony", "source": "y", "day": 1,
		"claims": [{"kind": "said", "subject": fnd, "predicate": "elsewhere", "place": "", "time": 25.0, "until": -1.0, "item": "", "certainty": 0.9, "source": "y", "text": "", "cid": "kB"}]})
	hud.show_case("board")
	await snap("board", 8)
	var bv: Control = hud.board_view
	if bv != null and not bv.cards.is_empty():
		var pid: String = bv.pins.keys()[0] if not bv.pins.is_empty() else ""
		var cids: Array = bv.cards.keys()
		if pid != "":
			g.board_theory(cids[0], pid)
			g.board_theory(cids[1], pid)
			g.board_theory(cids[2], pid)
		hud.board_sel = pid
		bv.cards[cids[3]].toggle()
		hud.show_case("board")
		bv = hud.board_view
		bv.cards[bv.cards.keys()[3]].toggle()
		hud._board_present()
		await snap("board_linked", 8)
		hud.scroll.scroll_vertical = 330
		await snap("board_mid", 4)
		hud.scroll.scroll_vertical = 100000
		await snap("board_bottom", 4)
	# the chat
	var npc: String = g._truth["found_by"]
	g.near = [npc]
	hud.show_talk(npc)
	await snap("chat0", 8)
	hud.chat_tone = "kind"
	hud._q(npc, "victim", "")
	hud.chat_tone = "press"
	hud._q(npc, "alibi", "")
	hud._toggle_tray(npc)
	await snap("chat", 10)
	hud._pick_evidence(npc, g.det.order[0])
	await snap("chat_sel", 6)
	quit()
