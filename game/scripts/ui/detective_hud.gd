extends "res://scripts/ui/town3d_hud.gd"
## The detective's screens over the 3D town: the case file, the scene menu, interrogation, your sheet, the accusation.
## Noir paper-and-ink look; every panel shows the clock and what each button costs in minutes.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const Justice = preload("res://scripts/detective/justice.gd")
const Serial = preload("res://scripts/detective/serial.gd")
const News = preload("res://scripts/detective/news.gd")
const Waypoint = preload("res://scripts/ui/waypoint.gd")
const FullMap = preload("res://scripts/ui/full_map.gd")
const SceneView = preload("res://scripts/ui/scene_view.gd")
const DustPad = preload("res://scripts/ui/dust_pad.gd")
const TutorialOverlay = preload("res://scripts/ui/tutorial_overlay.gd")

const GREEN := UiKit.GREEN
const OXBLOOD := UiKit.OXBLOOD
const WINDOWS := [["Evening, 6 pm to midnight", 18.0, 24.0], ["Midnight to 3 am", 24.0, 27.0], ["3 am to 6 am", 27.0, 30.0]]
const TABS := [["Case", "case", "case"], ["Notes", "notebook", "notebook"], ["People", "people", "people"], ["News", "news", "news"],
	["CCTV", "cctv", "cctv"], ["Court", "court", "court"], ["Accuse", "accuse", "accuse"], ["You", "you", "you"]]
const NB_FILTERS := [["All", "all"], ["Evidence", "evidence"], ["Testimony", "testimony"], ["Lab", "lab"], ["Lore", "lore"]]
const MOTIVES := {"grudge": "An old grudge", "money": "Money", "family": "Inheritance", "silence": "To keep a secret", "passion": "Jealousy"}
const METHODS := {"blunt": "A blow to the head", "knife": "A knife", "strangle": "Strangulation", "poison": "Poison"}
# what each action costs, in minutes (the case rules in scripts/detective charge these)
const COST_ASK := 6
const COST_SHOW := 5
const COST_FRIENDLY := 5
const COST_SPOT := 15
const COST_DUST := 20
const COST_SAMPLE := 10
const COST_LAB := 15
const COST_WARRANT := 30
const COST_WATCH := 30
const COST_CLOCK := 10

var cam_sel := ""
var obj_label: Label
var obj_box: PanelContainer
var dist_label: Label
var travel_btn: Button
var scene_btn: Button      # one tap to the crime scene, whatever the objective says
var waypoint: Control
var tab := "case"
var sel_culprit := ""
var acc_query := ""
var acc_list: VBoxContainer
var sel_motive := ""
var sel_method := ""
var result_text := ""
var force_tutorial := false
var tutorial: Control
var nb_filter := "all"
var nb_query := ""
var nb_open: Dictionary = {}
var nb_limit := 25
var nb_list: VBoxContainer
var nb_new: Dictionary = {}
var _seen_n := 0
var _obj_timer := 0.0
var _last_level := 1
var _acc_armed := false


func _extra_topbar() -> Array:
	return [["Case", "CaseBtn", show_case, "case"], ["Map", "MapBtn", open_full_map, "map"]]


var full_map: Control


## The big map: pan, pinch, tap a place for its card, fast travel from there.
func open_full_map() -> void:
	if full_map != null and is_instance_valid(full_map):
		close_full_map()
		return
	full_map = FullMap.new()
	full_map.setup(game, _objective_lot())
	full_map.player_world = Vector2(world.player.global_position.x, world.player.global_position.z)
	full_map.player_yaw = world.player.yaw
	full_map.travel_requested.connect(func(lot: String):
		close_full_map()
		travel_to_objective(lot))
	full_map.closed.connect(close_full_map)
	add_child(full_map)
	full_map.refresh()


func close_full_map() -> void:
	if full_map != null and is_instance_valid(full_map):
		full_map.queue_free()
	full_map = null


# ------------------------------------------------------------------ furniture: objective chip, waypoint
func _hud_built() -> void:
	_last_level = int(game.det.level)
	_seen_n = int(game.det.order.size())
	obj_box = PanelContainer.new()
	obj_box.name = "ObjBox"
	obj_box.add_theme_stylebox_override("panel", UiKit.box(Color(0.96, 0.92, 0.82, 0.94), INK, 3, 12, 8))
	obj_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(obj_box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	obj_box.add_child(hb)
	var pin := TabIcon.new().setup("pin", RED, 30.0)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(pin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var cap := Label.new()
	cap.text = "OBJECTIVE"
	cap.add_theme_font_size_override("font_size", UiKit.fs(15))
	cap.add_theme_color_override("font_color", RED)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cap)
	obj_label = Label.new()
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.add_theme_font_size_override("font_size", UiKit.fs(22))
	obj_label.add_theme_color_override("font_color", INK)
	obj_label.custom_minimum_size = Vector2(330, 0)
	obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(obj_label)
	dist_label = Label.new()
	dist_label.add_theme_font_size_override("font_size", UiKit.fs(19))
	dist_label.add_theme_color_override("font_color", VIOLET)
	dist_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(dist_label)
	travel_btn = Button.new()
	travel_btn.name = "TravelBtn"
	travel_btn.text = "Travel there"
	travel_btn.clip_text = false
	travel_btn.add_theme_font_size_override("font_size", UiKit.fs(22))
	travel_btn.custom_minimum_size = Vector2(150, 56)
	travel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.set_button_style(travel_btn, INK, INK, PAPER)
	UiKit.press_fx(travel_btn)
	travel_btn.pressed.connect(func(): travel_to_objective())
	hb.add_child(travel_btn)
	scene_btn = Button.new()
	scene_btn.name = "SceneBtn"
	scene_btn.text = "To scene"
	scene_btn.clip_text = false
	scene_btn.add_theme_font_size_override("font_size", UiKit.fs(22))
	scene_btn.custom_minimum_size = Vector2(130, 56)
	scene_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.set_button_style(scene_btn, Color("7a2323"), Color("7a2323"), PAPER)
	UiKit.press_fx(scene_btn)
	scene_btn.pressed.connect(travel_to_scene)
	hb.add_child(scene_btn)
	waypoint = Waypoint.new()
	add_child(waypoint)
	waypoint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	waypoint.camera = world.player.cam
	move_child(waypoint, 1)                     # over the look pad, under every button
	_refresh_objective()


func _layout_extra(sm: Vector4) -> void:
	if obj_box == null:
		return
	var left := sm.x + 232.0
	var avail := minf(640.0, size.x - left - sm.z - 12.0)
	obj_box.position = Vector2(left, TOPBAR_H + 8.0)
	obj_box.custom_minimum_size = Vector2(avail, 0)
	obj_box.size = Vector2(avail, 20)
	obj_label.custom_minimum_size = Vector2(maxf(160.0, avail - 34.0 - 150.0 - 40.0), 0)
	waypoint.margin = Vector4(sm.x + 40.0, TOPBAR_H + 150.0, sm.z + 40.0, sm.w + 130.0)


func _refresh_objective() -> void:
	if obj_label == null:
		return
	obj_label.text = game.objective()
	var lot := _objective_lot()
	var phase_day: bool = game.phase == "day"
	var sl: String = game.scene_lot()
	scene_btn.visible = phase_day and sl != "" and world.builder.doors.has(sl) and not game.solved() and world.inside == "" and sl != lot and game.me().location != sl
	if lot == "" or not world.builder.doors.has(lot):
		dist_label.text = ""
		travel_btn.visible = false
		waypoint.clear_target()
		return
	var d: Dictionary = world.builder.doors[lot]
	waypoint.set_target(d["front"], game.place_name(lot))
	waypoint.player_pos = world.player.global_position
	var m := Vector2(d["front"].x - world.player.global_position.x, d["front"].z - world.player.global_position.z).length()
	dist_label.text = ("%s  ·  %d m away" % [game.place_name(lot), int(round(m))]) if m >= 12.0 else ("You are at %s." % game.place_name(lot))
	map.target_world = Vector2(d["front"].x, d["front"].z)
	var mins := travel_minutes(lot)
	travel_btn.visible = phase_day and m > 12.0
	travel_btn.text = "Travel there" if mins == 0 else "Travel  %s" % UiKit.minutes_text(mins)


## The building the objective points at: the scene first, then wherever the next person to question is.
func _objective_lot() -> String:
	if game.solved():
		return ""
	var det: RefCounted = game.det
	if not det.has("c_body"):
		return game.scene_lot()
	var asked := {}
	for st in det.statements:
		asked[st["npc"]] = true
	var order: Array = game.persons_of_interest()
	for id in order:
		if String(id) != "" and not asked.has(id) and game.sim.people.has(id):
			var p: RefCounted = game.sim.people[id]
			var lot := String(p.location)
			if world.builder.doors.has(lot):
				return lot
			if world.builder.doors.has(String(p.home)):
				return String(p.home)
	return game.scene_lot()


func travel_minutes(lot: String) -> int:
	return int(game.distance(game.me().location, lot) / 450.0) * 30


## Fast travel: the sim's own walk, so the minutes come off the day.
func travel_to_scene() -> void:
	travel_to_objective(game.scene_lot())


func travel_to_objective(target: String = "") -> void:
	var lot := target if target != "" else _objective_lot()
	if lot == "" or game.phase != "day":
		return
	var r: Dictionary = go(lot)
	if not r.get("ok", false):
		if game.me().location == lot:
			world.arrive_at(lot)              # standing a way off, but "at" the building as far as the sim goes: just step to the door
			_say("You walk to %s." % game.place_name(lot))
			close_panel()
		else:
			_say(String(r.get("text", "")))
	UiKit.haptic(20)


func _process(delta: float) -> void:
	super._process(delta)
	if waypoint != null and world != null:
		waypoint.player_pos = world.player.global_position
	_obj_timer -= delta
	if _obj_timer <= 0.0 and obj_label != null:
		_obj_timer = 0.5
		_refresh_objective()
		_update_visibility()
		_update_badges()
		_check_level()


func _update_visibility() -> void:
	var clear: bool = not panel.visible and card == null and (settings_ui == null or not is_instance_valid(settings_ui))
	obj_box.visible = clear and world.inside == ""
	waypoint.visible = clear and world.inside == "" and not game.solved()
	mini.visible = card == null


func _update_badges() -> void:
	var unseen := maxi(0, int(game.det.order.size()) - _seen_n)
	if _topicons.has("CaseBtn"):
		(_topicons["CaseBtn"] as Control).set_count(unseen)
	if _topicons.has("MeBtn"):
		(_topicons["MeBtn"] as Control).set_count(int(game.det.points))


func _check_level() -> void:
	var lv: int = int(game.det.level)
	if lv > _last_level:
		_last_level = lv
		_say("Level %d. %d skill points to spend: open Sheet." % [lv, int(game.det.points)])
		UiKit.haptic(60)


func close_panel() -> void:
	super.close_panel()
	_acc_armed = false
	if game.flush_time() > 0:
		world.time_skipped()


func _step_out() -> void:
	super._step_out()
	if game.flush_time() > 0:
		world.time_skipped()


func _card(title: String, subtitle: String, body: String, button: String, cb: Callable, person: RefCounted = null) -> void:
	super._card(title, subtitle, body, button, cb, person)
	if card != null:
		_raise_overlays()          # the page sits above the objective box and every other HUD piece
		if obj_box != null:
			obj_box.visible = false
			waypoint.visible = false
	if act_btn != null:
		act_btn.visible = false


func _close_card() -> void:
	super._close_card()
	if act_btn != null:
		if not panel.visible:
			world.refresh_prompt(true)
		_on_prompt(world.prompt)


# ------------------------------------------------------------------ the tutorial
func _should_tutorial() -> bool:
	if force_tutorial:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	return not bool(UiKit.get_v("tutorial_done")) and int(game.sim.day) == 1


func start_tutorial(_force: bool = false) -> void:
	if tutorial != null and is_instance_valid(tutorial):
		return
	var t := TutorialOverlay.new()
	tutorial = t
	add_child(t)
	t.start(self)
	t.finished.connect(func(_s): tutorial = null)
	_raise_overlays()


## Where each tutorial step's ring goes: the real control it teaches.
func tut_rect(key: String) -> Rect2:
	var tb: Control = get_node("TopBar")
	match key:
		"move":
			return Rect2(_safe.x + 20.0, size.y - 300.0, 330.0, 270.0)
		"look":
			return Rect2(size.x - 440.0, size.y * 0.3, 360.0, 260.0)
		"objective":
			if obj_box != null:
				return Rect2(obj_box.position, obj_box.size)
		"interact":
			return Rect2(size.x - _safe.z - 430.0, size.y - _safe.w - 124.0, 430.0, 116.0)
		"case":
			var b: Control = tb.get_node("CaseBtn")
			return Rect2(tb.position + b.position, b.size)
		"time":
			var b2: Control = tb.get_node("SpeedBtn")
			return Rect2(tb.position + b2.position, b2.size)
	return Rect2(size / 2.0 - Vector2(100, 60), Vector2(200, 120))


func _menu_extra() -> void:
	var tb := _btn(box, "Replay the tutorial", func(): close_panel(); start_tutorial(true), 28, 68)
	tb.name = "TutorialBtn"


# ------------------------------------------------------------------ mornings and nights
func _after_wake() -> void:
	super._after_wake()
	if _should_tutorial() and tutorial == null:
		start_tutorial()


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


## The end-of-day page: what the day taught you, what the lab owes you, who arrived, the headlines, how you are holding up.
func _report_card() -> void:
	var d: RefCounted = game.det
	var day: int = int(game.sim.day)
	_card("DAY %d" % day, "The day is done", "", "Sleep until morning", _eod_sleep, game.me())
	card_body.visible = false
	_compact_card()
	_eod_stress()
	var learned: Array = []
	for eid in d.order:
		var e: Dictionary = d.known[eid]
		if int(e.get("day", 0)) == day and not String(eid).begins_with("cmp_"):
			learned.append(String(e["title"]))
	var counts := {}
	var titles: Array = []
	for t in learned:
		if not counts.has(t):
			titles.append(t)
		counts[t] = int(counts.get(t, 0)) + 1
	var lines: Array = []
	for t in titles.slice(0, 4):
		lines.append("%s%s" % [t, " x%d" % counts[t] if counts[t] > 1 else ""])
	if titles.size() > 4:
		lines.append("and %d more in the notebook" % (titles.size() - 4))
	var stm := 0
	for st in d.statements:
		if int(st.get("day", 0)) == day:
			stm += 1
	if lines.is_empty():
		lines.append("Nothing new went into the notebook today.")
	if stm > 0:
		lines.append("%d statement%s taken." % [stm, "" if stm == 1 else "s"])
	_eod_section("WHAT YOU LEARNED", lines)
	var lab_lines: Array = []
	for l in d.lab:
		var cid := String(l.get("clue", ""))
		var nm: String = String(d.known[cid]["title"]) if d.known.has(cid) else cid
		var rd := int(l.get("ready_day", day + 1))
		lab_lines.append("%s: %s" % [nm, "ready tomorrow morning" if rd <= day + 1 else "due on day %d" % rd])
	_eod_section("AT THE LAB", lab_lines if not lab_lines.is_empty() else ["Nothing waiting on the lab."])
	var news_in: Array = []
	for n in game.newcomers:
		if int(n.get("arrived", 0)) >= day - 2:
			news_in.append("%s, %d, %s: now living in %s." % [n["name"], int(n["age"]), n["job"], game.place_name(n["home"])])
	if not news_in.is_empty():
		_eod_section("NEW IN TOWN", news_in)
	var heads: Array = []
	for c in game.chronicle:
		if int(c["day"]) == day:
			heads.append(String(c["text"]))
	var nw: Array = game.news()
	if not nw.is_empty():
		heads.append(String(nw[nw.size() - 1]["head"]))
	_eod_section("HEADLINES", heads.slice(0, 4) if not heads.is_empty() else ["Nothing in the Courier today. A quiet town, or a careful one."])
	var sec := _btn(card_button.get_parent(), "Read the case file first", func(): _close_card(); show_case(), 24, 56)
	sec.name = "CardSecondary"
	sec.custom_minimum_size = Vector2(0, 48)
	card_button.get_parent().move_child(sec, card_button.get_index())
	var tail := Control.new()          # room under the last line so it never ends flush against the buttons
	tail.custom_minimum_size = Vector2(0, 10)
	card_content.add_child(tail)
	UiKit.haptic(30)


## A tighter page for the long end-of-day report: smaller headings and buttons so the list gets the height.
func _compact_card() -> void:
	var v: Control = card_button.get_parent()
	var heads := 0
	for c in v.get_children():
		if c is Label and heads < 2:
			(c as Label).add_theme_font_size_override("font_size", 46 if heads == 0 else 28)
			heads += 1
	v.add_theme_constant_override("separation", 6)
	card_button.custom_minimum_size = Vector2(0, 62)
	card_content.add_theme_constant_override("separation", 6)


func _eod_stress() -> void:
	var d: RefCounted = game.det
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card_content.add_child(row)
	var sl := Label.new()
	sl.text = "Stress %d/100" % int(d.stress)
	sl.custom_minimum_size = Vector2(190, 0)
	sl.add_theme_font_size_override("font_size", UiKit.fs(24))
	sl.add_theme_color_override("font_color", INK)
	row.add_child(sl)
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = d.stress
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(300, 26)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.name = "StressBar"
	row.add_child(pb)
	var tip := "Level %d  ·  XP %d/%d" % [d.level, d.xp, d.level * d.XP_PER_LEVEL]
	if d.stress >= 70.0:
		tip += "  ·  your skills are fraying. Sleep."
	if d.points > 0:
		tip += "  ·  %d skill points to spend" % d.points
	var tl := _lbl(card_content, tip, 22, VIOLET)
	tl.custom_minimum_size = Vector2(0, 0)


func _eod_section(title: String, lines: Array) -> void:
	var h := _head(card_content, title, 26, RED)
	h.custom_minimum_size = Vector2(0, 0)
	for l in lines:
		var lb := _lbl(card_content, "·  " + String(l), 22)
		lb.custom_minimum_size = Vector2(0, 0)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _eod_sleep() -> void:
	_close_card()
	next_morning()


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
	_lbl(box, "The town is quiet. Somewhere out there someone is sleeping badly.", 24)
	_need("Stress", game.det.stress)
	if not game.today.is_empty():
		_lbl(box, "\n".join(game.today.slice(-4)), 22, VIOLET)
	_btn(box, "Case file", show_case, 30, 66)
	var sl := _btn(box, "Sleep until morning", next_morning, 32, 76)
	sl.name = "Sleep"
	UiKit.set_button_style(sl, INK, INK, PAPER)
	_bottom_room()


func _inside_panel() -> void:
	var lot: String = world.inside
	var l: Dictionary = game.layout.by_id.get(lot, {})
	_head(box, game.place_name(lot) if l.get("kind", "") in ["house", "home"] else String(l.get("name", lot)), 38)
	if lot == game.scene_lot() and not game.solved():
		UiKit.stamp(box, "THE SCENE  ·  TAPE ACROSS THE DOOR", RED, 18)
	if result_text != "":
		var rp := PanelContainer.new()
		rp.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 10))
		box.add_child(rp)
		var rl := _lbl(rp, result_text, 23)
		rl.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
		rl.name = "Result"
	_lbl(box, "LOOK CLOSER", 20, VIOLET)
	for s in game.spots(lot):
		var b := _btn(box, "%s  (%d min)" % [s["label"], COST_SPOT], _spot.bind(lot, s["id"]), 26, 62)
		b.name = "Spot_" + s["id"]
	if lot == game.scene_lot() and game.det.tools.has("fingerprint kit"):
		_lbl(box, "DUST FOR PRINTS", 20, VIOLET)
		var shown := {}
		for spot in game.dust_spots():
			if not shown.has(spot):
				shown[spot] = true
				var pb := _btn(box, "Dust: %s  (%d min)" % [Prints.SPOT_NAMES.get(spot, spot), COST_DUST], _dust.bind(lot, spot), 24, 58)
				pb.name = "Dust_" + spot
	var here: Array = game.people_here()
	if not here.is_empty():
		_lbl(box, "HERE WITH YOU", 20, VIOLET)
		for id in here.slice(0, 6):
			var q: RefCounted = game.sim.people[id]
			var tb := _btn(box, "Talk to %s  (%s)" % [q.display, q.job], show_talk.bind(id), 24, 60)
			tb.name = "Talk_" + id
	if lot == game.me().home:
		var rest := _btn(box, "Sleep until morning", end_day, 28, 64)
		rest.name = "SleepHome"
	_btn(box, "Case file", show_case, 26, 58)
	var out := _btn(box, "Step outside", _step_out, 32, 72)
	out.name = "StepOut"
	UiKit.set_button_style(out, INK, INK, PAPER)


var _examined := {}


func _spot(lot: String, spot: String) -> void:
	_examined[lot + "|" + spot] = true
	UiKit.haptic(15)
	var r: Dictionary = game.examine(lot, spot)
	result_text = r["text"]
	_learned(r["learned"])
	show_host()


## Dusting by hand: the brush pad comes first; the game is asked what the powder found once enough has been brushed.
func _dust_pad(lot: String, spot: String) -> void:
	_clear_panel()
	_head(box, "DUSTING", 38)
	var pad := DustPad.new()
	pad.title = String(Prints.SPOT_NAMES.get(spot, spot))
	pad.custom_minimum_size = Vector2(PANEL_W - 60.0, 280)
	box.add_child(pad)
	pad.brushed.connect(func(_c: float):
		UiKit.haptic(25)
		_dust(lot, spot))
	var skip := _btn(box, "Quick dust (skip the brush)", _dust.bind(lot, spot), 22, 56)
	skip.name = "QuickDust_" + spot


func _dust(lot: String, spot: String) -> void:
	var r: Dictionary = game.dust(lot, spot)
	result_text = r["text"]
	_learned(r["learned"])
	show_host()


func _learned(entries: Array) -> void:
	if not entries.is_empty():
		var counts := {}
		var order: Array = []
		for e in entries:
			var t := String(e["title"])
			if not counts.has(t):
				order.append(t)
			counts[t] = int(counts.get(t, 0)) + 1
		var parts: Array = order.map(func(t): return "%s x%d" % [t, counts[t]] if counts[t] > 1 else t)
		_say("New in your notebook: %s" % ", ".join(parts))
		UiKit.haptic(30)
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


## Typed out line by line. A tap anywhere on the page finishes it at once.
func _typewriter() -> void:
	if card == null or card_body == null:
		return
	var lbl := card_body
	lbl.visible_ratio = 0.0
	var tw := card.create_tween()          # dies with the page
	tw.tween_property(lbl, "visible_ratio", 1.0, clampf(float(lbl.text.length()) / 70.0, 1.0, 10.0))
	var hint := Label.new()
	hint.name = "SkipHint"
	hint.text = "Tap to skip"
	hint.add_theme_font_size_override("font_size", UiKit.fs(18))
	hint.add_theme_color_override("font_color", VIOLET)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var holder := card_button.get_parent()
	holder.add_child(hint)
	holder.move_child(hint, card_button.get_index())
	_typing = {"lbl": weakref(lbl), "hint": weakref(hint), "tw": tw}
	var st := _typing
	tw.finished.connect(func(): _finish_typing(st))
	card.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_finish_typing(st))


var _typing: Dictionary = {}


func _finish_typing(st: Dictionary) -> void:
	var lbl: Object = (st["lbl"] as WeakRef).get_ref()
	var hint: Object = (st["hint"] as WeakRef).get_ref()
	if lbl != null and (lbl as Label).visible_ratio < 1.0:
		(st["tw"] as Tween).kill()
		(lbl as Label).visible_ratio = 1.0
	if hint != null:
		(hint as Node).queue_free()


func _sheet_panel() -> void:
	var d: RefCounted = game.det
	_tab_bar("you")
	_head(box, "DETECTIVE", 40)
	_lbl(box, "Level %d  ·  XP %d/%d" % [d.level, d.xp, d.level * d.XP_PER_LEVEL], 24)
	if d.points > 0:
		var pt := UiKit.stamp(box, "%d SKILL POINTS TO SPEND" % d.points, RED, 20, true)
		pt.name = "PointsBadge"
	_need("Stress", d.stress)
	for s in d.SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var l := Label.new()
		l.text = "%s  %d" % [d.LABELS[s], d.skill(s)]
		l.custom_minimum_size = Vector2(200, 0)
		l.add_theme_font_size_override("font_size", UiKit.fs(26))
		l.add_theme_color_override("font_color", INK)
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.min_value = 0
		pb.max_value = 10
		pb.value = d.skill(s)
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(110, 22)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		if d.points > 0:
			var up := _btn(row, "+", _spend.bind(s), 28, 56)
			up.custom_minimum_size.x = 64
			up.size_flags_horizontal = Control.SIZE_SHRINK_END
			up.name = "Spend_" + s
	_lbl(box, "Tools: " + ", ".join(d.tools), 22, VIOLET)
	_lbl(box, "Sheriff %+d  ·  Town %+d  ·  Cases solved %d" % [d.reputation["sheriff"], d.reputation["town"], d.cases_solved], 22, VIOLET)
	_btn(box, "Case file", show_case, 30, 66)


func _spend(skill: String) -> void:
	game.det.spend_point(skill)
	UiKit.haptic(15)
	show_host()


# ------------------------------------------------------------------ talking
func show_talk(npc: String) -> void:
	_clear_panel()
	box.add_theme_constant_override("separation", 6)
	talk_npc = npc
	var q: RefCounted = game.sim.people[npc]
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	box.add_child(hdr)
	var tone := ""
	if not last_talk.is_empty() and last_talk.get("npc", "") == npc:
		tone = last_talk.get("tone", "")
	hdr.add_child(_portrait(q, 64, tone))
	var hv := VBoxContainer.new()
	hdr.add_child(hv)
	_head(hv, q.display, 34).custom_minimum_size = Vector2(PANEL_W - 210.0, 0)
	_lbl(hv, "%d · %s" % [q.age, q.job], 22).custom_minimum_size = Vector2(PANEL_W - 210.0, 0)
	var rel := String(load("res://scripts/sim/relationship.gd").describe(game.sim, "player", npc))
	_lbl(hv, rel.capitalize(), 22, VIOLET).custom_minimum_size = Vector2(PANEL_W - 210.0, 0)
	var line := ""
	if not last_talk.is_empty() and last_talk.get("npc", "") == npc:
		line = last_talk["text"]
	else:
		var ops: Array = load("res://scripts/core/reactions.gd").openers(game.sim, npc, "player", game.sim.day)
		line = "\"%s\"" % ops[0]["text"] if not ops.is_empty() else "(They look at you. They've heard what happened.)"
	_balloon(line)
	var victim: String = CaseEngine.first(game.sim, game.case["victim"])
	var qs := [["Where were you last night?", "alibi", COST_ASK], ["How did you know %s?" % victim, "victim", COST_ASK], ["Who do you suspect?", "suspects", COST_ASK], ["Did you see anything?", "saw", COST_ASK]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for x in qs:
		var b := _wbtn(grid, "%s  (%d min)" % [x[0], x[2]], _q.bind(npc, x[1], ""))
		b.name = "Q_" + x[1]
	var wb := _wbtn(grid, "Ask where someone else was...", _ask_about_menu.bind(npc))
	wb.name = "Q_about"
	var tm := _wbtn(grid, "Ask about a person...", _person_menu.bind(npc))
	tm.name = "Q_person"
	var sb := _wbtn(grid, "Show them evidence...", _present_menu.bind(npc))
	sb.name = "Q_show"
	var fb := _wbtn(grid, "Be friendly  (%d min)" % COST_FRIENDLY, _friendly.bind(npc))
	fb.name = "Q_friendly"
	var lv := _btn(box, "Done talking", _leave_talk, 26, 50)
	lv.name = "Q_leave"
	UiKit.set_button_style(lv, INK, INK, PAPER)
	_bottom_room(8.0)


## A wrapping two-line button for the question grid.
func _wbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := _btn(parent, text, cb, 20, 52)
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


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
	_head(box, "Where was...?", 38)
	_lbl(box, "Ask %s where someone else was last night.  (%d min each)" % [CaseEngine.first(game.sim, npc), COST_ASK], 22)
	for sid in game.persons_of_interest():
		if sid != npc:
			_btn(box, CaseEngine.name_of(game.sim, sid), _q.bind(npc, "alibi", sid), 26, 62)
	_btn(box, "Back to the conversation", show_talk.bind(npc), 26, 60)


func _person_menu(npc: String) -> void:
	_clear_panel()
	_head(box, "Ask about a person", 38)
	_lbl(box, "What does %s think of them?  (%d min each)" % [CaseEngine.first(game.sim, npc), COST_ASK], 22)
	for sid in game.persons_of_interest() + [game.case["victim"]]:
		if sid != npc:
			_btn(box, CaseEngine.name_of(game.sim, sid), _q.bind(npc, "person", sid), 26, 62)
	_btn(box, "Back to the conversation", show_talk.bind(npc), 26, 60)


func _present_menu(npc: String) -> void:
	_clear_panel()
	_head(box, "Show them evidence", 38)
	_lbl(box, "Pick something from your notebook.  (%d min)" % COST_SHOW, 22)
	if game.det.order.is_empty():
		_lbl(box, "Your notebook is empty.", 24)
	for eid in game.det.order:
		if String(eid).begins_with("cmp_"):
			continue
		var e: Dictionary = game.det.known[eid]
		var b := _btn(box, String(e["title"]), _present.bind(npc, eid), 24, 56)
		b.name = "Show_" + eid
	_btn(box, "Back to the conversation", show_talk.bind(npc), 26, 60)


func _present(npc: String, eid: String) -> void:
	var r: Dictionary = game.present(npc, eid)
	last_talk = {"npc": npc, "text": r["text"], "tone": "neutral"}
	_learned(r["learned"])
	show_talk(npc)


# ------------------------------------------------------------------ the case file
## The eight tabs: an icon over a short label, two rows of four, each a big target. `current` is the one showing.
func _tab_bar(current: String) -> void:
	var grid := GridContainer.new()
	grid.name = "TabBar"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var unseen := maxi(0, int(game.det.order.size()) - _seen_n)
	for t in TABS:
		var sel: bool = current == t[1]
		var b := Button.new()
		b.text = t[0]
		b.name = "Tab_" + t[1]
		b.clip_text = false
		b.custom_minimum_size = Vector2(0, 68)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiKit.fs(21))
		var fill := INK if sel else PAPER
		var fcol := PAPER if sel else INK
		for st in ["normal", "hover", "focus", "disabled"]:
			var s := UiKit.box(fill, INK, 3, 10, 4)
			s.content_margin_top = 30
			b.add_theme_stylebox_override(st, s)
		var sp := UiKit.box(MARIGOLD, INK, 3, 10, 4)
		sp.content_margin_top = 30
		b.add_theme_stylebox_override("pressed", sp)
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
			b.add_theme_color_override(c, fcol)
		var ic := TabIcon.new().setup(t[2], fcol, 26.0)
		ic.set_anchors_preset(Control.PRESET_CENTER_TOP)
		ic.offset_left = -13
		ic.offset_right = 13
		ic.offset_top = 6
		ic.offset_bottom = 32
		b.add_child(ic)
		if t[1] == "notebook" and unseen > 0 and not sel:
			ic.set_count(unseen)
		if t[1] == "you" and int(game.det.points) > 0:
			ic.set_count(int(game.det.points))
		if t[1] == "you":
			b.pressed.connect(open_me)
		else:
			b.pressed.connect(show_case.bind(t[1]))
		UiKit.press_fx(b)
		grid.add_child(b)


func show_case(tab_name: String = "") -> void:
	_clear_panel()
	var prev := tab
	if tab_name != "":
		tab = tab_name
	if tab != "accuse":
		_acc_armed = false
	if tab == "notebook" and prev != "notebook":
		nb_new = {}
		for eid in game.det.order.slice(_seen_n):
			nb_new[eid] = true
		nb_limit = 25
	_tab_bar(tab)
	if Serial.active(game.serial):
		var row2 := HBoxContainer.new()
		box.add_child(row2)
		_pressure_bar(row2)
	match tab:
		"news": _tab_news()
		"case": _tab_case()
		"notebook":
			_tab_notebook()
			_seen_n = int(game.det.order.size())
		"people": _tab_people()
		"cctv": _tab_cctv()
		"court": _tab_court()
		"accuse": _tab_accuse()


## The town's patience, 0-100, and how many days are left before the state police come.
func _pressure_bar(parent: Control) -> void:
	if not Serial.active(game.serial):
		return
	var p: float = game.pressure()
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = p
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 30)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.name = "PressureBar"
	parent.add_child(bar)
	var left: int = Serial.days_left(game.serial, int(game.sim.day))
	var pl := _lbl(parent, " PRESSURE %d  ·  %s  ·  %d days" % [int(p), String(News.stage(p)).to_upper(), left], 17, RED if p >= 70.0 else VIOLET)
	pl.name = "PressureLabel"
	pl.custom_minimum_size = Vector2(PANEL_W - 64.0 - 160.0, 0)


## A friendly empty page: a headline and why it is empty.
func _empty_state(head: String, body: String) -> void:
	var pc := PanelContainer.new()
	pc.name = "EmptyState"
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), VIOLET, 3, 12, 18))
	box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var h := _head(v, head, 30, VIOLET)
	h.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	var b := _lbl(v, body, 22)
	b.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)


func _tab_news() -> void:
	_head(box, "THE LITTLE MERCY COURIER", 32)
	var s: Dictionary = game.serial
	var rl: String = News.radio(s)
	if rl != "":
		_lbl(box, rl, 20, VIOLET)
	var items: Array = game.news()
	var log_items: Array = game.chronicle.slice(-6)
	if items.is_empty() and log_items.is_empty():
		_empty_state("No headlines yet", "The Courier prints when something happens in town: a death, an arrest, a trial, a stranger arriving. Check back after a day has passed.")
	for i in range(items.size() - 1, maxi(items.size() - 4, -1), -1):
		var p: Dictionary = items[i]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 10))
		box.add_child(pc)
		var v := VBoxContainer.new()
		pc.add_child(v)
		_head(v, "%s  (day %d)" % [String(p["head"]), int(p["day"])], 24).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
		_lbl(v, String(p["body"]), 20).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	if not log_items.is_empty():
		_lbl(box, "AROUND TOWN", 20, VIOLET)
		for c in log_items:
			_lbl(box, "Day %d: %s" % [int(c["day"]), String(c["text"])], 20)
	var lt: String = News.letter(s, int(game.sim.day))
	if lt != "":
		_lbl(box, "LETTERS: " + lt, 18, VIOLET)


func _tab_case() -> void:
	var c: Dictionary = game.case
	var v: RefCounted = game.sim.people[c["victim"]]
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	box.add_child(hdr)
	hdr.add_child(_portrait(v, 90, "sad"))
	var hv := VBoxContainer.new()
	hdr.add_child(hv)
	_head(hv, "THE DEATH OF %s" % String(v.display).to_upper(), 30).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	_lbl(hv, "%d · %s" % [v.age, v.job], 22).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	if game.solved():
		UiKit.stamp(hv, "CASE CLOSED", GREEN, 20, true)
	_lbl(box, game.briefing(), 24)
	var d: RefCounted = game.det
	_fact("CAUSE", String(d.known["c_body"]["text"]) if d.has("c_body") else "not yet established", d.has("c_body"))
	_fact("TIME OF DEATH", String(d.known["c_time"]["text"]) if d.has("c_time") else "not yet established", d.has("c_time"))
	var asked := {}
	for st in d.statements:
		asked[st["npc"]] = true
	var interviewed := 0
	for sid in game.persons_of_interest():
		if asked.has(sid):
			interviewed += 1
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 6)
	box.add_child(stats)
	UiKit.stamp(stats, "DAY %d" % game.sim.day, VIOLET, 18)
	UiKit.stamp(stats, "STRESS %d/100" % int(d.stress), RED if d.stress >= 70.0 else VIOLET, 18)
	UiKit.stamp(stats, "NOTES %d" % d.order.size(), VIOLET, 18)
	UiKit.stamp(stats, "QUESTIONED %d/%d" % [interviewed, game.persons_of_interest().size()], VIOLET, 18)
	if not d.lab.is_empty():
		UiKit.stamp(stats, "LAB PENDING %d" % d.lab.size(), RED, 18)
	var nx := PanelContainer.new()
	nx.name = "NextBox"
	nx.add_theme_stylebox_override("panel", UiKit.box(Color(0.89, 0.24, 0.24, 0.12), RED, 3, 10, 10))
	box.add_child(nx)
	var nv := VBoxContainer.new()
	nx.add_child(nv)
	var nh := _lbl(nv, "NEXT", 17, RED)
	nh.custom_minimum_size = Vector2(0, 0)
	var nt := _lbl(nv, game.objective(), 24, INK)
	nt.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	if not game.episodes.is_empty():
		var eb := _btn(box, "Episodes (%d)" % game.episodes.size(), _archive, 26, 60)
		eb.name = "Archive"


func _fact(label: String, text: String, known: bool) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0") if known else Color(0.86, 0.81, 0.7, 0.5), VIOLET, 2, 10, 8))
	box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pc.add_child(v)
	var h := _lbl(v, label, 16, VIOLET)
	h.custom_minimum_size = Vector2(0, 0)
	var b := _lbl(v, text, 21, INK if known else Color("6b6558"))
	b.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)


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


# ------------------------------------------------------------------ the notebook: filters, search, expandable entries
func _entry_cat(e: Dictionary) -> String:
	match String(e.get("kind", "")):
		"physical", "print", "cctv", "doorbell": return "evidence"
		"testimony", "confession": return "testimony"
		"lab": return "lab"
		"lore": return "lore"
	return "evidence"


func _kind_color(cat: String) -> Color:
	match cat:
		"testimony": return Color("2f6f8f")
		"lab": return GREEN
		"lore": return VIOLET
	return OXBLOOD


func _nb_count(f: String) -> int:
	var n := 0
	for eid in game.det.order:
		var e: Dictionary = game.det.known[eid]
		if f == "all" or _entry_cat(e) == f:
			n += 1
	return n


func _tab_notebook() -> void:
	var d: RefCounted = game.det
	if d.order.is_empty():
		_empty_state("The notebook is empty", "Start at the scene. Everything you notice, hear or prove is written here, and it cannot be edited.")
		return
	var flow := HFlowContainer.new()
	flow.name = "Filters"
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	for f in NB_FILTERS:
		var cnt_f := _nb_count(f[1])
		var b := _btn(flow, "%s %d" % [f[0], cnt_f], _nb_set_filter.bind(f[1]), 20, 52)
		b.disabled = cnt_f == 0 and nb_filter != f[1]
		b.name = "Filter_" + f[1]
		b.clip_text = false
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if nb_filter == f[1]:
			UiKit.set_button_style(b, INK, MARIGOLD, PAPER)
	var le := LineEdit.new()
	le.name = "NotebookSearch"
	le.placeholder_text = "Search the notebook"
	le.text = nb_query
	le.clear_button_enabled = true
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", UiKit.fs(22))
	le.add_theme_color_override("font_placeholder_color", Color("6b6558"))
	le.text_changed.connect(_nb_search)
	box.add_child(le)
	nb_list = VBoxContainer.new()
	nb_list.name = "NotebookList"
	nb_list.add_theme_constant_override("separation", 8)
	box.add_child(nb_list)
	_nb_fill()
	if not d.statements.is_empty():
		_lbl(box, "Statements taken: %d" % d.statements.size(), 20, VIOLET)


func _nb_set_filter(f: String) -> void:
	nb_filter = f
	nb_limit = 25
	show_case("notebook")


func _nb_search(t: String) -> void:
	nb_query = t
	nb_limit = 25
	_nb_fill()


func _nb_matches(eid: String) -> bool:
	var e: Dictionary = game.det.known[eid]
	if nb_filter != "all" and _entry_cat(e) != nb_filter:
		return false
	if nb_query.strip_edges() != "":
		var hay := (String(e["title"]) + " " + String(e["text"])).to_lower()
		for w in nb_query.to_lower().split(" ", false):
			if not hay.contains(w):
				return false
	return true


func _nb_fill() -> void:
	if nb_list == null or not is_instance_valid(nb_list):
		return
	for c in nb_list.get_children():
		nb_list.remove_child(c)
		c.queue_free()
	var d: RefCounted = game.det
	var ids: Array = []
	var hidden_cmp := 0
	for i in range(d.order.size() - 1, -1, -1):
		var eid: String = d.order[i]
		if not _nb_matches(eid):
			continue
		if String(eid).begins_with("cmp_") and nb_filter != "lab" and nb_query.strip_edges() == "":
			hidden_cmp += 1
			continue
		ids.append(eid)
	var cnt := _lbl(nb_list, "%d entr%s" % [ids.size(), "y" if ids.size() == 1 else "ies"], 18, VIOLET)
	cnt.name = "NotebookCount"
	cnt.custom_minimum_size = Vector2(0, 0)
	if ids.is_empty():
		var el := _lbl(nb_list, "Nothing matches. Try another filter or word.", 22)
		el.name = "NotebookNone"
	for eid in ids.slice(0, nb_limit):
		_nb_card(eid)
	if ids.size() > nb_limit:
		var mb := _btn(nb_list, "Show more (%d left)" % (ids.size() - nb_limit), func(): nb_limit += 25; _nb_fill(), 24, 56)
		mb.name = "NotebookMore"
	if hidden_cmp > 0:
		_lbl(nb_list, "%d print comparisons are filed under Lab." % hidden_cmp, 18, VIOLET)


func _nb_card(eid: String) -> void:
	var d: RefCounted = game.det
	var e: Dictionary = d.known[eid]
	var open := nb_open.has(eid)
	var cat := _entry_cat(e)
	var pc := PanelContainer.new()
	pc.name = "Card_" + eid
	var st := UiKit.box(Color("fffaf0"), INK, 3, 10, 10)
	if nb_new.has(eid):
		st.border_color = RED
		st.set_border_width_all(4)
	pc.add_theme_stylebox_override("panel", st)
	nb_list.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var tap := PanelContainer.new()
	tap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	v.add_child(tap)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tap.add_child(inner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(head)
	var tl := Label.new()
	tl.text = String(e["title"])
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(150, 0)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_theme_font_override("font", TownTheme.bold())
	tl.add_theme_font_size_override("font_size", UiKit.fs(23))
	tl.add_theme_color_override("font_color", INK)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tl)
	if nb_new.has(eid):
		UiKit.stamp(head, "NEW", RED, 15, true)
	UiKit.stamp(head, String(e.get("kind", cat)).to_upper(), _kind_color(cat), 14)
	var txt := String(e["text"])
	var tx := Label.new()
	tx.text = txt
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	tx.add_theme_font_size_override("font_size", UiKit.fs(21))
	tx.add_theme_color_override("font_color", INK)
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		tx.max_lines_visible = 2
	inner.add_child(tx)
	if open:
		var src := String(e["source"])
		var who: String = CaseEngine.name_of(game.sim, src) if game.sim.people.has(src) else game.place_name(src)
		var sl := Label.new()
		sl.text = "Source: %s  ·  Day %d" % [who, int(e["day"])]
		sl.add_theme_font_size_override("font_size", UiKit.fs(18))
		sl.add_theme_color_override("font_color", VIOLET)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sl)
	elif txt.length() > 90:
		var more := Label.new()
		more.text = "tap to read all"
		more.add_theme_font_size_override("font_size", UiKit.fs(16))
		more.add_theme_color_override("font_color", VIOLET)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(more)
	var ov := Button.new()
	ov.name = "Entry_" + eid
	ov.flat = true
	ov.focus_mode = Control.FOCUS_NONE
	ov.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	ov.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	ov.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pr := UiKit.box(Color(0.96, 0.72, 0.18, 0.22), Color(0, 0, 0, 0), 0, 8, 0)
	ov.add_theme_stylebox_override("pressed", pr)
	ov.pressed.connect(_nb_toggle.bind(eid))
	tap.add_child(ov)
	if open:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var db := _btn(row, "Open", _entry.bind(eid), 20, 52)
		db.name = "Open_" + eid
		if e.get("lab", false) and not d.has("lab_" + eid):
			var lb := _btn(row, "Send to lab", _lab.bind(eid), 20, 52)
			lb.name = "QuickLab_" + eid


func _nb_toggle(eid: String) -> void:
	if nb_open.has(eid):
		nb_open.erase(eid)
	else:
		nb_open[eid] = true
	var sv := scroll.scroll_vertical
	_nb_fill()
	await get_tree().process_frame
	scroll.scroll_vertical = sv


func _entry(eid: String) -> void:
	_clear_panel()
	var e: Dictionary = game.det.known[eid]
	_head(box, String(e["title"]), 34)
	_lbl(box, String(e["text"]), 26)
	_lbl(box, "Source: %s  ·  Day %d" % [CaseEngine.name_of(game.sim, e["source"]) if game.sim.people.has(e["source"]) else game.place_name(e["source"]), int(e["day"])], 20, VIOLET)
	if e.get("lab", false) and not game.det.has("lab_" + eid):
		var lb := _btn(box, "Send to the lab  (%d min)" % COST_LAB, _lab.bind(eid), 28, 64)
		lb.name = "Lab"
	if e.get("latent", "") != "":
		_lbl(box, "Compare with...", 24, VIOLET)
		for sid in game.persons_of_interest() + [game.case["victim"]]:
			if game.det.samples.get(sid, false):
				var cb := _btn(box, CaseEngine.name_of(game.sim, sid), _compare.bind(eid, sid), 24, 56)
				cb.name = "Cmp_" + sid
	_btn(box, "Back to the notebook", show_case.bind("notebook"), 28, 60)


func _compare(eid: String, sid: String) -> void:
	var r: Dictionary = game.compare_print(eid, sid)
	_say(r["text"])
	UiKit.haptic(30)
	_entry(eid)


func _lab(eid: String) -> void:
	var r: Dictionary = game.submit_lab(eid)
	_say(r["text"])
	UiKit.haptic(40)
	show_case("notebook")


# ------------------------------------------------------------------ people
## Everyone worth a card: the suspects, the one who found the body, anyone you have taken a statement from, and the new neighbours.
func _people_groups() -> Array:
	var seen := {}
	var sus: Array = []
	for sid in game.persons_of_interest():
		seen[sid] = true
		sus.append(sid)
	var wit: Array = []
	var fb: String = String(game.case.get("found_by", ""))
	if fb != "" and not seen.has(fb) and game.sim.people.has(fb):
		seen[fb] = true
		wit.append(fb)
	for st in game.det.statements:
		var nid := String(st["npc"])
		if not seen.has(nid) and game.sim.people.has(nid):
			seen[nid] = true
			wit.append(nid)
	var fresh: Array = []
	for n in game.newcomers:
		var nid2 := String(n["id"])
		if not seen.has(nid2) and game.sim.people.has(nid2):
			seen[nid2] = true
			fresh.append(nid2)
	return [["PERSONS OF INTEREST", sus, ""], ["WITNESSES AND OTHERS", wit, ""], ["NEW IN TOWN", fresh, "NEW"]]


func _tab_people() -> void:
	var total := 0
	for g in _people_groups():
		total += (g[1] as Array).size()
		if (g[1] as Array).is_empty():
			continue
		_lbl(box, "%s  (%d)" % [g[0], (g[1] as Array).size()], 20, VIOLET)
		for sid in g[1]:
			_person_card(String(sid), String(g[2]))
	if total == 0:
		_empty_state("No one yet", "People appear here as the case brings them into your notebook.")


func _person_card(sid: String, badge: String) -> void:
	var q: RefCounted = game.sim.people[sid]
	var is_suspect: bool = game.persons_of_interest().has(sid)
	var pc := PanelContainer.new()
	pc.name = "Person_" + sid
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 10))
	box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	v.add_child(hdr)
	hdr.add_child(_portrait(q, 74))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hdr.add_child(hv)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	hv.add_child(nr)
	var nm := _head(nr, q.display, 27)
	nm.custom_minimum_size = Vector2(0, 0)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if badge != "":
		var bs := UiKit.stamp(nr, badge, RED, 15, true)
		bs.name = "NewBadge"
	var mentions := 0
	for eid in game.det.order:
		if String(game.det.known[eid]["text"]).contains(String(q.display).split(" ")[0]):
			mentions += 1
	var said := ""
	for st in game.det.statements:
		if st["npc"] == sid and st["topic"] == "alibi" and st.get("about", "") in ["", sid]:
			said = String(st["text"]).split("\n")[0]
	var jl := _lbl(hv, "%s  ·  %d in your notes" % [q.job, mentions], 20)
	jl.custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	if said != "":
		var sl := _lbl(hv, said, 19, VIOLET)
		sl.custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
		sl.max_lines_visible = 3
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	if is_suspect:
		_btn(grid, "Warrant  (%d min)" % COST_WARRANT, _warrant.bind(sid), 20, 54).name = "Warrant_" + sid
		_btn(grid, "Prints" if not game.det.samples.get(sid, false) else "Prints: on file", _sample.bind(sid), 20, 54).name = "Sample_" + sid
	_btn(grid, "Their circle", _circle.bind(sid), 20, 54).name = "Circle_" + sid
	var mins := travel_minutes(q.home)
	var gb := _wbtn(grid, "Go to their house  (%s)" % ("now" if mins == 0 else UiKit.minutes_text(mins).replace(" ", " ")), go.bind(q.home))
	gb.custom_minimum_size.y = 64
	gb.add_theme_font_size_override("font_size", UiKit.fs(19))


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
		var row := GridContainer.new()
		row.columns = 2
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		box.add_child(row)
		_btn(row, "Where was %s?" % CaseEngine.first(game.sim, sid), _circle_ask.bind(id, "alibi", sid), 20, 54)
		_btn(row, "About them", _circle_ask.bind(id, "person", sid), 20, 54)
		_btn(row, "Go there", go.bind(q.home), 20, 54)
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
		for sid in game.persons_of_interest():
			var b := _btn(box, "Arrest %s" % CaseEngine.name_of(game.sim, sid), _arrest.bind(sid), 22, 58)
			b.name = "Arrest_" + sid
	else:
		var q: RefCounted = game.sim.people[t]
		_head(box, "IN CUSTODY: %s" % String(q.display).to_upper(), 28)
		var ss: Dictionary = game.court["sess"]
		_lbl(box, "Trial on day %d (today is day %d).  Sessions: %d   Rapport: %d   Fatigue: %d" % [game.court["trial_day"], game.sim.day, ss["sessions"], int(ss["rapport"]), int(ss["fatigue"])], 20, VIOLET)
		var dac := PanelContainer.new()
		dac.name = "DaRead"
		dac.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), VIOLET, 3, 10, 10))
		box.add_child(dac)
		var dav := VBoxContainer.new()
		dac.add_child(dav)
		_lbl(dav, "THE DA'S READ", 17, VIOLET)
		_lbl(dav, game.da_advice(t), 20).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
		for a in [["Build rapport", "rapport"], ["Lay out the evidence", "evidence"], ["Apply pressure", "pressure"]]:
			var ib := _btn(box, "%s  (1 h)" % a[0], _interrogate.bind(a[1]), 22, 58)
			ib.name = "Int_" + a[1]
		var tb := _btn(box, "Go to trial", _trial, 26, 64)
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
		var vb := _btn(box, "%s  (%s)" % [p.display, i["type"]], _visit.bind(i["id"]), 22, 58)
		vb.disabled = not open
		vb.name = "Visit_" + i["id"]
	if not game.jail.is_empty() and not open:
		_lbl(box, "Visiting hours are 10 am to 4 pm.", 20, VIOLET)


func _arrest(sid: String) -> void:
	var r: Dictionary = game.arrest(sid)
	result_text = r["text"]
	_say(r["text"])
	UiKit.haptic(50)
	show_case("court")


func _interrogate(approach: String) -> void:
	var r: Dictionary = game.interrogate(approach)
	result_text = r["text"]
	_learned(r["learned"])
	show_case("court")


func _trial() -> void:
	var r: Dictionary = game.run_trial()
	var lines: Array = r["attacks"].map(func(a): return String(a["text"]))
	var body := "\n\n".join(lines) + "\n\nThe jury is out. When it returns, the room is silent.\n\nVERDICT: %s" % String(r["verdict"]).to_upper()
	if r.get("wrongful", false):
		body += "\n\nYou have a bad feeling about this one."
	close_panel()
	world.refresh_markers()
	UiKit.haptic(80)
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
		var b := _btn(box, a[0], _visit_do.bind(id, a[1]), 22, 58)
		b.name = "VT_" + a[1]
	var ab := _btn(box, "Appeal their conviction", _appeal.bind(id), 22, 58)
	ab.name = "Appeal"
	_btn(box, "Back", show_case.bind("court"), 26, 58)


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
	if cam_sel == "":
		_lbl(box, "Pick a camera. Clocks are rarely exact: check one before you trust its times.", 21)
	for cam in game.cameras():
		if cam_sel != "" and cam_sel != cam["id"]:
			continue
		var sel: bool = cam_sel == cam["id"]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0") if not sel else UiKit.PAPER_DIM, INK, 3, 10, 6))
		box.add_child(pc)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		pc.add_child(hb)
		var b := Button.new()
		b.text = String(cam["label"])
		b.name = "Cam_" + cam["id"]
		b.clip_text = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UiKit.fs(21))
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.flat = true
		b.disabled = sel
		for c in ["font_color", "font_disabled_color"]:
			b.add_theme_color_override(c, INK)
		b.pressed.connect(_pick_cam.bind(cam["id"]))
		UiKit.press_fx(b)
		hb.add_child(b)
		UiKit.stamp(hb, "FACE" if cam["quality"] == "hd" else "FIGURES", GREEN if cam["quality"] == "hd" else VIOLET, 14)
	if cam_sel != "":
		var back := _btn(box, "Choose another camera", _pick_cam.bind(""), 22, 54)
		back.name = "CamBack"
		var cam: Dictionary = game.camera(cam_sel)
		var cal := _btn(box, ("Check the camera's clock  (%d min)" % COST_CLOCK) if not game.det.calibrated.get(cam_sel, false) else "Clock checked", _calibrate.bind(cam_sel), 22, 56)
		cal.disabled = game.det.calibrated.get(cam_sel, false)
		cal.name = "Calibrate"
		for w in WINDOWS:
			var wb := _btn(box, "Watch: %s  (%d min)" % [w[0], COST_WATCH], _watch.bind(cam_sel, w[1], w[2]), 21, 60)
			wb.name = "Watch_%d" % int(w[1])
			wb.clip_text = false
			wb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if result_text != "":
			var rp := PanelContainer.new()
			rp.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 10))
			box.add_child(rp)
			var rl := _lbl(rp, result_text, 21)
			rl.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
		_lbl(box, "%s" % cam["label"], 16, VIOLET)


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


# ------------------------------------------------------------------ the accusation
func _tab_accuse() -> void:
	if game.solved():
		_empty_state("The case is closed", "Rest, and watch the town. A new case will find you.")
		return
	_lbl(box, "Name the killer, the reason, and the method. The judge will weigh what is in your notebook.", 22)
	_lbl(box, "WHO?", 20, VIOLET)
	_lbl(box, "People your notebook names, or search anyone in Little Mercy.", 18)
	var poi: Array = game.persons_of_interest()
	for sid in poi:
		var b := _btn(box, CaseEngine.name_of(game.sim, sid), _pick.bind("culprit", sid), 24, 56)
		_mark(b, sel_culprit == sid)
		b.name = "Acc_" + sid
	var se := LineEdit.new()
	se.name = "AccuseSearch"
	se.placeholder_text = "Search anyone in Little Mercy"
	se.text = acc_query
	se.clear_button_enabled = true
	se.custom_minimum_size = Vector2(0, 56)
	se.add_theme_font_size_override("font_size", UiKit.fs(22))
	se.add_theme_color_override("font_placeholder_color", Color("6b6558"))
	se.text_changed.connect(_acc_search)
	box.add_child(se)
	acc_list = VBoxContainer.new()
	acc_list.name = "AccuseResults"
	acc_list.add_theme_constant_override("separation", 6)
	box.add_child(acc_list)
	_acc_fill()
	if sel_culprit != "" and not poi.has(sel_culprit):
		_lbl(box, "Accusing: %s" % CaseEngine.name_of(game.sim, sel_culprit), 22, VIOLET)
	_lbl(box, "WHY?", 20, VIOLET)
	for k in MOTIVES:
		var b2 := _btn(box, MOTIVES[k], _pick.bind("motive", k), 22, 54)
		_mark(b2, sel_motive == k)
		b2.name = "Why_" + k
	_lbl(box, "HOW?", 20, VIOLET)
	for k in METHODS:
		var b3 := _btn(box, METHODS[k], _pick.bind("method", k), 22, 54)
		_mark(b3, sel_method == k)
		b3.name = "How_" + k
	if sel_culprit != "":
		var dr := PanelContainer.new()
		dr.name = "DaRead"
		dr.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), VIOLET, 3, 10, 10))
		box.add_child(dr)
		var dv := VBoxContainer.new()
		dr.add_child(dv)
		_lbl(dv, "THE DA'S READ", 17, VIOLET)
		_lbl(dv, game.da_advice(sel_culprit), 20).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	var ready: bool = sel_culprit != "" and sel_motive != "" and sel_method != ""
	if ready:
		var sm := PanelContainer.new()
		sm.name = "AccuseSummary"
		sm.add_theme_stylebox_override("panel", UiKit.box(Color(0.89, 0.24, 0.24, 0.12), RED, 3, 10, 10))
		box.add_child(sm)
		var tx := "You accuse %s: %s, by %s." % [CaseEngine.name_of(game.sim, sel_culprit), String(MOTIVES.get(sel_motive, sel_motive)).to_lower(), String(METHODS.get(sel_method, sel_method)).to_lower()]
		var sl := _lbl(sm, tx, 22)
		sl.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	var go_b := _btn(box, "Are you sure? Tap again" if _acc_armed else "Make the accusation", _accuse_tap, 30, 72)
	go_b.disabled = not ready
	go_b.name = "Accuse"
	if _acc_armed:
		UiKit.set_button_style(go_b, RED, INK, PAPER)


func _acc_search(t: String) -> void:
	acc_query = t
	_acc_fill()


## Anyone living in Little Mercy who matches the search and is not already listed (the notebook's names are above).
func _acc_fill() -> void:
	if acc_list == null or not is_instance_valid(acc_list):
		return
	for c in acc_list.get_children():
		acc_list.remove_child(c)
		c.queue_free()
	var q := acc_query.strip_edges().to_lower()
	if q == "":
		return
	var poi: Array = game.persons_of_interest()
	var shown := 0
	for sid in game.residents():
		if poi.has(sid):
			continue
		var nm := CaseEngine.name_of(game.sim, sid)
		var hay := (nm + " " + String(game.sim.people[sid].job)).to_lower()
		var ok := true
		for w in q.split(" ", false):
			if not hay.contains(w):
				ok = false
		if not ok or shown >= 8:
			continue
		shown += 1
		var rb := _btn(acc_list, "%s  (%s)" % [nm, game.sim.people[sid].job], _pick_found.bind(sid), 22, 54)
		rb.name = "Acc_" + sid
		_mark(rb, sel_culprit == sid)
	if shown == 0:
		_lbl(acc_list, "No one by that name.", 20, VIOLET)


func _pick_found(sid: String) -> void:
	game.flag_person(sid)
	acc_query = ""
	_pick("culprit", sid)


## The chosen option is shown inked in.
func _mark(b: Button, selected: bool) -> void:
	if selected:
		UiKit.set_button_style(b, INK, MARIGOLD, PAPER)


func _pick(which: String, v: String) -> void:
	match which:
		"culprit": sel_culprit = v
		"motive": sel_motive = v
		"method": sel_method = v
	_acc_armed = false
	show_case("accuse")


func _accuse_tap() -> void:
	if not _acc_armed:
		_acc_armed = true
		UiKit.haptic(25)
		show_case("accuse")
		return
	_accuse()


func _accuse() -> void:
	_acc_armed = false
	var res: Dictionary = game.accuse(sel_culprit, sel_motive, sel_method)
	var suspect: RefCounted = game.sim.people[sel_culprit]
	var verdict_title: String = {"convicted": "CASE CLOSED", "released": "NOT ENOUGH", "insufficient": "NO CASE", "wrong": "WRONG PERSON"}.get(res.get("verdict", ""), "VERDICT")
	var body: String = "%s\n\nThe DA's read: %s" % [res.get("text", ""), game.da_advice(sel_culprit)]
	if res.get("verdict", "") == "convicted":
		body += "\n\nXP awarded. The Sheriff will remember this."
	close_panel()
	world.refresh_markers()
	UiKit.haptic(120)
	_card(verdict_title, "Your accusation: %s" % suspect.display, body, "Read the episode", func(): _close_card(); _archive(), suspect)
	sel_culprit = ""; sel_motive = ""; sel_method = ""
