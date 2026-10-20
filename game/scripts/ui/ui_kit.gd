extends RefCounted
## Shared pieces of the UI polish: palette, persisted settings (text size, sound, haptics, quality, tutorial flag), haptics, safe-area
## margins, press feedback, stamps. Everything static so any screen can use it without wiring.

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const PAPER_DIM := Color("dccfae")
const RED := Color("e23d3d")
const OXBLOOD := Color("a82d2d")
const MARIGOLD := Color("f5b82e")
const VIOLET := Color("4a3f7a")
const GREEN := Color("3f7a4f")
const NIGHT := Color(0.08, 0.07, 0.11, 0.9)

const QUALITIES := ["low", "med", "high"]
const QUALITY_NAMES := {"low": "Low", "med": "Medium", "high": "High"}
const QUALITY_SCALE := {"low": 0.6, "med": 0.8, "high": 1.0}
const TEXT_SCALES := [0.9, 1.0, 1.15, 1.3]

static var cfg_path := "user://ui_settings.cfg"
static var data := {"text_scale": 1.0, "sound": true, "haptics": true, "quality": "med", "tutorial_done": false}
static var loaded := false


# ------------------------------------------------------------------ settings
static func load_settings() -> void:
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(cfg_path) != OK:
		return
	for k in data.keys():
		data[k] = cf.get_value("ui", k, data[k])
	data["text_scale"] = clampf(float(data["text_scale"]), 0.8, 1.4)
	if not QUALITIES.has(String(data["quality"])):
		data["quality"] = "med"


static func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in data.keys():
		cf.set_value("ui", k, data[k])
	cf.save(cfg_path)


static func get_v(key: String) -> Variant:
	if not loaded:
		load_settings()
	return data[key]


static func set_v(key: String, v: Variant) -> void:
	if not loaded:
		load_settings()
	data[key] = v
	save_settings()


## A font size at the player's chosen text scale.
static func fs(px: float) -> int:
	return int(round(px * float(get_v("text_scale"))))


static func quality_label() -> String:
	return String(QUALITY_NAMES[String(get_v("quality"))])


static func cycle_quality() -> String:
	var i := (QUALITIES.find(String(get_v("quality"))) + 1) % QUALITIES.size()
	set_v("quality", QUALITIES[i])
	return QUALITIES[i]


## Quality low / med / high. A world with its own `set_quality(q)` gets it; everything else gets the 3D render scale and MSAA.
static func apply_quality(q: String, vp: Viewport, world: Object = null) -> void:
	if world != null and world.has_method("set_quality"):
		world.call("set_quality", q)
	if vp != null:
		vp.scaling_3d_scale = float(QUALITY_SCALE.get(q, 0.8))
		vp.msaa_3d = Viewport.MSAA_4X if q == "high" else (Viewport.MSAA_2X if q == "med" else Viewport.MSAA_DISABLED)


static func apply_sound() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not bool(get_v("sound")))


## Short buzz on a handheld (new clue, lab result, accusation). Silent on desktop, in tests and when switched off.
static func haptic(ms: int = 20) -> void:
	if not bool(get_v("haptics")):
		return
	if DisplayServer.get_name() == "headless":
		return
	Input.vibrate_handheld(ms)


# ------------------------------------------------------------------ layout
## Margins to keep clear of the camera cutout and rounded corners: Vector4(left, top, right, bottom) in the control's own units.
static func safe_margins(ctrl: Control) -> Vector4:
	var m := Vector4(24, 6, 24, 12)
	if DisplayServer.get_name() == "headless" or ctrl == null or not ctrl.is_inside_tree():
		return m
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 1.0 or win.y < 1.0 or ctrl.size.x < 1.0:
		return m
	var rect := Rect2(DisplayServer.get_display_safe_area())
	if rect.size.x < 1.0:
		return m
	var k := ctrl.size.x / win.x
	m.x = maxf(m.x, rect.position.x * k)
	m.y = maxf(m.y, rect.position.y * k)
	m.z = maxf(m.z, (win.x - rect.end.x) * k)
	m.w = maxf(m.w, (win.y - rect.end.y) * k)
	return m


# ------------------------------------------------------------------ styles
static func box(fill: Color, border: Color = INK, bw: int = 3, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func set_button_style(b: Button, fill: Color, border: Color, font: Color) -> void:
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, box(fill, border, 3, 8, 8))
	b.add_theme_stylebox_override("pressed", box(MARIGOLD, INK, 3, 8, 8))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, font)
	b.add_theme_color_override("font_pressed_color", INK)


## Buttons squash a little when pressed and buzz lightly.
static func press_fx(b: Button) -> void:
	b.button_down.connect(func():
		if not is_instance_valid(b):
			return
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.05)
		haptic(8))
	b.button_up.connect(func():
		if not is_instance_valid(b) or not b.is_inside_tree():
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.09))


## A rounded "rubber stamp" label: a small ink-bordered tag.
static func stamp(parent: Control, text: String, color: Color = RED, size_px: int = 18, filled: bool = false) -> PanelContainer:
	var pc := PanelContainer.new()
	var st := box(color if filled else Color(0, 0, 0, 0), color, 2, 9, 2)
	st.content_margin_left = 9
	st.content_margin_right = 9
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size_px))
	l.add_theme_color_override("font_color", PAPER if filled else color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(l)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(pc)
	return pc


## Quick fade-in for a freshly shown control.
static func fade_in(c: CanvasItem, seconds: float = 0.16, from: float = 0.0) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = from
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, seconds)


# ------------------------------------------------------------------ saves
## True only if the detective save exists and is a readable detective game: the title's Continue button depends on it.
static func detective_save_valid(path: String = "user://detective_save.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return false
	var d: Variant = j.data
	return typeof(d) == TYPE_DICTIONARY and d.get("mode", "") == "detective" and d.has("seed") and d.has("case")


static func delete_detective_save(path: String = "user://detective_save.json") -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func minutes_text(m: int) -> String:
	if m <= 0:
		return "no time"
	if m < 60:
		return "%d min" % m
	return "%dh %02dm" % [m / 60, m % 60] if m % 60 != 0 else "%d h" % (m / 60)
