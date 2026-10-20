extends Control
## The first-case tutorial: six short steps, each with a glowing ring around the real control it teaches. Shows once (flag kept in
## UiKit settings), skippable at any step, and never blocks the controls it points at (touches pass through the dimmer).

const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal finished(skipped: bool)

const HOLE_SHADER := """
shader_type canvas_item;
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(100.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float radius = 18.0;
uniform float dim = 0.62;
float sdbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec2 px = UV * view_size;
	float d = sdbox(px - (rect_pos + rect_size * 0.5), rect_size * 0.5, radius);
	COLOR = vec4(0.04, 0.03, 0.07, dim * smoothstep(-2.0, 12.0, d));
}
"""

const STEPS := [
	{"key": "move", "title": "WALK", "body": "Drag with your left thumb anywhere on the left half of the screen to walk. The stick appears under your finger.", "advance": "move"},
	{"key": "look", "title": "LOOK AROUND", "body": "Drag on the right side to turn the camera. Pinch to zoom in and out.", "advance": "look"},
	{"key": "objective", "title": "YOUR OBJECTIVE", "body": "The note up here says what to do next. A red marker floats over the place, with the distance. Tap Travel to go straight there: the walk costs time on the clock.", "advance": ""},
	{"key": "interact", "title": "TALK AND ENTER", "body": "When a door or a person is close, a big button appears here. Tap it to go inside or start talking.", "advance": ""},
	{"key": "case", "title": "THE CASE FILE", "body": "Everything you learn is written here: notes, people, cameras, the court, and your accusation. A red dot means something new.", "advance": ""},
	{"key": "time", "title": "TIME PASSES", "body": "Walking and investigating move the clock. The speed button changes how fast it runs. Menu holds settings, text size and this tutorial.", "advance": ""},
]

var hud: Control
var index := 0
var dim_rect: ColorRect
var ring: Control
var card_panel: PanelContainer
var title_lbl: Label
var body_lbl: Label
var step_lbl: Label
var next_btn: Button
var skip_btn: Button
var _rect := Rect2()
var _t := 0.0
var _advance_ready := true


func _init() -> void:
	name = "Tutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start(h: Control) -> void:
	hud = h
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_rect = ColorRect.new()
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = HOLE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	dim_rect.material = mat
	add_child(dim_rect)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring = Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel = PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.NIGHT, UiKit.MARIGOLD, 4, 14, 16))
	card_panel.custom_minimum_size = Vector2(600, 0)
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card_panel.add_child(v)
	step_lbl = Label.new()
	step_lbl.add_theme_font_size_override("font_size", 20)
	step_lbl.add_theme_color_override("font_color", UiKit.MARIGOLD)
	v.add_child(step_lbl)
	title_lbl = Label.new()
	title_lbl.add_theme_font_override("font", load("res://assets/fonts/Bangers-Regular.ttf"))
	title_lbl.add_theme_font_size_override("font_size", 40)
	title_lbl.add_theme_color_override("font_color", UiKit.PAPER)
	v.add_child(title_lbl)
	body_lbl = Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(560, 0)
	body_lbl.add_theme_font_size_override("font_size", UiKit.fs(24))
	body_lbl.add_theme_color_override("font_color", UiKit.PAPER)
	v.add_child(body_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	skip_btn = Button.new()
	skip_btn.text = "Skip tutorial"
	skip_btn.name = "TutorialSkip"
	skip_btn.add_theme_font_size_override("font_size", 24)
	skip_btn.custom_minimum_size = Vector2(0, 60)
	skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_btn.pressed.connect(func(): _finish(true))
	UiKit.press_fx(skip_btn)
	row.add_child(skip_btn)
	next_btn = Button.new()
	next_btn.name = "TutorialNext"
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.custom_minimum_size = Vector2(0, 60)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(_next)
	UiKit.set_button_style(next_btn, UiKit.MARIGOLD, UiKit.INK, UiKit.INK)
	UiKit.press_fx(next_btn)
	row.add_child(next_btn)
	# the real controls tell us when you have tried them
	if hud.stick != null:
		hud.stick.moved.connect(_on_move)
	if hud.look != null:
		hud.look.dragged.connect(_on_look)
	_show_step(0)


func _on_move(v: Vector2) -> void:
	if is_inside_tree() and STEPS[index]["advance"] == "move" and v.length() > 0.5:
		_next()


func _on_look(d: Vector2) -> void:
	if is_inside_tree() and STEPS[index]["advance"] == "look" and d.length() > 6.0:
		_next()


func _process(delta: float) -> void:
	_t += delta
	# a panel or page over the world: step out of its way (and count opening the Case panel as doing the "case" step)
	var covered: bool = (hud.panel != null and hud.panel.visible) or hud.card != null or (hud.settings_ui != null and is_instance_valid(hud.settings_ui))
	if covered:
		if hud.panel != null and hud.panel.visible and String(STEPS[index]["key"]) == "case" and index < STEPS.size() - 1:
			_show_step(index + 1)
		visible = false
		return
	visible = true
	if ring != null:
		ring.queue_redraw()
	_rect = hud.tut_rect(String(STEPS[index]["key"]))
	var mat := dim_rect.material as ShaderMaterial
	mat.set_shader_parameter("rect_pos", _rect.position - Vector2(8, 8))
	mat.set_shader_parameter("rect_size", _rect.size + Vector2(16, 16))
	mat.set_shader_parameter("view_size", size)
	_place_card()


func _place_card() -> void:
	var cs := card_panel.get_combined_minimum_size()
	card_panel.size = cs
	var x := (size.x - cs.x) / 2.0
	if _rect.get_center().y > size.y * 0.45:
		card_panel.position = Vector2(x, 84.0)                  # the target is low on the screen: the words go high
	else:
		card_panel.position = Vector2(x, size.y - cs.y - 28.0)


func _show_step(i: int) -> void:
	index = i
	var st: Dictionary = STEPS[i]
	step_lbl.text = "STEP %d OF %d" % [i + 1, STEPS.size()]
	title_lbl.text = String(st["title"])
	body_lbl.text = String(st["body"])
	next_btn.text = "Let's go" if i == STEPS.size() - 1 else "Next"
	skip_btn.visible = i < STEPS.size() - 1
	UiKit.haptic(10)


func _next() -> void:
	if index >= STEPS.size() - 1:
		_finish(false)
	else:
		_show_step(index + 1)


func _finish(skipped: bool) -> void:
	UiKit.set_v("tutorial_done", true)
	finished.emit(skipped)
	queue_free()


func _draw_ring() -> void:
	var r := _rect.grow(8.0)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	ring.draw_rect(r, Color(UiKit.MARIGOLD, 0.5 + 0.5 * pulse), false, 4.0 + pulse * 2.0)
	var e := fmod(_t * 0.9, 1.0)
	ring.draw_rect(r.grow(8.0 + e * 26.0), Color(UiKit.MARIGOLD, (1.0 - e) * 0.7), false, 3.0)
