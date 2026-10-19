extends RefCounted
## One shared look for every screen: paper buttons, ink borders, marigold focus. Large by default.

const INK := Color("14121c")
const PAPER := Color("f6ecd2")
const MARIGOLD := Color("f5b82e")
const RED := Color("e23d3d")


static func _box(fill: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_offset = Vector2(0, 4)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _box(PAPER, INK, 4))
	t.set_stylebox("hover", "Button", _box(PAPER.lightened(0.25), INK, 4))
	t.set_stylebox("pressed", "Button", _box(MARIGOLD, INK, 4))
	t.set_stylebox("focus", "Button", _box(PAPER.lightened(0.25), MARIGOLD.darkened(0.1), 8))
	t.set_stylebox("disabled", "Button", _box(PAPER.darkened(0.2), INK.lightened(0.5), 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK.lightened(0.5))
	t.set_color("font_color", "Label", INK)
	t.set_constant("outline_size", "Button", 0)
	var bar_bg := _box(PAPER.darkened(0.25), INK, 3)
	var bar_fill := _box(MARIGOLD, INK, 3)
	bar_bg.shadow_size = 0
	bar_fill.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t
