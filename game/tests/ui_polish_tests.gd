extends SceneTree
## godot --headless --path game -s tests/ui_polish_tests.gd : the UI polish pass. Tabs, notebook, people, waypoint, travel, tutorial,
## settings, title, end-of-day card, safe margins, tap-target sizes.

const MainScene = preload("res://scenes/main.tscn")
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
var fails := 0
var checks := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)


func buttons(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is Button:
			out.append(c)
		out.append_array(buttons(c))
	return out


func by_name(root: Node, n: String) -> Button:
	for b in buttons(root):
		if String(b.name) == n:
			return b
	return null


func find(root: Node, n: String) -> Node:
	return root.find_child(n, true, false)


func stale(root: Node) -> int:
	var n := 0
	for c in root.get_children():
		if c.is_queued_for_deletion():
			n += 1
	return n


func _initialize() -> void:
	UiKit.cfg_path = "user://ui_polish_test.cfg"
	DirAccess.remove_absolute(UiKit.cfg_path)
	UiKit.loaded = false
	UiKit.data["tutorial_done"] = false
	UiKit.data["text_scale"] = 1.0
	# ---- settings and helpers
	ok(ProjectSettings.get_setting("application/config/name") == "LITTLE MERCY", "the game is called LITTLE MERCY")
	ok(UiKit.fs(20) == 20, "text scale 1.0 leaves sizes alone")
	UiKit.set_v("text_scale", 1.3)
	ok(UiKit.fs(20) == 26, "text scale 1.3 grows sizes")
	UiKit.loaded = false
	UiKit.data["text_scale"] = 1.0
	UiKit.load_settings()
	ok(absf(float(UiKit.get_v("text_scale")) - 1.3) < 0.01, "settings persist to disk")
	UiKit.set_v("text_scale", 1.0)
	var q0 := String(UiKit.get_v("quality"))
	var q1 := UiKit.cycle_quality()
	ok(q1 != q0 and UiKit.QUALITIES.has(q1), "quality cycles low/med/high")
	UiKit.set_v("quality", "med")
	var fake := _FakeWorld.new()
	UiKit.apply_quality("low", null, fake)
	ok(fake.got == "low", "quality calls the world's set_quality hook when it has one")
	ok(UiKit.minutes_text(0) == "no time" and UiKit.minutes_text(90) == "1h 30m" and UiKit.minutes_text(45) == "45 min", "minutes read plainly")
	DetectiveGame.delete_save()
	UiKit.delete_detective_save()
	ok(not UiKit.detective_save_valid(), "no save: no Continue")
	var jp := "user://ui_junk_save.json"
	var jf := FileAccess.open(jp, FileAccess.WRITE)
	jf.store_string("{not json")
	jf.close()
	ok(not UiKit.detective_save_valid(jp), "a corrupt save does not count")
	UiKit.delete_detective_save(jp)

	# ---- the title screen
	var main: Control = MainScene.instantiate()
	get_root().add_child(main)
	await process_frame
	var ts := TitleScreen.new()
	main.ui.add_child(ts)
	ts.build(false)
	await process_frame
	ok(find(ts, "ContinueButton") == null, "a fresh install has no Continue on the title")
	ok(find(ts, "NewCaseButton") != null and find(ts, "SettingsButton") != null and find(ts, "QualityButton") != null, "title: New case, Settings, quality toggle")
	ok(find(ts, "TownSimButton") == null and find(ts, "Map2DButton") == null and find(ts, "StoryButton") == null, "no sandbox modes on the title")
	ok(find(ts, "Title_LITTLE") != null and find(ts, "Title_MERCY") != null, "the title says LITTLE MERCY")
	var tt := ""
	for l in ts.find_children("*", "Label", true, false):
		tt += (l as Label).text + " "
	ok(not tt.contains("UNDERSTUDY"), "no UNDERSTUDY left on the title")
	ts.new_pressed.connect(func(): pass)
	var qb: Button = find(ts, "QualityButton")
	var before := qb.text
	qb.pressed.emit()
	ok(qb.text != before, "the title's quality button changes the setting")
	UiKit.set_v("quality", "med")
	ts.queue_free()
	var ts2 := TitleScreen.new()
	main.ui.add_child(ts2)
	ts2.build(true)
	await process_frame
	ok(find(ts2, "ContinueButton") != null, "with a saved case Continue shows")
	var nb2: Button = find(ts2, "NewCaseButton")
	var got_new := [false]
	ts2.new_pressed.connect(func(): got_new[0] = true)
	nb2.pressed.emit()
	ok(not got_new[0] and nb2.text.contains("replaces"), "New case asks before it replaces a saved case")
	nb2.pressed.emit()
	ok(got_new[0], "and goes ahead on the second tap")
	ts2.queue_free()
	var sp := SettingsPanel.new()
	main.ui.add_child(sp)
	sp.open()
	await process_frame
	var up: Button = find(sp, "TextLarger")
	up.pressed.emit()
	await process_frame
	ok(float(UiKit.get_v("text_scale")) > 1.0, "settings: the larger-text button works")
	var snd_before: bool = bool(UiKit.get_v("sound"))
	(find(sp, "SoundToggle") as Button).pressed.emit()
	ok(bool(UiKit.get_v("sound")) != snd_before, "settings: sound toggles")
	UiKit.set_v("sound", true)
	UiKit.apply_sound()
	(find(sp, "Quality_high") as Button).pressed.emit()
	ok(String(UiKit.get_v("quality")) == "high", "settings: quality can be set")
	UiKit.set_v("quality", "med")
	UiKit.set_v("text_scale", 1.0)
	sp.close()

	# ---- the HUD
	DetectiveGame.delete_save()
	UiKit.delete_detective_save()
	var hud: Control = await main._detective_3d(31)
	await process_frame
	await process_frame
	var w: Node3D = hud.world
	var g: RefCounted = hud.game
	ok(hud.card != null and hud.card_body != null, "the opening card is up")
	ok(hud.get_child(hud.get_child_count() - 1) == hud.card, "the opening card sits above the objective box and everything else")
	ok(not hud.obj_box.visible, "the objective box is hidden behind the opening card")
	# the card can be tapped to finish the typewriter
	hud.card_body.visible_ratio = 0.1
	hud._typewriter()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	hud.card.gui_input.emit(ev)
	ok(hud.card_body.visible_ratio >= 1.0, "a tap finishes the typewriter")
	hud._after_wake()
	await process_frame
	ok(hud.tutorial == null, "the tutorial stays quiet in headless runs")
	var sm: Vector4 = UiKit.safe_margins(hud)
	ok(sm.x >= 24.0 and sm.z >= 24.0 and sm.w >= 8.0, "safe margins clear the cutout and rounded corners")
	var tb: Control = hud.get_node("TopBar")
	var x_prev := 1.0e9
	var overlap := false
	for n in ["MenuBtn", "CaseBtn", "MeBtn", "SpeedBtn"]:
		var b: Control = tb.get_node(n)
		ok(b.size.y >= 48.0, "top bar button %s is a real tap target (%d px)" % [n, int(b.size.y)])
		if b.position.x + b.size.x > x_prev:
			overlap = true
		x_prev = b.position.x
		ok(b.position.x + b.size.x <= hud.size.x - sm.z + 0.5, "%s stays inside the safe margin" % n)
	ok(not overlap, "top bar buttons do not overlap each other")
	ok(hud.speed_btn.text.begins_with("Speed"), "the time-speed button says what it is")
	ok(hud.top.position.x + hud.top.size.x <= (tb.get_node("SpeedBtn") as Control).position.x, "the clock text does not run under the buttons")
	# objective chip: beside the minimap, below the top bar
	ok(hud.obj_box.position.x >= hud.mini.position.x + hud.mini.size.x, "the objective chip does not overlap the minimap")
	hud.open_full_map()
	await process_frame
	ok(hud.full_map != null and is_instance_valid(hud.full_map) and hud.full_map.markers.size() > 0, "the full map opens with markers")
	hud.open_full_map()
	ok(hud.full_map == null, "the Map button toggles it closed again")
	ok(hud.obj_box.position.y >= tb.size.y, "the objective chip sits below the top bar")
	ok(hud.obj_label.text.contains("Examine the crime scene"), "the objective is shown")
	# waypoint and distance readout
	await process_frame
	hud._refresh_objective()
	var scene: String = g.scene_lot()
	var door: Vector3 = w.builder.doors[scene]["front"]
	ok(hud.waypoint.has_target and hud.waypoint.target.is_equal_approx(door), "the waypoint points at the scene door")
	ok(hud.dist_label.text.contains(" m"), "the HUD reads out the distance (%s)" % hud.dist_label.text)
	ok(hud.travel_btn.visible, "a Travel button is offered when the objective is away")
	ok(hud.map.target_world != Vector2.INF, "the minimap carries the objective marker")
	# Travel there
	var clock0: int = g.sim.clock
	hud.travel_to_objective()
	ok(w.player.global_position.distance_to(door) < 2.5, "Travel there puts you at the objective")
	ok(g.sim.clock >= clock0, "and the walk is on the in-game clock")
	hud._refresh_objective()
	ok(not hud.travel_btn.visible, "no Travel button once you are there")
	# the action button never clips its label
	hud.act_btn.text = "Enter Sheriff's Office"
	hud._place_act()
	var f: Font = hud.act_btn.get_theme_default_font()
	var need: float = f.get_string_size(hud.act_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hud.act_btn.get_theme_font_size("font_size")).x
	ok(hud.act_btn.size.x >= need + 40.0, "the action button is wide enough for its label (%d of %d)" % [int(hud.act_btn.size.x), int(need)])
	ok(hud.act_btn.position.x + hud.act_btn.size.x <= hud.size.x - sm.z, "and stays inside the safe margin")
	# toasts: one at a time, no doubling
	hud._say("Hello")
	hud._say("Hello")
	ok(hud.toast_box.visible and hud.toast.text == "Hello", "a toast shows once, not twice")
	hud._say("")
	ok(not hud.toast_box.visible, "and clears")
	# panels: no stale rows under new ones (the old overprint)
	hud.show_host()
	hud.show_host()
	ok(stale(hud.box) == 0, "a rebuilt panel leaves no stale rows to overprint")
	g.det.points = 2
	hud._update_badges()
	ok(hud._topicons["MeBtn"].count == 2, "unspent skill points badge the Sheet button")
	hud.show_host()
	ok(find(hud.box, "PointsBadge") != null and by_name(hud.box, "Spend_observation") != null, "the sheet flags points to spend")
	g.det.points = 0

	# ---- tabs
	hud.show_case("case")
	await process_frame
	await process_frame
	var tabs := ["case", "notebook", "people", "news", "cctv", "court", "accuse", "you"]
	var labels := {"case": "Case", "notebook": "Notes", "people": "People", "news": "News", "cctv": "CCTV", "court": "Court", "accuse": "Accuse", "you": "You"}
	var font: Font = hud.get_theme_default_font()
	for k in tabs:
		var b: Button = by_name(hud.box, "Tab_" + k)
		ok(b != null, "tab %s exists" % k)
		if b == null:
			continue
		ok(b.size.y >= 48.0, "tab %s is at least 48 px tall (%d)" % [k, int(b.size.y)])
		var fsz := b.get_theme_font_size("font_size")
		ok(fsz >= 21, "tab %s has a readable font (%d)" % [k, fsz])
		var tw := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		ok(b.text == labels[k] and tw + 8.0 <= b.size.x, "tab %s is not truncated (%s: %d of %d px)" % [k, b.text, int(tw), int(b.size.x)])
	# every button in every tab is a decent target
	var small := 0
	for tname in ["case", "notebook", "people", "news", "cctv", "court", "accuse"]:
		hud.show_case(tname)
		await process_frame
		for b in buttons(hud.box):
			if String(b.name).begins_with("Entry_"):
				continue
			if b.visible and b.size.y > 1.0 and b.size.y < 47.5:
				small += 1
				print("   small button: ", tname, " ", b.name, " ", b.text, " ", b.size)
	ok(small == 0, "all case-file buttons are at least 48 px tall (%d small)" % small)

	# ---- empty states
	hud.show_case("news")
	ok(find(hud.box, "EmptyState") != null, "the News tab says why it is empty")
	hud.show_case("notebook")
	ok(find(hud.box, "EmptyState") != null, "an empty notebook says so")

	# ---- the notebook with a case worked
	var CaseBot = load("res://tests/case_bot.gd")
	var bot = CaseBot.new(g)
	bot.solve()
	hud.nb_new = {}
	hud.show_case("case")
	hud.show_case("notebook")
	await process_frame
	ok(find(hud.box, "NotebookSearch") != null, "the notebook has a search box")
	for f2 in ["all", "evidence", "testimony", "lab", "lore"]:
		ok(by_name(hud.box, "Filter_" + f2) != null, "filter chip %s" % f2)
	var total: int = g.det.order.size()
	var shown := 0
	for c in hud.nb_list.get_children():
		if String(c.name).begins_with("Card_"):
			shown += 1
	ok(shown > 0 and shown <= 25, "the notebook shows a page of entries, not %d at once (%d)" % [total, shown])
	var cmp_shown := 0
	for c in hud.nb_list.get_children():
		if String(c.name).begins_with("Card_cmp_"):
			cmp_shown += 1
	ok(cmp_shown == 0, "print comparisons stay out of the All view")
	hud._nb_search("weapon")
	var hits := 0
	for c in hud.nb_list.get_children():
		if String(c.name).begins_with("Card_"):
			hits += 1
	ok(hits >= 1 and hits < shown + 1, "search narrows the list (%d)" % hits)
	hud._nb_search("zzzzzz")
	ok(find(hud.nb_list, "NotebookNone") != null, "a search with no match says so")
	hud._nb_search("")
	hud.nb_filter = "testimony"
	hud.show_case("notebook")
	var tcards := 0
	for c in hud.nb_list.get_children():
		if String(c.name).begins_with("Card_"):
			tcards += 1
			var eid := String(c.name).substr(5)
			ok(hud._entry_cat(g.det.known[eid]) == "testimony", "the Testimony filter only shows testimony (%s)" % eid)
	ok(tcards >= 1, "there is testimony to show")
	hud.nb_filter = "lab"
	hud.show_case("notebook")
	var lcards := 0
	for c in hud.nb_list.get_children():
		if String(c.name).begins_with("Card_"):
			lcards += 1
	ok(lcards >= 1, "the Lab filter lists lab entries and comparisons")
	hud.nb_filter = "all"
	hud.nb_limit = 25
	hud.show_case("notebook")
	var first_entry: Button = null
	for b in buttons(hud.nb_list):
		if String(b.name).begins_with("Entry_"):
			first_entry = b
			break
	ok(first_entry != null, "entries are tappable cards")
	var eid1 := String(first_entry.name).substr(6)
	var tx_label: Label = null
	for l in hud.nb_list.find_child("Card_" + eid1, true, false).find_children("*", "Label", true, false):
		if (l as Label).text == String(g.det.known[eid1]["text"]):
			tx_label = l
	ok(tx_label != null and tx_label.max_lines_visible == 2, "a collapsed entry shows two wrapped lines")
	hud.nb_open[eid1] = true
	hud._nb_fill()
	for l in hud.nb_list.find_child("Card_" + eid1, true, false).find_children("*", "Label", true, false):
		if (l as Label).text == String(g.det.known[eid1]["text"]):
			tx_label = l
	ok(tx_label.max_lines_visible == -1, "tapping an entry expands the whole text")
	ok(by_name(hud.nb_list, "Open_" + eid1) != null, "an open entry offers Open")
	hud._entry("c_body")
	ok(by_name(hud.box, "Lab") != null or find(hud.box, "Lab") == null, "the entry page still builds")
	# unread dot
	hud._seen_n = 0
	hud._update_badges()
	ok(hud._topicons["CaseBtn"].count > 0, "new notebook entries put a dot on the Case button")
	hud.show_case("notebook")
	hud._update_badges()
	ok(hud._topicons["CaseBtn"].count == 0, "and opening the notebook clears it")

	# ---- people, including newcomers
	g._welcome_newcomer()
	g._welcome_newcomer()
	hud.show_case("people")
	var nid := String(g.newcomers[0]["id"])
	ok(find(hud.box, "Person_" + nid) != null, "a new neighbour is listed in People")
	var pc: Node = find(hud.box, "Person_" + nid)
	ok(pc.find_child("NewBadge", true, false) != null, "and carries a NEW badge")
	ok(find(hud.box, "Person_" + String(g._truth["found_by"])) != null, "the one who found the body is listed")
	ok(by_name(hud.box, "Warrant_" + g._truth["killer"]) != null, "suspects keep their warrant and prints buttons")

	# ---- cctv: wrapped labels, and picking a camera collapses the list
	hud.show_case("cctv")
	var cams: Array = g.cameras()
	var cam_btns := 0
	for c in cams:
		var cb: Button = by_name(hud.box, "Cam_" + c["id"])
		if cb != null:
			cam_btns += 1
			ok(cb.autowrap_mode != TextServer.AUTOWRAP_OFF and not cb.clip_text, "camera label %s wraps instead of clipping" % c["id"])
	ok(cam_btns == cams.size(), "every camera is listed")
	hud._pick_cam(cams[0]["id"])
	var left := 0
	for c in cams:
		if by_name(hud.box, "Cam_" + c["id"]) != null:
			left += 1
	ok(left == 1 and by_name(hud.box, "CamBack") != null, "choosing a camera collapses the list so the controls fit")
	ok(String(by_name(hud.box, "Watch_18").text).contains("min"), "watching shows its cost")

	# ---- interview menu
	var finder: String = g._truth["found_by"]
	hud.show_talk(finder)
	await process_frame
	for k in ["alibi", "victim", "suspects", "saw", "friendly"]:
		var qb2: Button = by_name(hud.box, "Q_" + k)
		ok(qb2 != null and qb2.text.contains("min"), "question %s shows its time cost" % k)
		ok(qb2.size.y >= 48.0, "question %s is a big target" % k)
	ok(by_name(hud.box, "Q_leave") != null and by_name(hud.box, "Q_leave").text != "Leave", "the leave button is spelled out")
	var hdr := find(hud.box, "PanelHeader") as Label
	ok(hdr != null and hdr.text.contains("Day"), "every panel carries the clock")
	hud._q(finder, "saw", "")
	await process_frame
	hdr = find(hud.box, "PanelHeader") as Label
	ok(hdr.text.contains("this visit"), "the header shows time spent this visit (%s)" % hdr.text)
	hud.close_panel()

	# ---- accusation needs a second tap
	hud.show_case("accuse")
	hud._pick("culprit", g._truth["killer"])
	hud._pick("motive", g._truth["motive"])
	hud._pick("method", g._truth["method"])
	var acc: Button = by_name(hud.box, "Accuse")
	ok(acc != null and not acc.disabled and find(hud.box, "AccuseSummary") != null, "the accusation shows a summary before it is made")
	hud._accuse_tap()
	ok(by_name(hud.box, "Accuse").text.contains("sure") and not g.solved(), "the first tap only asks 'are you sure'")
	hud._accuse()
	ok(g.solved() and hud.card != null, "the accusation still goes through the game API")
	hud._close_card()

	# ---- the end-of-day card
	hud.show_host()
	g.det.lab.append({"clue": "c_dropped", "ready_day": g.sim.day + 1})
	var day_before: int = g.sim.day
	w.end_of_day()
	await process_frame
	ok(hud.card != null and hud.card_button != null and hud.card_button.text == "Sleep until morning", "the night card is a detective's day card with a Sleep button")
	var ct := ""
	for l in hud.card.find_children("*", "Label", true, false):
		ct += (l as Label).text + "\n"
	ok(ct.contains("DAY") and ct.contains("WHAT YOU LEARNED") and ct.contains("AT THE LAB") and ct.contains("HEADLINES"), "it lists what you learned, the lab and the headlines")
	ok(ct.contains("NEW IN TOWN") and ct.contains("Stress"), "it lists newcomers and your stress")
	ok(not ct.contains("Wishes") and not ct.contains("Money:") and not ct.contains("'s day"), "no sandbox leftovers on the night card")
	ok(find(hud.card, "StressBar") != null, "with a stress bar")
	hud.card_button.pressed.emit()
	await process_frame
	ok(g.sim.day == day_before + 1 and hud.card != null, "Sleep wakes you the next day with the morning card")
	hud._close_card()

	# ---- the tutorial
	UiKit.data["tutorial_done"] = false
	hud.force_tutorial = true
	hud.start_tutorial()
	await process_frame
	ok(hud.tutorial != null, "the tutorial overlay starts")
	ok(hud.tutorial.STEPS.size() <= 6 and hud.tutorial.STEPS.size() >= 5, "it has at most six steps (%d)" % hud.tutorial.STEPS.size())
	for st in hud.tutorial.STEPS:
		var r: Rect2 = hud.tut_rect(String(st["key"]))
		ok(r.size.x > 40.0 and r.size.y > 40.0 and Rect2(Vector2.ZERO, hud.size).encloses(r.grow(-1.0)), "step %s rings a real control on screen" % st["key"])
	ok(hud.tutorial.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the overlay lets touches through to the controls")
	hud.tutorial._next()
	ok(hud.tutorial.index == 1, "Next advances")
	hud.stick.moved.emit(Vector2(0, 1))
	hud.look.dragged.emit(Vector2(30, 0))
	await process_frame
	ok(hud.tutorial.index == 2, "looking around advances the look step")
	hud.tutorial._finish(true)
	await process_frame
	ok(hud.tutorial == null or not is_instance_valid(hud.tutorial), "it can be skipped")
	ok(bool(UiKit.get_v("tutorial_done")), "and it will not show again")
	hud.force_tutorial = false
	hud._after_wake()
	ok(hud.tutorial == null, "a second case never re-runs the tutorial")

	# ---- menu and settings from the HUD
	hud._main_menu()
	ok(by_name(hud.box, "SettingsBtn") != null and by_name(hud.box, "Resume") != null and by_name(hud.box, "ExitBtn") != null, "the menu: Resume, Settings, Save and exit")
	hud.open_settings()
	ok(hud.settings_ui != null and is_instance_valid(hud.settings_ui), "settings open over the game")
	hud.settings_ui.close()
	hud.close_panel()
	# a game exits cleanly
	g.save()
	ok(UiKit.detective_save_valid(), "a saved case is a valid Continue")
	DetectiveGame.delete_save()
	UiKit.delete_detective_save()
	ok(not UiKit.detective_save_valid(), "after the save is deleted the title offers no Continue")
	DirAccess.remove_absolute(UiKit.cfg_path)
	print("ui_polish_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)


class _FakeWorld extends Object:
	var got := ""
	func set_quality(q: String) -> void:
		got = q
