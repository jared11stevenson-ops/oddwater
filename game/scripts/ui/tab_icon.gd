extends Control
## A small procedural icon (no font glyphs, no textures) for the case-file tabs and HUD buttons, with an optional red count badge.

var kind := "case"
var color := Color("14121c")
var count := 0                 # a red badge in the corner when > 0
var dot := false               # a plain red dot instead of a number


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)


func setup(k: String, c: Color, sz: float = 28.0) -> Control:
	kind = k
	color = c
	custom_minimum_size = Vector2(sz, sz)
	queue_redraw()
	return self


func set_count(n: int) -> void:
	if n != count:
		count = n
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	var o := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	var u := s / 28.0
	var w := maxf(2.0, 2.4 * u)
	match kind:
		"case":                    # a folder with a tab
			var pts := PackedVector2Array([Vector2(3, 8), Vector2(11, 8), Vector2(13, 11), Vector2(25, 11), Vector2(25, 23), Vector2(3, 23)])
			draw_polyline(_p(pts, o, u) + PackedVector2Array([_pt(Vector2(3, 8), o, u)]), color, w, true)
			draw_line(o + Vector2(3, 15) * u, o + Vector2(25, 15) * u, color, w * 0.7)
		"notebook":                # a notebook with lines and a spiral edge
			draw_rect(Rect2(o + Vector2(6, 3) * u, Vector2(17, 22) * u), color, false, w)
			for i in 3:
				draw_line(o + Vector2(10, 10 + i * 5) * u, o + Vector2(20, 10 + i * 5) * u, color, w * 0.7)
			for i in 4:
				draw_circle(o + Vector2(6, 6 + i * 5.5) * u, 1.6 * u, color)
		"people":                  # two heads and shoulders
			draw_circle(o + Vector2(10, 9) * u, 4.2 * u, color)
			draw_arc(o + Vector2(10, 25) * u, 8.0 * u, PI, TAU, 14, color, w, true)
			draw_arc(o + Vector2(20, 11) * u, 3.4 * u, 0, TAU, 12, color, w * 0.8, true)
			draw_arc(o + Vector2(20, 25) * u, 6.0 * u, PI * 1.1, PI * 1.9, 10, color, w * 0.8, true)
		"news":                    # a folded paper with headline bars
			draw_rect(Rect2(o + Vector2(3, 5) * u, Vector2(22, 18) * u), color, false, w)
			draw_rect(Rect2(o + Vector2(6, 8) * u, Vector2(8, 5) * u), color)
			for i in 3:
				draw_line(o + Vector2(16, 9 + i * 4) * u, o + Vector2(22, 9 + i * 4) * u, color, w * 0.6)
			draw_line(o + Vector2(6, 18) * u, o + Vector2(22, 18) * u, color, w * 0.6)
		"cctv":                    # a camera: body, lens, mount
			draw_rect(Rect2(o + Vector2(3, 8) * u, Vector2(17, 11) * u), color, false, w)
			draw_colored_polygon(_p(PackedVector2Array([Vector2(20, 12), Vector2(26, 8), Vector2(26, 19), Vector2(20, 15)]), o, u), color)
			draw_circle(o + Vector2(11, 13.5) * u, 3.0 * u, color)
			draw_line(o + Vector2(11, 19) * u, o + Vector2(11, 24) * u, color, w)
		"court":                   # scales of justice
			draw_line(o + Vector2(14, 4) * u, o + Vector2(14, 23) * u, color, w)
			draw_line(o + Vector2(5, 8) * u, o + Vector2(23, 8) * u, color, w)
			draw_line(o + Vector2(9, 24) * u, o + Vector2(19, 24) * u, color, w)
			for sx in [5.0, 23.0]:
				draw_line(o + Vector2(sx, 8) * u, o + Vector2(sx - 3, 16) * u, color, w * 0.6)
				draw_line(o + Vector2(sx, 8) * u, o + Vector2(sx + 3, 16) * u, color, w * 0.6)
				draw_arc(o + Vector2(sx, 16) * u, 3.4 * u, 0, PI, 10, color, w, true)
		"accuse":                  # a pointing finger-like arrow with a bar
			draw_colored_polygon(_p(PackedVector2Array([Vector2(3, 11), Vector2(16, 11), Vector2(16, 6), Vector2(26, 14), Vector2(16, 22), Vector2(16, 17), Vector2(3, 17)]), o, u), color)
		"you":                     # a badge: star in a shield
			var pts2 := PackedVector2Array([Vector2(5, 4), Vector2(23, 4), Vector2(23, 15), Vector2(14, 25), Vector2(5, 15), Vector2(5, 4)])
			draw_polyline(_p(pts2, o, u), color, w, true)
			var star := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + float(i) * PI / 5.0
				var r := 6.0 if i % 2 == 0 else 2.6
				star.append(o + (Vector2(14, 12) + Vector2(cos(a), sin(a)) * r) * u)
			draw_colored_polygon(star, color)
		"clock":
			draw_arc(o + Vector2(14, 14) * u, 10.0 * u, 0, TAU, 24, color, w, true)
			draw_line(o + Vector2(14, 14) * u, o + Vector2(14, 8) * u, color, w)
			draw_line(o + Vector2(14, 14) * u, o + Vector2(19, 16) * u, color, w)
		"gear":
			draw_arc(o + Vector2(14, 14) * u, 6.5 * u, 0, TAU, 20, color, w, true)
			for i in 8:
				var a2 := float(i) * TAU / 8.0
				draw_line(o + (Vector2(14, 14) + Vector2(cos(a2), sin(a2)) * 8.5) * u, o + (Vector2(14, 14) + Vector2(cos(a2), sin(a2)) * 11.5) * u, color, w * 1.3)
		"menu":
			for i in 3:
				draw_line(o + Vector2(5, 8 + i * 6) * u, o + Vector2(23, 8 + i * 6) * u, color, w)
		"pin":                     # an objective marker
			draw_circle(o + Vector2(14, 11) * u, 7.0 * u, color)
			draw_colored_polygon(_p(PackedVector2Array([Vector2(8, 15), Vector2(20, 15), Vector2(14, 26)]), o, u), color)
			draw_circle(o + Vector2(14, 11) * u, 2.6 * u, Color("f3e9d2"))
		"map":                     # a folded map with a route
			var fold := _p(PackedVector2Array([Vector2(3, 6), Vector2(10, 9), Vector2(18, 6), Vector2(25, 9), Vector2(25, 23), Vector2(18, 20), Vector2(10, 23), Vector2(3, 20), Vector2(3, 6)]), o, u)
			draw_polyline(fold, color, w, true)
			draw_line(o + Vector2(10, 9) * u, o + Vector2(10, 23) * u, color, w * 0.6)
			draw_line(o + Vector2(18, 6) * u, o + Vector2(18, 20) * u, color, w * 0.6)
		"board":                   # a pinboard: two cards, a pin and a string
			draw_rect(Rect2(o + Vector2(3, 4) * u, Vector2(22, 20) * u), color, false, w)
			draw_rect(Rect2(o + Vector2(6, 8) * u, Vector2(7, 6) * u), color)
			draw_rect(Rect2(o + Vector2(16, 14) * u, Vector2(6, 7) * u), color)
			draw_line(o + Vector2(10, 11) * u, o + Vector2(19, 17) * u, color, w * 0.6)
		"walk":
			draw_circle(o + Vector2(15, 5) * u, 3.0 * u, color)
			draw_line(o + Vector2(15, 8) * u, o + Vector2(13, 17) * u, color, w * 1.2)
			draw_line(o + Vector2(13, 17) * u, o + Vector2(9, 25) * u, color, w)
			draw_line(o + Vector2(13, 17) * u, o + Vector2(19, 25) * u, color, w)
			draw_line(o + Vector2(14.5, 10) * u, o + Vector2(8, 14) * u, color, w * 0.9)
			draw_line(o + Vector2(14.5, 10) * u, o + Vector2(21, 13) * u, color, w * 0.9)
	if count > 0 or dot:
		var c := o + Vector2(s - 5.0, 5.0)
		var r2 := 9.0 if (count > 0 and not dot) else 6.0
		draw_circle(c, r2 + 2.0, Color("14121c"))
		draw_circle(c, r2, Color("e23d3d"))
		if count > 0 and not dot:
			var f := get_theme_default_font()
			var t := str(mini(count, 9))
			var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			draw_string(f, c + Vector2(-ts.x / 2.0, 5.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f3e9d2"))


func _p(pts: PackedVector2Array, o: Vector2, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(o + p * u)
	return out


func _pt(p: Vector2, o: Vector2, u: float) -> Vector2:
	return o + p * u
