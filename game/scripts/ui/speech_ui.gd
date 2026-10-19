extends Control
## The Council Chamber. Read the room: three crowd groups react to every line.

signal finished(result: Dictionary)

const Speech = preload("res://scripts/core/speech.gd")
const GROUPS := {"holdfast": "The faithful", "neutral": "The undecided", "waking": "The restless"}

var state: RefCounted
var core: RefCounted
var prompt_label: Label
var bars: Dictionary = {}
var box: VBoxContainer
var outcome: Label


func setup(game_state: RefCounted, speech_id: String) -> void:
	state = game_state
	core = Speech.new(speech_id)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = core.def["title"].to_upper()
	title.position = Vector2(70, 36)
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)
	var y := 120
	for k in GROUPS:
		var l := Label.new(); l.text = GROUPS[k]; l.position = Vector2(70, y)
		l.add_theme_font_size_override("font_size", 26); add_child(l)
		var b := ProgressBar.new()
		b.position = Vector2(330, y + 4); b.size = Vector2(520, 28); b.show_percentage = false
		b.max_value = 100; b.value = core.seg[k]
		add_child(b); bars[k] = b
		y += 48
	prompt_label = Label.new()
	prompt_label.position = Vector2(70, 290)
	prompt_label.custom_minimum_size = Vector2(1780, 0)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 36)
	add_child(prompt_label)
	box = VBoxContainer.new()
	box.position = Vector2(70, 520)
	box.custom_minimum_size = Vector2(1780, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_show()


func _show() -> void:
	for k in bars:
		(bars[k] as ProgressBar).value = core.seg[k]
	for c in box.get_children():
		c.queue_free()
	if core.finished():
		prompt_label.text = core.outcome_text()
		var b := Button.new(); b.text = "Sit down"
		b.custom_minimum_size = Vector2(520, 100)
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(finish)
		box.add_child(b)
		b.grab_focus()
		return
	prompt_label.text = core.beat_def()["prompt"]
	var cs: Array = core.beat_def()["choices"]
	for i in cs.size():
		var b := Button.new(); b.text = cs[i]["text"]
		b.custom_minimum_size = Vector2(1780, 110)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(choose_option.bind(i))
		box.add_child(b)
	(box.get_child(0) as Button).grab_focus.call_deferred()


func choose_option(i: int) -> Dictionary:
	var r: Dictionary = core.choose(i)
	_show()
	return r


func finish() -> void:
	for k in core.notes_gain:
		state.notes.add(k, int(core.notes_gain[k]))
	for f in core.flags:
		state.flags[f] = true
	# the room's mood spreads: a cold room frightens the town a little, a warm one calms it
	state.town_mood = clampi(state.town_mood + int((core.mood() - 50.0) * 0.3), 0, 100)
	finished.emit({"outcome": core.outcome(), "mood": core.mood(), "flags": core.flags.keys()})
