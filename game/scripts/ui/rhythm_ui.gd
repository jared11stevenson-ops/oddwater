extends Control
## Two-lane drum game. Touch buttons, Z/X or arrows, or gamepad face buttons. Notes fall to the hit line.

signal finished(result: Dictionary)

const Rhythm = preload("res://scripts/core/rhythm.gd")
const TRAVEL := 2.0
const LANE_X := [700.0, 1220.0]
const HIT_Y := 760.0
const TOP_Y := 140.0

var rhythm: RefCounted
var clock := 0.0
var running := false
var reply_mode := false
var feedback := ""
var feedback_t := 0.0
var done := false


func setup(song_id: String, lenient: float = 1.0, is_reply: bool = false) -> void:
	rhythm = Rhythm.new(song_id, lenient)
	reply_mode = is_reply
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var names := ["KICK", "SNARE"]
	for lane in 2:
		var b := Button.new()
		b.text = names[lane]
		b.position = Vector2(LANE_X[lane] - 200.0, 880.0)
		b.custom_minimum_size = Vector2(400, 150)
		b.add_theme_font_size_override("font_size", 44)
		b.button_down.connect(tap_lane.bind(lane))   # fires on touch-down, not release
		b.focus_mode = Control.FOCUS_NONE
		add_child(b)
	var t := Label.new()
	t.text = rhythm.song["title"]
	t.position = Vector2(60, 30)
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color("f6ecd2"))
	add_child(t)
	var h := Label.new()
	h.text = "Tap KICK / SNARE as the notes reach the line.  (Z / X, arrows, or gamepad)"
	h.position = Vector2(60, 90)
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", Color("b8b0d8"))
	add_child(h)
	running = true
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	clock += delta
	rhythm.update(clock)
	feedback_t = maxf(0.0, feedback_t - delta)
	if clock > rhythm.duration():
		finish()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Z, KEY_LEFT]:
			tap_lane(0)
		elif event.keycode in [KEY_X, KEY_RIGHT]:
			tap_lane(1)
	elif event is InputEventJoypadButton and event.pressed:
		tap_lane(0 if event.button_index in [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER] else 1)


func tap_lane(lane: int) -> String:
	if not running:
		return ""
	var r: String = rhythm.tap(lane, clock)
	feedback = r.to_upper()
	feedback_t = 0.5
	return r


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1a2e"))
	for lane in 2:
		draw_rect(Rect2(LANE_X[lane] - 150.0, TOP_Y, 300, HIT_Y - TOP_Y + 60), Color("2b2a4a"))
		draw_arc(Vector2(LANE_X[lane], HIT_Y), 58, 0, TAU, 40, Color("f5b82e"), 5.0)
	for n in rhythm.notes:
		if n["state"] != "pending":
			continue
		var p: float = 1.0 - (float(n["t"]) - clock) / TRAVEL   # 0 at top .. 1 at hit line
		if p < 0.0 or p > 1.15:
			continue
		var y := lerpf(TOP_Y, HIT_Y, p)
		draw_circle(Vector2(LANE_X[n["lane"]], y), 36.0, Color("f5b82e") if n["lane"] == 0 else Color("e23d3d"))
		draw_arc(Vector2(LANE_X[n["lane"]], y), 36.0, 0, TAU, 32, Color("14121c"), 5.0)
	if feedback_t > 0.0:
		var col := Color("f5b82e") if feedback == "PERFECT" else (Color("f6ecd2") if feedback == "GOOD" else Color("e23d3d"))
		draw_string(ThemeDB.fallback_font, Vector2(810, 470 - feedback_t * 40.0), feedback, HORIZONTAL_ALIGNMENT_CENTER, 280, 54, col)
	var c: Dictionary = rhythm.counts()
	draw_string(ThemeDB.fallback_font, Vector2(1500, 80), "Combo %d" % rhythm.combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("f6ecd2"))
	if reply_mode:
		draw_string(ThemeDB.fallback_font, Vector2(1500, 130), "The lake is listening", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("7fd0d8"))
	draw_string(ThemeDB.fallback_font, Vector2(1500, 170), "Hit %d / %d" % [c["perfect"] + c["good"], rhythm.notes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("b8b0d8"))


## Test hook / accessibility "auto-drum": plays the whole song with the given timing error.
func auto_play(jitter: float = 0.0, skip_every: int = 0) -> void:
	var i := 0
	for n in rhythm.notes.duplicate():
		i += 1
		if skip_every > 0 and i % skip_every == 0:
			continue
		clock = n["t"] + jitter
		tap_lane(n["lane"])
	clock = rhythm.duration() + 1.0
	finish()


func finish() -> void:
	if done:
		return
	done = true
	running = false
	rhythm.update(clock)
	finished.emit({"stars": rhythm.stars(), "accuracy": rhythm.accuracy(), "answered": rhythm.reply_answered(),
		"best_combo": rhythm.best_combo, "reply": reply_mode})
