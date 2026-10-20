extends Control
## The objective marker over the 3D world: a diamond with the distance floating over the target, or an arrow on the screen edge pointing
## the way when the target is off screen or behind you. Pure drawing: the HUD tells it where the target is and where the camera is.

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const RED := Color("e23d3d")
const MARIGOLD := Color("f5b82e")

var camera: Camera3D
var target := Vector3.ZERO
var has_target := false
var player_pos := Vector3.ZERO
var title := ""
var margin := Vector4(60, 90, 60, 90)       # keep-clear insets: left, top, right, bottom
var distance_m := 0.0
var on_screen := false
var screen_pos := Vector2.ZERO               # where the marker was drawn last frame (the tutorial rings it)
var _t := 0.0


func _init() -> void:
	name = "Waypoint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_target(world_pos: Vector3, label: String) -> void:
	target = world_pos
	title = label
	has_target = true


func clear_target() -> void:
	has_target = false
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if has_target and visible:
		queue_redraw()


## Where on screen a point in the world lands, and whether it is truly in view. Edge-clamped when it is not.
func project(p: Vector3) -> Dictionary:
	var out := {"pos": size / 2.0, "visible": false, "angle": 0.0}
	if camera == null or not is_instance_valid(camera):
		return out
	var behind := camera.is_position_behind(p)
	var sp := camera.unproject_position(p)
	var area := Rect2(Vector2(margin.x, margin.y), size - Vector2(margin.x + margin.z, margin.y + margin.w))
	if not behind and area.has_point(sp):
		out["pos"] = sp
		out["visible"] = true
		return out
	# off screen: slide the marker to the edge along the direction from the middle
	var c := area.get_center()
	var d := sp - c
	if behind:
		d = -d
	if d.length() < 1.0:
		d = Vector2(0, 1)
	var k := minf((area.size.x / 2.0) / maxf(absf(d.x), 0.001), (area.size.y / 2.0) / maxf(absf(d.y), 0.001))
	out["pos"] = c + d * k
	out["angle"] = d.angle()
	return out


func _draw() -> void:
	if not has_target or camera == null:
		return
	distance_m = Vector2(target.x - player_pos.x, target.z - player_pos.z).length()
	if distance_m < 6.0:
		on_screen = false
		return                                      # you are there: no marker
	var pr := project(target + Vector3(0, 3.2, 0))
	var pos: Vector2 = pr["pos"]
	on_screen = bool(pr["visible"])
	screen_pos = pos
	var f := get_theme_default_font()
	var bob := sin(_t * 3.2) * 4.0
	var label := "%d m" % int(round(distance_m))
	if on_screen:
		var c := pos + Vector2(0, bob)
		var pts := PackedVector2Array([c + Vector2(0, -20), c + Vector2(15, 0), c + Vector2(0, 20), c + Vector2(-15, 0)])
		draw_colored_polygon(pts, RED)
		draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 3.0, true)
		draw_circle(c, 4.0, PAPER)
		draw_line(c + Vector2(0, 22), c + Vector2(0, 40), Color(0.96, 0.91, 0.82, 0.5), 3.0)
		_tag(f, c + Vector2(0, -34), label, 24)
	else:
		var ang: float = pr["angle"]
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var tip := pos + dir * 22.0
		var tri := PackedVector2Array([tip, pos - dir * 14.0 + perp * 18.0, pos - dir * 14.0 - perp * 18.0])
		draw_colored_polygon(tri, RED)
		draw_polyline(tri + PackedVector2Array([tri[0]]), INK, 3.0, true)
		var tp := pos - dir * 46.0
		tp.x = clampf(tp.x, 70.0, size.x - 70.0)
		tp.y = clampf(tp.y, 40.0, size.y - 40.0)
		_tag(f, tp, label, 22)


func _tag(f: Font, center: Vector2, text: String, px: int) -> void:
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var r := Rect2(center - Vector2(ts.x / 2.0 + 10.0, ts.y / 2.0 + 3.0), ts + Vector2(20.0, 6.0))
	draw_rect(r, Color(0.08, 0.07, 0.11, 0.85))
	draw_rect(r, MARIGOLD, false, 2.0)
	draw_string(f, Vector2(r.position.x + 10.0, r.position.y + r.size.y - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, PAPER)
