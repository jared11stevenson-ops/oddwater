extends Control
## The case sheet: a clean, touch-sized screen where you fill in WHO, WHEN, WHERE, HOW and WHY and cite the notebook claims that support each
## answer. Big pickers (a searchable people picker, time-band chips, a place picker, method and motive chips), a tray of claim cards, and a
## stamp for each linked group: CONFIRMED, or NOT YET SUPPORTED (never which part is wrong). It talks to the game only through its public
## sheet API and reads nothing but the case file and the notebook.

signal closed
signal file_requested(force: bool)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TownTheme = preload("res://scripts/ui/town_theme.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Sheet = preload("res://scripts/detective/sheet.gd")
const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const PAPER_HI := Color("fffaf0")
const MARIGOLD := Color("f5b82e")
const VIOLET := Color("4a3f7a")
const RED := Color("e23d3d")
const GREEN := Color("3f7a4f")
const CHANNEL := {"physical": Color("a8412f"), "testimony": Color("2f6f8f"), "records": Color("7b5a9e"), "lab": Color("3f7a4f")}
const LABELS := {"who": "WHO", "when": "WHEN", "where": "WHERE", "how": "HOW", "why": "WHY"}
const ASK := {"who": "Who did it?", "when": "In which hours?", "where": "Where was it done?", "how": "How was it done?", "why": "Why?"}

var game: RefCounted
var field := "who"
var query := ""
var armed := false
var _safe := Vector4(24, 6, 24, 12)
var rows: Dictionary = {}
var group_boxes: Dictionary = {}
var picker_box: VBoxContainer
var picker_scroll: ScrollContainer
var tray_box: HBoxContainer
var tray_title: Label
var result_label: Label
var res_label: Label
var search: LineEdit
var file_btn: Button
var hunch_btn: Button
var left_col: VBoxContainer
var right_col: VBoxContainer
var body: HBoxContainer


func setup(the_game: RefCounted) -> void:
	game = the_game
	name = "SheetScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout()
	refresh()


func _layout() -> void:
	_safe = UiKit.safe_margins(self)
	var root: Control = get_node_or_null("Root")
	if root != null:
		root.position = Vector2(_safe.x, _safe.y)
		root.size = Vector2(size.x - _safe.x - _safe.z, size.y - _safe.y - _safe.w)


# ------------------------------------------------------------------ building
func _btn(parent: Control, text: String, cb: Callable, px: int = 22, h: float = 64.0, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.add_theme_font_size_override("font_size", UiKit.fs(px))
	b.custom_minimum_size = Vector2(w, maxf(h, 64.0))
	if w == 0.0:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.set_button_style(b, PAPER_HI, INK, INK)
	b.pressed.connect(cb)
	UiKit.press_fx(b)
	parent.add_child(b)
	return b


func _lbl(parent: Control, text: String, px: int, color: Color = INK, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiKit.fs(px))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("e9dec0")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	# top bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	var title := Label.new()
	title.text = "THE CASE SHEET"
	TownTheme.heading(title, UiKit.fs(34), INK)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(title)
	res_label = _lbl(bar, "", 17, VIOLET)
	res_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cl := _btn(bar, "Close", func(): closed.emit(), 24, 64, 150)
	cl.name = "SheetClose"
	UiKit.set_button_style(cl, INK, MARIGOLD, PAPER)
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# left: the five lines and the three stamps
	left_col = VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(470, 0)
	left_col.add_theme_constant_override("separation", 6)
	body.add_child(left_col)
	for f in Sheet.FIELDS:
		var b := Button.new()
		b.name = "Line_" + f
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 66)
		b.add_theme_font_size_override("font_size", UiKit.fs(22))
		b.pressed.connect(_pick_field.bind(f))
		UiKit.press_fx(b)
		left_col.add_child(b)
		rows[f] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	left_col.add_child(gap)
	for g in Sheet.GROUPS:
		var pc := PanelContainer.new()
		pc.name = "Group_" + String(g["id"])
		pc.custom_minimum_size = Vector2(0, 64)
		left_col.add_child(pc)
		group_boxes[g["id"]] = pc
	# right: the picker, the tray, the verdict line, the actions
	right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	body.add_child(right_col)
	var ph := Label.new()
	ph.name = "PickerTitle"
	right_col.add_child(ph)
	search = LineEdit.new()
	search.name = "SheetSearch"
	search.custom_minimum_size = Vector2(0, 56)
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", UiKit.fs(22))
	search.add_theme_color_override("font_placeholder_color", Color("6b6558"))
	search.text_changed.connect(func(t: String): query = t; _fill_picker())
	right_col.add_child(search)
	picker_scroll = ScrollContainer.new()
	picker_scroll.name = "PickerScroll"
	picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_scroll.custom_minimum_size = Vector2(0, 120)
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(picker_scroll)
	picker_box = VBoxContainer.new()
	picker_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_box.add_theme_constant_override("separation", 6)
	picker_scroll.add_child(picker_box)
	tray_title = _lbl(right_col, "", 17, VIOLET)
	var ts := ScrollContainer.new()
	ts.name = "TrayScroll"
	ts.custom_minimum_size = Vector2(0, 148)
	ts.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(ts)
	tray_box = HBoxContainer.new()
	tray_box.add_theme_constant_override("separation", 8)
	ts.add_child(tray_box)
	var rs := ScrollContainer.new()
	rs.custom_minimum_size = Vector2(0, 76)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(rs)
	result_label = _lbl(rs, "", 18, INK)
	result_label.name = "SheetResult"
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 8)
	right_col.add_child(act)
	_btn(act, "Check the sheet", _on_check, 21).name = "SheetCheck"
	_btn(act, "Test theory", _on_theory, 21).name = "SheetTheory"
	hunch_btn = _btn(act, "Hunch", _on_hunch, 21)
	hunch_btn.name = "SheetHunch"
	file_btn = _btn(act, "File the charge", _on_file, 21)
	file_btn.name = "SheetFile"


# ------------------------------------------------------------------ state
func refresh() -> void:
	var sh: Dictionary = game.sheet()
	for f in Sheet.FIELDS:
		var b: Button = rows[f]
		var val: String = _value_text(f)
		var n: int = (sh["cites"][f] as Array).size()
		b.text = "%s   %s%s" % [LABELS[f], val if val != "" else "tap to answer", ("   (%d cited)" % n) if n > 0 else ""]
		var sel: bool = f == field
		UiKit.set_button_style(b, INK if sel else (PAPER_HI if val == "" else Color("f7ecc6")), MARIGOLD if sel else INK, PAPER if sel else INK)
		if val == "" and not sel:
			b.add_theme_color_override("font_color", Color("6b6558"))
	var lines: Dictionary = game.sheet_lines()
	for g in Sheet.GROUPS:
		_fill_group(g, lines)
	res_label.text = game.resource_line()
	hunch_btn.text = "Hunch (%d)" % int(game.det.res.get("hunches", 0))
	var lv: String = game.sheet_level()
	var ft := "File the charge"
	match lv:
		"murder": ft = "File: murder"
		"killing": ft = "File: unlawful killing"
		"held": ft = "File: hold on suspicion"
		"unconfirmed": ft = "Press a charge anyway" if not armed else "Tap again to press it"
		"unchecked": ft = "Check first"
	file_btn.text = ft
	file_btn.disabled = String(sh["who"]) == "" or lv == "unchecked"
	UiKit.set_button_style(file_btn, RED if (lv == "unconfirmed" and armed) else (GREEN if lv in ["murder", "killing", "held"] else PAPER_HI), INK, PAPER if lv in ["murder", "killing", "held"] or armed else INK)
	_fill_picker()
	_fill_tray()


func _value_text(f: String) -> String:
	var sh: Dictionary = game.sheet()
	var v: String = String(sh[f])
	if v == "":
		return ""
	match f:
		"who": return CaseEngine.name_of(game.sim, v) if game.sim.people.has(v) else v
		"when": return String(Sheet.band(v).get("label", v))
		"where": return game.place_name(v)
		"how": return String(Sheet.METHODS.get(v, v))
		"why": return String(Sheet.MOTIVES.get(v, v))
	return v


func _fill_group(g: Dictionary, lines: Dictionary) -> void:
	var pc: PanelContainer = group_boxes[g["id"]]
	for c in pc.get_children():
		pc.remove_child(c)
		c.queue_free()
	var st: String = String(lines[g["id"]]["stamp"])
	var col: Color = GREEN if st == "confirmed" else (RED if st == "unsupported" else VIOLET)
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("dff0e0") if st == "confirmed" else PAPER_HI, col, 3, 10, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	_lbl(v, String(g["label"]), 20, INK, false)
	var parts: Array = (g["fields"] as Array).map(func(f): return String(f))
	_lbl(v, ", ".join(parts), 16, Color("6b6558"), false)
	var tx := "CONFIRMED" if st == "confirmed" else ("NOT YET SUPPORTED" if st == "unsupported" else "OPEN")
	var s := UiKit.stamp(h, tx, col, 18, st != "open")
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.name = "Stamp_" + String(g["id"])


func _pick_field(f: String) -> void:
	field = f
	query = ""
	search.text = ""
	armed = false
	refresh()


func _choose(f: String, v: String) -> void:
	var cur: String = String(game.sheet()[f])
	game.sheet_set(f, "" if cur == v else v)
	armed = false
	refresh()


# ------------------------------------------------------------------ pickers
func _fill_picker() -> void:
	for c in picker_box.get_children():
		picker_box.remove_child(c)
		c.queue_free()
	var ttl: Label = right_col.get_node("PickerTitle")
	ttl.text = ASK[field]
	TownTheme.heading(ttl, UiKit.fs(30), INK)
	var sh: Dictionary = game.sheet()
	var cur: String = String(sh[field])
	search.visible = field in ["who", "where"]
	search.placeholder_text = "Search anyone in Little Mercy" if field == "who" else "Search a place or a household"
	match field:
		"when": _chips(Sheet.BANDS.map(func(b): return [String(b["id"]), String(b["label"])]), cur, 2)
		"how": _chips(Sheet.METHODS.keys().map(func(k): return [String(k), String(Sheet.METHODS[k])]), cur, 2)
		"why": _chips(Sheet.MOTIVES.keys().map(func(k): return [String(k), String(Sheet.MOTIVES[k])]), cur, 2)
		"who": _people(cur)
		"where": _places(cur)


func _chips(items: Array, cur: String, cols: int) -> void:
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_box.add_child(grid)
	for it in items:
		var b := _btn(grid, String(it[1]), _choose.bind(field, String(it[0])), 24, 72)
		b.name = "Chip_" + String(it[0])
		if cur == String(it[0]):
			UiKit.set_button_style(b, INK, MARIGOLD, PAPER)


func _people(cur: String) -> void:
	var q := query.strip_edges().to_lower()
	var poi: Array = game.persons_of_interest()
	var shown := {}
	if q == "":
		_lbl(picker_box, "In your notebook", 17, VIOLET, false)
		for sid in poi:
			shown[sid] = true
			_person_row(String(sid), cur)
		_lbl(picker_box, "Or search anyone in Little Mercy.", 17, Color("6b6558"), false)
		return
	var n := 0
	for sid in game.residents() + poi:
		if shown.has(sid) or not game.sim.people.has(sid):
			continue
		var hay: String = (CaseEngine.name_of(game.sim, sid) + " " + String(game.sim.people[sid].job)).to_lower()
		var ok := true
		for w in q.split(" ", false):
			if not hay.contains(w):
				ok = false
		if ok and n < 12:
			shown[sid] = true
			n += 1
			_person_row(String(sid), cur)
	if n == 0:
		_lbl(picker_box, "No one by that name.", 20, VIOLET, false)


func _person_row(sid: String, cur: String) -> void:
	var p: RefCounted = game.sim.people[sid]
	var b := _btn(picker_box, "%s   %s" % [p.display, p.job], _pick_person.bind(sid), 22, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.name = "Pick_" + sid
	if cur == sid:
		UiKit.set_button_style(b, INK, MARIGOLD, PAPER)


func _pick_person(sid: String) -> void:
	game.flag_person(sid)
	_choose("who", sid)


func _places(cur: String) -> void:
	var q := query.strip_edges().to_lower()
	var shown := {}
	var scene: String = String(game.case.get("scene", ""))
	if q == "":
		if scene != "":
			_lbl(picker_box, "Where they were found", 17, VIOLET, false)
			shown[scene] = true
			_place_row(scene, cur)
		var named: Array = []
		for eid in game.det.order:
			for cl in game.det.known[eid].get("claims", []):
				var pl := String(cl.get("place", ""))
				if pl != "" and game.layout.by_id.has(pl) and not shown.has(pl) and not named.has(pl):
					named.append(pl)
		if not named.is_empty():
			_lbl(picker_box, "In your notebook", 17, VIOLET, false)
		for pl2 in named.slice(0, 10):
			shown[pl2] = true
			_place_row(String(pl2), cur)
		_lbl(picker_box, "Or search the town.", 17, Color("6b6558"), false)
		return
	var n := 0
	for l in game.layout.lots:
		var lot := String(l["id"])
		if shown.has(lot) or String(l["kind"]) == "green":
			continue
		var hay: String = game.place_name(lot).to_lower()
		var ok := true
		for w in q.split(" ", false):
			if not hay.contains(w):
				ok = false
		if ok and n < 12:
			n += 1
			shown[lot] = true
			_place_row(lot, cur)
	if n == 0:
		_lbl(picker_box, "No such place.", 20, VIOLET, false)


func _place_row(lot: String, cur: String) -> void:
	var b := _btn(picker_box, game.place_name(lot), _choose.bind("where", lot), 22, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.name = "Place_" + lot
	if cur == lot:
		UiKit.set_button_style(b, INK, MARIGOLD, PAPER)


# ------------------------------------------------------------------ the claim tray
func _fill_tray() -> void:
	for c in tray_box.get_children():
		tray_box.remove_child(c)
		c.queue_free()
	var sh: Dictionary = game.sheet()
	var who: String = String(sh["who"])
	var cards: Array = game.sheet_cards(field)
	cards.sort_custom(func(a, b): return _rank(a, who) > _rank(b, who))
	var n_cited: int = (sh["cites"][field] as Array).size()
	tray_title.text = "CITE WHAT SUPPORTS %s  ·  %d cited  ·  %d claims in your notebook" % [LABELS[field], n_cited, cards.size()]
	if cards.is_empty():
		_lbl(tray_box, "Nothing in the notebook yet. Go and find something.", 20, VIOLET, false)
	for cd in cards.slice(0, 40):
		tray_box.add_child(_card(cd))


func _rank(c: Dictionary, who: String) -> int:
	var r := 0
	if bool(c["cited"]):
		r += 100
	if who != "" and String(c["subject"]) == who:
		r += 50
	if String(c["predicate"]) in ["time_of_death", "cause_of_death"]:
		r += 40
	if String(c["subject"]) == "":
		r -= 5
	return r


func _card(cd: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Cite_" + String(cd["cid"])
	b.custom_minimum_size = Vector2(228, 128)
	b.clip_contents = true
	var cited: bool = bool(cd["cited"])
	UiKit.set_button_style(b, INK if cited else PAPER_HI, MARIGOLD if cited else Color("7b5a9e"), PAPER if cited else INK)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	m.add_child(v)
	var ink: Color = PAPER if cited else INK
	var t := _lbl(v, ("CITED  " if cited else "") + String(cd["title"]), 17, ink)
	t.max_lines_visible = 2
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var meta: Array = [String(cd["pred"])]
	if String(cd["who"]) != "":
		meta.append(String(cd["who"]))
	if String(cd["clock"]) != "":
		meta.append(String(cd["clock"]))
	var mt := _lbl(v, " · ".join(meta), 15, MARIGOLD if cited else VIOLET)
	mt.max_lines_visible = 1
	mt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ex := _lbl(v, String(cd["text"]).replace("\n", " "), 15, ink)
	ex.max_lines_visible = 3
	ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(_toggle_cite.bind(String(cd["cid"]), not cited))
	UiKit.press_fx(b)
	return b


func _toggle_cite(cid: String, on: bool) -> void:
	game.sheet_cite(field, cid, on)
	armed = false
	refresh()


# ------------------------------------------------------------------ actions
func show_result(t: String) -> void:
	result_label.text = t


func _on_check() -> void:
	var r: Dictionary = game.sheet_check()
	var lines: Dictionary = r["lines"]
	var out: Array = []
	for g in Sheet.GROUPS:
		out.append("%s: %s" % [String(g["label"]).capitalize(), String(lines[g["id"]]["text"])])
	armed = false
	refresh()
	show_result("\n".join(out))
	UiKit.haptic(40)


func _on_theory() -> void:
	var r: Dictionary = game.sheet_test_theory()
	refresh()
	show_result(String(r["text"]))


func _on_hunch() -> void:
	var r: Dictionary = game.sheet_hunch()
	refresh()
	show_result(String(r["text"]))


func _on_file() -> void:
	var lv: String = game.sheet_level()
	if lv == "unconfirmed" and not armed:
		armed = true
		refresh()
		show_result("Nothing on the sheet is confirmed. A charge now is on your own judgement, and you answer for it if it fails. Tap again to press it.")
		return
	armed = false
	file_requested.emit(lv == "unconfirmed")
