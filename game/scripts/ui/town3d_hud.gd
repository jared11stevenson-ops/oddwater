extends "res://scripts/ui/town_sim_ui.gd"
## The 3D game's screen furniture. The world fills the screen; on top: the clock, a minimap, the move stick, the look pad, one big
## context button (Talk / Enter), and the familiar panel (needs, actions, wishes, talk, night, report) that slides over the right
## side and pauses the town while it's open.

const VirtualStick = preload("res://scripts/ui/virtual_stick.gd")
const LookPad = preload("res://scripts/ui/look_pad.gd")

var world: Node3D
var stick: Control
var look: Control
var act_btn: Button
var close_btn: Button
var speed_btn: Button
var mini: PanelContainer
var _mini_timer := 0.0
var _toast_t := 0.0


func start3d(w: Node3D) -> void:
	world = w
	game = w.game
	game.talk_costs_time = false
	theme = TownTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look = LookPad.new()
	add_child(look)
	look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	look.dragged.connect(func(d): world.player.look_delta += d)
	look.zoomed.connect(func(f): world.player.apply_zoom(f))
	stick = VirtualStick.new()
	add_child(stick)
	stick.moved.connect(func(v): world.player.move_input = v)
	var topbar := ColorRect.new(); topbar.color = Color(0.08, 0.07, 0.11, 0.82); topbar.name = "TopBar"; add_child(topbar)
	top = Label.new()
	TownTheme.heading(top, 32, PAPER)
	topbar.add_child(top)
	top.position = Vector2(14, 10)
	for spec in [["Menu", "MenuBtn", _main_menu], ["Me", "MeBtn", open_me], ["x1", "SpeedBtn", _cycle_speed]]:
		var b := _btn(topbar, spec[0], spec[2], 26)
		b.name = spec[1]
		b.clip_text = false
		b.size_flags_horizontal = Control.SIZE_FILL
	speed_btn = topbar.get_node("SpeedBtn")
	# minimap
	mini = PanelContainer.new()
	var msb := StyleBoxFlat.new()
	msb.bg_color = PAPER; msb.border_color = INK; msb.set_border_width_all(4); msb.set_corner_radius_all(10); msb.set_content_margin_all(0)
	mini.add_theme_stylebox_override("panel", msb)
	mini.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(mini)
	map = TownMap.new()
	map.custom_minimum_size = Vector2(300, 190)
	mini.add_child(map)
	map.setup(game)
	map.zoom = 1.9
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
	close_btn.clip_text = false
	close_btn.visible = false
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 28)
	toast.add_theme_color_override("font_color", PAPER)
	toast.add_theme_color_override("font_outline_color", INK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.add_theme_font_override("font", TownTheme.bold())
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast)
	news = Label.new()
	news.visible = false
	add_child(news)
	act_btn = Button.new()
	act_btn.add_theme_font_size_override("font_size", 34)
	act_btn.custom_minimum_size = Vector2(300, 96)
	act_btn.visible = false
	act_btn.pressed.connect(func(): world.interact())
	add_child(act_btn)
	resized.connect(_layout)
	world.prompt_changed.connect(_on_prompt)
	world.entered.connect(_on_entered)
	world.left.connect(_on_left)
	world.day_ended.connect(_on_day_ended)
	world.talk_requested.connect(func(npc): show_talk(npc))
	_layout()
	if game.phase == "night":
		_on_day_ended()
	else:
		_wake_card()
		world.paused = true


func _layout() -> void:
	var sz := size
	var tb: Control = get_node("TopBar")
	tb.position = Vector2.ZERO
	tb.size = Vector2(sz.x, 60)
	var x := sz.x - 10.0
	for n in ["MenuBtn", "MeBtn", "SpeedBtn"]:
		var b: Control = tb.get_node(n)
		b.size = Vector2(maxf(b.get_combined_minimum_size().x, 78.0), 48)
		x -= b.size.x + 8.0
		b.position = Vector2(x, 6)
	mini.position = Vector2(10, 68)
	mini.size = Vector2(300, 190)
	map.size = Vector2(300, 190)
	panel.position = Vector2(sz.x - PANEL_W, 60)
	panel.size = Vector2(PANEL_W, sz.y - 60)
	close_btn.size = Vector2(58, 54)
	close_btn.position = Vector2(sz.x - 66, 66)
	stick.position = Vector2(0, sz.y * 0.28)
	stick.size = Vector2(sz.x * 0.42, sz.y * 0.72)
	act_btn.position = Vector2(sz.x - 330, sz.y - 130)
	act_btn.size = Vector2(300, 96)
	toast.position = Vector2(sz.x * 0.2, sz.y - 190)
	toast.size = Vector2(sz.x * 0.6, 60)


func _process(delta: float) -> void:
	_mini_timer -= delta
	if _mini_timer <= 0.0 and world != null and map != null:
		_mini_timer = 0.15
		var p: Vector3 = world.player.global_position
		map.host_world = Vector2(p.x, p.z)
		map.center = Vector2(p.x, p.z)
		map.update_tint()
		map.redraw_all()
		_refresh_hud()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast.text = ""


func _say(t: String) -> void:
	toast.text = t
	_toast_t = 3.5


func _refresh_hud() -> void:
	var h: float = world.hour()
	var wx: String = String(game.sim.weather_today()).capitalize()
	var ev: String = game.sim.event_today()
	top.text = "%s  ·  Day %d %s  ·  %s%s" % [Brief.clock_text(h), game.sim.day, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][game.sim.weekday()], wx, (" · " + ev) if ev != "" else ""]


func _cycle_speed() -> void:
	var opts := [1.0, 3.0, 8.0]
	var i := (opts.find(world.time_scale) + 1) % opts.size()
	world.time_scale = opts[i]
	speed_btn.text = "x%d" % int(opts[i])


# ------------------------------------------------------------------ the panel
func _clear_panel() -> void:
	super._clear_panel()
	panel.visible = true
	close_btn.visible = true
	world.paused = true


func close_panel() -> void:
	panel.visible = false
	close_btn.visible = false
	last_talk = {}
	if world.inside == "" and game.phase == "day":
		world.paused = false


func open_me() -> void:
	show_host()


func _main_menu() -> void:
	game.save()
	back_to_menu.emit()


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
	act_btn.visible = not p.is_empty() and not panel.visible
	if not p.is_empty():
		act_btn.text = p["label"]


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
	return r


func end_day() -> void:
	world.end_of_day()


func next_morning() -> String:
	var id: String = super.next_morning()
	world.morning()
	return id
