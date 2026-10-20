extends "res://scripts/ui/town3d_hud.gd"
## The detective's screens over the 3D town: the case file, the scene menu, interrogation, your sheet, the accusation.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")

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
		body = game.briefing() + "\n\nThe weather is %s. Everyone in Little Mercy is friendly, and someone here is a killer.\n\nStart at the scene. Look at everything. Talk to everyone. Write it down: your notebook is the one record in this town that cannot be edited." % String(game.sim.weather_today())
	else:
		body = "Another morning. %s" % game.objective()
		if not game.today.is_empty():
			body += "\n\n" + "\n".join(game.today)
		body += "\n\nStress: %d/100." % int(game.det.stress)
	_card(title, sub, body, "Take the case" if game.det.order.is_empty() else "Start the day", _after_wake, v)


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


func _learned(entries: Array) -> void:
	if entries.is_empty():
		return
	_say("Notebook: %s" % ", ".join(entries.map(func(e): return String(e["title"]))))


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
	for t in [["Case", "case"], ["Notes", "notebook"], ["People", "people"], ["Accuse", "accuse"]]:
		var b := _btn(row, t[0], show_case.bind(t[1]), 20, 52)
		b.disabled = tab == t[1]
		b.name = "Tab_" + t[1]
	match tab:
		"case": _tab_case()
		"notebook": _tab_notebook()
		"people": _tab_people()
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
	_btn(box, "Back", show_case.bind("notebook"), 28, 60)


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
		_btn(wr, "Go to their house", go.bind(q.home), 20, 50)


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
	_card(verdict_title, "Your accusation: %s" % suspect.display, body, "Continue", func(): _close_card(), suspect)
	sel_culprit = ""; sel_motive = ""; sel_method = ""
