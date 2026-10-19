extends Control
## The day loop, driven entirely by data/days.json:
## WAKE (snoop) -> PERFORM (steps) -> STEP OFF (Remnant) -> NIGHT (snoop + event) -> Case Board -> SLACK -> next day.

const GameState = preload("res://scripts/core/game_state.gd")
const Data = preload("res://scripts/core/data.gd")
const Snoop = preload("res://scripts/ui/snoop.gd")
const DialogueUI = preload("res://scripts/ui/dialogue_ui.gd")
const DentalUI = preload("res://scripts/ui/dental_ui.gd")
const RhythmUI = preload("res://scripts/ui/rhythm_ui.gd")
const EavesdropUI = preload("res://scripts/ui/eavesdrop_ui.gd")
const BoardUI = preload("res://scripts/ui/board_ui.gd")
const SlackUI = preload("res://scripts/ui/slack_ui.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")
const POST := preload("res://shaders/page_post.gdshader")

var state: RefCounted
var days: Dictionary
var snoop: Control
var queue: Array = []
var stage: Control            # backgrounds / world (gets the print pass)
var ui: Control               # all readable UI sits above the print pass
var post_mat: ShaderMaterial
var lenient := 1.0            # accessibility: rhythm timing leniency


func _ready() -> void:
	state = GameState.new()
	days = Data.load_json("days.json")
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	var layer := CanvasLayer.new(); layer.layer = 50; add_child(layer)
	var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new(); post_mat.shader = POST; rect.material = post_mat
	layer.add_child(rect)
	var ui_layer := CanvasLayer.new(); ui_layer.layer = 60; add_child(ui_layer)
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.theme = UITheme.build(); ui_layer.add_child(ui)
	_title()


func _process(_d: float) -> void:
	# the look follows the game: town mood -> hush, proven seals -> truth
	post_mat.set_shader_parameter("hush", state.hush_strength())
	post_mat.set_shader_parameter("truth", float(state.board.seals.size()) / 40.0)


func _clear() -> void:
	for c in stage.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()


func _bg(color: Color) -> void:
	var bg := ColorRect.new(); bg.color = color; bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)


func _text(t: String, pos: Vector2, size: int = 44, color: Color = Color("14121c"), width: float = 1480.0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.custom_minimum_size = Vector2(width, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	ui.add_child(l)
	return l


func _button(t: String, pos: Vector2, cb: Callable, w: float = 520.0) -> Button:
	var b := Button.new()
	b.text = t
	b.position = pos
	b.custom_minimum_size = Vector2(w, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(cb)
	ui.add_child(b)
	b.grab_focus()
	return b


func day_def() -> Dictionary:
	return days[str(state.day)]


# ---------------------------------------------------------------- title / wake
func _title() -> void:
	_clear()
	_bg(Color("f1dfc0"))
	_text("UNDERSTUDY\n\nEvery morning someone in Little Mercy vanishes.\nEvery morning you wake up as them.", Vector2(300, 300), 48)
	_button("Wake up", Vector2(300, 700), start_day, 360.0)


func start_day() -> void:
	_clear()
	_bg(Color("2b2a3a"))
	snoop = Snoop.new()
	ui.add_child(snoop)
	snoop.setup(state, day_def()["home"])
	snoop.finished.connect(_perform)


# ---------------------------------------------------------------- perform
func _perform(result: Dictionary) -> void:
	state.advance()   # WAKE -> PERFORM
	if result["vague_brief"]:
		for step in day_def()["perform"]:
			if step["type"] == "convo":
				state.suspicion.raise(_npc_of(step), 15)   # a half-known self is noticeable
	queue = day_def()["perform"].duplicate(true)
	_next_step()


func _npc_of(step: Dictionary) -> String:
	return String(step.get("id", ""))


func _next_step() -> void:
	_clear()
	_bg(Color("c9d8d4"))
	if queue.is_empty():
		_step_off()
		return
	var s: Dictionary = queue.pop_front()
	match s["type"]:
		"convo":
			var d := DialogueUI.new()
			ui.add_child(d)
			d.setup(state, s["file"], s["id"])
			d.finished.connect(func(npc): _after_convo(npc, s))
		"vignette":
			match s["kind"]:
				"rhythm": _rhythm(s)
				"small_paths": _eavesdrop(s)
				_:
					_next_step()
		_:
			_next_step()


func _after_convo(npc: String, step: Dictionary) -> void:
	var after: Dictionary = step.get("after", {})
	if not after.is_empty() and state.board.evidence.has(after.get("if_evidence", "")) and after.get("vignette", "") == "dental":
		_clear()
		_bg(Color("e9e4d4"))
		var d := DentalUI.new()
		ui.add_child(d)
		d.setup(after["case"])
		d.finished.connect(_after_overlay)
		return
	_next_step()


func _after_overlay(result: Dictionary) -> void:
	if result["proven"] and result["seal"] != "":
		for e in ["LF-055", "LF-056"]:
			state.board.pin(e, "who")
		state.notes.add("curiosity", 10)
		if state.board.complete_test(result["seal"], state.day):
			_stamp(result["seal"], result["verdict"])
			return
	_next_step()


func _rhythm(step: Dictionary) -> void:
	_clear()
	var r := RhythmUI.new()
	ui.add_child(r)
	r.setup(step["song"], lenient, false)
	r.finished.connect(func(res):
		state.notes.add("nerve", 5 * res["stars"])
		state.notes.add("warmth", 3 * res["stars"])
		_applause(res["stars"], "The set is over.", _next_step))


func _eavesdrop(step: Dictionary) -> void:
	_clear()
	_bg(Color("efe4c8"))
	var e := EavesdropUI.new()
	ui.add_child(e)
	e.setup(state, step["map"])
	e.finished.connect(func(_r): _next_step())


func _applause(stars: int, line: String, cont: Callable) -> void:
	_clear()
	_bg(Color("f1dfc0"))
	_text("%s\n\n%s" % [line, "★".repeat(stars) + "☆".repeat(3 - stars)], Vector2(260, 300), 52)
	_button("Keep going", Vector2(260, 700), cont)


## A red Seal stamp: a proven truth.
func _stamp(seal: String, verdict: String) -> void:
	_clear()
	_bg(Color("f1dfc0"))
	_text("SEAL  %s\n\n%s\n\n(One piece of the Model is placed. Something small and dry in your head says: \"Told you.\")" % [seal, verdict], Vector2(220, 240), 42, Color("e23d3d"))
	_button("Carry on", Vector2(220, 820), _next_step)


# ---------------------------------------------------------------- step off / night
func _step_off() -> void:
	state.advance()   # PERFORM -> STEP_OFF
	state.advance()   # STEP_OFF -> NIGHT (Remnant forms)
	_clear()
	_bg(Color("2b2a3a"))
	var life: Dictionary = state.current_life()
	var r: Dictionary = state.remnants.by_life[life["id"]]["notes"]
	_text("Dusk. You step out of %s's life.\n\nThey stay behind, and they're now a little:\n%s\n\nSomeone tied a red ribbon on your door. Who?" % [life["name"].split(" ")[0], _describe(r)], Vector2(260, 220), 40, Color("f6ecd2"))
	_button("Night", Vector2(260, 800), _night)


func _night() -> void:
	_clear()
	_bg(Color("1b1a2e"))
	snoop = Snoop.new()
	ui.add_child(snoop)
	snoop.setup(state, day_def()["night"])
	snoop.finished.connect(func(_r): _night_event())


func _night_event() -> void:
	var ev: Dictionary = day_def().get("night_event", {})
	if ev.get("type", "") == "reply" and state.board.evidence.has(ev["if_evidence"]):
		_clear()
		_bg(Color("0e0d1a"))
		_text("4:10 a.m. The tape recorder is running by itself. The pipes have stopped dripping. Something is waiting for you to begin.", Vector2(260, 240), 40, Color("f6ecd2"))
		_button("Play the Mercy Roll", Vector2(260, 700), _reply)
		return
	_board()


func _reply() -> void:
	_clear()
	var r := RhythmUI.new()
	ui.add_child(r)
	r.setup("reply", lenient, true)
	r.finished.connect(func(res):
		_clear()
		_bg(Color("0e0d1a"))
		if res["answered"]:
			state.board.pin("LF-047", "what")
			state.board.complete_test("S20", state.day)
			_text("You stop. The room is very quiet.\n\nThen, from under the floor, from under the lake, 212 slow strokes of a bell answer you. One for each of them.", Vector2(260, 240), 42, Color("7fd0d8"))
		else:
			_text("You stop. Somewhere below, something almost answers. Not yet. The roll wants a steadier hand.", Vector2(260, 240), 42, Color("b8b0d8"))
		_button("Pack up", Vector2(260, 760), _board))


func _board() -> void:
	_clear()
	_bg(Color("efe4c8"))
	var b := BoardUI.new()
	ui.add_child(b)
	b.setup(state)
	b.finished.connect(_slack)


func _slack() -> void:
	_clear()
	_bg(Color("14121c"))
	state.advance()   # NIGHT -> SLACK
	var next_life: Dictionary = state.lives[state.day]
	var s := SlackUI.new()
	ui.add_child(s)
	s.setup(next_life, next_life["decision_time"])
	s.finished.connect(_new_day)


func _new_day() -> void:
	state.advance()   # SLACK -> next day's WAKE (or ENDED)
	if days.has(str(state.day)) and state.phase == 0:
		start_day()
		return
	_clear()
	_bg(Color("f1dfc0"))
	var life: Dictionary = state.current_life()
	_text("DAY %d\n\nYou wake up as %s.\n\n(Their bedroom is built next pass.)\n\nSeals so far: %d / 40" % [state.day, life["name"], state.board.seals.size()], Vector2(260, 280), 46)


func _describe(n: Dictionary) -> String:
	var words := {"warmth": ["cold", "warm"], "candor": ["guarded", "candid"], "nerve": ["timid", "bold"],
		"curiosity": ["incurious", "curious"], "fidelity": ["off-script", "in character"]}
	var out: Array = []
	for k in words:
		var v := int(n[k])
		if absi(v) >= 8:
			out.append("  %s (%+d)" % [words[k][1 if v > 0 else 0], v])
	return "\n".join(out) if not out.is_empty() else "  unremarkable. A quiet day."
