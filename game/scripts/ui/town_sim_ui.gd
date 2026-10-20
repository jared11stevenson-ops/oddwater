extends Control
## THE TOWN: a living town you play from the inside. Map on the left, the person you are on the right.
## Designed on a 1280x720 canvas so text and touch targets are phone-sized (Galaxy S25 in landscape).

signal back_to_menu

const TownGame = preload("res://scripts/sim/town_game.gd")
const TownMap = preload("res://scripts/ui/town_map.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Talk = preload("res://scripts/sim/talk.gd")
const TownTheme = preload("res://scripts/ui/town_theme.gd")
const Portrait = preload("res://scripts/art/portrait.gd")
const PRINT = preload("res://shaders/page_post.gdshader")

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const MARIGOLD := Color("f5b82e")
const VIOLET := Color("4a3f7a")
const RED := Color("e23d3d")
const PANEL_W := 470.0
const DURATIONS := [0.5, 1.0, 2.0, 4.0]

var game: RefCounted
var map: Control
var panel: PanelContainer
var box: VBoxContainer
var scroll: ScrollContainer
var top: Label
var toast: Label
var news: Label
var card: Control
var print_pass: ColorRect
var dur_i := 1
var last_talk: Dictionary = {}
var talk_npc := ""


func start(seed_value: int = 1961, first_host: String = "") -> void:
	game = TownGame.new(seed_value, first_host)
	theme = TownTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = Color("e8dcc0"); add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map = TownMap.new()
	add_child(map)
	map.setup(game)
	map.place_tapped.connect(show_place)
	print_pass = ColorRect.new()
	print_pass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new(); pm.shader = PRINT
	pm.set_shader_parameter("paper", Color(0.99, 0.98, 0.96)); pm.set_shader_parameter("grain", 0.03); pm.set_shader_parameter("vignette", 0.22); pm.set_shader_parameter("levels", 10.0)
	print_pass.material = pm
	add_child(print_pass)
	var topbar := ColorRect.new(); topbar.color = INK; topbar.name = "TopBar"; add_child(topbar)
	top = Label.new()
	TownTheme.heading(top, 34, PAPER)
	topbar.add_child(top)
	top.position = Vector2(16, 12)
	var menu := _btn(topbar, "Menu", func(): back_to_menu.emit(), 26)
	menu.name = "MenuBtn"
	menu.clip_text = false
	for z in [["+", 1.3], ["-", 0.77]]:
		var zb := _btn(topbar, z[0], func(): map.set_zoom(map.zoom * z[1]), 34)
		zb.custom_minimum_size = Vector2(64, 52)
		zb.clip_text = false
		zb.name = "Zoom" + ("In" if z[0] == "+" else "Out")
	var me_btn := _btn(topbar, "Me", func(): map.focus_on(game.host), 26)
	me_btn.name = "MeBtn"
	me_btn.clip_text = false
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER; sb.set_content_margin_all(14)
	sb.border_color = INK; sb.border_width_left = 6; sb.border_width_top = 0; sb.border_width_right = 0; sb.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(PANEL_W - 64.0, 0)
	scroll.add_child(box)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 28)
	toast.add_theme_color_override("font_color", INK)
	toast.add_theme_font_override("font", TownTheme.bold())
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(toast)
	news = Label.new()
	news.add_theme_font_size_override("font_size", 22)
	news.add_theme_color_override("font_color", Color("4a3f7a"))
	news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(news)
	resized.connect(_layout)
	_layout()
	_wake_card()


func _layout() -> void:
	var sz := size
	var tb: Control = get_node("TopBar")
	tb.position = Vector2.ZERO
	tb.size = Vector2(sz.x, 64)
	var x := sz.x - 12.0
	for n in ["MenuBtn", "MeBtn", "ZoomOut", "ZoomIn"]:
		var b: Control = tb.get_node(n)
		b.size = b.get_combined_minimum_size()
		x -= b.size.x + 8.0
		b.position = Vector2(x, 6)
	panel.position = Vector2(sz.x - PANEL_W, 64)
	panel.size = Vector2(PANEL_W, sz.y - 64)
	map.position = Vector2(0, 64)
	map.size = Vector2(sz.x - PANEL_W, sz.y - 64 - 74)
	print_pass.position = map.position
	print_pass.size = map.size
	toast.position = Vector2(14, sz.y - 74 - 0)
	toast.custom_minimum_size = Vector2(sz.x - PANEL_W - 28, 0)
	toast.size = Vector2(sz.x - PANEL_W - 28, 40)
	news.position = Vector2(14, sz.y - 36)
	news.custom_minimum_size = Vector2(sz.x - PANEL_W - 28, 0)
	map.queue_redraw()


# ------------------------------------------------------------------ little builders
func _btn(parent: Control, text: String, cb: Callable, size_px: int = 30, min_h: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size_px)
	b.custom_minimum_size = Vector2(0, min_h if min_h > 0.0 else size_px * 1.9)
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _lbl(parent: Control, text: String, size_px: int = 28, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - 68.0, 0)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _head(parent: Control, text: String, size_px: int = 40, color: Color = INK) -> Label:
	var l := _lbl(parent, text, size_px, color)
	TownTheme.heading(l, size_px, color)
	return l


func _portrait(p: RefCounted, w: float, expr: String = "") -> Control:
	var pt: Control = Portrait.new()
	pt.custom_minimum_size = Vector2(w, w * 1.3)
	pt.setup(p, expr)
	return pt


func _need(name: String, v: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = name; l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", 24); l.add_theme_color_override("font_color", INK)
	row.add_child(l)
	var pb := ProgressBar.new(); pb.min_value = 0; pb.max_value = 100; pb.value = v; pb.show_percentage = false
	pb.custom_minimum_size = Vector2(250, 22); pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pb)
	box.add_child(row)


func _clear_panel() -> void:
	for c in box.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0


func _say(t: String) -> void:
	toast.text = t


func _refresh_hud() -> void:
	top.text = game.now_text() + "   " + ("%d hours left" % int(game.hours_left()) if game.phase == "day" else "night")
	var recent: Array = game.chronicle.slice(-2)
	news.text = "News: " + (" · ".join(recent.map(func(e): return e["text"])) if not recent.is_empty() else "quiet so far")


# ------------------------------------------------------------------ the morning card
func _wake_card() -> void:
	var b: Dictionary = game.brief()
	var body: String = Brief.text(game.sim, b)
	body += "\nToday:\n  " + "\n  ".join(b["plan"])
	_card("DAY %d" % game.sim.day, "You wake up as %s." % game.me().display, body, "Start the day", func(): _close_card(); show_host(); map.focus_on(game.host), game.me())


## A printed page over the map: sound-lettering title, the person's face, the facts.
func _card(title: String, subtitle: String, body: String, button: String, cb: Callable, person: RefCounted = null) -> void:
	if card != null:
		card.queue_free()
	card = ColorRect.new()
	(card as ColorRect).color = Color(0.08, 0.07, 0.11, 0.78)
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER; sb.border_color = INK; sb.set_border_width_all(6); sb.set_content_margin_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_offset = Vector2(8, 10)
	page.add_theme_stylebox_override("panel", sb)
	card.add_child(page)
	page.position = Vector2(40, 24)
	page.size = Vector2(size.x - 80, size.y - 48)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	page.add_child(row)
	if person != null:
		var pv := VBoxContainer.new()
		row.add_child(pv)
		pv.add_child(_portrait(person, 250))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var tl := _head(v, title, 66, RED)
	tl.custom_minimum_size = Vector2(0, 0)
	_head(v, subtitle, 40)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var t := _lbl(sc, body, 28)
	t.custom_minimum_size = Vector2(size.x - 440, 0)
	var bt := _btn(v, button, cb, 36)
	bt.custom_minimum_size = Vector2(0, 76)
	bt.name = "CardButton"


func _close_card() -> void:
	if card != null:
		card.queue_free()
		card = null


# ------------------------------------------------------------------ you
func show_host() -> void:
	_clear_panel()
	_refresh_hud()
	var p: RefCounted = game.me()
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	box.add_child(hdr)
	hdr.add_child(_portrait(p, 96))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hv)
	var nm := _head(hv, p.display, 38)
	nm.custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	_lbl(hv, "%d · %s · %s" % [p.age, p.job, p.mood_word()], 24).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	_lbl(hv, "At %s  ·  $%d" % [game.place_name(p.location), int(p.money)], 24).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	for n in [["Energy", "energy"], ["Hunger", "hunger"], ["Social", "social"], ["Fun", "fun"], ["Purpose", "purpose"]]:
		_need(n[0], float(p.needs[n[1]]))
	var w: String = Brief.worry(p)
	if w != "":
		_lbl(box, w, 24, Color("b4584a"))
	if game.phase != "day":
		_show_night()
		return
	var d := _btn(box, "Each action: %s" % _dur_text(), _cycle_dur, 26, 56)
	d.name = "DurBtn"
	_lbl(box, "Do something", 26, VIOLET)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for o in game.sim.options_for(game.host):
		var b := _btn(grid, o["label"], do_action.bind(o["act"]), 28, 60)
		b.name = "Act_" + o["act"]
		b.disabled = o["why_not"] != ""
		b.tooltip_text = o["why_not"]
	var here: Array = game.people_here()
	if not here.is_empty():
		_lbl(box, "Here with you", 26, VIOLET)
		for id in here.slice(0, 8):
			var q: RefCounted = game.sim.people[id]
			var b2 := _btn(box, "%s  (%s)" % [q.display, q.mood_word()], show_talk.bind(id), 26, 56)
			b2.name = "Talk_" + id
	_lbl(box, "More", 26, VIOLET)
	var row := HBoxContainer.new(); box.add_child(row)
	for m in [["Brief", _wake_again], ["Do more…", show_more], ["Big moves", show_decisions], ["Lives", show_lives]]:
		var mb := _btn(row, m[0], m[1], 22, 56)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.name = "More_" + m[0]
	var end := _btn(box, "End the day", end_day, 32, 72)
	end.name = "EndDay"


func _dur_text() -> String:
	var h: float = DURATIONS[dur_i]
	return "30 min" if h < 1.0 else "%d hour%s" % [int(h), "" if h == 1.0 else "s"]


func _cycle_dur() -> void:
	dur_i = (dur_i + 1) % DURATIONS.size()
	show_host()


func _wake_again() -> void:
	var b: Dictionary = game.brief()
	_card("BRIEFING", game.me().display, Brief.text(game.sim, b) + "\nToday:\n  " + "\n  ".join(b["plan"]), "Back", func(): _close_card(), game.me())


func do_action(act: String) -> Dictionary:
	map.snapshot()
	var r: Dictionary = game.do(act, DURATIONS[dur_i])
	_say(r["text"])
	map.animate_to_now()
	show_host()
	return r


func go(place: String) -> Dictionary:
	map.snapshot()
	var r: Dictionary = game.go(place)
	_say(r["text"])
	map.animate_to_now()
	map.focus_on(game.host)
	show_host()
	return r


func end_day() -> void:
	map.snapshot()
	game.end_day()
	map.animate_to_now(1.2)
	_say("The day is over.")
	show_host()


# ------------------------------------------------------------------ places
func show_place(id: String) -> void:
	_clear_panel()
	var l: Dictionary = game.layout.by_id.get(id, {})
	if l.is_empty():
		return
	var title: String = game.place_name(id) if l["kind"] in ["house", "home"] else String(l["name"])
	_head(box, title, 40)
	var here: Array = []
	for pid in game.sim.order:
		var q: RefCounted = game.sim.people[pid]
		if game.sim.alive(q) and q.location == id:
			here.append(pid)
	var owners: Array = game.sim.order.filter(func(x): return game.sim.people[x].home == id)
	if not owners.is_empty():
		_lbl(box, "Home of " + ", ".join(owners.map(func(x): return game.sim.people[x].display)), 24)
	var mins := int(game.distance(game.me().location, id) / 450.0) * 30
	if game.phase == "day" and id != game.me().location:
		var gb := _btn(box, "Go here (%s)" % ("right away" if mins == 0 else "%d min" % mins), go.bind(id), 32, 72)
		gb.name = "GoHere"
	elif id == game.me().location:
		_lbl(box, "You are here.", 26, Color("3f7a4f"))
	_lbl(box, "%d people here" % here.size() if not here.is_empty() else "Nobody here right now.", 26, VIOLET)
	for pid in here.slice(0, 12):
		var q2: RefCounted = game.sim.people[pid]
		var label := "%s  (%s%s)" % [q2.display, q2.job, ", you" if pid == game.host else ""]
		if id == game.me().location and pid != game.host:
			_btn(box, label, show_talk.bind(pid), 24, 54)
		else:
			_lbl(box, label, 24)
	_btn(box, "Back to me", show_host, 28, 60)


# ------------------------------------------------------------------ people
func _feel(q: RefCounted) -> String:
	var a: float = q.affinity(game.host)
	return "close to you" if a >= 50.0 else ("friendly" if a >= 15.0 else ("strained with you" if a <= -15.0 else "knows you a little"))


func show_talk(npc: String) -> void:
	_clear_panel()
	talk_npc = npc
	var q: RefCounted = game.sim.people[npc]
	var tone := ""
	if not last_talk.is_empty() and last_talk.get("npc", "") == npc:
		tone = Portrait.expression_for_tone(last_talk.get("tone", "neutral"))
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	box.add_child(hdr)
	hdr.add_child(_portrait(q, 110, tone))
	var hv := VBoxContainer.new()
	hdr.add_child(hv)
	_head(hv, q.display, 36).custom_minimum_size = Vector2(PANEL_W - 210.0, 0)
	_lbl(hv, "%d · %s · %s" % [q.age, q.job, q.mood_word()], 22).custom_minimum_size = Vector2(PANEL_W - 210.0, 0)
	_lbl(hv, _feel(q), 22, VIOLET).custom_minimum_size = Vector2(PANEL_W - 210.0, 0)
	var line := ""
	if not last_talk.is_empty() and last_talk.get("npc", "") == npc:
		line = "\"%s\"" % last_talk["text"]
	else:
		var ops: Array = load("res://scripts/core/reactions.gd").openers(game.sim, npc, game.host, game.sim.day)
		line = "\"%s\"" % ops[0]["text"] if not ops.is_empty() else "(They look at you, waiting.)"
	_balloon(line)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for tp in Talk.TOPICS:
		var b := _btn(grid, tp["label"], talk.bind(npc, tp["id"]), 24, 76)
		b.name = "Topic_" + tp["id"]
	_btn(box, "Leave", func(): last_talk = {}; show_host(), 30, 64)


## A comic speech balloon: white, inked, with a tail toward the speaker above it.
func _balloon(text: String) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	box.add_child(wrap)
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 16)
	tail.draw.connect(func():
		tail.draw_colored_polygon(PackedVector2Array([Vector2(40, 16), Vector2(62, 0), Vector2(78, 16)]), Color("fffaf0"))
		tail.draw_polyline(PackedVector2Array([Vector2(40, 16), Vector2(62, 0), Vector2(78, 16)]), INK, 4.0, true))
	wrap.add_child(tail)
	var bp := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffaf0"); sb.border_color = INK; sb.set_border_width_all(4); sb.set_corner_radius_all(22); sb.set_content_margin_all(14)
	bp.add_theme_stylebox_override("panel", sb)
	wrap.add_child(bp)
	var l := _lbl(bp, text, 28)
	l.name = "Reply"


func talk(npc: String, topic: String) -> Dictionary:
	map.snapshot()
	var r: Dictionary = game.talk(npc, topic)
	r["npc"] = npc
	last_talk = r
	_refresh_hud()
	if game.sim.day_over():
		show_host()
		return r
	show_talk(npc)
	return r


func show_more() -> void:
	_clear_panel()
	_head(box, "Do more", 40)
	var here: Array = game.people_here()
	if here.is_empty():
		_lbl(box, "Nobody is here to do anything to.", 26)
	for id in here.slice(0, 5):
		var q: RefCounted = game.sim.people[id]
		_lbl(box, q.display, 26, VIOLET)
		var row := HBoxContainer.new(); box.add_child(row)
		for a in [["Gift $20", "gift", {"amount": 20}], ["Praise", "praise", {}], ["Insult", "insult", {}], ["Steal $50", "steal", {"amount": 50}]]:
			var b := _btn(row, a[0], free_act.bind(a[1], id, a[2]), 20, 56)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn(box, "Back", show_host, 30, 64)


func free_act(action: String, target: String, args: Dictionary) -> Dictionary:
	var a := args.duplicate()
	a["target"] = target
	var r: Dictionary = game.act(action, a)
	_say(r["text"])
	show_more()
	return r


func show_decisions() -> void:
	_clear_panel()
	_head(box, "Big moves", 40)
	_lbl(box, "These change a life for good. Whoever you are tomorrow, they will still be living with it.", 24)
	var p: RefCounted = game.me()
	var opts: Array = []
	if p.employed:
		opts.append(["Quit the job", "quit_job"])
	else:
		opts.append(["Take a job", "take_job"])
	opts.append_array([["Sell the house", "sell_house"], ["Confess something", "confess"], ["Sign a year's lease", "sign_lease"], ["Leave town for good", "leave_town"]])
	for o in opts:
		var b := _btn(box, o[0], big_move.bind(o[1]), 28, 64)
		b.name = "Big_" + o[1]
	_btn(box, "Back", show_host, 30, 64)


func big_move(action: String) -> Dictionary:
	var r: Dictionary = game.act(action, {})
	_say(r["text"])
	show_host()
	return r


# ------------------------------------------------------------------ night and morning
func _show_night() -> void:
	_head(box, "NIGHT", 40)
	_lbl(box, "Everyone is home, or should be. You can't be anyone tonight, but you can change someone's night. At dawn the town hands you whoever is most ready to change.", 24)
	var edges: Array = game.night_edges()
	_lbl(box, "Looked on the edge today:", 26, VIOLET)
	if edges.is_empty():
		_lbl(box, "Nobody. A calm town.", 24)
	for e in edges.slice(0, 6):
		var row := HBoxContainer.new(); box.add_child(row)
		var l := Label.new(); l.text = "%s %s" % [e["name"], e["tell"]]; l.custom_minimum_size = Vector2(230, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 22); l.add_theme_color_override("font_color", INK); row.add_child(l)
		for a in [["Calm", "comfort"], ["Scare", "unsettle"]]:
			var b := _btn(row, a[0], night_do.bind(a[1], e["id"]), 20, 52)
			b.disabled = game.night_budget <= 0
	_lbl(box, "Visits left: %d" % game.night_budget, 28, RED)
	var sl := _btn(box, "Sleep until dawn", next_morning, 32, 72)
	sl.name = "Sleep"
	_btn(box, "Lives so far", show_lives, 24, 56)


func night_do(action: String, target: String) -> Dictionary:
	var r: Dictionary = game.night_visit(action, target)
	_say(r["text"])
	show_host()
	return r


func next_morning() -> String:
	map.snapshot()
	var id: String = game.dawn()
	map.animate_to_now(0.2)
	last_talk = {}
	_say("")
	_refresh_hud()
	_wake_card()
	return id


func show_lives() -> void:
	_clear_panel()
	_head(box, "Everyone you've been", 40)
	var rep: Array = game.lives_report()
	for r in rep:
		var tag := "gone" if r["gone"] else "%s" % r["mood_word"]
		var delta: int = int(r["money_now"]) - int(r["money_then"])
		_lbl(box, "Day %d  %s  ·  %s  ·  $%d (%s$%d since)" % [r["day"], r["name"], tag, r["money_now"], "+" if delta >= 0 else "-", absi(delta)], 22)
	_btn(box, "Back", show_host, 30, 64)
