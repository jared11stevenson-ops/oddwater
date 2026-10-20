extends "res://scripts/ui/town_sim_ui.gd"
## The 3D game's screen furniture. The world fills the screen; on top: the clock, a minimap, the move stick, the look pad, one big
## context button (Talk / Enter), and the familiar panel (needs, actions, wishes, talk, night, report) that slides over the right
## side and pauses the town while it's open. Margins keep clear of the phone's camera cutout and rounded corners.

const VirtualStick = preload("res://scripts/ui/virtual_stick.gd")
const LookPad = preload("res://scripts/ui/look_pad.gd")
const TabIcon = preload("res://scripts/ui/tab_icon.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

const TOPBAR_H := 68.0
const SPEEDS := [1.0, 3.0, 8.0]

var world: Node3D
var stick: Control
var look: Control
var act_btn: Button
var close_btn: Button
var speed_btn: Button
var mini: PanelContainer
var topbar: ColorRect
var toast_box: PanelContainer
var settings_ui: Control
var _mini_timer := 0.0
var _toast_t := 0.0
var _topicons: Dictionary = {}
var _safe := Vector4(24, 6, 24, 12)


func start3d(w: Node3D) -> void:
	world = w
	game = w.game
	game.talk_costs_time = false
	theme = TownTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.load_settings()
	UiKit.apply_sound()
	UiKit.apply_quality(String(UiKit.get_v("quality")), get_viewport(), world)
	look = LookPad.new()
	add_child(look)
	look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look.dragged.connect(func(d): world.player.look_delta += d)
	look.zoomed.connect(func(f): world.player.apply_zoom(f))
	stick = VirtualStick.new()
	add_child(stick)
	stick.moved.connect(func(v): world.player.move_input = v)
	topbar = ColorRect.new()
	topbar.color = Color(0.08, 0.07, 0.11, 0.86)
	topbar.name = "TopBar"
	add_child(topbar)
	top = Label.new()
	TownTheme.heading(top, UiKit.fs(32), PAPER)
	top.clip_text = true
	topbar.add_child(top)
	top.position = Vector2(14, 14)
	var specs := [["Menu", "MenuBtn", _main_menu, "menu"], ["Sheet", "MeBtn", open_me, "you"], ["Speed x1", "SpeedBtn", _cycle_speed, "clock"]]
	for spec in specs + _extra_topbar():
		var icon_kind: String = spec[3] if spec.size() > 3 else ""
		var b := _topbtn(spec[0], spec[1], spec[2], icon_kind)
		topbar.add_child(b)
	speed_btn = topbar.get_node("SpeedBtn")
	# minimap
	mini = PanelContainer.new()
	mini.name = "Minimap"
	var msb := StyleBoxFlat.new()
	msb.bg_color = PAPER; msb.border_color = INK; msb.set_border_width_all(4); msb.set_corner_radius_all(12); msb.set_content_margin_all(0)
	msb.set_expand_margin_all(0)
	mini.add_theme_stylebox_override("panel", msb)
	mini.mouse_filter = Control.MOUSE_FILTER_PASS
	mini.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mini.modulate = Color(1, 1, 1, 0.94)
	add_child(mini)
	map = TownMap.new()
	map.mini = true
	map.custom_minimum_size = Vector2(220, 140)
	mini.add_child(map)
	map.setup(game)
	map.zoom = 1.7
	map.place_tapped.connect(show_place)
	# the panel
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER; sb.set_content_margin_all(14)
	sb.border_color = INK; sb.border_width_left = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.visible = false
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(PANEL_W - 64.0, 0)
	scroll.add_child(box)
	close_btn = _btn(self, "X", close_panel, 30)
	close_btn.name = "CloseBtn"
	close_btn.clip_text = false
	close_btn.visible = false
	UiKit.set_button_style(close_btn, INK, INK, PAPER)
	# toasts: a small dark stamp low in the middle, one at a time
	toast_box = PanelContainer.new()
	toast_box.name = "ToastBox"
	toast_box.add_theme_stylebox_override("panel", UiKit.box(Color(0.08, 0.07, 0.11, 0.9), MARIGOLD, 3, 12, 12))
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.visible = false
	add_child(toast_box)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", UiKit.fs(26))
	toast.add_theme_color_override("font_color", PAPER)
	toast.add_theme_font_override("font", TownTheme.bold())
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.custom_minimum_size = Vector2(520, 0)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(toast)
	news = Label.new()
	news.visible = false
	add_child(news)
	act_btn = Button.new()
	act_btn.name = "ActBtn"
	act_btn.add_theme_font_size_override("font_size", UiKit.fs(32))
	act_btn.custom_minimum_size = Vector2(300, 96)
	act_btn.clip_text = false
	act_btn.visible = false
	UiKit.set_button_style(act_btn, INK, MARIGOLD, PAPER)
	UiKit.press_fx(act_btn)
	act_btn.pressed.connect(func(): world.interact())
	add_child(act_btn)
	resized.connect(_layout)
	world.prompt_changed.connect(_on_prompt)
	world.entered.connect(_on_entered)
	world.left.connect(_on_left)
	world.day_ended.connect(_on_day_ended)
	world.talk_requested.connect(func(npc): show_talk(npc))
	_hud_built()
	_layout()
	if game.phase == "night":
		_on_day_ended()
	else:
		_wake_card()
		world.paused = true
	_raise_overlays()


## A top-bar button: an icon on the left, a label, and room for a red count badge.
func _topbtn(text: String, nm: String, cb: Callable, icon_kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.name = nm
	b.clip_text = false
	b.add_theme_font_size_override("font_size", UiKit.fs(24))
	var pad := 44 if icon_kind != "" else 14
	for st in ["normal", "hover", "focus", "disabled"]:
		var s := UiKit.box(PAPER, INK, 3, 10, 6)
		s.content_margin_left = pad
		s.content_margin_right = 14
		b.add_theme_stylebox_override(st, s)
	var sp := UiKit.box(MARIGOLD, INK, 3, 10, 6)
	sp.content_margin_left = pad
	sp.content_margin_right = 14
	b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(cb)
	UiKit.press_fx(b)
	if icon_kind != "":
		var ic := TabIcon.new().setup(icon_kind, INK, 28.0)
		ic.position = Vector2(8, 12)
		ic.size = Vector2(28, 28)
		ic.name = "Icon"
		b.add_child(ic)
		_topicons[nm] = ic
	return b


## Subclasses add their own top-bar buttons: [[label, node name, callable, icon]].
func _extra_topbar() -> Array:
	return []


func _extra_names() -> Array:
	return _extra_topbar().map(func(x): return x[1])


## For subclasses: build their own furniture just before the first layout.
func _hud_built() -> void:
	pass


## For subclasses: place their own furniture. `sm` is the safe margin (left, top, right, bottom).
func _layout_extra(_sm: Vector4) -> void:
	pass


## Keep the card, settings and any overlays above everything else.
func _raise_overlays() -> void:
	for n in ["Tutorial", "SettingsPanel"]:
		var c := get_node_or_null(n)
		if c != null:
			move_child(c, get_child_count() - 1)
	if card != null:
		move_child(card, get_child_count() - 1)
	if settings_ui != null and is_instance_valid(settings_ui):
		move_child(settings_ui, get_child_count() - 1)


func _layout() -> void:
	var sz := size
	_safe = UiKit.safe_margins(self)
	var tb: Control = get_node("TopBar")
	tb.position = Vector2.ZERO
	tb.size = Vector2(sz.x, TOPBAR_H)
	var x := sz.x - _safe.z
	var names: Array = ["MenuBtn"] + _extra_names() + ["MeBtn", "SpeedBtn"]
	for n in names:
		var b: Button = tb.get_node(n)
		b.add_theme_font_size_override("font_size", UiKit.fs(24))
		var cms := b.get_combined_minimum_size()
		b.size = Vector2(maxf(cms.x, 96.0), 54)
		x -= b.size.x + 8.0
		b.position = Vector2(x, 7)
	top.add_theme_font_size_override("font_size", UiKit.fs(32))
	top.position = Vector2(_safe.x + 4.0, 14)
	top.size = Vector2(maxf(120.0, x - _safe.x - 12.0), 44)
	mini.position = Vector2(_safe.x, TOPBAR_H + 8.0)
	mini.size = Vector2(220, 140)
	map.size = Vector2(220, 140)
	panel.position = Vector2(sz.x - PANEL_W, TOPBAR_H)
	panel.size = Vector2(PANEL_W, sz.y - TOPBAR_H)
	var psb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	psb.content_margin_right = 14.0 + _safe.z * 0.5
	psb.content_margin_bottom = 14.0 + _safe.w
	close_btn.size = Vector2(62, 54)
	close_btn.position = Vector2(sz.x - _safe.z * 0.5 - 76.0, TOPBAR_H + 14.0)
	stick.position = Vector2(0, sz.y * 0.28)
	stick.size = Vector2(sz.x * 0.42, sz.y * 0.72)
	_place_act()
	_place_toast()
	_layout_extra(_safe)


## The toast sits low in the part of the screen the panel is not covering.
func _place_toast() -> void:
	var right := size.x - (PANEL_W if panel.visible else 0.0)
	if act_btn != null and act_btn.visible:
		right = minf(right, act_btn.position.x - 16.0)
	var left := _safe.x + 16.0
	var w := clampf(right - left, 260.0, 600.0)
	toast.custom_minimum_size = Vector2(w - 28.0, 0)
	toast_box.size = Vector2(w, 20)
	toast_box.position = Vector2(left + (right - left - w) / 2.0, size.y - _safe.w - 150.0)


func _place_act() -> void:
	var f := act_btn.get_theme_default_font()
	var px := UiKit.fs(32)
	act_btn.add_theme_font_size_override("font_size", px)
	var w := maxf(300.0, f.get_string_size(act_btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 80.0)
	act_btn.size = Vector2(w, 96)
	act_btn.position = Vector2(size.x - _safe.z - w - 6.0, size.y - _safe.w - 108.0)
	_place_toast()


func _process(delta: float) -> void:
	_mini_timer -= delta
	if _mini_timer <= 0.0 and world != null and map != null:
		_mini_timer = 0.15
		var p: Vector3 = world.player.global_position
		map.host_world = Vector2(p.x, p.z)
		map.center = Vector2(p.x, p.z)
		map.host_yaw = world.player.yaw
		map.update_tint()
		map.redraw_all()
		_refresh_hud()
		if act_btn != null and card != null:
			act_btn.visible = false
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast.text = ""
			toast_box.visible = false


func _say(t: String) -> void:
	if t == "":
		toast.text = ""
		toast_box.visible = false
		_toast_t = 0.0
		return
	var fresh := not toast_box.visible or toast.text != t
	toast.text = t
	toast_box.visible = true
	_place_toast()
	_toast_t = 3.5 + minf(float(t.length()) / 60.0, 3.0)
	if fresh:
		UiKit.fade_in(toast_box, 0.14, 0.2)


func _refresh_hud() -> void:
	var h: float = world.hour()
	var wx: String = String(game.sim.weather_today()).capitalize()
	var ev: String = game.sim.event_today()
	top.text = "%s  ·  Day %d %s  ·  %s%s%s" % [Brief.clock_text(h), game.sim.day, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][game.sim.weekday()], wx, (" · " + ev) if ev != "" else "", "  ·  PAUSED" if world.paused else ""]


func _cycle_speed() -> void:
	var i := (SPEEDS.find(world.time_scale) + 1) % SPEEDS.size()
	world.time_scale = SPEEDS[i]
	speed_btn.text = "Speed x%d" % int(SPEEDS[i])
	_say("Time runs %s." % ["at normal speed", "3 times faster", "8 times faster"][i])
	_layout()


# ------------------------------------------------------------------ the panel
func _clear_panel() -> void:
	var was_open := panel.visible
	super._clear_panel()
	panel.visible = true
	close_btn.visible = true
	world.paused = true
	if not was_open:
		UiKit.fade_in(panel, 0.16)
	else:
		UiKit.fade_in(box, 0.12, 0.35)
	if act_btn != null:
		act_btn.visible = false
	_place_toast()
	_panel_header()


## A thin strip at the top of every panel: the clock, and how much time this visit has cost so far.
func _panel_header() -> void:
	var spent: Variant = game.get("_minutes")
	var t := "%s  ·  Day %d" % [Brief.clock_text(world.hour()), game.sim.day]
	if spent != null and int(spent) > 0:
		t += "  ·  this visit: %s" % UiKit.minutes_text(int(spent))
	var l := Label.new()
	l.name = "PanelHeader"
	l.text = t
	l.custom_minimum_size = Vector2(PANEL_W - 64.0 - 76.0, 36)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiKit.fs(20))
	l.add_theme_color_override("font_color", RED if (spent != null and int(spent) > 0) else VIOLET)
	box.add_child(l)


## A little air under the last button of a panel, so a scrolled panel never ends flush against the screen edge.
func _bottom_room(h: float = 16.0) -> void:
	var sp := Control.new()
	sp.name = "BottomRoom"
	sp.custom_minimum_size = Vector2(0, h)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sp)


func close_panel() -> void:
	panel.visible = false
	close_btn.visible = false
	_place_toast()
	last_talk = {}
	if world.inside == "" and game.phase == "day":
		world.paused = false
		world.refresh_prompt()
		_on_prompt(world.prompt)


func open_me() -> void:
	show_host()


func _main_menu() -> void:
	_clear_panel()
	_head(box, "MENU", 44)
	var rb := _btn(box, "Resume", close_panel, 30, 68)
	rb.name = "Resume"
	var sb := _btn(box, "Settings", open_settings, 30, 68)
	sb.name = "SettingsBtn"
	_menu_extra()
	var qb := _btn(box, "Save and exit to title", _exit_to_title, 28, 68)
	qb.name = "ExitBtn"


func _menu_extra() -> void:
	pass


func _exit_to_title() -> void:
	game.save()
	back_to_menu.emit()


func open_settings() -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
		return
	var sp := SettingsPanel.new()
	sp.show_replay = has_method("start_tutorial")
	settings_ui = sp
	add_child(sp)
	sp.open()
	sp.changed.connect(_settings_changed)
	sp.replay_tutorial.connect(func():
		close_panel()
		if has_method("start_tutorial"):
			call("start_tutorial", true))
	sp.closed.connect(_settings_changed)
	_raise_overlays()


func _settings_changed() -> void:
	UiKit.apply_quality(String(UiKit.get_v("quality")), get_viewport(), world)
	UiKit.apply_sound()
	_layout()
	if panel.visible:
		_main_menu()


func _leave_talk() -> void:
	close_panel()


func _after_wake() -> void:
	_close_card()
	close_panel()


func show_host() -> void:
	super.show_host()
	if world.inside != "" and game.phase == "day":
		var b := _btn(box, "Step outside", _step_out, 32, 72)
		b.name = "StepOut"
		box.move_child(b, 1)


func _step_out() -> void:
	close_panel()
	world.leave()
	world.paused = false


func _on_prompt(p: Dictionary) -> void:
	act_btn.visible = not p.is_empty() and not panel.visible and card == null
	if not p.is_empty():
		act_btn.text = p["label"]
		_place_act()
	_place_toast()


func _on_entered(lot: String) -> void:
	_say("You step inside %s." % game.place_name(lot))
	show_host()


func _on_left() -> void:
	_say("")


func _on_day_ended() -> void:
	show_host()
	_report_card()


# ------------------------------------------------------------------ actions that move the clock
func do_action(act: String) -> Dictionary:
	var r: Dictionary = super.do_action(act)
	world.time_skipped()
	return r


func go(place: String) -> Dictionary:
	var r: Dictionary = super.go(place)
	if r.get("ok", false):
		world.arrive_at(place)
		close_panel()
		world.refresh_prompt()
		_on_prompt(world.prompt)
	return r


func end_day() -> void:
	world.end_of_day()


func next_morning() -> String:
	var id: String = super.next_morning()
	world.morning()
	return id
