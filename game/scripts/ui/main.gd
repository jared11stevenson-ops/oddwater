extends Control
## Boot -> Wake & Snoop -> Perform (patients) -> brief. Night, the vignette and the Slack follow.

const GameState = preload("res://scripts/core/game_state.gd")
const Snoop = preload("res://scripts/ui/snoop.gd")
const DialogueUI = preload("res://scripts/ui/dialogue_ui.gd")
const DentalUI = preload("res://scripts/ui/dental_ui.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")
const BoardUI = preload("res://scripts/ui/board_ui.gd")
const SlackUI = preload("res://scripts/ui/slack_ui.gd")
const POST := preload("res://shaders/page_post.gdshader")

const DAY1_PATIENTS := ["silas", "bea", "cal"]

var state: RefCounted
var snoop: Control
var queue: Array = []
var stage: Control            # backgrounds / world (gets the print pass)
var ui: Control               # all readable UI sits above the print pass
var post_mat: ShaderMaterial


func _ready() -> void:
	state = GameState.new()
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


func _title() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("f1dfc0"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var l := Label.new()
	l.text = "UNDERSTUDY\n\nEvery morning someone in Little Mercy vanishes.\nEvery morning you wake up as them."
	l.position = Vector2(300, 300)
	l.add_theme_font_size_override("font_size", 48)
	l.add_theme_color_override("font_color", Color("14121c"))
	ui.add_child(l)
	var b := Button.new()
	b.text = "Wake up"
	b.position = Vector2(300, 700)
	b.custom_minimum_size = Vector2(360, 100)
	b.pressed.connect(start_day)
	ui.add_child(b)
	b.grab_focus()


func start_day() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("2b2a3a"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	snoop = Snoop.new()
	ui.add_child(snoop)
	snoop.setup(state, "homes/%s.json" % state.current_life()["id"])
	snoop.finished.connect(_perform)


func _perform(result: Dictionary) -> void:
	state.advance()   # WAKE -> PERFORM
	if result["vague_brief"]:
		for n in ["silas", "bea", "cal"]:
			state.suspicion.raise(n, 15)   # a half-known self is noticeable
	queue = DAY1_PATIENTS.duplicate()
	_next_patient()


func _next_patient() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("c9d8d4"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	if queue.is_empty():
		_step_off()
		return
	var d := DialogueUI.new()
	ui.add_child(d)
	d.setup(state, "day01.json", queue.pop_front())
	d.finished.connect(_after_convo)


func _step_off() -> void:
	state.advance()   # PERFORM -> STEP_OFF
	state.advance()   # STEP_OFF -> NIGHT (Remnant forms)
	_clear()
	var bg := ColorRect.new(); bg.color = Color("2b2a3a"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var r: Dictionary = state.remnants.by_life["mags"]["notes"]
	var l := Label.new()
	l.text = "Dusk. You step out of Mags's life.\n\nShe stays behind, and she's now a little:\n%s\n\nSomeone tied a red ribbon on your door. Who?" % _describe(r)
	l.position = Vector2(260, 220)
	l.add_theme_font_size_override("font_size", 40)
	ui.add_child(l)
	var b := Button.new(); b.text = "Night"
	b.position = Vector2(260, 800); b.custom_minimum_size = Vector2(520, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(_night)
	ui.add_child(b); b.grab_focus()


## NIGHT: one location (Pell Dentistry after hours), then the Case Board, then the Slack.
func _night() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("1b1a2e"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	snoop = Snoop.new()
	ui.add_child(snoop)
	snoop.setup(state, "homes/practice_night.json")
	snoop.finished.connect(func(_r): _board())


func _board() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("efe4c8"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var b := BoardUI.new()
	ui.add_child(b)
	b.setup(state)
	b.finished.connect(_slack)


func _slack() -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("14121c"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	state.advance()   # NIGHT -> SLACK
	var next_life: Dictionary = state.lives[state.day]   # tomorrow
	var s := SlackUI.new()
	ui.add_child(s)
	s.setup(next_life, "11:58 p.m.")
	s.finished.connect(_new_day)


func _new_day() -> void:
	state.advance()   # SLACK -> next day's WAKE
	_clear()
	var bg := ColorRect.new(); bg.color = Color("f1dfc0"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var l := Label.new()
	var life: Dictionary = state.current_life()
	l.text = "DAY %d\n\nYou wake up as %s.\n\n(Their bedroom is built next pass. The loop above is the Day 1 slice.)\n\nSeals so far: %d / 40" % [state.day, life["name"], state.board.seals.size()]
	l.position = Vector2(260, 280)
	l.add_theme_font_size_override("font_size", 46)
	ui.add_child(l)


func _describe(n: Dictionary) -> String:
	var words := {"warmth": ["cold", "warm"], "candor": ["guarded", "candid"], "nerve": ["timid", "bold"],
		"curiosity": ["incurious", "curious"], "fidelity": ["off-script", "in character"]}
	var out: Array = []
	for k in words:
		var v := int(n[k])
		if absi(v) >= 8:
			out.append("  %s (%+d)" % [words[k][1 if v > 0 else 0], v])
	return "\n".join(out) if not out.is_empty() else "  unremarkable. A quiet Tuesday."


## After a conversation, some patients trigger the X-ray overlay Proof Tool.
func _after_convo(npc: String) -> void:
	var challenged: bool = npc == "silas" and state.board.evidence.has("LF-056")
	if not challenged:
		_next_patient()
		return
	_clear()
	var bg := ColorRect.new(); bg.color = Color("e9e4d4"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var d := DentalUI.new()
	ui.add_child(d)
	d.setup(npc)
	d.finished.connect(_after_overlay)


func _after_overlay(result: Dictionary) -> void:
	if result["proven"] and result["seal"] != "":
		for e in ["LF-055", "LF-056"]:
			state.board.pin(e, "who")
		state.notes.add("curiosity", 10)
		if state.board.complete_test(result["seal"], state.day):
			_stamp(result)
			return
	_next_patient()


## A red Seal stamp on the page: the player's first proven truth.
func _stamp(result: Dictionary) -> void:
	_clear()
	var bg := ColorRect.new(); bg.color = Color("f1dfc0"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)
	var l := Label.new()
	l.text = "SEAL  %s\n\n%s\n\n(One piece of the Model is placed. Something small and dry in your head says: \"Told you.\")" % [result["seal"], result["verdict"]]
	l.position = Vector2(220, 240)
	l.custom_minimum_size = Vector2(1480, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 42)
	l.add_theme_color_override("font_color", Color("e23d3d"))
	ui.add_child(l)
	var b := Button.new(); b.text = "Next patient"
	b.position = Vector2(220, 820); b.custom_minimum_size = Vector2(520, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(_next_patient)
	ui.add_child(b); b.grab_focus()
