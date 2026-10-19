extends Control
## WAKE & SNOOP: a timed bedroom search. Touch or gamepad; no dead inputs.

signal finished(result: Dictionary)

const Data = preload("res://scripts/core/data.gd")

var state: RefCounted
var home: Dictionary
var items: Dictionary = {}
var found: Dictionary = {}
var time_left := 0.0
var time_total := 0.0
var running := false
var minute_used := false
var timer_scale := 1.0   # accessibility: 0.5x..3x, 0 = untimed
var bar: ProgressBar
var text_label: Label
var panel: PanelContainer
var minute_btn: Button


func setup(game_state: RefCounted, home_file: String, scale: float = 1.0) -> void:
	state = game_state
	home = Data.load_json(home_file)
	timer_scale = scale
	for it in home["items"]:
		items[it["id"]] = it
	time_total = float(state.tuning["search_seconds"]) * (timer_scale if timer_scale > 0.0 else 1.0)
	time_left = time_total
	_build()
	running = true


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("2b2a3a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var title := Label.new()
	title.text = "%s\n%s" % [home["title"], home["intro"]]
	title.position = Vector2(60, 30)
	title.add_theme_font_size_override("font_size", 34)
	add_child(title)
	bar = ProgressBar.new()
	bar.position = Vector2(60, 140)
	bar.size = Vector2(1100, 28)
	bar.max_value = time_total
	bar.value = time_total
	bar.show_percentage = false
	bar.visible = timer_scale > 0.0
	add_child(bar)
	minute_btn = Button.new()
	minute_btn.text = "Take your minute (+10s)"
	minute_btn.position = Vector2(1200, 128)
	minute_btn.size = Vector2(420, 60)
	minute_btn.visible = state.board.has_ability("take_your_minute") and timer_scale > 0.0
	minute_btn.pressed.connect(take_minute)
	add_child(minute_btn)
	for id in items:
		var it: Dictionary = items[id]
		var b := Button.new()
		b.text = it["label"]
		b.position = Vector2(it["x"], it["y"])
		b.custom_minimum_size = Vector2(240, 96)   # large touch target
		b.add_theme_font_size_override("font_size", 26)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(interact.bind(id))
		b.name = id
		add_child(b)
	panel = PanelContainer.new()
	panel.position = Vector2(160, 900)
	panel.custom_minimum_size = Vector2(1600, 150)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(1560, 0)
	text_label.add_theme_font_size_override("font_size", 30)
	panel.add_child(text_label)
	add_child(panel)
	var done := Button.new()
	done.text = "Get dressed (end search)"
	done.position = Vector2(1500, 40)
	done.size = Vector2(380, 70)
	done.pressed.connect(finish)
	add_child(done)
	if has_node("ribbon"):
		get_node("ribbon").grab_focus()


func take_minute() -> void:
	if minute_used or not state.board.has_ability("take_your_minute"):
		return
	minute_used = true
	time_left += float(state.tuning["minute_bonus"])
	time_total += float(state.tuning["minute_bonus"])
	bar.max_value = time_total
	minute_btn.disabled = true


## Returns true if this was the first time the item was inspected.
func interact(id: String) -> bool:
	if not running or not items.has(id):
		return false
	var it: Dictionary = items[id]
	text_label.text = it["text"]
	var first := not found.has(id)
	if first:
		found[id] = true
		var n: Array = it["note"]
		state.notes.add(n[0], int(n[1]))
		if it.has("evidence"):
			state.board.add_evidence(it["evidence"])
		if it["kind"] == "pet":
			state.suspicion.calm("pet_" + home["life"], 10)
		(get_node(id) as Button).modulate = Color(0.7, 1.0, 0.7)
	return first


func _process(delta: float) -> void:
	if not running or timer_scale <= 0.0:
		return
	time_left -= delta
	bar.value = maxf(time_left, 0.0)
	if time_left <= 0.0:
		finish()


func finish() -> void:
	if not running:
		return
	running = false
	var props := 0
	var role_found := 0
	var evidence: Array = []
	for id in found:
		var it: Dictionary = items[id]
		if it["kind"] == "prop":
			props += 1
		if it["kind"] in ["role", "mirror", "pet"]:
			role_found += 1
		if it.has("evidence"):
			evidence.append(it["evidence"])
	# A thin search gives a vaguer brief and a warier start. Never a fail state.
	var vague := role_found < 2
	finished.emit({"found": found.size(), "props": props, "role_found": role_found,
		"evidence": evidence, "vague_brief": vague})
