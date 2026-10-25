extends Control
## The scene as a floor plan you tap, instead of a list you read. Each place worth a look is a pulsing ring; examined ones get a tick.
## Pure drawing and taps: the HUD owns what examining does. It shows only what the detective can see (every spot pulses, even ones
## their skills may not read yet), so the view never hints at what is, or is not, there.

signal spot_tapped(id: String)

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const MARIGOLD := Color("f5b82e")
const RED := Color("e23d3d")
const GREEN := Color("3f7a4f")
const PLAN := Color("e8dcc0")
const WALL := Color("5b4d3c")

# where each kind of spot sits on the plan (0-1 of the room rectangle)
const POS := {"body": Vector2(0.5, 0.52), "door": Vector2(0.5, 0.93), "floor": Vector2(0.27, 0.7), "desk": Vector2(0.83, 0.22), "phone": Vector2(0.64, 0.17),
	"garden": Vector2(0.1, 0.2), "weapon": Vector2(0.18, 0.4), "records": Vector2(0.75, 0.3), "search": Vector2(0.5, 0.4), "window": Vector2(0.9, 0.55),
	"counter": Vector2(0.8, 0.3), "kitchen": Vector2(0.15, 0.25), "bed": Vector2(0.85, 0.7), "shelf": Vector2(0.4, 0.15), "safe": Vector2(0.2, 0.15)}

var spots: Array = []            # [{id, label}]
var done: Dictionary = {}        # id -> true
var kind := "home"
var _t := 0.0
var _hot := {}                   # id -> screen pos, from the last draw


func _init() -> void:
	name = "SceneView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 360)
	clip_contents = true


func set_spots(list: Array, finished: Dictionary, room_kind: String = "home") -> void:
	spots = list
	done = finished
	kind = room_kind
	queue_redraw()


func _room() -> Rect2:
	return Rect2(Vector2(14, 12), size - Vector2(28, 54))


func _pos_of(id: String, i: int, r: Rect2) -> Vector2:
	var u: Vector2 = POS.get(id, Vector2(0.2 + 0.18 * (i % 4), 0.35 + 0.2 * (i / 4)))
	return r.position + u * r.size


func _process(d: float) -> void:
	_t += d
	if visible:
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var p := Vector2.INF
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		p = e.position
	elif e is InputEventScreenTouch and e.pressed:
		p = e.position
	if p == Vector2.INF:
		return
	var best := ""
	var bd := 70.0
	for id in _hot:
		var d: float = (_hot[id] as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = id
	if best != "":
		spot_tapped.emit(best)


func _draw() -> void:
	var r := _room()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.9))
	draw_rect(r, PLAN)
	# faint floor boards
	for i in range(1, 9):
		var y := r.position.y + r.size.y * i / 9.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(WALL, 0.12), 2.0)
	draw_rect(r, WALL, false, 6.0)
	# the door gap in the bottom wall
	var dp := _pos_of("door", 0, r)
	draw_rect(Rect2(dp.x - 46, r.end.y - 4, 92, 9), PLAN)
	draw_arc(Vector2(dp.x - 46, r.end.y), 46, -PI / 2, 0.0, 16, Color(WALL, 0.4), 2.0)
	# furniture suggestions by kind of place
	var fc := Color(WALL, 0.25)
	draw_rect(Rect2(r.position + r.size * Vector2(0.72, 0.1), r.size * Vector2(0.24, 0.16)), fc)
	draw_rect(Rect2(r.position + r.size * Vector2(0.76, 0.58), r.size * Vector2(0.2, 0.24)), fc)
	draw_rect(Rect2(r.position + r.size * Vector2(0.08, 0.08), r.size * Vector2(0.2, 0.12)), fc)
	draw_circle(r.position + r.size * Vector2(0.28, 0.72), r.size.y * 0.12, Color(WALL, 0.16))
	# the chalk outline over the body spot
	if spots.any(func(s): return s["id"] == "body"):
		var bp := _pos_of("body", 0, r)
		draw_circle(bp + Vector2(0, -22), 11, Color(PAPER, 0.0), false, 2.0)
		draw_arc(bp + Vector2(0, -22), 11, 0, TAU, 20, INK, 2.0)
		draw_line(bp + Vector2(0, -11), bp + Vector2(0, 26), INK, 2.0)
		draw_line(bp + Vector2(-22, 0), bp + Vector2(22, 6), INK, 2.0)
		draw_line(bp + Vector2(0, 26), bp + Vector2(-12, 44), INK, 2.0)
		draw_line(bp + Vector2(0, 26), bp + Vector2(14, 44), INK, 2.0)
	_hot.clear()
	for i in spots.size():
		var s: Dictionary = spots[i]
		var id: String = s["id"]
		var p := _pos_of(id, i, r)
		_hot[id] = p
		var ok: bool = done.get(id, false)
		var pulse := 0.5 + 0.5 * sin(_t * 3.0 + i)
		var col := GREEN if ok else MARIGOLD
		if not ok:
			draw_circle(p, 26 + 10 * pulse, Color(col, 0.18 + 0.12 * pulse))
		draw_circle(p, 22, Color(INK, 0.85))
		draw_arc(p, 22, 0, TAU, 28, col, 4.0)
		if ok:
			draw_polyline(PackedVector2Array([p + Vector2(-9, 1), p + Vector2(-2, 9), p + Vector2(11, -8)]), GREEN, 5.0)
		else:
			draw_circle(p, 6, col)
		var label := String(s["label"])
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var lp := Vector2(clampf(p.x - w / 2.0, 6.0, size.x - w - 6.0), p.y + 50.0)
		draw_rect(Rect2(lp + Vector2(-6, -22), Vector2(w + 12, 28)), Color(INK, 0.75))
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
