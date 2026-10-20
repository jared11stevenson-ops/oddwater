extends Control
## A resident's face, drawn in the game's own style: flat spot colour, one inked line in three weights, a halftone cel shadow,
## dot eyes and a short brow. Simple, normal people: the acting is in the brow and the mouth. Fully procedural and deterministic:
## the same person always has the same face; the sim (age, job, hobby, quirk) decides the details.
## Local drawing space is 200 x 260; the control scales it to fit.

const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const SKIN := ["f6d9bf", "efc7a0", "e3b088", "cf9468", "b27549", "8c5634", "63391f", "f3d0c0"]
const HAIR := ["1c1620", "2d211b", "47301f", "6a4528", "9a6a38", "c99a4e", "dcc27a", "9c3f24", "5a3a58"]
const GREY := ["a9a9b4", "c9c9d2", "e6e6ec", "8b8b96"]
const CLOTH := ["b4584a", "2f8f9d", "e0a82e", "71915a", "4a3f7a", "d9cfb2", "7a8aa0", "c76a8a", "3d5a80"]
const STYLES := ["crop", "side", "long", "bob", "bun", "ponytail", "curls", "bald"]
const EXPR := {   # brow tilt (+ = worried inner-up), eye openness, mouth curve (+ smile), blush
	"happy":   {"brow": -0.1, "eye": 1.0, "mouth": 1.0, "blush": 1.0},
	"content": {"brow": 0.0, "eye": 1.0, "mouth": 0.45, "blush": 0.3},
	"neutral": {"brow": 0.0, "eye": 0.95, "mouth": 0.0, "blush": 0.0},
	"sad":     {"brow": 0.7, "eye": 0.85, "mouth": -0.7, "blush": 0.0},
	"tired":   {"brow": 0.25, "eye": 0.45, "mouth": -0.15, "blush": 0.0},
	"cross":   {"brow": -0.8, "eye": 0.8, "mouth": -0.4, "blush": 0.0},
	"surprised": {"brow": 0.4, "eye": 1.25, "mouth": 0.0, "blush": 0.0}}

var traits: Dictionary = {}
var expression := "neutral"


static func _pick(id: String, salt: String, n: int) -> int:
	return int(absi(hash(id + "|" + salt)) % n)


## Everything about how this person looks, from who they are.
static func traits_for(p: RefCounted) -> Dictionary:
	var id: String = p.id
	var elder: bool = p.group == "elder" or p.age >= 62
	var kid: bool = p.group == "child" or p.group == "teen"
	var hair_col: Color
	if elder and _pick(id, "grey", 10) < 8:
		hair_col = Color(GREY[_pick(id, "greyc", GREY.size())])
	else:
		hair_col = Color(HAIR[_pick(id, "haircol", HAIR.size())])
	var style: String = STYLES[_pick(id, "style", STYLES.size())]
	if style == "bald" and (kid or _pick(id, "baldok", 4) != 0):
		style = "crop"
	var cloth := Color(CLOTH[_pick(id, "cloth", CLOTH.size())])
	var outfit := "crew"
	var job: String = p.job
	if job in ["nurse", "orderly", "medical receptionist", "night nurse", "hygienist", "care aide"]:
		cloth = Color("3aa0a6"); outfit = "vneck"
	elif job in ["baker", "counter hand", "line cook", "cook", "diner cook", "kitchen aide", "cafeteria cook", "dishwasher"]:
		cloth = Color("efe9da"); outfit = "apron"
	elif job in ["deputy", "dispatcher", "mail carrier", "dam technician", "inspector"]:
		cloth = Color("a8946a"); outfit = "collar"
	elif job in ["teacher", "teaching aide", "librarian", "library assistant", "archivist", "clerk", "planner", "records officer", "council aide"]:
		outfit = "collar"
	elif p.group == "teen" or p.group == "child":
		outfit = "hood"
	elif elder:
		outfit = "crew"; cloth = Color(CLOTH[_pick(id, "oldcloth", 5)]).lightened(0.15)
	var glasses: bool = _pick(id, "glasses", 100) < (14 + (30 if elder else 0) + (20 if p.hobby == "reading" else 0))
	var beard := 0
	if not kid and _pick(id, "beard", 100) < 16:
		beard = 1 + _pick(id, "beardk", 2)           # 1 = stubble, 2 = beard
	var hat := ""
	if not kid or p.group == "teen":
		if p.hobby == "fishing" and _pick(id, "hat", 100) < 55:
			hat = "cap"
		elif p.hobby == "gardening" and _pick(id, "hat", 100) < 50:
			hat = "sun"
		elif p.hobby == "sports" and _pick(id, "hat", 100) < 40:
			hat = "band"
	return {"skin": Color(SKIN[_pick(id, "skin", SKIN.size())]), "hair": hair_col, "style": style, "cloth": cloth, "outfit": outfit,
		"glasses": glasses, "beard": beard, "hat": hat, "kid": p.group == "child", "teen": p.group == "teen", "elder": elder,
		"wide": 0.92 + float(_pick(id, "wide", 21)) / 100.0, "jaw": float(_pick(id, "jaw", 100)) / 100.0,
		"eye_gap": 19.0 + float(_pick(id, "gap", 7)), "nose": _pick(id, "nose", 3), "id": id}


static func expression_for_mood(word: String) -> String:
	return {"radiant": "happy", "content": "content", "flat": "neutral", "low": "sad", "desperate": "tired"}.get(word, "neutral")


static func expression_for_tone(tone: String) -> String:
	return {"warm": "happy", "neutral": "neutral", "cold": "cross"}.get(tone, "neutral")


func setup(p: RefCounted, expr: String = "") -> void:
	traits = traits_for(p)
	expression = expr if expr != "" else expression_for_mood(p.mood_word())
	custom_minimum_size = Vector2(100, 130) if custom_minimum_size == Vector2.ZERO else custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_expression(e: String) -> void:
	expression = e
	queue_redraw()


# ------------------------------------------------------------------ drawing helpers
var _u := 1.0


func _w(weight: float) -> float:
	return maxf(1.4, weight * _u)


func _pt(p: Vector2) -> Vector2:
	return p * _u


func _ell(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int = 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(i) / n))
		out.append(Vector2(c.x + cos(a) * rx, c.y + sin(a) * ry))
	return out


func _scaled(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * _u)
	return out


## Fill only if the polygon is drawable (self-overlapping shapes would error); the line is drawn either way.
func _fill(sp: PackedVector2Array, col: Color) -> void:
	if sp.size() >= 3 and not Geometry2D.triangulate_polygon(sp).is_empty():
		draw_colored_polygon(sp, col)


func _poly(pts: PackedVector2Array, fill: Color, line: float = 2.6, closed: bool = true) -> void:
	var sp := _scaled(pts)
	if fill.a > 0.0:
		_fill(sp, fill)
	if line > 0.0:
		var ln := sp.duplicate()
		if closed:
			ln.append(sp[0])
		draw_polyline(ln, INK, _w(line), true)


func _line(a: Vector2, b: Vector2, w: float = 1.8, col: Color = INK) -> void:
	draw_line(_pt(a), _pt(b), col, _w(w), true)


func _dot(c: Vector2, r: float, fill: Color, line: float = 0.0) -> void:
	draw_circle(_pt(c), r * _u, fill)
	if line > 0.0:
		draw_arc(_pt(c), r * _u, 0.0, TAU, 18, INK, _w(line), true)


## Printed halftone: a grid of small dots, kept inside an ellipse and to one side.
func _halftone(c: Vector2, rx: float, ry: float, x_min: float, col: Color, step: float = 5.5, r: float = 1.5) -> void:
	var y := c.y - ry
	var row := 0
	while y <= c.y + ry:
		var x := x_min + (step * 0.5 if row % 2 == 1 else 0.0)
		while x <= c.x + rx:
			var nx := (x - c.x) / rx
			var ny := (y - c.y) / ry
			if nx * nx + ny * ny < 0.86:
				draw_circle(_pt(Vector2(x, y)), r * _u, col)
			x += step
		y += step * 0.86
		row += 1


func _draw() -> void:
	if traits.is_empty():
		return
	_u = minf(size.x / 200.0, size.y / 260.0)
	var t := traits
	var ex: Dictionary = EXPR.get(expression, EXPR["neutral"])
	var skin: Color = t["skin"]
	var skin_sh: Color = skin.darkened(0.16).lerp(Color("4a3f7a"), 0.12)
	var hair: Color = t["hair"]
	var kid: bool = t["kid"]
	var c := Vector2(100, 108 if not kid else 118)
	var rx := 53.0 * float(t["wide"]) * (1.04 if kid else 1.0)
	var ry := 61.0 * (1.0 if not kid else 0.95)
	var body_top := 192.0 if not kid else 204.0

	# paper behind the head: a soft spot so the portrait sits on the page
	draw_circle(_pt(Vector2(100, 130)), 118.0 * _u, Color(PAPER.r, PAPER.g, PAPER.b, 0.0))

	var style: String = t["style"]
	# back hair
	if style in ["long", "bob", "ponytail", "bun", "curls"]:
		var hb := PackedVector2Array()
		match style:
			"long":
				hb.append_array(_ell(c, rx + 8, ry + 7, 160.0, 380.0, 20))
				hb.append(Vector2(c.x + rx + 12, 232)); hb.append(Vector2(c.x - rx - 12, 232))
			"bob":
				hb.append_array(_ell(c, rx + 9, ry + 6, 165.0, 375.0, 20))
				hb.append(Vector2(c.x + rx + 10, c.y + 44)); hb.append(Vector2(c.x - rx - 10, c.y + 44))
			"ponytail":
				hb.append_array(_ell(c, rx + 5, ry + 5, 170.0, 370.0, 20))
				hb.append(Vector2(c.x + rx + 4, c.y + 6)); hb.append(Vector2(c.x - rx - 4, c.y + 6))
			"bun":
				hb.append_array(_ell(c, rx + 4, ry + 4, 170.0, 370.0, 20))
				hb.append(Vector2(c.x + rx, c.y)); hb.append(Vector2(c.x - rx, c.y))
			"curls":
				hb.append_array(_ell(c, rx + 11, ry + 9, 150.0, 390.0, 24))
				hb.append(Vector2(c.x + rx + 8, c.y + 22)); hb.append(Vector2(c.x - rx - 8, c.y + 22))
		_poly(hb, hair, 4.0)
	if style == "ponytail":
		_poly(PackedVector2Array([Vector2(c.x + rx - 2, c.y - 6), Vector2(c.x + rx + 34, c.y + 18), Vector2(c.x + rx + 22, c.y + 70), Vector2(c.x + rx + 4, c.y + 46)]), hair, 3.4)

	# neck and shoulders
	_poly(PackedVector2Array([Vector2(84, c.y + ry - 18), Vector2(116, c.y + ry - 18), Vector2(118, body_top + 4), Vector2(82, body_top + 4)]), skin_sh, 2.6)
	var cloth: Color = t["cloth"]
	var sh := PackedVector2Array([Vector2(14, 262), Vector2(26, body_top + 22), Vector2(70, body_top - 2), Vector2(130, body_top - 2), Vector2(174, body_top + 22), Vector2(186, 262)])
	if t["outfit"] == "hood":
		_poly(PackedVector2Array(_ell(Vector2(100, body_top + 2), 42, 26, 180.0, 360.0, 14)), cloth.darkened(0.25), 3.0)
	_poly(sh, cloth, 4.0)
	# cel shadow on the clothes, with printed dots
	_poly(PackedVector2Array([Vector2(120, body_top - 1), Vector2(173, body_top + 22), Vector2(185, 262), Vector2(132, 262)]), cloth.darkened(0.18).lerp(Color("4a3f7a"), 0.12), 0.0)
	for gy in range(0, 5):
		for gx in range(0, 7):
			var dp := Vector2(100 + gx * 9.5 + (4.0 if gy % 2 == 1 else 0.0), body_top + 30 + gy * 8.0)
			if dp.x < 168:
				draw_circle(_pt(dp), 1.3 * _u, cloth.darkened(0.3))
	match t["outfit"]:
		"vneck":
			_poly(PackedVector2Array([Vector2(82, body_top + 2), Vector2(100, body_top + 30), Vector2(118, body_top + 2)]), skin_sh, 2.2)
		"collar":
			_poly(PackedVector2Array([Vector2(82, body_top + 2), Vector2(98, body_top + 22), Vector2(88, body_top + 30), Vector2(70, body_top + 8)]), Color("f6f0e0"), 2.2)
			_poly(PackedVector2Array([Vector2(118, body_top + 2), Vector2(102, body_top + 22), Vector2(112, body_top + 30), Vector2(130, body_top + 8)]), Color("f6f0e0"), 2.2)
		"apron":
			_poly(PackedVector2Array([Vector2(66, body_top + 4), Vector2(134, body_top + 4), Vector2(138, 262), Vector2(62, 262)]), Color("faf5e6"), 2.4)
			_line(Vector2(66, body_top + 4), Vector2(82, body_top - 6), 2.2); _line(Vector2(134, body_top + 4), Vector2(118, body_top - 6), 2.2)
		"hood":
			_line(Vector2(92, body_top + 8), Vector2(90, body_top + 40), 2.2); _line(Vector2(108, body_top + 8), Vector2(110, body_top + 40), 2.2)
		_:
			_poly(PackedVector2Array(_ell(Vector2(100, body_top + 2), 18, 10, 0.0, 180.0, 10)), skin_sh, 2.2, false)

	# ears
	_dot(Vector2(c.x - rx + 1, c.y + 6), 9.5, skin, 2.4)
	_dot(Vector2(c.x + rx - 1, c.y + 6), 9.5, skin_sh, 2.4)
	# head
	var head := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0
		var jaw: float = 1.0 - 0.1 * float(t["jaw"]) * maxf(0.0, sin(a))
		head.append(Vector2(c.x + cos(a) * rx * (jaw if sin(a) > 0.0 else 1.0), c.y + sin(a) * ry))
	head.remove_at(head.size() - 1)
	_poly(head, skin, 4.0)
	# printed cel shadow on the shadow side: solid band + halftone dots
	var shadow := PackedVector2Array()
	shadow.append_array(_ell(c, rx - 1.0, ry - 1.0, -62.0, 78.0, 16))
	for i in 7:
		var a := deg_to_rad(lerpf(78.0, -62.0, float(i) / 6.0))
		shadow.append(Vector2(c.x + rx * (0.55 + 0.08 * sin(a * 2.0)), c.y + ry * sin(a) * 0.96))
	_fill(_scaled(shadow), skin_sh)
	_halftone(c, rx * 0.97, ry * 0.97, c.x + rx * 0.32, skin_sh, 6.0, 1.4)
	# redraw the head outline over the shadow
	var hl := _scaled(head); hl.append(hl[0])
	draw_polyline(hl, INK, _w(4.0), true)

	# face
	var eye_y := c.y + 2.0 - (5.0 if kid else 0.0)
	var gap := float(t["eye_gap"]) + (3.0 if kid else 0.0)
	var er := (6.0 if kid else 5.0) * float(ex["eye"]) ** 0.5
	for sx in [-1.0, 1.0]:
		var ec := Vector2(c.x + sx * gap, eye_y)
		if float(ex["eye"]) < 0.6:
			_line(ec + Vector2(-6, 0), ec + Vector2(6, 1.0), 3.0)      # heavy lids: tired
		else:
			draw_set_transform(_pt(ec), 0.0, Vector2(1.0, float(ex["eye"])))
			draw_circle(Vector2.ZERO, er * _u * 1.12, INK)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(_pt(ec + Vector2(1.4, -1.6) * float(ex["eye"])), 1.3 * _u, PAPER)
		# brow: a short line; worried lifts the inner end, cross drops it
		var tilt: float = float(ex["brow"])
		var by := eye_y - 14.0 - (3.0 if float(ex["eye"]) > 1.1 else 0.0)
		_line(Vector2(c.x + sx * (gap + 7.0), by + tilt * 3.0), Vector2(c.x + sx * (gap - 7.0), by - tilt * 5.0), 3.0 if not t["elder"] else 2.6, hair.darkened(0.35))
		if float(ex["blush"]) > 0.2:
			draw_circle(_pt(Vector2(c.x + sx * (gap + 9.0), eye_y + 14.0)), 6.0 * _u, Color(0.9, 0.38, 0.35, 0.22 * float(ex["blush"])))
	# nose
	var nx := c.x + 1.0
	var ny := eye_y + 15.0
	match int(t["nose"]):
		0: draw_polyline(_scaled(PackedVector2Array([Vector2(nx, ny - 6), Vector2(nx - 2, ny + 3), Vector2(nx + 4, ny + 4)])), INK, _w(1.9), true)
		1: draw_arc(_pt(Vector2(nx, ny + 2)), 5.0 * _u, 0.3, 2.9, 8, INK, _w(1.9), true)
		_: _line(Vector2(nx + 1, ny - 4), Vector2(nx + 1, ny + 4), 2.0)
	# mouth
	var my := eye_y + 34.0
	var curve: float = float(ex["mouth"])
	var mw := 13.0
	var mpts := PackedVector2Array()
	for i in 9:
		var f := float(i) / 8.0
		var u2 := 2.0 * f - 1.0
		mpts.append(Vector2(c.x + u2 * mw, my - curve * 1.5 + curve * 6.5 * (1.0 - u2 * u2)))
	draw_polyline(_scaled(mpts), INK, _w(2.4), true)
	if curve > 0.8:
		_poly(PackedVector2Array([Vector2(c.x - 9, my + 1), Vector2(c.x + 9, my + 1), Vector2(c.x + 6, my + 8), Vector2(c.x - 6, my + 8)]), Color("f6f0e0"), 1.6)
	# age lines
	if t["elder"]:
		_line(Vector2(c.x - gap - 8, eye_y + 9), Vector2(c.x - gap + 4, eye_y + 11), 1.5)
		_line(Vector2(c.x + gap + 8, eye_y + 9), Vector2(c.x + gap - 4, eye_y + 11), 1.5)
		_line(Vector2(c.x - 14, my - 9), Vector2(c.x - 18, my + 2), 1.5)
		_line(Vector2(c.x + 14, my - 9), Vector2(c.x + 18, my + 2), 1.5)
	# facial hair
	if int(t["beard"]) > 0:
		var bd := PackedVector2Array()
		bd.append_array(_ell(Vector2(c.x, c.y + 14), rx * 0.95, ry * 0.8, 10.0, 170.0, 14))
		bd.append(Vector2(c.x - 18, my + 4)); bd.append(Vector2(c.x, my - 4)); bd.append(Vector2(c.x + 18, my + 4))
		if int(t["beard"]) == 1:
			_fill(_scaled(bd), Color(hair.r, hair.g, hair.b, 0.35))
		else:
			_poly(bd, hair, 3.0)
			_poly(PackedVector2Array(_ell(Vector2(c.x, my - 3), 16, 6, 0.0, 180.0, 8)), skin, 0.0)
			draw_polyline(_scaled(mpts), INK, _w(2.4), true)
	# glasses
	if t["glasses"]:
		for sx in [-1.0, 1.0]:
			draw_arc(_pt(Vector2(c.x + sx * gap, eye_y)), 11.5 * _u, 0.0, TAU, 20, INK, _w(2.6), true)
		_line(Vector2(c.x - gap + 11.5, eye_y), Vector2(c.x + gap - 11.5, eye_y), 2.4)
		_line(Vector2(c.x - gap - 11.5, eye_y), Vector2(c.x - rx + 2, eye_y - 2), 2.0)
		_line(Vector2(c.x + gap + 11.5, eye_y), Vector2(c.x + rx - 2, eye_y - 2), 2.0)

	# front hair
	var cap_out := _ell(c, rx + 4.0, ry + 5.0, 188.0, 352.0, 22)
	var fr := PackedVector2Array()
	var fringe_y := c.y - ry * 0.52
	match style:
		"crop":
			fr = _cap(c, rx, ry, cap_out, [Vector2(c.x + rx - 3, c.y - 14), Vector2(c.x + 26, fringe_y + 5), Vector2(c.x, fringe_y + 1), Vector2(c.x - 24, fringe_y + 6), Vector2(c.x - rx + 3, c.y - 14)])
		"side":
			fr = _cap(c, rx, ry, cap_out, [Vector2(c.x + rx - 3, c.y - 12), Vector2(c.x + 24, fringe_y - 2), Vector2(c.x - 4, fringe_y + 14), Vector2(c.x - 26, fringe_y + 18), Vector2(c.x - rx + 2, c.y - 2)])
		"long", "bob", "ponytail":
			fr = _cap(c, rx, ry, cap_out, [Vector2(c.x + rx - 2, c.y + 4), Vector2(c.x + 22, fringe_y + 6), Vector2(c.x, fringe_y + 10), Vector2(c.x - 22, fringe_y + 6), Vector2(c.x - rx + 2, c.y + 4)])
		"bun":
			fr = _cap(c, rx, ry, cap_out, [Vector2(c.x + rx - 3, c.y - 12), Vector2(c.x + 20, fringe_y + 3), Vector2(c.x, fringe_y), Vector2(c.x - 20, fringe_y + 3), Vector2(c.x - rx + 3, c.y - 12)])
			_dot(Vector2(c.x, c.y - ry - 12), 17.0, hair, 3.4)
		"curls":
			for i in 11:
				var a := deg_to_rad(lerpf(188.0, 352.0, float(i) / 10.0))
				_dot(Vector2(c.x + cos(a) * (rx + 4.0), c.y + sin(a) * (ry + 5.0)), 13.5, hair, 3.0)
			fr = _cap(c, rx, ry, cap_out, [Vector2(c.x + rx - 4, c.y - 16), Vector2(c.x + 20, fringe_y + 2), Vector2(c.x, fringe_y - 2), Vector2(c.x - 20, fringe_y + 2), Vector2(c.x - rx + 4, c.y - 16)])
		"bald":
			if t["elder"]:
				_poly(PackedVector2Array(_ell(c, rx + 2.0, ry * 0.8, 160.0, 205.0, 5)), hair, 2.4, false)
	if fr.size() > 2:
		_poly(fr, hair, 3.6)
		# hair cel shadow, printed
		var hs := PackedVector2Array()
		for p in fr:
			if p.x > c.x + 12.0:
				hs.append(p)
		if hs.size() > 2:
			_fill(_scaled(hs), hair.darkened(0.28))
			var fl := _scaled(fr); fl.append(fl[0])
			draw_polyline(fl, INK, _w(3.6), true)
	# hats
	match t["hat"]:
		"cap":
			_poly(PackedVector2Array(_ell(c, rx + 6, ry * 0.78, 180.0, 360.0, 18)), Color("2f8f9d"), 3.6)
			_poly(PackedVector2Array([Vector2(c.x - 6, c.y - ry * 0.74), Vector2(c.x + rx + 18, c.y - ry * 0.52), Vector2(c.x + rx + 8, c.y - ry * 0.4), Vector2(c.x - 6, c.y - ry * 0.46)]), Color("266f7a"), 3.0)
		"sun":
			_poly(PackedVector2Array([Vector2(c.x - rx - 30, c.y - ry * 0.5), Vector2(c.x - rx + 10, c.y - ry * 0.72), Vector2(c.x + rx - 10, c.y - ry * 0.72), Vector2(c.x + rx + 30, c.y - ry * 0.5), Vector2(c.x + rx, c.y - ry * 0.42), Vector2(c.x - rx, c.y - ry * 0.42)]), Color("e0c27a"), 3.6)
			_poly(PackedVector2Array(_ell(Vector2(c.x, c.y - ry * 0.7), rx * 0.66, ry * 0.4, 180.0, 360.0, 14)), Color("d4b266"), 3.2)
		"band":
			_poly(PackedVector2Array([Vector2(c.x - rx - 1, c.y - ry * 0.42), Vector2(c.x + rx + 1, c.y - ry * 0.42), Vector2(c.x + rx + 1, c.y - ry * 0.26), Vector2(c.x - rx - 1, c.y - ry * 0.26)]), Color("e23d3d"), 3.0)


## The visible hair cap: the outer arc over the head, closed by a fringe line.
func _cap(c: Vector2, rx: float, ry: float, outer: PackedVector2Array, inner: Array) -> PackedVector2Array:
	var out := PackedVector2Array(outer)
	for i in range(inner.size() - 1, -1, -1):
		out.append(inner[i])
	return out


# ------------------------------------------------------------------ a tiny head for the map
static func draw_token(ci: CanvasItem, pos: Vector2, r: float, tr: Dictionary, ring: bool = false) -> void:
	ci.draw_circle(pos, r, tr["skin"])
	var hair: Color = tr["hair"]
	if tr["style"] != "bald":
		ci.draw_arc(pos, r * 0.78, deg_to_rad(185.0), deg_to_rad(355.0), 10, hair, r * 0.62, true)
	ci.draw_arc(pos, r, 0.0, TAU, 16, INK, maxf(1.2, r * 0.22), true)
	ci.draw_circle(pos + Vector2(-r * 0.32, r * 0.1), maxf(0.7, r * 0.1), INK)
	ci.draw_circle(pos + Vector2(r * 0.32, r * 0.1), maxf(0.7, r * 0.1), INK)
	if ring:
		ci.draw_arc(pos, r * 1.35, 0.0, TAU, 22, Color("f5b82e"), maxf(2.0, r * 0.3), true)
