extends Control
## "Small Paths": spend a child's bedtime clock on listening at the right places.

signal finished(result: Dictionary)

const Eavesdrop = preload("res://scripts/core/eavesdrop.gd")

var state: RefCounted
var core: RefCounted
var buttons: Dictionary = {}
var clock_label: Label
var text_label: Label
var heard_evidence: Array = []


func setup(game_state: RefCounted, map_id: String) -> void:
	state = game_state
	core = Eavesdrop.new(map_id)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "SMALL PATHS: nobody notices a nine-year-old"
	title.position = Vector2(70, 40)
	title.add_theme_font_size_override("font_size", 44)
	add_child(title)
	clock_label = Label.new()
	clock_label.position = Vector2(70, 110)
	clock_label.add_theme_font_size_override("font_size", 30)
	clock_label.add_theme_color_override("font_color", Color("4a3f7a"))
	add_child(clock_label)
	var y := 180
	for s in core.map["spots"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(820, 90)
		b.position = Vector2(70, y)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(listen_spot.bind(s["id"]))
		add_child(b)
		buttons[s["id"]] = b
		y += 104
	text_label = Label.new()
	text_label.position = Vector2(940, 180)
	text_label.custom_minimum_size = Vector2(900, 0)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 30)
	text_label.text = "Pick a place to listen. You only have so much of the day. (Some places only open later.)"
	add_child(text_label)
	var done := Button.new(); done.text = "Go to bed"
	done.position = Vector2(1400, 960)
	done.custom_minimum_size = Vector2(440, 90)
	done.add_theme_font_size_override("font_size", 32)
	done.pressed.connect(finish)
	add_child(done)
	_refresh()


func _refresh() -> void:
	clock_label.text = "Bedtime clock: %d of %d left" % [core.budget, core.map["budget"]]
	for s in core.map["spots"]:
		var b: Button = buttons[s["id"]]
		var why: String = core.block_reason(s["id"])
		b.text = s["label"] + ("   (heard)" if why == "heard" else ("   (not yet)" if why == "locked" else ""))
		b.disabled = why in ["heard", "locked", "no_time"]


func listen_spot(id: String) -> Dictionary:
	var r: Dictionary = core.listen(id)
	if not r["ok"]:
		return r
	text_label.text = r["text"]
	for k in r.get("notes", {}):
		state.notes.add(k, int(r["notes"][k]))
	for npc in r.get("suspicion", {}):
		state.suspicion.raise(npc, int(r["suspicion"][npc]))
	if r.has("evidence"):
		state.board.add_evidence(r["evidence"])
		heard_evidence.append(r["evidence"])
	_refresh()
	return r


func finish() -> void:
	finished.emit({"heard": core.heard.keys(), "evidence": heard_evidence})
