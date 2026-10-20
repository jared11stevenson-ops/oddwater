extends "res://scripts/ui/town3d_hud.gd"
## The detective's screens over the 3D town: the case file, the scene menu, interrogation, your sheet, the accusation.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const Justice = preload("res://scripts/detective/justice.gd")

const WINDOWS := [["Evening, 6 pm to midnight", 18.0, 24.0], ["Midnight to 3 am", 24.0, 27.0], ["3 am to 6 am", 27.0, 30.0]]
var cam_sel := ""

var obj_label: Label
var tab := "case"
var sel_culprit := ""
var sel_motive := ""
var sel_method := ""
var result_text := ""
var _obj_timer := 0.0

const MOTIVES := {"grudge": "An old grudge", "money": "Money", "family": "Inheritance", "silence": "To keep a secret", "passion": "Jealousy"}
const METHODS := {"blunt": "A blow to the head", "knife": "A knife", "strangle": "Strangulation", "poison": "Poison"}


func _extra_topbar() -> Array:
	return [["Case", "CaseBtn", show_case]]


func start3d(w: Node3D) -> void:
	super.start3d(w)
	obj_label = Label.new()
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.add_theme_font_size_override("font_size", 22)
	obj_label.add_theme_color_override("font_color", INK)
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.92, 0.82, 0.92); sb.border_color = INK; sb.set_border_width_all(3); sb.set_corner_radius_all(8); sb.set_content_margin_all(8)
	bg.add_theme_stylebox_override("panel", sb)
	bg.name = "ObjBox"
	bg.add_child(obj_label)
	bg.position = Vector2(10, 266)
	bg.custom_minimum_size = Vector2(300, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_refresh_objective()


func _refresh_objective() -> void:
	obj_label.text = "Objective: " + game.objective()
	obj_label.custom_minimum_size = Vector2(280, 0)


func _process(delta: float) -> void:
	super._process(delta)
	_obj_timer -= delta
	if _obj_timer <= 0.0 and obj_label != null:
		_obj_timer = 0.6
		_refresh_objective()


func close_panel() -> void:
	super.close_panel()
	if game.flush_time() > 0:
		world.time_skipped()


func _step_out() -> void:
	super._step_out()
	if game.flush_time() > 0:
		world.time_skipped()


func _card(title: String, subtitle: String, body: String, button: String, cb: Callable, person: RefCounted = null) -> void:
	super._card(title, subtitle, body, button, cb, person)
	if card != null:
		move_child(card, get_child_count() - 1)          # the page sits above the objective box


# ------------------------------------------------------------------ mornings
func _wake_card() -> void:
	var v: RefCounted = game.sim.people[game.case["victim"]]
	var body := ""
	var title := "DAY %d" % game.sim.day
	var sub := "Little Mercy"
	if game.sim.day == 1 and game.det.order.is_empty():
		title = "A CALL AT DAWN"
		sub = "You are the town's only detective."
		body = game.opening() + "\n\nStart at the scene. Look at everything. Talk to everyone. Write it down: your notebook is the one record in this town that cannot be edited."
	else:
		body = "Another morning. %s" % game.objective()
		if not game.today.is_empty():
			body += "\n\n" + "\n".join(game.today)
		body += "\n\nStress: %d/100." % int(game.det.stress)
	_card(title, sub, body, "Take the case" if game.det.order.is_empty() else "Start the day", _after_wake, v)
	if game.det.order.is_empty():
		_typewriter()


# ------------------------------------------------------------------ you, and inside places
func show_host() -> void:
	_clear_panel()
	if game.phase != "day":
		_night_panel()
	elif world.inside != "":
		_inside_panel()
	else:
		_sheet_panel()


func _night_panel() -> void:
	_head(box, "NIGHT", 44)
	_lbl(box, "The town is quiet. Somewhere out there someone is sleeping badly. Stress: %d/100." % int(game.det.stress), 26)
	var r: Dictionary = game.report
	if not game.today.is_empty():
		_lbl(box, "\n".join(game.today.slice(-4)), 22, VIOLET)
	_btn(box, "Case file", show_case, 30, 66)
	var sl := _btn(box, "Sleep until morning", next_morning, 32, 76)
	sl.name = "Sleep"


func _inside_panel() -> void:
	var lot: String = world.inside
	var l: Dictionary = game.layout.by_id.get(lot, {})
	_head(box, game.place_name(lot) if l.get("kind", "") in ["house", "home"] else String(l.get("name", lot)), 38)
	if lot == game.scene_lot() and not game.solved():
		_lbl(box, "THE SCENE. Yellow tape across the door.", 24, RED)
	if result_text != "":
		var rl := _lbl(box, result_text, 24)
		rl.name = "Result"
	_lbl(box, "Look closer", 24, VIOLET)
	for s in game.spots(lot):
		var b := _btn(box, s["label"], _spot.bind(lot, s["id"]), 26, 60)
		b.name = "Spot_" + s["id"]
	if lot == game.scene_lot() and game.det.tools.has("fingerprint kit"):
		_lbl(box, "Dust for prints", 24, VIOLET)
		var shown := {}
		for lat in game.case["latents"]:
			if not shown.has(lat["spot"]):
				shown[lat["spot"]] = true
				var pb := _btn(box, "Dust: %s" % Prints.SPOT_NAMES.get(lat["spot"], lat["spot"]), _dust.bind(lot, lat["spot"]), 24, 54)
				pb.name = "Dust_" + lat["spot"]
	var here: Array = game.people_here()
	if not here.is_empty():
		_lbl(box, "Here with you", 24, VIOLET)
		for id in here.slice(0, 6):
			var q: RefCounted = game.sim.people[id]
			var tb := _btn(box, "%s  (%s)" % [q.display, q.job], show_talk.bind(id), 24, 56)
			tb.name = "Talk_" + id
	if lot == game.me().home:
		var rest := _btn(box, "Sleep until morning", end_day, 28, 62)
		rest.name = "SleepHome"
	_btn(box, "Case file", show_case, 26, 56)
	var out := _btn(box, "Step outside", _step_out, 32, 70)
	out.name = "StepOut"


func _spot(lot: String, spot: String) -> void:
	var r: Dictionary = game.examine(lot, spot)
	result_text = r["text"]
	_learned(r["learned"])
	show_host()


func _dust(lot: String, spot: String) -> void:
	var r: Dictionary = game.dust(lot, spot)
	result_text = r["text"]
	_learned(r["learned"])
	show_host()


func _learned(entries: Array) -> void:
	if not entries.is_empty():
		_say("Notebook: %s" % ", ".join(entries.map(func(e): return String(e["title"]))))
	_beats()


## The storyteller steps in: an interlude when the story reaches a moment, typed out line by line.
func _beats() -> void:
	if card != null or game.pending_beats.is_empty():
		return
	var b: Dictionary = game.take_beat()
	_card(String(b["title"]), "", String(b["text"]), "Continue", _next_beat, null)
	_typewriter()


func _next_beat() -> void:
	_close_card()
	_beats()


func _typewriter() -> void:
	if card == null or card_body == null:
		return
	var lbl := card_body
	lbl.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(lbl, "visible_ratio", 1.0, clampf(float(lbl.text.length()) / 55.0, 1.2, 14.0))
	card.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and lbl.visible_ratio < 1.0:
			tw.kill()
			lbl.visible_ratio = 1.0)


func _sheet_panel() -> void:
	var d: RefCounted = game.det
	_head(box, "DETECTIVE", 44)
	_lbl(box, "Level %d  ·  XP %d/%d  ·  Points to spend: %d" % [d.level, d.xp, d.level * d.XP_PER_LEVEL, d.points], 24)
	_need("Stress", d.stress)
	for s in d.SKILLS:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := Label.new()
		l.text = "%s  %d" % [d.LABELS[s], d.skill(s)]
		l.custom_minimum_size = Vector2(250, 0)
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", INK)
		row.add_child(l)
		if d.points > 0:
			var up := _btn(row, "+", _spend.bind(s), 26, 48)
			up.custom_minimum_size.x = 60
			up.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lbl(box, "Tools: " + ", ".join(d.tools), 22, VIOLET)
	_lbl(box, "Sheriff %+d  ·  Town %+d  ·  Cases solved %d" % [d.reputation["sheriff"], d.reputation["town"], d.cases_solved], 22, VIOLET)
	_btn(box, "Case file", show_case, 30, 66)


func _spend(skill: String) -> void:
	game.det.spend_point(skill)
	show_host()


# ------------------------------------------------------------------ talking
func show_talk(npc: String) -> void:
	_clear_panel()
	talk_npc = npc
	var q: RefCounted = game.sim.people[npc]
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	box.add_child(hdr)
	var tone := ""
	if not last_talk.is_empty() and last_talk.get("npc", "") == npc:
		tone = last_talk.get("tone", "")
	hdr.add_child(_portrait(q, 100, tone))
	var hv := VBoxContainer.new()
	hdr.add_child(hv)
	_head(hv, q.display, 34).custom_minimum_size = Vector2(PANEL_W - 200.0, 0)
	_lbl(hv, "%d · %s" % [q.age, q.job], 22).custom_minimum_size = Vector2(PANEL_W - 200.0, 0)
	var rel := String(load("res://scripts/sim/relationship.gd").describe(game.sim, "player", npc))
	_lbl(hv, rel.capitalize(), 22, VIOLET).custom_minimum_size = Vector2(PANEL_W - 200.0, 0)
	var line := ""
	if not last_talk.is_empty() and last_talk.get("npc", "") == npc:
		line = last_talk["text"]
	else:
		var ops: Array = load("res://scripts/core/reactions.gd").openers(game.sim, npc, "player", game.sim.day)
		line = "\"%s\"" % ops[0]["text"] if not ops.is_empty() else "(They look at you. They've heard what happened.)"
	_balloon(line)
	var qs := [["Last night?", "alibi", ""], ["About %s" % CaseEngine.first(game.sim, game.case["victim"]), "victim", ""], ["Who did it?", "suspects", ""], ["Seen anything?", "saw", ""]]
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for x in qs:
		var b := _btn(grid, x[0], _q.bind(npc, x[1], x[2]), 22, 70)
		b.name = "Q_" + x[1]
	var wb := _btn(grid, "Where was...?", _ask_about_menu.bind(npc), 22, 70)
	wb.name = "Q_about"
	var tm := _btn(grid, "Tell me about...", _person_menu.bind(npc), 22, 70)
	tm.name = "Q_person"
	var sb := _btn(grid, "Show them...", _present_menu.bind(npc), 22, 70)
	sb.name = "Q_show"
	var fb := _btn(grid, "Be friendly", _friendly.bind(npc), 22, 70)
	fb.name = "Q_friendly"
	_btn(grid, "Leave", _leave_talk, 22, 70)


func _q(npc: String, topic: String, about: String) -> void:
	var r: Dictionary = game.ask(npc, topic, about)
	last_talk = {"npc": npc, "text": r["text"], "tone": "neutral"}
	_learned(r["learned"])
	show_talk(npc)


func _friendly(npc: String) -> void:
	var r: Dictionary = game.talk(npc, "compliment")
	last_talk = {"npc": npc, "text": "\"%s\"" % r.get("text", ""), "tone": r.get("tone", "neutral")}
	game.spend(5)
	show_talk(npc)


func _ask_about_menu(npc: String) -> void:
	_clear_panel()
	_head(box, "Where was...?", 36)
	for sid in game.suspects():
		if sid != npc:
			_btn(box, CaseEngine.name_of(game.sim, sid), _q.bind(npc, "alibi", sid), 26, 62)
	_btn(box, "Back", show_talk.bind(npc), 28, 60)


func _person_menu(npc: String) -> void:
	_clear_panel()
	_head(box, "Tell me about...", 36)
	for sid in game.suspects() + [game.case["victim"]]:
		if sid != npc:
			_btn(box, CaseEngine.name_of(game.sim, sid), _q.bind(npc, "person", sid), 26, 62)
	_btn(box, "Back", show_talk.bind(npc), 28, 60)


func _present_menu(npc: String) -> void:
	_clear_panel()
	_head(box, "Show them...", 36)
	if game.det.order.is_empty():
		_lbl(box, "Your notebook is empty.", 24)
	for eid in game.det.order:
		var e: Dictionary = game.det.known[eid]
		var b := _btn(box, String(e["title"]), _present.bind(npc, eid), 24, 56)
		b.name = "Show_" + eid
	_btn(box, "Back", show_talk.bind(npc), 28, 60)


func _present(npc: String, eid: String) -> void:
	var r: Dictionary = game.present(npc, eid)
	last_talk = {"npc": npc, "text": r["text"], "tone": "neutral"}
	_learned(r["learned"])
	show_talk(npc)


# ------------------------------------------------------------------ the case file
func show_case(tab_name: String = "") -> void:
	_clear_panel()
	if tab_name != "":
		tab = tab_name
	var row := HBoxContainer.new()
	box.add_child(row)
	for t in [["Case", "case"], ["Notes", "notebook"], ["People", "people"], ["CCTV", "cctv"], ["Court", "court"], ["Accuse", "accuse"]]:
		var b := _btn(row, t[0], show_case.bind(t[1]), 16, 52)
		b.disabled = tab == t[1]
		b.name = "Tab_" + t[1]
	match tab:
		"case": _tab_case()
		"notebook": _tab_notebook()
		"people": _tab_people()
		"cctv": _tab_cctv()
		"court": _tab_court()
		"accuse": _tab_accuse()


func _tab_case() -> void:
	var c: Dictionary = game.case
	var v: RefCounted = game.sim.people[c["victim"]]
	var hdr := HBoxContainer.new()
	box.add_child(hdr)
	hdr.add_child(_portrait(v, 90, "sad"))
	var hv := VBoxContainer.new()
	hdr.add_child(hv)
	_head(hv, "THE DEATH OF %s" % String(v.display).to_upper(), 30).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	_lbl(hv, "%d · %s" % [v.age, v.job], 22).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	_lbl(box, game.briefing(), 24)
	var d: RefCounted = game.det
	_lbl(box, "Cause: %s" % (d.known["c_body"]["text"] if d.has("c_body") else "not yet established"), 22, VIOLET)
	_lbl(box, "Time of death: %s" % (d.known["c_time"]["text"] if d.has("c_time") else "not yet established"), 22, VIOLET)
	_lbl(box, "Day %d  ·  Stress %d/100  ·  Notebook: %d entries" % [game.sim.day, int(d.stress), d.order.size()], 22)
	_lbl(box, "Next: " + game.objective(), 24, RED)
	if game.solved():
		_lbl(box, "CASE CLOSED.", 36, Color("3f7a4f"))
	if not game.episodes.is_empty():
		var eb := _btn(box, "Episodes (%d)" % game.episodes.size(), _archive, 26, 60)
		eb.name = "Archive"


func _archive() -> void:
	_clear_panel()
	_head(box, "EPISODES", 40)
	for i in game.episodes.size():
		var ep: Dictionary = game.episodes[i]
		var b := _btn(box, "%s  (%s)" % [ep["title"], ep["verdict"]], _episode.bind(i), 22, 62)
		b.name = "Ep_%d" % i
	_btn(box, "Back", show_case.bind("case"), 28, 60)


func _episode(i: int) -> void:
	_clear_panel()
	var ep: Dictionary = game.episodes[i]
	_head(box, String(ep["title"]), 34)
	_lbl(box, String(ep["text"]), 22)
	_btn(box, "Back", _archive, 28, 60)


func _tab_notebook() -> void:
	var d: RefCounted = game.det
	if d.order.is_empty():
		_lbl(box, "Empty. Start at the scene.", 26)
	for eid in d.order:
		var e: Dictionary = d.known[eid]
		var txt := String(e["text"])
		var b := _btn(box, "%s: %s" % [e["title"], txt.substr(0, 46) + ("..." if txt.length() > 46 else "")], _entry.bind(eid), 22, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Entry_" + eid
	if not d.statements.is_empty():
		_lbl(box, "Statements taken: %d" % d.statements.size(), 22, VIOLET)


func _entry(eid: String) -> void:
	_clear_panel()
	var e: Dictionary = game.det.known[eid]
	_head(box, String(e["title"]), 34)
	_lbl(box, String(e["text"]), 26)
	_lbl(box, "Source: %s  ·  Day %d" % [CaseEngine.name_of(game.sim, e["source"]) if game.sim.people.has(e["source"]) else game.place_name(e["source"]), int(e["day"])], 20, VIOLET)
	if e.get("lab", false) and not game.det.has("lab_" + eid):
		var lb := _btn(box, "Send to the lab", _lab.bind(eid), 28, 64)
		lb.name = "Lab"
	if e.get("latent", "") != "":
		_lbl(box, "Compare with...", 24, VIOLET)
		for sid in game.suspects() + [game.case["found_by"], game.case["victim"]]:
			if game.det.samples.get(sid, false):
				var cb := _btn(box, CaseEngine.name_of(game.sim, sid), _compare.bind(eid, sid), 24, 52)
				cb.name = "Cmp_" + sid
	_btn(box, "Back", show_case.bind("notebook"), 28, 60)


func _compare(eid: String, sid: String) -> void:
	var r: Dictionary = game.compare_print(eid, sid)
	_say(r["text"])
	_entry(eid)


func _lab(eid: String) -> void:
	var r: Dictionary = game.submit_lab(eid)
	_say(r["text"])
	show_case("notebook")


func _tab_people() -> void:
	for sid in game.suspects():
		var q: RefCounted = game.sim.people[sid]
		var hdr := HBoxContainer.new()
		hdr.add_theme_constant_override("separation", 10)
		box.add_child(hdr)
		hdr.add_child(_portrait(q, 78))
		var hv := VBoxContainer.new()
		hdr.add_child(hv)
		_head(hv, q.display, 28).custom_minimum_size = Vector2(PANEL_W - 170.0, 0)
		var mentions := 0
		for eid in game.det.order:
			if String(game.det.known[eid]["text"]).contains(String(q.display).split(" ")[0]):
				mentions += 1
		var said := ""
		for st in game.det.statements:
			if st["npc"] == sid and st["topic"] == "alibi" and st.get("about", "") in ["", sid]:
				said = String(st["text"]).split("\n")[0]
		_lbl(hv, "%s. In your notes: %d" % [q.job, mentions], 20).custom_minimum_size = Vector2(PANEL_W - 170.0, 0)
		if said != "":
			_lbl(hv, said, 20, VIOLET).custom_minimum_size = Vector2(PANEL_W - 170.0, 0)
		var wr := HBoxContainer.new()
		box.add_child(wr)
		_btn(wr, "Warrant", _warrant.bind(sid), 20, 50).name = "Warrant_" + sid
		_btn(wr, "Prints" if not game.det.samples.get(sid, false) else "Prints: on file", _sample.bind(sid), 20, 50).name = "Sample_" + sid
		var wr2 := HBoxContainer.new()
		box.add_child(wr2)
		_btn(wr2, "Their circle", _circle.bind(sid), 20, 50).name = "Circle_" + sid
		_btn(wr2, "Go to their house", go.bind(q.home), 20, 50)


func _sample(sid: String) -> void:
	var r: Dictionary = game.take_sample(sid)
	result_text = r["text"]
	_say(r["text"])
	show_case("people")


## The people around a suspect: family and the closest friends, with a way to go and ask each about them.
func _circle(sid: String) -> void:
	_clear_panel()
	_head(box, "Around %s" % CaseEngine.first(game.sim, sid), 36)
	var fam: Array = CaseEngine.relatives_of(game.sim, sid)
	if fam.is_empty():
		_lbl(box, "No close family or friends in town.", 24)
	for id in fam:
		var q: RefCounted = game.sim.people[id]
		var role: String = load("res://scripts/sim/relationship.gd").describe(game.sim, sid, id)
		_lbl(box, "%s: %s, %s" % [q.display, role, q.job], 24)
		var row := HBoxContainer.new()
		box.add_child(row)
		_btn(row, "Where was %s?" % CaseEngine.first(game.sim, sid), _circle_ask.bind(id, "alibi", sid), 20, 50)
		_btn(row, "About them", _circle_ask.bind(id, "person", sid), 20, 50)
		_btn(row, "Go there", go.bind(q.home), 20, 50)
	_btn(box, "Back", show_case.bind("people"), 28, 60)


func _circle_ask(npc: String, topic: String, about: String) -> void:
	var r: Dictionary = game.ask(npc, topic, about)
	last_talk = {"npc": npc, "text": r["text"], "tone": "neutral"}
	_learned(r["learned"])
	_say("%s: %s" % [CaseEngine.first(game.sim, npc), String(r["text"]).substr(0, 90)])
	_circle(about)


# ------------------------------------------------------------------ custody, trial and the jail
func _tab_court() -> void:
	var t: String = game.court.get("custody", "")
	if t == "":
		_lbl(box, "No one in custody. Arrest needs probable cause: real evidence of more than one kind.", 22)
		for sid in game.suspects():
			var b := _btn(box, "Arrest %s" % CaseEngine.name_of(game.sim, sid), _arrest.bind(sid), 22, 54)
			b.name = "Arrest_" + sid
	else:
		var q: RefCounted = game.sim.people[t]
		_head(box, "IN CUSTODY: %s" % String(q.display).to_upper(), 28)
		var ss: Dictionary = game.court["sess"]
		_lbl(box, "Trial on day %d (today is day %d).  Sessions: %d   Rapport: %d   Fatigue: %d" % [game.court["trial_day"], game.sim.day, ss["sessions"], int(ss["rapport"]), int(ss["fatigue"])], 20, VIOLET)
		for a in [["Build rapport", "rapport"], ["Lay out the evidence", "evidence"], ["Apply pressure", "pressure"]]:
			var ib := _btn(box, a[0], _interrogate.bind(a[1]), 22, 54)
			ib.name = "Int_" + a[1]
		var tb := _btn(box, "Go to trial", _trial, 26, 62)
		tb.disabled = not game.trial_ready()
		tb.name = "Trial"
		if result_text != "":
			_lbl(box, result_text, 22)
	_head(box, "THE JAIL", 30)
	if game.jail.is_empty():
		_lbl(box, "Empty. Everyone you put here will be kept in the Gallery.", 22)
	var open: bool = Justice.visiting_hours(world.hour())
	for i in game.jail:
		var p: RefCounted = game.sim.people[i["id"]]
		var vb := _btn(box, "%s  (%s)" % [p.display, i["type"]], _visit.bind(i["id"]), 22, 54)
		vb.disabled = not open
		vb.name = "Visit_" + i["id"]
	if not game.jail.is_empty() and not open:
		_lbl(box, "Visiting hours are 10 am to 4 pm.", 20, VIOLET)


func _arrest(sid: String) -> void:
	var r: Dictionary = game.arrest(sid)
	result_text = r["text"]
	_say(r["text"])
	show_case("court")


func _interrogate(approach: String) -> void:
	var r: Dictionary = game.interrogate(approach)
	result_text = r["text"]
	_learned(r["learned"])
	show_case("court")


func _trial() -> void:
	var r: Dictionary = game.run_trial()
	var lines: Array = r["attacks"].map(func(a): return "%s  (%+d)" % [a["text"], int(a["delta"])])
	var body := "\n\n".join(lines) + "\n\nThe jury is out. When it returns, the room is silent.\n\nVERDICT: %s  (confidence %d)" % [String(r["verdict"]).to_upper(), int(r["confidence"])]
	if r.get("wrongful", false):
		body += "\n\nYou have a bad feeling about this one."
	close_panel()
	world.refresh_markers()
	_card("THE TRIAL", "", body, "Continue", func(): _close_card(), null)
	_typewriter()


func _visit(id: String) -> void:
	_clear_panel()
	var p: RefCounted = game.sim.people[id]
	_head(box, p.display, 34)
	_lbl(box, "Across the glass. Rapport %d." % int(game.inmate(id)["rapport"]), 22, VIOLET)
	if result_text != "":
		_lbl(box, result_text, 22)
	for a in [["Talk", "talk"], ["About the crime", "crime"], ["About the town", "town"], ["What they are like", "profile"]]:
		var b := _btn(box, a[0], _visit_do.bind(id, a[1]), 22, 54)
		b.name = "VT_" + a[1]
	var ab := _btn(box, "Appeal their conviction", _appeal.bind(id), 22, 54)
	ab.name = "Appeal"
	_btn(box, "Back", show_case.bind("court"), 26, 56)


func _visit_do(id: String, topic: String) -> void:
	var r: Dictionary = game.visit(id, topic)
	result_text = r["text"]
	_visit(id)


func _appeal(id: String) -> void:
	var r: Dictionary = game.appeal(id)
	result_text = r["text"]
	_say(r["text"])
	if r["ok"]:
		show_case("court")
	else:
		_visit(id)


# ------------------------------------------------------------------ the cameras
func _tab_cctv() -> void:
	_lbl(box, "Every camera you can get footage from. Clocks are rarely exact: check one before you trust its times.", 22)
	for cam in game.cameras():
		var b := _btn(box, "%s%s" % [cam["label"], "  (face)" if cam["quality"] == "hd" else "  (figures only)"], _pick_cam.bind(cam["id"]), 22, 56)
		b.name = "Cam_" + cam["id"]
		b.disabled = cam_sel == cam["id"]
	if cam_sel != "":
		var cam: Dictionary = Cctv.camera(game.case, cam_sel)
		_head(box, cam["label"], 30)
		var cal := _btn(box, "Check the camera's clock" if not game.det.calibrated.get(cam_sel, false) else "Clock checked", _calibrate.bind(cam_sel), 22, 52)
		cal.disabled = game.det.calibrated.get(cam_sel, false)
		cal.name = "Calibrate"
		for w in WINDOWS:
			var wb := _btn(box, "Watch: %s" % w[0], _watch.bind(cam_sel, w[1], w[2]), 22, 56)
			wb.name = "Watch_%d" % int(w[1])
		if result_text != "":
			_lbl(box, result_text, 22)


func _pick_cam(id: String) -> void:
	cam_sel = id
	result_text = ""
	show_case("cctv")


func _calibrate(id: String) -> void:
	var r: Dictionary = game.calibrate_camera(id)
	result_text = r["text"]
	show_case("cctv")


func _watch(id: String, a: float, b: float) -> void:
	var r: Dictionary = game.view_camera(id, a, b)
	result_text = r["text"]
	_learned(r["learned"])
	show_case("cctv")


func _warrant(sid: String) -> void:
	var r: Dictionary = game.warrant(sid)
	result_text = r["text"]
	_say(r["text"])
	show_case("people")


func _tab_accuse() -> void:
	if game.solved():
		_lbl(box, "The case is closed.", 30)
		return
	_lbl(box, "Name the killer, the reason, and the method. The judge will weigh what is in your notebook.", 24)
	_lbl(box, "Who?", 24, VIOLET)
	for sid in game.suspects():
		var b := _btn(box, CaseEngine.name_of(game.sim, sid), _pick.bind("culprit", sid), 24, 54)
		b.disabled = sel_culprit == sid
		b.name = "Acc_" + sid
	_lbl(box, "Why?", 24, VIOLET)
	for k in MOTIVES:
		var b2 := _btn(box, MOTIVES[k], _pick.bind("motive", k), 22, 50)
		b2.disabled = sel_motive == k
		b2.name = "Why_" + k
	_lbl(box, "How?", 24, VIOLET)
	for k in METHODS:
		var b3 := _btn(box, METHODS[k], _pick.bind("method", k), 22, 50)
		b3.disabled = sel_method == k
		b3.name = "How_" + k
	var go_b := _btn(box, "Make the accusation", _accuse, 30, 72)
	go_b.disabled = sel_culprit == "" or sel_motive == "" or sel_method == ""
	go_b.name = "Accuse"


func _pick(which: String, v: String) -> void:
	match which:
		"culprit": sel_culprit = v
		"motive": sel_motive = v
		"method": sel_method = v
	show_case("accuse")


func _accuse() -> void:
	var res: Dictionary = game.accuse(sel_culprit, sel_motive, sel_method)
	var suspect: RefCounted = game.sim.people[sel_culprit]
	var verdict_title: String = {"convicted": "CASE CLOSED", "released": "NOT ENOUGH", "insufficient": "NO CASE", "wrong": "WRONG PERSON"}.get(res["verdict"], "VERDICT")
	var body: String = "%s\n\nScore: %d/100   (%d kinds of proof, %d in all)" % [res["text"], res["score"], res["cats"], res["total"]]
	if res["verdict"] == "convicted":
		body += "\n\nXP awarded. The Sheriff will remember this."
	close_panel()
	world.refresh_markers()
	_card(verdict_title, "Your accusation: %s" % suspect.display, body, "Read the episode", func(): _close_card(); _archive(), suspect)
	sel_culprit = ""; sel_motive = ""; sel_method = ""
