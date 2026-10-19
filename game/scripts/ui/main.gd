extends Control
## Boot -> Wake & Snoop -> Perform (patients) -> brief. Night, the vignette and the Slack follow.

const GameState = preload("res://scripts/core/game_state.gd")
const Snoop = preload("res://scripts/ui/snoop.gd")
const DialogueUI = preload("res://scripts/ui/dialogue_ui.gd")
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
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui_layer.add_child(ui)
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
	d.finished.connect(func(_n): _next_patient())


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
	var b := Button.new(); b.text = "Night (next pass)"
	b.position = Vector2(260, 800); b.custom_minimum_size = Vector2(520, 100)
	ui.add_child(b); b.grab_focus()


func _describe(n: Dictionary) -> String:
	var words := {"warmth": ["cold", "warm"], "candor": ["guarded", "candid"], "nerve": ["timid", "bold"],
		"curiosity": ["incurious", "curious"], "fidelity": ["off-script", "in character"]}
	var out: Array = []
	for k in words:
		var v := int(n[k])
		if absi(v) >= 8:
			out.append("  %s (%+d)" % [words[k][1 if v > 0 else 0], v])
	return "\n".join(out) if not out.is_empty() else "  unremarkable. A quiet Tuesday."
