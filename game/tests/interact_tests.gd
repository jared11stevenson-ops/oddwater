extends SceneTree
## godot --headless --path game -s tests/interact_tests.gd : the hands-on parts: the scene plan and the dusting pad.
const SceneView = preload("res://scripts/ui/scene_view.gd")
const DustPad = preload("res://scripts/ui/dust_pad.gd")
const Scrubber = preload("res://scripts/ui/cctv_scrubber.gd")
const EvidenceBoard = preload("res://scripts/ui/evidence_board.gd")
const ChatView = preload("res://scripts/ui/chat_view.gd")
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")
var fails := 0
var checks := 0
var tapped := ""
var brushed := false

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var v := SceneView.new()
	v.size = Vector2(620, 340)
	root.add_child(v)
	v.set_spots([{"id": "body", "label": "The body"}, {"id": "door", "label": "The door"}], {})
	v.spot_tapped.connect(func(id: String): tapped = id)
	await process_frame
	await process_frame
	var bp: Vector2 = v._hot["body"]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = bp + Vector2(10, 5)
	v._gui_input(e)
	ok(tapped == "body", "tapping a ring picks that spot: %s" % tapped)
	tapped = ""
	e.position = Vector2(5, 5)
	v._gui_input(e)
	ok(tapped == "", "tapping empty floor does nothing")
	var pad := DustPad.new()
	pad.size = Vector2(620, 280)
	root.add_child(pad)
	pad.brushed.connect(func(_c: float): brushed = true)
	await process_frame
	ok(pad.coverage() == 0.0 and not brushed, "nothing brushed yet")
	var r: Rect2 = pad._rect()
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			pad.brush_at(Vector2(x, y))
			x += 20.0
		y += 18.0
	ok(brushed and pad.coverage() >= 0.6, "brushing enough of the surface completes the dusting: %d%%" % int(pad.coverage() * 100))
	await _tape_and_board()
	print("interact_tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _mouse(ctrl: Control, pos: Vector2, down: bool) -> void:
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = down
	m.position = pos
	ctrl._gui_input(m)


func _motion(ctrl: Control, pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	ctrl._gui_input(m)


func _tape_and_board() -> void:
	var g: RefCounted = null
	var cam := ""
	var win := [18.0, 24.0]
	for sd in [31, 7, 12, 5, 19]:
		g = DetectiveGame.new(sd)
		for c in g.cameras():
			for w in [[18.0, 24.0], [24.0, 27.0], [27.0, 30.0]]:
				if cam == "":
					var fr0: Dictionary = g.camera_frames(c["id"], w[0], w[1])
					ok(fr0["frames"].is_empty() and fr0.get("locked", false), "the tape is locked until you have watched that stretch")
					g.view_camera(c["id"], w[0], w[1])
					var fr1: Dictionary = g.camera_frames(c["id"], w[0], w[1])
					for f in fr1["frames"]:
						if not (f["figures"] as Array).is_empty() and cam == "":
							cam = c["id"]
							win = w
		if cam != "":
			break
	ok(cam != "", "some camera has someone on tape")
	if cam == "":
		return
	var fr: Dictionary = g.camera_frames(cam, win[0], win[1])
	var rad: float = fr["radius"]
	ok(fr["frames"].size() == int(floor((win[1] - win[0]) / 0.05 + 0.0001)) + 1, "one frame per slice of the window")
	var inside := true
	var named_ok := true
	var any_fig := false
	for f in fr["frames"]:
		for fg in f["figures"]:
			any_fig = true
			if Vector2(fg["x"], fg["y"]).length() > rad + 0.01:
				inside = false
			if (fg["who"] != "") != bool(fg["ident"]):
				named_ok = false
	ok(any_fig and inside, "figures are only ever inside the camera's reach")
	ok(named_ok, "only an identified figure carries a name")
	var off: int = int(g.camera(cam)["offset"])
	ok(is_equal_approx(float(fr["frames"][0]["at"]), win[0] + float(off) / 60.0), "the stamp reads the camera's own clock")
	ok(not fr.has("offset"), "how far out the clock is stays hidden")
	var cal: Dictionary = g.calibrate_camera(cam)
	var fr2: Dictionary = g.camera_frames(cam, win[0], win[1])
	ok(fr2["clock_checked"] and is_equal_approx(float(fr2["frames"][0]["at"]), win[0]), "after checking, the stamp is the real time")
	# the scrubber
	var sc := Scrubber.new()
	sc.size = Vector2(436, 410)
	root.add_child(sc)
	var tapped_key := []
	sc.dot_tapped.connect(func(k: String, _t: float): tapped_key.append(k))
	sc.set_data(fr2, "cam")
	await process_frame
	var hr: Rect2 = sc._handle_rect()
	ok(hr.size.x >= 64.0 and hr.size.y >= 64.0, "the handle is a thumb-sized target")
	var p0: float = sc.pos
	_mouse(sc, hr.get_center(), true)
	_motion(sc, hr.get_center() + Vector2(120, 0))
	_mouse(sc, hr.get_center() + Vector2(120, 0), false)
	ok(sc.pos > p0, "dragging the handle scrubs the tape")
	# find a frame with a figure and tap its dot
	for i in fr2["frames"].size():
		if not (fr2["frames"][i]["figures"] as Array).is_empty():
			sc.pos = float(i)
			break
	sc.queue_redraw()
	await process_frame
	await process_frame
	ok(not sc._hot.is_empty(), "dots are on the map")
	var k0: String = sc._hot.keys()[0]
	k0 = sc.tap_at(sc._hot[k0] + Vector2(2, 2))
	ok(k0 != "" and tapped_key == [k0], "tapping a dot picks that figure")
	var at: float = sc.at_time()
	var n0: int = g.det.order.size()
	var tr: Dictionary = g.tag_figure(cam, win[0], win[1], at, k0)
	ok(tr["ok"] and g.det.order.size() == n0 + 1, "tagging a figure adds a claim to the notebook")
	if tr["who"] != "":
		ok(g.det.flagged.has(tr["who"]), "tagging a named figure flags a person of interest")
	var n1: int = g.det.order.size()
	var fz: Dictionary = g.freeze_frame(cam, win[0], win[1], at)
	ok(fz["ok"] and g.det.order.size() == n1 + 1, "freeze frame saves a snapshot claim")
	ok(g.tag_figure("cam_nope", 18.0, 24.0, 20.0, "zz")["ok"] == false, "tagging on a tape you have not watched does nothing")
	# the evidence board
	var fnd: String = g._truth["found_by"]
	g.det.learn({"id": "t_a", "title": "Seen out", "text": "Someone saw them out late.", "kind": "testimony", "source": "x", "day": 1,
		"claims": [{"kind": "seen", "subject": fnd, "predicate": "seen_out_at_night", "place": "", "time": 25.0, "until": -1.0, "item": "", "certainty": 0.9, "source": "x", "text": "", "cid": "kA"}]})
	g.det.learn({"id": "t_b", "title": "At the chapel", "text": "They were at the chapel all night.", "kind": "testimony", "source": "y", "day": 1,
		"claims": [{"kind": "said", "subject": fnd, "predicate": "elsewhere", "place": "", "time": 25.0, "until": -1.0, "item": "", "certainty": 0.9, "source": "y", "text": "", "cid": "kB"}]})
	var cards: Array = g.board_cards()
	ok(cards.size() >= 2 and cards.any(func(c): return c["cid"] == "kA"), "every notebook claim can be a card")
	ok(g.board_contradictions().size() >= 1, "the rules find the contradiction")
	var people := [{"id": fnd, "name": "F", "p": g.sim.people[fnd]}]
	var bd := EvidenceBoard.new()
	bd.size = Vector2(436, 640)
	root.add_child(bd)
	var made := []
	var moved_to := []
	bd.string_made.connect(func(c: String, p: String): made.append([c, p]))
	bd.moved.connect(func(c: String, x: float, y: float): moved_to.append([c, x, y]))
	bd.set_data(cards, people, g.det.theory, g.board_contradictions(), {})
	await process_frame
	ok(bd.red.size() >= 1, "contradictions show as red threads")
	var card: Control = bd.cards["kA"]
	ok(card.size.y >= 64.0, "a card is a big enough target")
	var cp: Vector2 = card.position
	_mouse(card, Vector2(20, 30), true)
	_motion(card, Vector2(70, 80))
	_mouse(card, Vector2(70, 80), false)
	ok(card.position.distance_to(cp + Vector2(50, 50)) < 1.0 and moved_to.size() == 1, "dragging moves the card and reports where it landed")
	var h0: float = card.size.y
	_mouse(card, Vector2(20, 30), true)
	_mouse(card, Vector2(20, 30), false)
	ok(card.open and card.size.y > h0, "tapping a card expands it")
	bd.set_mode("string")
	var pin: Control = bd.pins[fnd]
	card = bd.cards["kA"]
	_mouse(card, Vector2(20, 30), true)
	_motion(card, pin.position - card.position + Vector2(20, 20))
	_mouse(card, pin.position - card.position + Vector2(20, 20), false)
	ok(made.size() == 1 and made[0][0] == "kA" and made[0][1] == fnd, "dragging a string from a card to a person records it")
	ok(g.board_theory("kA", fnd) and g.det.theory.size() == 1, "the theory is kept on the detective")
	var saved: Dictionary = g.det.to_dict()
	ok((saved["theory"] as Array).size() == 1, "and saved")
	var read: String = g.board_read(fnd)
	ok(read.contains("Not a case") or read.length() > 40, "the DA reads the board's strings")
	var pr_all: Dictionary = g.det.proof_against(fnd)
	ok(int(pr_all["exonerate"]) > 0, "(the full notebook also holds the alibi)")
	var other: String = ""
	for pid in g.sim.order:
		if pid != fnd and pid != "player":
			other = pid
			break
	# chat
	var npc: String = fnd
	var aff0: float = g.sim.people[npc].affinity("player")
	g.ask(npc, "saw", "", "kind")
	var aff_kind: float = g.sim.people[npc].affinity("player")
	g.ask(npc, "victim", "", "press")
	var aff_press: float = g.sim.people[npc].affinity("player")
	ok(aff_kind > aff0 and aff_press < aff_kind, "kind earns rapport and pressing costs it")
	var a2: float = g.sim.people[npc].affinity("player")
	g.ask(npc, "suspects", "", "")
	ok(is_equal_approx(g.sim.people[npc].affinity("player"), a2 - 1.0) or is_equal_approx(g.sim.people[npc].affinity("player"), a2), "the default tone changes nothing")
	var ch := ChatView.new()
	ch.size = Vector2(436, 250)
	root.add_child(ch)
	var long_text := "I really cannot say that I remember anything much about that night, except that the rain came down hard and the lights in the square went out twice before midnight."
	ch.add_bubble("them", long_text, g.sim.people[npc])
	ch.add_bubble("me", "Where were you?")
	await process_frame
	ok(ch.is_cut(0) and not ch.is_cut(1), "a long answer is cut short, a short one is not")
	var b0: Control = ch.list.get_child(0).get_child(1)
	_mouse(b0, Vector2(8, 8), true)
	_mouse(b0, Vector2(8, 8), false)
	ok(ch.bubbles[0]["open"], "tapping a bubble expands it")
	var dz := ChatView.DropZone.new()
	var got := []
	dz.dropped.connect(func(e: String): got.append(e))
	ok(dz._can_drop_data(Vector2.ZERO, {"evidence": "c_body"}) and not dz._can_drop_data(Vector2.ZERO, {"x": 1}), "the portrait accepts a dragged notebook card")
	dz._drop_data(Vector2.ZERO, {"evidence": "c_body"})
	ok(got == ["c_body"], "dropping a card on the portrait presents it")
