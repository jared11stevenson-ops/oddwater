extends RefCounted
## Composite props baked once into single meshes with vertex colour: trees, shrubs, grass tufts, reeds, rocks, cars, boats. Each is one
## MultiMesh-able mesh instead of a pile of nodes. Everything is deterministic.

const Merge = preload("res://scripts/world3d/merger.gd")

static var _meshes: Dictionary = {}


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m = Merge.new()
	m.cell = 1.0e9
	match kind:
		"oak": _oak(m, false)
		"oak2": _oak(m, true)
		"maple": _maple(m)
		"pine": _pine(m)
		"poplar": _poplar(m)
		"fir_far": _fir_far(m)
		"bush": _bush(m)
		"tuft": _tuft(m, 0.38, 6)
		"tall_tuft": _tuft(m, 0.8, 7)
		"reed": _reed(m)
		"rock": _rock(m)
		"puff": m.blob(Vector3.ZERO, Vector3(0.5, 0.45, 0.5), Color.WHITE, 5)
	var am: ArrayMesh = m.to_mesh()
	_meshes[kind] = am
	return am


static func _trunk(m, h: float, r0: float, r1: float, col: Color, sides: int = 6) -> void:
	m.add("taper:%d" % sides, Transform3D(Basis.from_scale(Vector3(r0 * 2.0, h, r0 * 2.0)), Vector3(0, h * 0.5, 0)), col)
	m.add("cyl:%d" % sides, Transform3D(Basis.from_scale(Vector3(r0 * 2.35, 0.35, r0 * 2.35)), Vector3(0, 0.17, 0)), col.darkened(0.2))     # root flare


static func _oak(m, wide: bool) -> void:
	_trunk(m, 2.7, 0.24, 0.14, Color("6e4f33"))
	var s := 1.18 if wide else 1.0
	m.blob(Vector3(0, 3.05, 0), Vector3(4.2, 1.9, 4.2) * s, Color("3f7a3c"), 7)                           # shaded underside
	m.blob(Vector3(0.1, 4.25, 0.0), Vector3(4.7, 3.5, 4.5) * s, Color("5e9a45"), 7)
	m.blob(Vector3(1.4 * s, 3.8, 0.7), Vector3(2.9, 2.5, 2.8) * s, Color("6aa84f"), 6)
	m.blob(Vector3(-1.3 * s, 4.0, -0.8), Vector3(2.8, 2.5, 2.7) * s, Color("4f8f45"), 6)
	m.blob(Vector3(0.2, 5.55, 0.2), Vector3(2.8, 2.1, 2.7) * s, Color("7bb85c"), 6)
	m.blob(Vector3(-0.6, 4.6, 1.3 * s), Vector3(2.2, 1.9, 2.2) * s, Color("63a24c"), 5)


static func _maple(m) -> void:
	_trunk(m, 3.4, 0.2, 0.12, Color("8a7a66"))
	m.blob(Vector3(0, 4.3, 0), Vector3(3.2, 2.8, 3.2), Color("c98a32"), 7)
	m.blob(Vector3(0.9, 5.2, 0.3), Vector3(2.4, 2.4, 2.4), Color("d9a63e"), 6)
	m.blob(Vector3(-0.8, 5.4, -0.4), Vector3(2.2, 2.3, 2.2), Color("b8742b"), 6)
	m.blob(Vector3(0.1, 6.4, 0), Vector3(1.9, 1.8, 1.9), Color("e0b64a"), 5)
	m.blob(Vector3(0, 3.4, 0), Vector3(2.8, 1.2, 2.8), Color("8a5a24"), 6)


static func _pine(m) -> void:
	_trunk(m, 2.0, 0.2, 0.12, Color("5b402b"))
	var cols := [Color("2f6a42"), Color("37764a"), Color("3f8250"), Color("4a8f59")]
	for i in 4:
		var w := 4.0 - i * 0.85
		m.add("cone:7", Transform3D(Basis.from_scale(Vector3(w, 2.2, w)), Vector3(0, 2.2 + i * 1.35, 0)), cols[i])
	m.add("cone:6", Transform3D(Basis.from_scale(Vector3(0.9, 1.6, 0.9)), Vector3(0, 7.6, 0)), Color("56a062"))


static func _poplar(m) -> void:
	_trunk(m, 1.8, 0.16, 0.1, Color("7a6a55"))
	m.blob(Vector3(0, 3.4, 0), Vector3(2.2, 3.4, 2.2), Color("5a9a48"), 6)
	m.blob(Vector3(0, 5.6, 0), Vector3(2.0, 3.4, 2.0), Color("6aa854"), 6)
	m.blob(Vector3(0, 7.5, 0), Vector3(1.5, 2.6, 1.5), Color("78b45e"), 5)


static func _fir_far(m) -> void:       # a cheap tree for the far hills
	m.add("taper:5", Transform3D(Basis.from_scale(Vector3(0.5, 2.0, 0.5)), Vector3(0, 1.0, 0)), Color("5b402b"))
	m.add("cone:5", Transform3D(Basis.from_scale(Vector3(3.6, 4.2, 3.6)), Vector3(0, 3.6, 0)), Color("33714a"))
	m.add("cone:5", Transform3D(Basis.from_scale(Vector3(2.6, 3.4, 2.6)), Vector3(0, 5.9, 0)), Color("3f8250"))


static func _bush(m) -> void:
	m.blob(Vector3(0, 0.42, 0), Vector3(1.5, 0.95, 1.4), Color("4f8a43"), 6)
	m.blob(Vector3(0.45, 0.6, 0.1), Vector3(1.0, 0.85, 1.0), Color("62a04c"), 6)
	m.blob(Vector3(-0.4, 0.5, -0.2), Vector3(0.95, 0.8, 0.95), Color("5a9648"), 5)


static func _rock(m) -> void:
	m.blob(Vector3(0, 0.35, 0), Vector3(1.6, 0.95, 1.3), Color("8d908c"), 5, 0.4)
	m.blob(Vector3(0.5, 0.2, 0.3), Vector3(0.9, 0.55, 0.8), Color("a2a49d"), 5, 1.2)
	m.blob(Vector3(-0.5, 0.25, -0.2), Vector3(0.8, 0.6, 0.7), Color("7c7f7b"), 4, 2.0)


static func _tuft(m, h: float, blades: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + blades
	for i in blades:
		var a := TAU * float(i) / blades + rng.randf() * 0.6
		var r := rng.randf_range(0.02, 0.1)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var tang := Vector3(-sin(a), 0, cos(a))
		var hh := h * rng.randf_range(0.7, 1.15)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.04, 0.2) * hh * 2.0
		var w := 0.035 * (1.0 + h)
		var tip := base + lean + Vector3(0, hh, 0)
		m.tri_c(base - tang * w, base + tang * w, tip, Color("3a6a2c"), Color("3a6a2c"), Color("a6d06a"))


static func _reed(m) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf() * 0.5
		var r := rng.randf_range(0.0, 0.28)
		var base := Vector3(cos(a) * r, -0.1, sin(a) * r)
		var tang := Vector3(-sin(a), 0, cos(a))
		var hh := rng.randf_range(1.2, 2.0)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.5)
		var tip := base + lean + Vector3(0, hh, 0)
		var w := 0.05
		m.tri_c(base - tang * w, base + tang * w, tip, Color("4a6a2a"), Color("4a6a2a"), Color("b3c47a"))
		if i % 3 == 0:     # a cattail
			var hp := base + lean * 0.8 + Vector3(0, hh * 0.78, 0)
			m.add("cyl:5", Transform3D(Basis.from_scale(Vector3(0.09, 0.3, 0.09)), hp), Color("6b4423"))


# ------------------------------------------------------------------ vehicles and boats (added into a merger at a place)
static func car(m, pos: Vector3, yaw: float, body: Color, police: bool = false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var dark := Color("1f2530")
	m.add("box", Transform3D(b * Basis.from_scale(Vector3(1.8, 0.62, 4.3)), pos + b * Vector3(0, 0.62, 0)), body)
	m.add("box", Transform3D(b * Basis.from_scale(Vector3(1.64, 0.55, 2.25)), pos + b * Vector3(0, 1.17, -0.1)), dark)                  # glass
	m.add("box", Transform3D(b * Basis.from_scale(Vector3(1.6, 0.1, 2.1)), pos + b * Vector3(0, 1.48, -0.1)), body.darkened(0.05))      # roof
	if police:
		m.add("box", Transform3D(b * Basis.from_scale(Vector3(1.84, 0.34, 1.2)), pos + b * Vector3(0, 0.78, 0.0)), Color("f2f2f2"))     # white doors
	for sx in [-1.0, 1.0]:
		for sz in [-1.4, 1.4]:
			m.add("cyl:8", Transform3D(b * Basis(Vector3(0, 0, 1), PI / 2.0) * Basis.from_scale(Vector3(0.72, 0.24, 0.72)), pos + b * Vector3(sx * 0.9, 0.36, sz)), Color("17171b"))
		m.add("box", Transform3D(b * Basis.from_scale(Vector3(0.3, 0.14, 0.06)), pos + b * Vector3(sx * 0.6, 0.7, -2.16)), Color("fff2c8"))
		m.add("box", Transform3D(b * Basis.from_scale(Vector3(0.3, 0.14, 0.06)), pos + b * Vector3(sx * 0.6, 0.7, 2.16)), Color("c0392b"))


static func boat(m, pos: Vector3, yaw: float, hull: Color, length: float = 4.0, sail: bool = false) -> void:
	var b := Basis(Vector3.UP, yaw)
	m.add("sphere:8", Transform3D(b * Basis.from_scale(Vector3(length * 0.36, 0.7, length)), pos + b * Vector3(0, 0.0, 0)), hull)
	m.add("sphere:8", Transform3D(b * Basis.from_scale(Vector3(length * 0.28, 0.2, length * 0.8)), pos + b * Vector3(0, 0.22, 0)), hull.lightened(0.5))   # inner rim
	m.add("box", Transform3D(b * Basis.from_scale(Vector3(length * 0.3, 0.07, 0.3)), pos + b * Vector3(0, 0.3, length * 0.1)), Color("9a7a54"))
	if sail:
		m.add("taper:5", Transform3D(b * Basis.from_scale(Vector3(0.14, 5.6, 0.14)), pos + b * Vector3(0, 2.8, -length * 0.12)), Color("d9d4c4"))
		var a := pos + b * Vector3(0, 0.9, -length * 0.12)
		var c := pos + b * Vector3(0, 5.3, -length * 0.12)
		var d := pos + b * Vector3(0, 0.9, length * 0.38)
		m.tri(a, c, d, Color("f4efe2"))
		m.tri(a, d, c, Color("f4efe2"))
