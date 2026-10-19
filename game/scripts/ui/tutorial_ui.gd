extends Control
## Two small tutorial beats on Day 1: photograph something you want to keep, and make the Decision you've been putting off.

signal finished(result: Dictionary)

const Data = preload("res://scripts/core/data.gd")

var state: RefCounted
var sim: RefCounted
var mode := ""
var status: Label
var box: VBoxContainer
var chosen := false
var defs: Dictionary

const DECISIONS := [
	{"action": "sign_lease", "label": "Sign the lease for a full year. You live here now.", "text": "You sign the lease for the year."},
	{"action": "take_job", "label": "Take the job at the library. Mornings, a desk, a reason.", "text": "You take the library job."},
	{"action": "confess", "label": "Tell someone how you really feel. Properly. Tonight.", "text": "You tell them. All of it."}]


func setup(game_state: RefCounted, world: RefCounted, kind: String) -> void:
	state = game_state
	sim = world
	mode = kind
	defs = Data.load_json("evidence.json")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.position = Vector2(100, 70)
	title.custom_minimum_size = Vector2(1700, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 44)
	add_child(title)
	box = VBoxContainer.new()
	box.position = Vector2(100, 330)
	box.custom_minimum_size = Vector2(1700, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	status = Label.new()
	status.position = Vector2(100, 800)
	status.custom_minimum_size = Vector2(1700, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 32)
	add_child(status)
	if mode == "photo":
		title.text = "Your phone has a camera, and your notebook says WRITE IT DOWN.\nPhotograph one thing you want to be sure you'll remember."
		var ids: Array = state.board.evidence.keys()
		ids.sort()
		for id in ids:
			var b := Button.new(); b.text = defs.get(id, {"title": id})["title"]
			b.custom_minimum_size = Vector2(900, 80)
			b.add_theme_font_size_override("font_size", 30)
			b.pressed.connect(take_photo.bind(id))
			box.add_child(b)
		if ids.is_empty():
			status.text = "(You didn't pick anything up this morning. Never mind.)"
	else:
		title.text = "Tonight you decide.\nYou've been putting it off for weeks. It doesn't have to be perfect. It has to be yours."
		for i in DECISIONS.size():
			var b := Button.new(); b.text = DECISIONS[i]["label"]
			b.custom_minimum_size = Vector2(1500, 100)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 30)
			b.pressed.connect(decide_option.bind(i))
			box.add_child(b)
	var done := Button.new(); done.text = "Continue" if mode == "photo" else "Go to bed"
	done.position = Vector2(1400, 940)
	done.custom_minimum_size = Vector2(440, 100)
	done.add_theme_font_size_override("font_size", 34)
	done.pressed.connect(finish)
	add_child(done)


func take_photo(id: String) -> bool:
	var okp: bool = state.board.photograph(id)
	status.text = "Click. It's in your Notebook. (You have limited film each day.)" if okp else "No film left, or you already have that one."
	return okp


func decide_option(i: int) -> Dictionary:
	if chosen or i < 0 or i >= DECISIONS.size():
		return {"ok": false}
	chosen = true
	var d: Dictionary = DECISIONS[i]
	var args := {}
	if d["action"] == "confess":
		args = {}
	var r: Dictionary = sim.player_act("player", d["action"], args)
	state.flags["tutorial_decision"] = d["action"]
	state.flags["tutorial_decision_text"] = d["text"]
	status.text = "%s It feels like setting something heavy down." % d["text"]
	for c in box.get_children():
		c.disabled = true
	return r


func finish() -> void:
	if mode == "decision" and not chosen:
		status.text = "You can't sleep on it. Pick one."
		return
	finished.emit({"mode": mode, "decision": state.flags.get("tutorial_decision", "")})
