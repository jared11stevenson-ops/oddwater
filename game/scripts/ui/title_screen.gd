extends Control
## LITTLE MERCY: a rainy night-time skyline, the title in sound-lettering, and only the things a detective needs: Continue, New case,
## Settings, and a quick graphics-quality toggle. Continue appears only when a readable saved case exists.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const TownTheme = preload("res://scripts/ui/town_theme.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

signal continue_pressed
signal new_pressed

var has_save := false
var sky: Control
var cont_btn: Button
var new_btn: Button
var set_btn: Button
var quality_btn: Button
var settings_ui: Control
var _confirm_t := 0.0


func build(save_exists: bool) -> void:
	has_save = save_exists
	name = "TitleScreen"
	theme = TownTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.load_settings()
	sky = _Sky.new()
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := UiKit.safe_margins(self)
	var col := VBoxContainer.new()
	col.name = "TitleColumn"
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	col.position = Vector2(sm.x + 56.0, 60.0)
	col.custom_minimum_size = Vector2(560, 0)
	var tl := HBoxContainer.new()
	tl.add_theme_constant_override("separation", 22)
	tl.name = "TitleLine"
	col.add_child(tl)
	for part in [["LITTLE", UiKit.PAPER, UiKit.OXBLOOD], ["MERCY", UiKit.RED, Color(0, 0, 0, 0.7)]]:
		var t := Label.new()
		t.text = part[0]
		t.name = "Title_" + part[0]
		TownTheme.heading(t, 100, part[1])
		t.add_theme_color_override("font_shadow_color", part[2])
		t.add_theme_constant_override("shadow_offset_x", 5)
		t.add_theme_constant_override("shadow_offset_y", 6)
		tl.add_child(t)
	var tag := Label.new()
	tag.text = "A town that keeps its own counsel.\nYou are its only detective."
	tag.add_theme_font_size_override("font_size", 26)
	tag.add_theme_color_override("font_color", UiKit.PAPER_DIM)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	if has_save:
		cont_btn = _mk(col, "Continue the case", func(): continue_pressed.emit(), 34, true)
		cont_btn.name = "ContinueButton"
	new_btn = _mk(col, "New case", _new_tap, 34, not has_save)
	new_btn.name = "NewCaseButton"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	set_btn = _mk(row, "Settings", open_settings, 26, false)
	set_btn.name = "SettingsButton"
	quality_btn = _mk(row, "Graphics: %s" % UiKit.quality_label(), _cycle_quality, 24, false)
	quality_btn.name = "QualityButton"
	(cont_btn if cont_btn != null else new_btn).grab_focus()


func _mk(parent: Control, text: String, cb: Callable, px: int, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", UiKit.fs(px))
	b.custom_minimum_size = Vector2(0, 84 if px >= 30 else 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = false
	if primary:
		UiKit.set_button_style(b, Color(0.08, 0.07, 0.11, 0.9), UiKit.MARIGOLD, UiKit.PAPER)
	else:
		UiKit.set_button_style(b, Color(0.95, 0.9, 0.78, 0.92), UiKit.INK, UiKit.INK)
	b.pressed.connect(cb)
	UiKit.press_fx(b)
	parent.add_child(b)
	return b


## With a case already saved, "New case" asks once before it will replace it.
func _new_tap() -> void:
	if has_save and _confirm_t <= 0.0:
		_confirm_t = 3.0
		new_btn.text = "Tap again: this replaces your saved case"
		new_btn.add_theme_font_size_override("font_size", UiKit.fs(24))
		return
	new_pressed.emit()


func _process(delta: float) -> void:
	if _confirm_t > 0.0:
		_confirm_t -= delta
		if _confirm_t <= 0.0 and new_btn != null:
			new_btn.text = "New case"
			new_btn.add_theme_font_size_override("font_size", UiKit.fs(34))


func _cycle_quality() -> void:
	var q := UiKit.cycle_quality()
	UiKit.apply_quality(q, get_viewport())
	quality_btn.text = "Graphics: %s" % UiKit.quality_label()


func open_settings() -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
		return
	var sp := SettingsPanel.new()
	sp.show_replay = false
	settings_ui = sp
	add_child(sp)
	sp.open()
	sp.changed.connect(func():
		UiKit.apply_quality(String(UiKit.get_v("quality")), get_viewport())
		UiKit.apply_sound()
		quality_btn.text = "Graphics: %s" % UiKit.quality_label())


## The backdrop: night sky, a skyline of lit windows, a clock tower, the lake, and rain.
class _Sky extends Control:
	var _t := 0.0
	var _houses: Array = []

	func _init() -> void:
		name = "Sky"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 1961
		var x := -20.0
		while x < 1700.0:
			var w := rng.randf_range(60.0, 130.0)
			var h := rng.randf_range(50.0, 130.0)
			var wins: Array = []
			for i in 6:
				wins.append([rng.randf_range(0.12, 0.8), rng.randf_range(0.25, 0.75), rng.randf() < 0.45, rng.randf() * 6.0])
			_houses.append({"x": x, "w": w, "h": h, "roof": rng.randf_range(18.0, 46.0), "win": wins})
			x += w + rng.randf_range(4.0, 26.0)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var base := H * 0.80
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, base), Vector2(0, base)]),
			PackedColorArray([Color("0a0912"), Color("0a0912"), Color("2a2540"), Color("2a2540")]))
		# a low moon-glow behind the clouds
		for i in 6:
			draw_circle(Vector2(W * 0.74, H * 0.28), 150.0 - i * 20.0, Color(0.75, 0.78, 0.95, 0.022))
		for h in _houses:
			var x: float = h["x"] * (W / 1280.0)
			var w: float = h["w"]
			var hh: float = h["h"]
			var top := base - hh
			draw_rect(Rect2(x, top, w, hh), Color("12101c"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, top), Vector2(x + w / 2.0, top - h["roof"]), Vector2(x + w + 4, top)]), Color("0d0c16"))
			for wn in h["win"]:
				var on: bool = wn[2]
				if on:
					var flick := 0.8 + 0.2 * sin(_t * 1.3 + wn[3])
					draw_rect(Rect2(x + w * wn[0], top + hh * wn[1], 9, 12), Color(1.0, 0.8, 0.35, 0.85 * flick))
		# the clock tower
		var tx := W * 0.66
		draw_rect(Rect2(tx, base - 250, 56, 250), Color("100e1a"))
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 6, base - 250), Vector2(tx + 28, base - 320), Vector2(tx + 62, base - 250)]), Color("0b0a14"))
		draw_circle(Vector2(tx + 28, base - 205), 17, Color(0.95, 0.88, 0.62, 0.9))
		draw_arc(Vector2(tx + 28, base - 205), 17, 0, TAU, 20, Color("14121c"), 2.0, true)
		draw_line(Vector2(tx + 28, base - 205), Vector2(tx + 28, base - 217), Color("14121c"), 2.5)
		draw_line(Vector2(tx + 28, base - 205), Vector2(tx + 36, base - 202), Color("14121c"), 2.5)
		# the lake, with the lights doubled and wobbling
		draw_polygon(PackedVector2Array([Vector2(0, base), Vector2(W, base), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color("0b0a13"), Color("0b0a13"), Color("05040a"), Color("05040a")]))
		for h in _houses:
			for wn in h["win"]:
				if wn[2]:
					var x2: float = h["x"] * (W / 1280.0) + h["w"] * wn[0]
					var y2: float = base + (base - (base - h["h"] + h["h"] * wn[1])) * 0.35
					draw_rect(Rect2(x2 + sin(_t * 2.0 + wn[3]) * 3.0, y2, 9, 3), Color(1.0, 0.8, 0.35, 0.18))
		# rain
		var ms := _t * 1000.0
		for i in 130:
			var rx := fmod(float(i) * 97.3 + ms * 0.05 * (0.7 + float(i % 5) * 0.1), W + 80.0) - 40.0
			var ry := fmod(float(i) * 53.7 + ms * 0.62 * (0.8 + float(i % 7) * 0.05), H + 40.0) - 20.0
			draw_line(Vector2(rx, ry), Vector2(rx - 5, ry + 15), Color(0.65, 0.75, 0.95, 0.35), 1.6, true)
		# a vignette
		draw_rect(Rect2(0, 0, W, 90), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(0, H - 90, W, 90), Color(0, 0, 0, 0.3))
