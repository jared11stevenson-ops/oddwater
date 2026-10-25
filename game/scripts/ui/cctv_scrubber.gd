extends Control
## The tape as something you drag: a top-down map of what the camera sees, with a dot for each figure it recorded, and a timeline thumb
## under it. The frames come from DetectiveGame.camera_frames (only what the camera would have on tape); the stamp is the camera's own clock.
## Tap a dot to tag that figure. The control only draws and reports taps: the HUD asks the game to write the claims.

signal scrubbed(at: float)
signal dot_tapped(key: String, at: float)

const Brief = preload("res://scripts/sim/brief.gd")
const Ptr = preload("res://scripts/ui/ptr.gd")
const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const MARIGOLD := Color("f5b82e")
const RED := Color("e23d3d")
const GREEN := Color("3f7a4f")
const SCREEN := Color("1d2a26")
const GRID := Color("2f4a40")
const HANDLE := Vector2(72, 64)
const MAP_H := 300.0

var frames: Array = []
var radius := 40.0
var clock_checked := false
var cam_label := ""
var pos := 0.0                    # fractional frame index
var tagged: Dictionary = {}       # figure key -> true
var picked := ""
var names: Dictionary = {}        # person id -> name to print beside a dot the picture was good enough to name
var _hot: Dictionary = {}         # key -> screen position of the dot in the last draw
var _drag := false


func _init() -> void:
	name = "Scrubber"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, MAP_H + 140.0)
	clip_contents = true


func set_data(data: Dictionary, label: String) -> void:
	frames = data.get("frames", [])
	radius = maxf(float(data.get("radius", 40.0)), 1.0)
	clock_checked = bool(data.get("clock_checked", false))
	cam_label = label
	pos = 0.0
	# open on the first frame that has anyone in it
	for i in frames.size():
		if not (frames[i]["figures"] as Array).is_empty():
			pos = float(i)
			break
	queue_redraw()


func at_time() -> float:
	if frames.is_empty():
		return 0.0
	var i := clampi(int(floor(pos)), 0, frames.size() - 1)
	var j := mini(i + 1, frames.size() - 1)
	return lerpf(float(frames[i]["at"]), float(frames[j]["at"]), pos - float(i))


func set_pos_from_time(t: float) -> void:
	if frames.size() < 2:
		return
	var a := float(frames[0]["at"])
	var b := float(frames[frames.size() - 1]["at"])
	pos = clampf((t - a) / maxf(b - a, 0.0001), 0.0, 1.0) * float(frames.size() - 1)
	scrubbed.emit(at_time())
	queue_redraw()


## Figures at the current thumb position, positions blended between the two nearest frames: [{key, x, y, ident, who, note}].
func figures_now() -> Array:
	var out: Array = []
	if frames.is_empty():
		return out
	var i := clampi(int(floor(pos)), 0, frames.size() - 1)
	var j := mini(i + 1, frames.size() - 1)
	var u := pos - float(i)
	var fi: Array = frames[i]["figures"]
	var fj: Array = frames[j]["figures"]
	for a in fi:
		var f: Dictionary = (a as Dictionary).duplicate()
		f["label"] = String(names.get(f["who"], "")) if f["ident"] else "?"
		for b in fj:
			if b["key"] == a["key"]:
				f["x"] = lerpf(float(a["x"]), float(b["x"]), u)
				f["y"] = lerpf(float(a["y"]), float(b["y"]), u)
		if u < 0.5 or fj.any(func(b): return b["key"] == a["key"]):
			out.append(f)
	for b in fj:
		if u >= 0.5 and not fi.any(func(a): return a["key"] == b["key"]):
			var g: Dictionary = (b as Dictionary).duplicate()
			g["label"] = String(names.get(g["who"], "")) if g["ident"] else "?"
			out.append(g)
	return out


func _map() -> Rect2:
	return Rect2(Vector2(6, 6), Vector2(size.x - 12.0, MAP_H))


func _track() -> Rect2:
	var x0 := HANDLE.x / 2.0 + 4.0
	return Rect2(Vector2(x0, MAP_H + 66.0), Vector2(size.x - 2.0 * x0, 12.0))


func _handle_rect() -> Rect2:
	var t := _track()
	var f := 0.0 if frames.size() < 2 else pos / float(frames.size() - 1)
	var cx := t.position.x + t.size.x * f
	return Rect2(Vector2(cx - HANDLE.x / 2.0, t.get_center().y - HANDLE.y / 2.0), HANDLE)


func _to_screen(x: float, y: float) -> Vector2:
	var m := _map()
	var sc := minf(m.size.x, m.size.y) / 2.0 / radius * 0.92
	return m.get_center() + Vector2(x, y) * sc


func _input_pos(e: InputEvent) -> Dictionary:
	return Ptr.read(e)


func _gui_input(e: InputEvent) -> void:
	var ev := _input_pos(e)
	if ev.is_empty():
		return
	var p: Vector2 = ev["p"]
	if ev["down"]:
		if p.y >= MAP_H + 12.0:
			_drag = true
			_set_from_x(p.x)
		else:
			tap_at(p)
	elif ev["move"] and _drag:
		_set_from_x(p.x)
	elif ev["up"]:
		_drag = false


func _set_from_x(x: float) -> void:
	if frames.size() < 2:
		return
	var t := _track()
	pos = clampf((x - t.position.x) / t.size.x, 0.0, 1.0) * float(frames.size() - 1)
	scrubbed.emit(at_time())
	queue_redraw()


## A tap on the map: the nearest dot within a thumb's reach is tagged.
func tap_at(p: Vector2) -> String:
	var best := ""
	var bd := 44.0
	for k in _hot:
		var d: float = (_hot[k] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = k
	if best != "":
		picked = best
		dot_tapped.emit(best, at_time())
		queue_redraw()
	return best


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var m := _map()
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.92))
	draw_rect(m, SCREEN)
	# top-down view: grid, the camera's reach, a road strip
	var c := m.get_center()
	var sc := minf(m.size.x, m.size.y) / 2.0 / radius * 0.92
	var step := 10.0 * sc
	var gx := fmod(c.x - m.position.x, step)
	while gx < m.size.x:
		draw_line(Vector2(m.position.x + gx, m.position.y), Vector2(m.position.x + gx, m.end.y), Color(GRID, 0.6), 1.0)
		gx += step
	var gy := fmod(c.y - m.position.y, step)
	while gy < m.size.y:
		draw_line(Vector2(m.position.x, m.position.y + gy), Vector2(m.end.x, m.position.y + gy), Color(GRID, 0.6), 1.0)
		gy += step
	draw_rect(Rect2(Vector2(m.position.x, c.y - 14.0), Vector2(m.size.x, 28.0)), Color("33463f", 0.55))
	draw_arc(c, radius * sc, 0, TAU, 48, Color(MARIGOLD, 0.55), 2.0)
	draw_circle(c, 9.0, Color(MARIGOLD, 0.9))
	draw_string(font, c + Vector2(-9, 7), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	draw_string(font, m.position + Vector2(m.size.x - 26, 22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.7))
	# the stamp, read from the camera's own clock
	var stamp := "--:--"
	if not frames.is_empty():
		stamp = Brief.clock_text(fposmod(at_time(), 24.0))
	draw_rect(Rect2(m.position + Vector2(6, 6), Vector2(190, 34)), Color(INK, 0.75))
	draw_string(font, m.position + Vector2(14, 31), "CAM  " + stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, MARIGOLD if clock_checked else RED)
	if int(Time.get_ticks_msec() / 500) % 2 == 0 and _drag == false:
		draw_circle(m.position + Vector2(m.size.x - 20, 30), 6, RED)
	# the figures
	_hot.clear()
	var figs := figures_now()
	for f in figs:
		var p := _to_screen(float(f["x"]), float(f["y"]))
		_hot[f["key"]] = p
		var named: bool = bool(f["ident"])
		var col := PAPER if named else Color("9aa7a1")
		draw_circle(p, 17.0, Color(col, 0.2))
		draw_circle(p, 11.0, col)
		if f["key"] == picked:
			draw_arc(p, 20.0, 0, TAU, 24, MARIGOLD, 3.0)
		if tagged.has(f["key"]):
			draw_arc(p, 24.0, 0, TAU, 24, RED, 3.0)
			draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), INK, 3.0)
			draw_line(p + Vector2(5, -5), p + Vector2(-5, 5), INK, 3.0)
		var dir := Vector2(float(f["dx"]), float(f["dy"]))
		if dir.length() > 0.1:
			draw_line(p, p + dir * 22.0, col, 3.0)
		var label := String(f.get("label", ""))
		if label != "":
			draw_string(font, p + Vector2(14, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if figs.is_empty():
		draw_string(font, c + Vector2(-70, 60), "Nobody on screen", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(PAPER, 0.6))
	draw_rect(m, PAPER, false, 3.0)
	# the timeline: activity ticks, the track, a warning when the clock is unchecked, the thumb
	var t := _track()
	var warn := Rect2(Vector2(6, MAP_H + 12.0), Vector2(size.x - 12.0, 28.0))
	if clock_checked:
		draw_string(font, warn.position + Vector2(2, 22), "Clock checked: the stamp is right", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("8fd0a0"))
	else:
		draw_rect(warn, Color(RED, 0.25))
		draw_string(font, warn.position + Vector2(8, 22), "! Clock not checked: the stamp may be off", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ffb0a0"))
	draw_rect(t, Color("3a3646") if clock_checked else Color("5a3a38"))
	for i in frames.size():
		if not (frames[i]["figures"] as Array).is_empty():
			var x := t.position.x + t.size.x * float(i) / float(maxi(frames.size() - 1, 1))
			draw_line(Vector2(x, t.position.y - 12.0), Vector2(x, t.position.y), MARIGOLD, 3.0)
	if not frames.is_empty():
		draw_string(font, Vector2(t.position.x - 6, t.end.y + 52), Brief.clock_text(fposmod(float(frames[0]["at"]), 24.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.8))
		var endt := Brief.clock_text(fposmod(float(frames[frames.size() - 1]["at"]), 24.0))
		draw_string(font, Vector2(t.end.x - font.get_string_size(endt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 6, t.end.y + 52), endt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PAPER, 0.8))
	var h := _handle_rect()
	draw_rect(h, MARIGOLD if not _drag else Color("ffd866"))
	draw_rect(h, INK, false, 3.0)
	for gx2 in [-10.0, 0.0, 10.0]:
		draw_line(h.get_center() + Vector2(gx2, -14), h.get_center() + Vector2(gx2, 14), INK, 3.0)
