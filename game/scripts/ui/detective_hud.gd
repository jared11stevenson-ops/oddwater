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
const Scrubber = preload("res://scripts/ui/cctv_scrubber.gd")
const ChatView = preload("res://scripts/ui/chat_view.gd")
const EvidenceBoard = preload("res://scripts/ui/evidence_board.gd")
const TutorialOverlay = preload("res://scripts/ui/tutorial_overlay.gd")
const SheetScreen = preload("res://scripts/ui/sheet_screen.gd")
const Sheet = preload("res://scripts/detective/sheet.gd")
const Urgency = preload("res://scripts/detective/urgency.gd")

const GREEN := UiKit.GREEN
const OXBLOOD := UiKit.OXBLOOD
const WINDOWS := [["Evening, 6 pm to midnight", 18.0, 24.0], ["Midnight to 3 am", 24.0, 27.0], ["3 am to 6 am", 27.0, 30.0]]
const TABS := [["Case", "case", "case"], ["Notes", "notebook", "notebook"], ["People", "people", "people"], ["News", "news", "news"],
	["Board", "board", "board"], ["CCTV", "cctv", "cctv"], ["Court", "court", "court"], ["Charge", "accuse", "accuse"], ["You", "you", "you"]]
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
var chat_log: Dictionary = {}        # person id -> [{side, text, new, expr}] the bubbles so far
var chat_strain: Dictionary = {}     # person id -> 0-100: how hard you have leaned on them (this visit; not saved)
var chat_tone := "firm"
var chat_tray := false
var chat_sel_ev := ""
var chat_view: Control
var board_view: Control
var board_mode := "move"
var board_sel := ""
var board_read_box: VBoxContainer
var cam_win: Array = []              # [from, to] of the stretch of tape on the scrubber
var cam_scrub: Control
var cam_text_open := false
var obj_label: Label
var obj_box: PanelContainer
var dist_label: Label
var res_label: Label
var travel_btn: Button
var scene_btn: Button      # one tap to the crime scene, whatever the objective says
var waypoint: Control
var tab := "case"
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
	full_map.watch_requested.connect(func(lot: String):
		close_full_map()
		_watch_menu(lot))
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
	res_label = Label.new()
	res_label.name = "ResLabel"
	res_label.add_theme_font_size_override("font_size", UiKit.fs(16))
	res_label.add_theme_color_override("font_color", Color("6b6558"))
	res_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(res_label)
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
	_build_dread_fx()
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
	res_label.text = game.resource_line()
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
	_tick_dread(delta)
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
	if game.flush_time() > 0:
		world.time_skipped()


func _step_out() -> void:
	super._step_out()
	if game.flush_time() > 0:
		world.time_skipped()
	_maybe_intrusion.call_deferred()


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
	elif not _dread_card():
		_maybe_intrusion()


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


func _sting(nm: String) -> void:
	if world != null and world.audio != null:
		world.audio.play(nm)


func _learned(entries: Array) -> void:
	if not entries.is_empty():
		_sting("chime")
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
	var lg: Array = chat_log.get(npc, [])
	if lg.is_empty():
		var ops: Array = load("res://scripts/core/reactions.gd").openers(game.sim, npc, "player", game.sim.day)
		lg = [{"side": "them", "text": ("\"%s\"" % ops[0]["text"]) if not ops.is_empty() else "(They look at you. They've heard what happened.)", "new": false, "expr": ""}]
		chat_log[npc] = lg
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	box.add_child(hdr)
	var dz := ChatView.DropZone.new()
	dz.custom_minimum_size = Vector2(72, 94)
	dz.armed = chat_sel_ev != ""
	var pt: Control = _portrait(q, 64, _talk_expr(npc))
	pt.name = "TalkPortrait"
	pt.position = Vector2(4, 0)
	pt.size = Vector2(64, 83)
	dz.add_child(pt)
	dz.dropped.connect(_present_dropped.bind(npc))
	dz.tapped.connect(_portrait_tapped.bind(npc))
	hdr.add_child(dz)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hdr.add_child(hv)
	_head(hv, q.display, 30).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	var rel := String(load("res://scripts/sim/relationship.gd").describe(game.sim, "player", npc))
	_lbl(hv, "%d · %s · %s" % [q.age, q.job, rel], 18, VIOLET).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
	_meter(hv, "Rapport", "RapportBar", clampf((float(q.affinity("player")) + 40.0) / 80.0, 0.0, 1.0), GREEN)
	_meter(hv, "Strain", "StrainBar", clampf(float(chat_strain.get(npc, 0.0)) / 100.0, 0.0, 1.0), RED)
	var chat := ChatView.new()
	chat.font_px = UiKit.fs(20)
	box.add_child(chat)
	chat_view = chat
	for item in lg.slice(-9):
		chat.add_bubble(String(item["side"]), String(item["text"]), q if item["side"] == "them" else null, String(item.get("expr", "")), bool(item.get("new", false)))
	# how you ask
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	box.add_child(trow)
	for tn in [["Kind", "kind"], ["Firm", "firm"], ["Press", "press"]]:
		var tb := _btn(trow, tn[0], _set_tone.bind(npc, tn[1]), 22, 64)
		tb.name = "Tone_" + tn[1]
		if chat_tone == tn[1]:
			UiKit.set_button_style(tb, INK, INK, PAPER)
	# what you ask
	var victim: String = CaseEngine.first(game.sim, game.case["victim"])
	var qs := [["Where were you last night?", "alibi"], ["How did you know %s?" % victim, "victim"], ["Who do you suspect?", "suspects"], ["Did you see anything?", "saw"]]
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.custom_minimum_size = Vector2(PANEL_W - 68.0, 0)
	box.add_child(chips)
	for x in qs:
		var b := _chip(chips, "%s  (%d min)" % [x[0], COST_ASK], _q.bind(npc, x[1], ""))
		b.name = "Q_" + x[1]
	var wb := _chip(chips, "Where was someone else...", _ask_about_menu.bind(npc))
	wb.name = "Q_about"
	var tm := _chip(chips, "About a person...", _person_menu.bind(npc))
	tm.name = "Q_person"
	var fb := _chip(chips, "Be friendly  (%d min)" % COST_FRIENDLY, _friendly.bind(npc))
	fb.name = "Q_friendly"
	var sb := _chip(chips, "Show them...", _toggle_tray.bind(npc))
	sb.name = "Q_show"
	if chat_tray:
		var tbox := VBoxContainer.new()
		tbox.name = "TrayBox"
		tbox.add_theme_constant_override("separation", 4)
		box.add_child(tbox)
		box.move_child(tbox, hdr.get_index() + 1)
		_lbl(tbox, "Drag a card onto their portrait, or tap a card and then the portrait.  (%d min)" % COST_SHOW, 17, VIOLET)
		var tray := ScrollContainer.new()
		tray.name = "EvidenceTray"
		tray.custom_minimum_size = Vector2(PANEL_W - 68.0, 74)
		tray.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tbox.add_child(tray)
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 6)
		tray.add_child(tr)
		for eid in game.det.order:
			if String(eid).begins_with("cmp_"):
				continue
			var e: Dictionary = game.det.known[eid]
			var ch := ChatView.EvChip.new()
			ch.eid = String(eid)
			ch.title = String(e["title"])
			ch.text = String(e["title"])
			ch.name = "Show_" + String(eid)
			ch.custom_minimum_size = Vector2(150, 64)
			ch.clip_text = true
			ch.add_theme_font_size_override("font_size", UiKit.fs(18))
			UiKit.set_button_style(ch, MARIGOLD if chat_sel_ev == ch.eid else Color("fffaf0"), INK, INK)
			ch.pressed.connect(_pick_evidence.bind(npc, ch.eid))
			tr.add_child(ch)
		if game.det.order.is_empty():
			_lbl(tr, "Your notebook is empty.", 20)
	var lv := _btn(box, "Done talking", _leave_talk, 26, 56)
	lv.name = "Q_leave"
	UiKit.set_button_style(lv, INK, INK, PAPER)
	_bottom_room(8.0)


func _chip(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", UiKit.fs(19))
	b.custom_minimum_size = Vector2(floorf((PANEL_W - 68.0 - 6.0) / 2.0), 64)
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	UiKit.press_fx(b)
	parent.add_child(b)
	return b


func _meter(parent: Control, label: String, nm: String, v: float, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var l := _lbl(row, label.to_upper(), 15, VIOLET)
	l.custom_minimum_size = Vector2(76, 0)
	var bar := ProgressBar.new()
	bar.name = nm
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = v
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(PANEL_W - 190.0 - 82.0, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)


func _set_tone(npc: String, t: String) -> void:
	chat_tone = t
	UiKit.haptic(10)
	show_talk(npc)


func _toggle_tray(npc: String) -> void:
	chat_tray = not chat_tray
	if not chat_tray:
		chat_sel_ev = ""
	show_talk(npc)


func _pick_evidence(npc: String, eid: String) -> void:
	chat_sel_ev = "" if chat_sel_ev == eid else eid
	show_talk(npc)


func _portrait_tapped(npc: String) -> void:
	if chat_sel_ev != "":
		_present(npc, chat_sel_ev)
	else:
		_say("Open Show them..., then drag a card onto their portrait.")


func _present_dropped(eid: String, npc: String) -> void:
	_present(npc, eid)


## The face they pull: from how much they like you and how hard you have leaned on them.
func _talk_expr(npc: String) -> String:
	var aff: float = game.sim.people[npc].affinity("player")
	var st: float = float(chat_strain.get(npc, 0.0))
	if st >= 70.0:
		return "tired"
	if aff <= -4.0 or (st >= 40.0 and aff < 8.0):
		return "cross"
	if aff >= 12.0:
		return "happy"
	return "neutral"


func _said_line(topic: String, about: String, tone: String) -> String:
	var victim: String = CaseEngine.first(game.sim, game.case["victim"])
	var line := ""
	match topic:
		"alibi": line = "Where were you last night?" if about == "" else "Where was %s?" % CaseEngine.first(game.sim, about)
		"victim": line = "How did you know %s?" % victim
		"suspects": line = "Who do you suspect?"
		"saw": line = "Did you see anything?"
		"person": line = "What do you make of %s?" % CaseEngine.first(game.sim, about)
		_: line = "Tell me more."
	return ("Take your time. " if tone == "kind" else ("Don't dodge. " if tone == "press" else "")) + line


## Put a reply into the chat as short bubbles: quoted speech in one, each aside (an Empathy read, a new name) in a small one.
func _log_reply(npc: String, said: String, text: String, fresh: bool, tone: String) -> void:
	var lg: Array = chat_log.get(npc, [])
	if said != "":
		lg.append({"side": "me", "text": said, "new": false})
	var strain: float = float(chat_strain.get(npc, 0.0))
	strain += {"kind": -10.0, "press": 22.0}.get(tone, 6.0)
	chat_strain[npc] = clampf(strain, 0.0, 100.0)
	var expr := _talk_expr(npc)
	var spoken: Array = []
	for ln in text.split("\n"):
		var t := String(ln).strip_edges()
		if t == "":
			continue
		if t.begins_with("[") or t.begins_with("(") or t.begins_with("The chapel"):
			if not spoken.is_empty():
				lg.append({"side": "them", "text": " ".join(spoken).trim_prefix("\"").trim_suffix("\""), "new": fresh, "expr": expr})
				spoken = []
			lg.append({"side": "note", "text": t, "new": false})
		else:
			spoken.append(t)
	if not spoken.is_empty():
		lg.append({"side": "them", "text": " ".join(spoken).trim_prefix("\"").trim_suffix("\""), "new": fresh, "expr": expr})
	if lg.size() > 24:
		lg = lg.slice(-24)
	chat_log[npc] = lg


## A wrapping two-line button for the question grid.
func _wbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := _btn(parent, text, cb, 20, 52)
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _q(npc: String, topic: String, about: String) -> void:
	var tone := chat_tone
	var r: Dictionary = game.ask(npc, topic, about, "" if tone == "firm" else tone)
	last_talk = {"npc": npc, "text": r["text"], "tone": "neutral"}
	var fresh: bool = not (r["learned"] as Array).is_empty()
	_log_reply(npc, _said_line(topic, about, tone), String(r["text"]), fresh, tone)
	_learned(r["learned"])
	if fresh:
		UiKit.haptic(45)
	show_talk(npc)


func _friendly(npc: String) -> void:
	var r: Dictionary = game.talk(npc, "compliment")
	last_talk = {"npc": npc, "text": "\"%s\"" % r.get("text", ""), "tone": r.get("tone", "neutral")}
	game.spend(5)
	_log_reply(npc, "It's a good town, this.", "\"%s\"" % r.get("text", ""), false, "kind")
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
	var fresh: bool = not (r["learned"] as Array).is_empty()
	var title: String = String(game.det.known[eid]["title"]) if game.det.known.has(eid) else "this"
	_log_reply(npc, "Look at this: %s." % title, String(r["text"]), fresh, "press")
	chat_sel_ev = ""
	_learned(r["learned"])
	if fresh:
		UiKit.haptic(60)
	show_talk(npc)


# ------------------------------------------------------------------ the case file
## The eight tabs: an icon over a short label, two rows of four, each a big target. `current` is the one showing.
func _tab_bar(current: String) -> void:
	var grid := GridContainer.new()
	grid.name = "TabBar"
	grid.columns = 5
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
	if tab == "notebook" and prev != "notebook":
		nb_new = {}
		for eid in game.det.order.slice(_seen_n):
			nb_new[eid] = true
		nb_limit = 25
	if tab == "news" and prev != "news":
		_sting("chime_down")
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
		"board": _tab_board()
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
	if game.dread_level() >= 1:
		var fl := _lbl(box, "%s. %s" % [game.dread_name().capitalize(), ["", "Your hands are not quite still.", "The edges of the page will not stay put.", "You are not sure how long you have been awake."][game.dread_level()]], 19, Color("7a2323"))
		fl.name = "FearLine"
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
	_trails_panel()
	_dossier_panel()
	_resource_panel()
	if not game.episodes.is_empty():
		var eb := _btn(box, "Episodes (%d)" % game.episodes.size(), _archive, 26, 64)
		eb.name = "Archive"
	_bottom_room(8.0)


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
	_whisper_line()


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
	_sting("stamp")
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
	_street_section()
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
	_btn(grid, "Their circle", _circle.bind(sid), 20, 64).name = "Circle_" + sid
	var q_home: String = String(q.home)
	if q_home != "":
		_btn(grid, "Stake out", _watch_menu.bind(q_home), 20, 64).name = "Stake_" + sid
	if game.can_tell(sid):
		_btn(grid, "Tell them", _tell_menu.bind(sid), 20, 64).name = "TellBtn_" + sid
	elif game.family_circle().any(func(x): return x["id"] == sid):
		_btn(grid, "Who were they?", _remember_them.bind(sid), 20, 64).name = "Remember_" + sid
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
		var pb := _btn(box, "Offer a plea  (2 favours)", _plea.bind(t), 22, 64)
		pb.name = "Plea"
		pb.disabled = int(game.det.res.get("favours", 0)) < 2
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


# ------------------------------------------------------------------ the evidence board
func _tab_board() -> void:
	var cards: Array = game.board_cards(12)
	if cards.is_empty():
		_empty_state("An empty corkboard", "Claims you collect land here as cards. String them to the people you suspect.")
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for m in [["Move cards", "move"], ["Draw strings", "string"]]:
		var mb := _btn(row, m[0], _board_mode.bind(m[1]), 21, 64)
		mb.name = "Mode_" + m[1]
		if board_mode == m[1]:
			UiKit.set_button_style(mb, INK, INK, PAPER)
	var people: Array = []
	var want := {}
	for t in game.det.theory:
		want[t["person"]] = true
	for cd in cards:
		if String(cd["subject"]) != "":
			want[cd["subject"]] = true
	for pid in game.persons_of_interest():
		if want.has(pid) or people.size() < 4:
			if people.size() < 6:
				people.append({"id": pid, "name": CaseEngine.first(game.sim, pid), "p": game.sim.people[pid]})
	board_view = EvidenceBoard.new()
	var bw := PANEL_W - 64.0
	board_view.custom_minimum_size = Vector2(bw, 520)
	board_view.size = Vector2(bw, 520)
	board_view.mode = board_mode
	board_view.selected_pin = board_sel
	box.add_child(board_view)
	var red: Array = game.board_contradictions()
	board_view.set_data(cards, people, game.det.theory, red, game.det.board["pos"])
	board_view.string_made.connect(_board_string)
	_scroll_to.call_deferred(row)
	board_view.moved.connect(func(cid: String, nx: float, ny: float): game.det.board["pos"][cid] = [nx, ny])
	board_view.pin_tapped.connect(func(pid: String): board_sel = pid)
	_lbl(box, "Tap a card to open it. Colours: red physical, blue testimony, purple records, green lab." if board_mode == "move" else "Drag from a card to a person (or the other way) to record your theory. Drag again to cut it.", 17, VIOLET)
	if not red.is_empty():
		_lbl(box, "RED THREADS: claims that cannot both stand", 16, RED)
		for k in red:
			_lbl(box, "%s %s." % [CaseEngine.first(game.sim, String(k["who"])), k["why"]], 18)
	var pb := _btn(box, "Present to the DA", _board_present, 24, 64)
	pb.name = "PresentDA"
	board_read_box = VBoxContainer.new()
	board_read_box.name = "BoardRead"
	box.add_child(board_read_box)
	_bottom_room(8.0)


func _board_mode(m: String) -> void:
	board_mode = m
	show_case("board")


func _board_string(claim: String, person: String) -> void:
	var now: bool = game.board_theory(claim, person)
	UiKit.haptic(25 if now else 12)
	board_view.links = game.det.theory
	board_view.queue_redraw()
	_say("You string it to %s." % CaseEngine.first(game.sim, person) if now else "You cut the string.")


## The DA's read of the case you have laid out: built from the strings you drew, for the person selected (else the one with most strings).
func _board_present() -> void:
	for c in board_read_box.get_children():
		board_read_box.remove_child(c)
		c.queue_free()
	var who := board_sel
	if who == "":
		var n := {}
		for t in game.det.theory:
			n[t["person"]] = int(n.get(t["person"], 0)) + 1
		var best := 0
		for pid in n:
			if int(n[pid]) > best:
				best = int(n[pid])
				who = pid
	if who == "":
		_lbl(board_read_box, "Nothing to present yet. Draw a string from a claim to a person.", 20, VIOLET)
		return
	var pc := PanelContainer.new()
	pc.name = "DaRead"
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), VIOLET, 3, 10, 10))
	board_read_box.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	_lbl(v, "THE DA'S READ: %s" % CaseEngine.name_of(game.sim, who).to_upper(), 17, VIOLET)
	_lbl(v, game.board_read(who), 19).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)


# ------------------------------------------------------------------ the cameras
func _tab_cctv() -> void:
	if cam_sel == "":
		_lbl(box, "Pick a camera. Clocks are rarely exact: check one before you trust its times.", 21)
	for cam in game.cameras():
		if cam_sel != "":
			continue
		var sel: bool = false
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
		var back := _btn(box, "%s  (change camera)" % game.camera(cam_sel)["label"], _pick_cam.bind(""), 21, 56)
		back.name = "CamBack"
		var cam: Dictionary = game.camera(cam_sel)
		var wrow := HBoxContainer.new()
		wrow.add_theme_constant_override("separation", 6)
		box.add_child(wrow)
		for w in WINDOWS:
			var wb := _btn(wrow, "%s\n%d min" % [String(w[0]).split(",")[0], COST_WATCH], _watch.bind(cam_sel, w[1], w[2]), 19, 72)
			wb.name = "Watch_%d" % int(w[1])
			wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wb.clip_text = false
			if cam_win.size() == 2 and is_equal_approx(float(cam_win[0]), float(w[1])):
				UiKit.set_button_style(wb, INK, INK, PAPER)
		if cam_win.size() == 2:
			var fr: Dictionary = game.camera_frames(cam_sel, float(cam_win[0]), float(cam_win[1]))
			if not (fr["frames"] as Array).is_empty():
				cam_scrub = Scrubber.new()
				for pid in game.persons_of_interest():
					cam_scrub.names[pid] = CaseEngine.name_of(game.sim, pid)
				cam_scrub.set_data(fr, String(cam["label"]))
				cam_scrub.dot_tapped.connect(_tag_dot)
				box.add_child(cam_scrub)
				var brow := HBoxContainer.new()
				brow.add_theme_constant_override("separation", 6)
				box.add_child(brow)
				var fz := _btn(brow, "Freeze frame", _freeze, 21, 64)
				fz.name = "Freeze"
				fz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var cal := _btn(brow, ("Check clock (%d min)" % COST_CLOCK) if not game.det.calibrated.get(cam_sel, false) else "Clock checked", _calibrate.bind(cam_sel), 21, 64)
				cal.disabled = game.det.calibrated.get(cam_sel, false)
				cal.name = "Calibrate"
				cal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_lbl(box, "Drag the handle along the tape. Tap a figure on the map to tag them.", 17, VIOLET)
				_scroll_to.call_deferred(cam_scrub)
		if cam_win.size() != 2 or cam_scrub == null:
			var cal2 := _btn(box, ("Check the camera's clock  (%d min)" % COST_CLOCK) if not game.det.calibrated.get(cam_sel, false) else "Clock checked", _calibrate.bind(cam_sel), 22, 64)
			cal2.disabled = game.det.calibrated.get(cam_sel, false)
			cal2.name = "Calibrate"
		if result_text != "":
			var rb := _btn(box, "Hide the log" if cam_text_open else "Read the log", _toggle_cam_text, 20, 64)
			rb.name = "CamText"
			if cam_text_open:
				var rp := PanelContainer.new()
				rp.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 10))
				box.add_child(rp)
				_lbl(rp, result_text, 20).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
		_lbl(box, "%s" % cam["label"], 16, VIOLET)


func _scroll_to(c: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(c) and c.is_inside_tree():
		scroll.scroll_vertical = maxi(int(c.global_position.y - box.global_position.y) - 6, 0)


func _first_line(t: String) -> String:
	var l := t.split("\n")[0]
	return (l if l.length() < 70 else l.substr(0, 68) + "...") + ("  (tap for the log)" if t.contains("\n") else "")


func _toggle_cam_text() -> void:
	cam_text_open = not cam_text_open
	show_case("cctv")


func _tag_dot(key: String, at: float) -> void:
	var r: Dictionary = game.tag_figure(cam_sel, float(cam_win[0]), float(cam_win[1]), at, key)
	_say(String(r["text"]))
	if r["ok"]:
		cam_scrub.tagged[key] = true
		cam_scrub.queue_redraw()
		if bool(r.get("new", false)):
			UiKit.haptic(40 if String(r["who"]) != "" else 20)


func _freeze() -> void:
	var r: Dictionary = game.freeze_frame(cam_sel, float(cam_win[0]), float(cam_win[1]), cam_scrub.at_time())
	_say(String(r["text"]))
	if r["ok"] and bool(r.get("new", false)):
		UiKit.haptic(30)


func _pick_cam(id: String) -> void:
	cam_sel = id
	cam_win = []
	cam_text_open = false
	result_text = ""
	show_case("cctv")


func _calibrate(id: String) -> void:
	var r: Dictionary = game.calibrate_camera(id)
	result_text = r["text"]
	show_case("cctv")


func _watch(id: String, a: float, b: float) -> void:
	var r: Dictionary = game.view_camera(id, a, b)
	result_text = r["text"]
	cam_win = [a, b]
	cam_text_open = false
	_learned(r["learned"])
	show_case("cctv")


func _warrant(sid: String) -> void:
	var r: Dictionary = game.warrant(sid)
	result_text = r["text"]
	_say(r["text"])
	show_case("people")


# ------------------------------------------------------------------ the case sheet
## The Sheet tab: where the sheet stands, and the way in. The sheet itself is a full screen of its own.
func _tab_accuse() -> void:
	if game.solved():
		_empty_state("The case is closed", "Rest, and watch the town. A new case will find you.")
		return
	var sh: Dictionary = game.sheet()
	_lbl(box, "Fill in the case: who, when, where, how and why, and cite the notebook claims that hold each answer up. The game will not tell you which answer is wrong. It will only tell you which groups it can stamp.", 21)
	var lines: Dictionary = game.sheet_lines()
	for g in Sheet.GROUPS:
		var st: String = String(lines[g["id"]]["stamp"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var nm := _lbl(row, String(g["label"]).capitalize(), 22)
		nm.custom_minimum_size = Vector2(190, 0)
		UiKit.stamp(row, "CONFIRMED" if st == "confirmed" else ("NOT YET SUPPORTED" if st == "unsupported" else "OPEN"), GREEN if st == "confirmed" else (RED if st == "unsupported" else VIOLET), 18, st != "open")
	var ob := _btn(box, "Open the case sheet", open_sheet, 30, 72)
	ob.name = "OpenSheet"
	_lbl(box, "Answered: %d of 5.   Charges you can bring depend on what is stamped: murder needs all three groups, unlawful killing the night and one more, a hold on suspicion any one." % Sheet.answered(sh), 19, VIOLET)
	_resource_panel()
	_bottom_room(8.0)


var sheet_screen: Control


func open_sheet() -> void:
	if sheet_screen != null and is_instance_valid(sheet_screen):
		return
	close_panel()
	sheet_screen = SheetScreen.new()
	add_child(sheet_screen)
	sheet_screen.setup(game)
	world.paused = true
	sheet_screen.closed.connect(close_sheet)
	sheet_screen.file_requested.connect(_sheet_file)


func close_sheet() -> void:
	if sheet_screen != null and is_instance_valid(sheet_screen):
		remove_child(sheet_screen)
		sheet_screen.queue_free()
	sheet_screen = null
	world.paused = false
	game.flush_time()
	world.refresh_markers()


func _sheet_file(force: bool) -> void:
	var res: Dictionary = game.sheet_file(force)
	var v: String = String(res.get("verdict", ""))
	if v in ["blank", "unchecked", "unconfirmed", "no_cause"]:
		if sheet_screen != null:
			sheet_screen.show_result(String(res.get("text", "")))
		return
	var suspect: RefCounted = game.sim.people[game.sheet()["who"]] if game.sim.people.has(game.sheet()["who"]) else game.me()
	close_sheet()
	var titles := {"convicted": "CASE CLOSED", "released": "NOT ENOUGH", "insufficient": "NO CASE", "wrong": "WRONG PERSON", "charged": "CHARGED", "barred": "BARRED"}
	var verdict_title: String = String(titles.get(v, "VERDICT"))
	var body: String = String(res.get("text", ""))
	if v == "convicted":
		body += "\n\nXP awarded. The Sheriff will remember this."
	UiKit.haptic(120)
	_card(verdict_title, "Your charge: %s" % suspect.display, body, "Read the episode", func(): _close_card(); _archive(), suspect)


## What is left of the things you spend: warrants, lab slots, kit, favours, hunches.
func _resource_panel() -> void:
	var pc := PanelContainer.new()
	pc.name = "ResourcePanel"
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), VIOLET, 3, 10, 10))
	box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	_lbl(v, "WHAT YOU HAVE TO SPEND", 17, VIOLET)
	for r in game.resource_rows():
		var l := _lbl(v, "%s  %d of %d" % [r["label"], int(r["have"]), int(r["cap"])], 21, RED if int(r["have"]) == 0 else INK)
		l.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
		var n := _lbl(v, String(r["note"]), 16, Color("6b6558"))
		n.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)


# ------------------------------------------------------------------ who they were, trails going cold, fear
func _dossier_panel() -> void:
	var dz: Dictionary = game.dossier()
	var pc := PanelContainer.new()
	pc.name = "Dossier"
	pc.add_theme_stylebox_override("panel", UiKit.box(Color("fffaf0"), INK, 3, 10, 10))
	box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	_lbl(v, "WHO THEY WERE  (%d of 4)" % int(dz["count"]), 17, VIOLET)
	if int(dz["count"]) == 0:
		_lbl(v, String(dz["empty"]), 20).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	for r in dz["rows"]:
		if bool(r["known"]):
			_lbl(v, String(r["label"]), 15, VIOLET)
			_lbl(v, String(r["text"]), 19).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	var carry := _lbl(v, game.carrying(), 19, Color("6b6558"))
	carry.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	if game.can_return_keepsake():
		var rb := _btn(v, "Take it back to the family", _return_keepsake, 22, 64)
		rb.name = "ReturnKeepsake"


func _return_keepsake() -> void:
	var r: Dictionary = game.return_keepsake()
	result_text = String(r["text"])
	_card("A SMALL THING", "Returned", String(r["text"]), "Go on", _close_card, null)
	UiKit.haptic(60)


func _trails_panel() -> void:
	var tr: Array = game.trails()
	var pc := PanelContainer.new()
	pc.name = "Trails"
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(0.89, 0.24, 0.24, 0.1), RED, 3, 10, 10))
	box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	_lbl(v, "GOING COLD", 17, RED)
	if tr.is_empty():
		_lbl(v, "Nothing is about to slip away that you can see. That is not the same as nothing slipping away.", 19).custom_minimum_size = Vector2(PANEL_W - 110.0, 0)
	for t in tr.slice(0, 6):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var col: Color = RED if t["tier"] == "urgent" else (Color("b8741a") if t["tier"] == "warn" else VIOLET)
		UiKit.stamp(row, Urgency.tag(String(t["tier"])), col, 15, t["tier"] != "calm")
		var dl := int(t["days_left"])
		_lbl(row, String(t["label"]) + ("" if dl > 60 else ("  ·  today" if dl <= 0 else "  ·  %d day%s" % [dl, "" if dl == 1 else "s"])), 19).custom_minimum_size = Vector2(PANEL_W - 190.0, 0)
		var tx := _lbl(v, String(t["text"]), 17, Color("4a3f7a"))
		tx.custom_minimum_size = Vector2(PANEL_W - 110.0, 0)


# ------------------------------------------------------------------ dread: the night, the bad idea, the flicker
var dread_fx: ColorRect
var _dread_t := 0.0
var _flicker_t := 6.0


func _build_dread_fx() -> void:
	dread_fx = ColorRect.new()
	dread_fx.name = "DreadFx"
	dread_fx.color = Color(0.04, 0.02, 0.06, 0.0)
	dread_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dread_fx)
	dread_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Frayed nerves tint the edges of the screen and, now and then, the lights flicker. It is only ever a tint: nothing moves under your thumb.
func _tick_dread(delta: float) -> void:
	if dread_fx == null:
		return
	_dread_t -= delta
	if _dread_t <= 0.0:
		_dread_t = 1.0
		var lv: int = game.dread_level()
		dread_fx.set_meta("lv", lv)
		dread_fx.color.a = 0.0 if lv < 2 else (0.05 if lv == 2 else 0.1)
	var lv2: int = int(dread_fx.get_meta("lv", 0))
	if lv2 >= 2 and not bool(UiKit.get_v("calm")):
		_flicker_t -= delta
		if _flicker_t <= 0.0:
			_flicker_t = 7.0 + float(absi(hash("%d|%d" % [game.sim.day, int(Time.get_ticks_msec() / 1000.0)])) % 9)
			flicker()


func flicker() -> void:
	if dread_fx == null or not dread_fx.is_inside_tree():
		return
	var base: float = dread_fx.color.a
	var tw := dread_fx.create_tween()
	tw.tween_property(dread_fx, "color:a", minf(base + 0.22, 0.4), 0.05)
	tw.tween_property(dread_fx, "color:a", base, 0.07)
	tw.tween_property(dread_fx, "color:a", minf(base + 0.12, 0.3), 0.04)
	tw.tween_property(dread_fx, "color:a", base, 0.12)


## The notebook's own page whispers when you are frayed.
func _whisper_line() -> void:
	var w: String = game.dread_whisper()
	if w == "":
		return
	var l := _lbl(box, w, 19, Color("7a2323"))
	l.name = "Whisper"
	l.custom_minimum_size = Vector2(PANEL_W - 68.0, 0)


## A night event or a letter waits on the morning card: read it, and choose what to do about it.
func _dread_card() -> bool:
	var p: Dictionary = game.dread_pending()
	if p.is_empty():
		return false
	var ch: Array = p["choices"]
	_card(String(p["title"]), "In the night", String(p["text"]), String(ch[0]["label"]), _dread_choose.bind(String(ch[0]["id"])), game.me())
	var parent: Control = card_button.get_parent()
	for i in range(1, ch.size()):
		var b := _btn(parent, String(ch[i]["label"]), _dread_choose.bind(String(ch[i]["id"])), 24, 64)
		b.name = "Choice_" + String(ch[i]["id"])
		parent.move_child(b, card_button.get_index())
	card_button.name = "Choice_" + String(ch[0]["id"])
	UiKit.haptic(70)
	return true


func _dread_choose(choice: String) -> void:
	var r: Dictionary = game.dread_respond(choice)
	_close_card()
	if String(r.get("text", "")) != "":
		_card("YOUR CHOICE", "Little Mercy", String(r["text"]), "Go on", _after_dread, null)
	else:
		_after_dread()


func _after_dread() -> void:
	_close_card()
	_maybe_intrusion()


## At high stress an intrusive thought may offer a bad idea, and says honestly what it would cost.
func _maybe_intrusion() -> void:
	if card != null or game.phase != "day" or game.dread_level() < 2:
		return
	var t: Dictionary = game.dread_intrusion()
	if t.is_empty():
		return
	_card("A THOUGHT", "Not quite your own", "%s\n\n(%s)" % [t["text"], t["risk"]], String(t["label"]), _take_idea.bind(String(t["idea"]), String(t["who"])), null)
	var parent: Control = card_button.get_parent()
	var lg := _btn(parent, "Let it go", _dismiss_idea, 24, 64)
	lg.name = "LetItGo"
	parent.move_child(lg, card_button.get_index())
	card_button.name = "TakeIdea"
	flicker()


func _take_idea(idea: String, who: String) -> void:
	var r: Dictionary = game.dread_take(idea, who)
	_close_card()
	if String(r.get("text", "")) != "":
		_card("YOU DID IT", "And now you know", String(r["text"]), "Go on", _close_card, null)


func _dismiss_idea() -> void:
	var t: String = game.dread_dismiss()
	_close_card()
	_say(t)


# ------------------------------------------------------------------ watching, tips, telling
func _watch_menu(lot: String) -> void:
	_clear_panel()
	_head(box, "Stake out %s" % game.place_name(lot), 32)
	var room: int = game.stakeout_hours()
	_lbl(box, "Park across the way and watch. The clock runs. It wears on you (more in the dark), and a parked car can be noticed: that costs trust and may warn someone off.", 21)
	if room <= 0:
		_lbl(box, "It is too late in the day to start a watch.", 22, RED)
	for h in [1, 2, 4]:
		var b := _btn(box, "Watch for %d hour%s" % [h, "" if h == 1 else "s"], _stake.bind(lot, h), 24, 64)
		b.name = "Watch_%d" % h
		b.disabled = room < h
	_btn(box, "Back", show_case.bind("people"), 26, 64)


func _stake(lot: String, hours: int) -> void:
	var r: Dictionary = game.stakeout(lot, hours)
	result_text = String(r["text"])
	_learned(r.get("learned", []))
	close_panel()
	world.refresh_markers()
	_card("THE WATCH", "%d hour%s" % [int(r.get("hours", hours)), "" if int(r.get("hours", hours)) == 1 else "s"], String(r["text"]), "Go on", _close_card, null)


func _tell_menu(sid: String) -> void:
	_clear_panel()
	var q: RefCounted = game.sim.people[sid]
	_head(box, "Telling %s" % CaseEngine.first(game.sim, sid), 32)
	_lbl(box, "How you tell it matters. Sit with them first and they may give you what they would not give an inquiry.", 21)
	for a in [["Say it plainly", "direct", "15 min"], ["Sit with them first", "gentle", "45 min"], ["Ask your questions", "ask", "10 min"]]:
		var b := _btn(box, "%s  (%s)" % [a[0], a[2]], _tell.bind(sid, String(a[1])), 22, 64)
		b.name = "Tell_" + String(a[1])
	_btn(box, "Back", show_case.bind("people"), 26, 64)


func _tell(sid: String, approach: String) -> void:
	var r: Dictionary = game.tell_family(sid, approach)
	result_text = String(r["text"])
	_learned(r.get("learned", []))
	close_panel()
	_card("TELLING %s" % CaseEngine.first(game.sim, sid).to_upper(), "A hard visit", String(r["text"]), "Go on", _close_card, game.sim.people[sid])
	UiKit.haptic(50)


func _remember_them(sid: String) -> void:
	var r: Dictionary = game.remember_them(sid)
	result_text = String(r["text"])
	_learned(r.get("learned", []))
	_say(String(r["text"]).substr(0, 140))
	show_case("people")


func _tip(sid: String) -> void:
	var r: Dictionary = game.informant_tip(sid)
	result_text = String(r["text"])
	_learned(r.get("learned", []))
	close_panel()
	_card("A TIP", "For a favour", String(r["text"]), "Go on", _close_card, game.sim.people[sid])


func _street_section() -> void:
	var cs: Array = game.street_contacts()
	if cs.is_empty():
		return
	_lbl(box, "THE STREET  (a tip costs a favour; a tip can be wrong)", 18, VIOLET)
	for sid in cs:
		var b := _btn(box, "Ask %s for a tip  (1 favour)" % CaseEngine.first(game.sim, String(sid)), _tip.bind(String(sid)), 21, 64)
		b.name = "Tip_" + String(sid)
		b.disabled = int(game.det.res.get("favours", 0)) <= 0


func _plea(sid: String) -> void:
	var r: Dictionary = game.plea_deal(sid)
	result_text = String(r["text"])
	_say(String(r["text"]).substr(0, 140))
	world.refresh_markers()
	_card("THE DEAL", "A plea", String(r["text"]), "Go on", func(): _close_card(); show_case("court"), game.sim.people[sid])
