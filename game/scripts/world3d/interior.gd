extends Node3D
## A small furnished room, shown behind the panel when you step into a place. It is built from the same merged-box kit as the town
## (one mesh for solids, one for glass and lit things, one warm light), at a spot high above the map so nothing else is in view. One room
## per kind of place: a home, a bar, a shop, a library, a school, a clinic, a chapel, an office, a hall. The crime scene gets its
## chalk outline, evidence markers and tape. Everything is deterministic from the lot id.

const Merge = preload("res://scripts/world3d/merger.gd")

const W := 7.4          # x
const D := 6.2          # z
const H := 2.9

var style := "home"
var cam_pos := Vector3(3.0, 1.62, 2.55)        # local to the room
var cam_look := Vector3(-1.9, 0.85, -2.1)
var light: OmniLight3D
var lamp_light: OmniLight3D
var _m: RefCounted      # solids
var _g: RefCounted      # glass and lit things
var _rng := RandomNumberGenerator.new()
var _glass_mat: StandardMaterial3D
var _lit_mat: StandardMaterial3D
var _night := 0.0


static func style_for(lot_id: String, kind: String) -> String:
	if kind in ["house", "home"] or lot_id.ends_with("_home"):
		return "home"
	match lot_id:
		"low_water", "pink_heron":
			return "bar"
		"bait_shop", "hardware", "clock_shop", "rising_loaf", "paws_reflect", "funeral_home", "marina", "launch_quay":
			return "shop"
		"library":
			return "library"
		"school":
			return "school"
		"clinic", "pell_dentistry":
			return "clinic"
		"chapel":
			return "chapel"
		"sheriff", "post_office", "town_hall", "wmrc", "dam_house":
			return "office"
		_:
			return "hall"


func build(lot_id: String, kind: String, solid_mat: Material, scene: bool) -> void:
	name = "Interior"
	style = style_for(lot_id, kind)
	_rng.seed = hash(lot_id)
	_m = Merge.new()
	_m.cell = 1.0e9
	_g = Merge.new()
	_g.cell = 1.0e9
	var pal := _palette()
	_shell(pal)
	match style:
		"home": _home(pal)
		"bar": _bar(pal)
		"shop": _shop(pal, lot_id)
		"library": _library(pal)
		"school": _school(pal)
		"clinic": _clinic(pal)
		"chapel": _chapel(pal)
		"office": _office(pal, lot_id)
		_: _hall(pal)
	if scene:
		_crime_scene()
	var mi := MeshInstance3D.new()
	mi.mesh = _m.to_mesh()
	mi.material_override = solid_mat
	mi.name = "Room"
	add_child(mi)
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glass_mat.vertex_color_use_as_albedo = true
	_glass_mat.vertex_color_is_srgb = true
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gi := MeshInstance3D.new()
	gi.mesh = _g.to_mesh()
	gi.material_override = _glass_mat
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi.name = "Lit"
	add_child(gi)
	light = OmniLight3D.new()
	light.omni_range = 14.0
	light.omni_attenuation = 1.2
	light.light_color = Color(1.0, 0.88, 0.66)
	light.position = Vector3(0.4, H - 0.5, 0.2)
	light.shadow_enabled = false
	add_child(light)
	lamp_light = OmniLight3D.new()
	lamp_light.omni_range = 7.0
	lamp_light.light_color = Color(1.0, 0.78, 0.45)
	lamp_light.position = Vector3(-2.6, 1.3, -2.2)
	lamp_light.shadow_enabled = false
	add_child(lamp_light)
	set_night(0.0)


## Day: grey-blue light through the windows and a modest lamp. Night: dark panes, a warmer, stronger lamp.
func set_night(n: float) -> void:
	_night = n
	if light != null:
		light.light_energy = lerpf(2.4, 1.5, n)
		lamp_light.light_energy = lerpf(1.0, 2.6, n)
	if _glass_mat != null:
		_glass_mat.albedo_color = Color(1, 1, 1).lerp(Color(0.25, 0.28, 0.4), n)


# ------------------------------------------------------------------ the shell
func _palette() -> Dictionary:
	var p := {
		"home": {"wall": "d9c8a6", "floor": "8a6a46", "trim": "efe6d2", "accent": "7a8f6a"},
		"bar": {"wall": "6a3b34", "floor": "4a3322", "trim": "2c1d16", "accent": "d9a441"},
		"shop": {"wall": "c9bfa4", "floor": "7d6a52", "trim": "f0ead8", "accent": "b5533c"},
		"library": {"wall": "b9a67f", "floor": "6b4e34", "trim": "3a2b1e", "accent": "5d7a5a"},
		"school": {"wall": "d6d2b4", "floor": "9a8460", "trim": "f0efe0", "accent": "3f6b52"},
		"clinic": {"wall": "d9e2de", "floor": "b8c2bd", "trim": "f6f8f6", "accent": "4f9a8a"},
		"chapel": {"wall": "e3dccb", "floor": "6e5238", "trim": "ffffff", "accent": "7a2f3a"},
		"office": {"wall": "b7b9a0", "floor": "70624e", "trim": "e8e4d4", "accent": "35507a"},
		"hall": {"wall": "c8b690", "floor": "7e6244", "trim": "ede2c8", "accent": "9a3f3a"}}
	return p[style]


func _c(hex: String, jitter: float = 0.0) -> Color:
	var c := Color(hex)
	if jitter > 0.0:
		var k := 1.0 + _rng.randf_range(-jitter, jitter)
		c = Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))
	return c


func _shell(pal: Dictionary) -> void:
	var wall := _c(pal["wall"])
	var trim := _c(pal["trim"])
	_m.box(Vector3(0, -0.06, 0), Vector3(W + 0.6, 0.12, D + 0.6), _c(pal["floor"]), 0.2)
	_m.box(Vector3(0, H + 0.08, 0), Vector3(W + 0.6, 0.16, D + 0.6), _c("e8e2d2"), 1.0)
	_m.box(Vector3(0, H * 0.5, -D * 0.5 - 0.08), Vector3(W + 0.6, H, 0.16), wall, 0.7)
	_m.box(Vector3(0, H * 0.5, D * 0.5 + 0.08), Vector3(W + 0.6, H, 0.16), wall, 0.7)
	_m.box(Vector3(-W * 0.5 - 0.08, H * 0.5, 0), Vector3(0.16, H, D), wall, 0.7)
	_m.box(Vector3(W * 0.5 + 0.08, H * 0.5, 0), Vector3(0.16, H, D), wall, 0.7)
	# skirting and a picture rail
	_m.box(Vector3(0, 0.07, -D * 0.5 + 0.03), Vector3(W, 0.14, 0.06), trim, 1.0)
	_m.box(Vector3(-W * 0.5 + 0.03, 0.07, 0), Vector3(0.06, 0.14, D), trim, 1.0)
	_m.box(Vector3(W * 0.5 - 0.03, 0.07, 0), Vector3(0.06, 0.14, D), trim, 1.0)
	_m.box(Vector3(0, H - 0.2, -D * 0.5 + 0.03), Vector3(W, 0.05, 0.06), trim, 1.0)
	# a rug
	var rug := _c(pal["accent"])
	_m.box(Vector3(-0.4, 0.015, -0.2), Vector3(3.6, 0.03, 2.6), rug, 1.0)
	_m.box(Vector3(-0.4, 0.032, -0.2), Vector3(3.2, 0.02, 2.2), rug.lightened(0.18), 1.0)
	# windows: two on the back wall, one on the left. Frames are solid, panes are lit.
	for wx in [-1.9, 1.7]:
		_window(Vector3(wx, 1.55, -D * 0.5 + 0.02), 0.0)
	_window(Vector3(-W * 0.5 + 0.02, 1.55, 0.2), PI * 0.5)
	# the door in the right wall
	_m.box(Vector3(W * 0.5 - 0.05, 1.05, 1.9), Vector3(0.1, 2.1, 1.0), _c("5a4026"), 0.2)
	_m.box(Vector3(W * 0.5 - 0.1, 1.05, 1.9), Vector3(0.04, 2.2, 1.14), trim, 1.0)
	_m.box(Vector3(W * 0.5 - 0.12, 1.0, 1.55), Vector3(0.06, 0.06, 0.12), _c("c9a84a"), 0.1)


func _window(p: Vector3, yaw: float) -> void:
	var trim := Color("f0ead8")
	var ca := Vector3(1.0, 0.0, 0.0) if absf(yaw) < 0.1 else Vector3(0.0, 0.0, 1.0)
	_m.box(p, ca * 1.36 + Vector3(0.05, 1.26, 0.05) * (Vector3.ONE - ca), trim, 1.0)
	_g.box(p + (Vector3(0, 0, 0.012) if absf(yaw) < 0.1 else Vector3(0.012, 0, 0)), ca * 1.2 + Vector3(0.02, 1.1, 0.02) * (Vector3.ONE - ca), Color("bcd2e6"), 1.0)
	_m.box(p + (Vector3(0, 0, 0.03) if absf(yaw) < 0.1 else Vector3(0.03, 0, 0)), ca * 0.05 + Vector3(0.04, 1.1, 0.04) * (Vector3.ONE - ca), trim, 1.0)
	_m.box(p + (Vector3(0, 0, 0.03) if absf(yaw) < 0.1 else Vector3(0.03, 0, 0)), ca * 1.2 + Vector3(0.04, 0.05, 0.04) * (Vector3.ONE - ca), trim, 1.0)


# ------------------------------------------------------------------ furniture
func _table(c: Vector3, sx: float, sz: float, col: Color, h: float = 0.76) -> void:
	_m.box(c + Vector3(0, h, 0), Vector3(sx, 0.07, sz), col, 0.2)
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			_m.box(c + Vector3(dx * (sx * 0.5 - 0.07), h * 0.5, dz * (sz * 0.5 - 0.07)), Vector3(0.07, h, 0.07), col.darkened(0.25), 0.2)


func _chair(c: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	_m.box(c + b * Vector3(0, 0.45, 0), Vector3(0.44, 0.06, 0.44), col, 0.2, yaw)
	_m.box(c + b * Vector3(0, 0.78, -0.2), Vector3(0.44, 0.6, 0.05), col, 0.2, yaw)
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			_m.box(c + b * Vector3(dx * 0.19, 0.22, dz * 0.19), Vector3(0.05, 0.44, 0.05), col.darkened(0.2), 0.2, yaw)


func _shelf(c: Vector3, sx: float, sy: float, yaw: float, books: bool = true, depth: float = 0.34) -> void:
	var wood := _c("6b4a2e")
	var b := Basis(Vector3.UP, yaw)
	_m.box(c + b * Vector3(0, sy * 0.5, 0), Vector3(sx, sy, depth), wood.darkened(0.2), 0.2, yaw)
	var rows := int(sy / 0.42)
	for r in rows:
		var y := 0.2 + float(r) * 0.4
		_m.box(c + b * Vector3(0, y + 0.19, 0.02), Vector3(sx - 0.08, 0.34, depth - 0.06), wood.darkened(0.45), 1.0, yaw)
		if books:
			var x := -sx * 0.5 + 0.1
			while x < sx * 0.5 - 0.12:
				var bw := _rng.randf_range(0.04, 0.09)
				var bh := _rng.randf_range(0.2, 0.32)
				var col := Color.from_hsv(_rng.randf(), _rng.randf_range(0.35, 0.65), _rng.randf_range(0.35, 0.7))
				_m.box(c + b * Vector3(x + bw * 0.5, y + bh * 0.5, 0.06), Vector3(bw, bh, depth - 0.12), col, 1.0, yaw)
				x += bw + 0.005


func _bed(c: Vector3, yaw: float, sheet: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	_m.box(c + b * Vector3(0, 0.25, 0), Vector3(1.0, 0.3, 2.1), _c("6b4a2e"), 0.2, yaw)
	_m.box(c + b * Vector3(0, 0.48, 0.05), Vector3(0.92, 0.18, 1.95), sheet, 1.0, yaw)
	_m.box(c + b * Vector3(0, 0.62, -0.78), Vector3(0.62, 0.12, 0.34), Color("f4efe4"), 1.0, yaw)
	_m.box(c + b * Vector3(0, 0.55, 0.45), Vector3(0.94, 0.06, 1.0), sheet.darkened(0.2), 1.0, yaw)
	_m.box(c + b * Vector3(0, 0.7, -1.08), Vector3(1.0, 0.9, 0.08), _c("6b4a2e"), 0.2, yaw)


func _lamp(c: Vector3, h: float = 0.55) -> void:
	_m.cyl(c + Vector3(0, h * 0.5, 0), 0.025, h, _c("3a3028"), 6, 0.1)
	_m.cyl(c + Vector3(0, 0.03, 0), 0.1, 0.05, _c("3a3028"), 8, 0.1)
	_g.cyl(c + Vector3(0, h + 0.1, 0), 0.14, 0.24, Color("ffd890"), 8, 1.0)


func _plant(c: Vector3) -> void:
	_m.cyl(c + Vector3(0, 0.18, 0), 0.17, 0.36, _c("a8643c"), 8, 0.5)
	for k in 5:
		var a := float(k) / 5.0 * TAU
		_m.blob(c + Vector3(cos(a) * 0.12, 0.62 + _rng.randf() * 0.2, sin(a) * 0.12), Vector3(0.3, 0.42, 0.3), _c("4d7a3a", 0.2), 6)


func _sofa(c: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	_m.box(c + b * Vector3(0, 0.28, 0), Vector3(1.9, 0.34, 0.85), col, 1.0, yaw)
	_m.box(c + b * Vector3(0, 0.62, -0.34), Vector3(1.9, 0.5, 0.2), col.darkened(0.1), 1.0, yaw)
	for dx in [-1, 1]:
		_m.box(c + b * Vector3(dx * 0.92, 0.45, 0.0), Vector3(0.18, 0.5, 0.85), col.darkened(0.15), 1.0, yaw)


func _frame(c: Vector3, yaw: float, sx: float, sy: float, col: Color) -> void:
	_m.box(c, Vector3(sx + 0.08, sy + 0.08, 0.05) if absf(yaw) < 0.1 else Vector3(0.05, sy + 0.08, sx + 0.08), _c("3a2b1e"), 0.2)
	var off := Vector3(0, 0, 0.03) if absf(yaw) < 0.1 else Vector3(0.03, 0, 0)
	_m.box(c + off, Vector3(sx, sy, 0.03) if absf(yaw) < 0.1 else Vector3(0.03, sy, sx), col, 1.0)


# ------------------------------------------------------------------ the rooms
func _home(pal: Dictionary) -> void:
	var acc := _c(pal["accent"])
	_bed(Vector3(-2.6, 0.0, 1.5), 0.0, acc.lightened(0.1))
	_m.box(Vector3(-1.75, 0.28, 0.65), Vector3(0.4, 0.56, 0.4), _c("6b4a2e"), 0.2)
	_lamp(Vector3(-1.75, 0.56, 0.65), 0.34)
	_table(Vector3(1.4, 0, 0.9), 1.3, 0.8, _c("8a5e38"))
	_chair(Vector3(0.75, 0, 0.9), PI * 0.5, _c("8a5e38"))
	_chair(Vector3(2.05, 0, 0.9), -PI * 0.5, _c("8a5e38"))
	_m.cyl(Vector3(1.4, 0.83, 0.9), 0.12, 0.1, Color("e8e2d4"), 8, 0.5)
	_sofa(Vector3(0.2, 0, -2.4), 0.0, acc.darkened(0.15))
	_shelf(Vector3(2.7, 0, -2.9), 1.5, 2.0, 0.0)
	_lamp(Vector3(-1.1, 0.0, -2.5), 1.25)
	_plant(Vector3(-3.1, 0, -2.6))
	_frame(Vector3(0.2, 1.75, -D * 0.5 + 0.05), 0.0, 0.9, 0.6, _c("b4906a"))
	# a kitchen run along the right wall
	_m.box(Vector3(W * 0.5 - 0.4, 0.45, -0.8), Vector3(0.6, 0.9, 2.0), _c("e6e0d0"), 1.0)
	_m.box(Vector3(W * 0.5 - 0.4, 0.92, -0.8), Vector3(0.64, 0.05, 2.04), _c("5c5348"), 1.0)


func _bar(pal: Dictionary) -> void:
	var wood := _c("5b3a24")
	_m.box(Vector3(0.2, 0.55, -1.5), Vector3(4.6, 1.1, 0.7), wood, 0.2)
	_m.box(Vector3(0.2, 1.12, -1.5), Vector3(4.8, 0.08, 0.85), wood.lightened(0.15), 0.2)
	for k in 5:
		var sx := -1.7 + float(k) * 0.95
		_m.cyl(Vector3(sx + 0.2, 0.34, -0.8), 0.17, 0.05, _c("a4302c"), 8, 0.1)
		_m.cyl(Vector3(sx + 0.2, 0.17, -0.8), 0.04, 0.34, _c("2a2622"), 6, 0.1)
	_m.box(Vector3(0.2, 1.5, -D * 0.5 + 0.28), Vector3(4.6, 0.06, 0.4), wood, 0.2)
	_m.box(Vector3(0.2, 1.9, -D * 0.5 + 0.28), Vector3(4.6, 0.06, 0.4), wood, 0.2)
	for row in [1.53, 1.93]:
		for k in 14:
			var col := Color.from_hsv(_rng.randf(), 0.5, _rng.randf_range(0.4, 0.8))
			_m.cyl(Vector3(-1.9 + float(k) * 0.33, row + 0.14, -D * 0.5 + 0.28), 0.05, 0.28, col, 6, 0.1)
	_g.box(Vector3(0.2, 1.7, -D * 0.5 + 0.06), Vector3(4.2, 0.9, 0.02), Color("3a2a22"), 1.0)
	for k in 3:
		var tp := Vector3(-2.3 + float(k) * 1.9, 0, 1.5 - 0.5 * float(k % 2))
		_table(tp, 0.9, 0.9, wood.lightened(0.1), 0.74)
		_chair(tp + Vector3(0.75, 0, 0), -PI * 0.5, wood)
		_chair(tp + Vector3(-0.75, 0, 0), PI * 0.5, wood)
		_g.cyl(tp + Vector3(0, 0.84, 0), 0.04, 0.1, Color("ffcf70"), 6, 1.0)
	# a neon sign on the side wall
	_g.box(Vector3(W * 0.5 - 0.1, 2.0, -1.2), Vector3(0.04, 0.4, 1.4), Color("ff6a8a"), 1.0)
	_m.box(Vector3(W * 0.5 - 0.06, 2.0, -1.2), Vector3(0.04, 0.5, 1.5), _c("201a1a"), 1.0)


func _shop(pal: Dictionary, lot_id: String) -> void:
	var wood := _c("8a6a46")
	_m.box(Vector3(0.6, 0.5, 0.2), Vector3(3.4, 1.0, 0.7), wood, 0.2)
	_m.box(Vector3(0.6, 1.02, 0.2), Vector3(3.5, 0.06, 0.8), wood.lightened(0.2), 0.2)
	_m.box(Vector3(1.6, 1.18, 0.2), Vector3(0.4, 0.28, 0.34), _c("3a4a4a"), 0.1)     # a till
	var goods := {"rising_loaf": ["d9a05a", "c4783c", "efe0b8"], "hardware": ["8a8f94", "b5533c", "d9b84a"], "clock_shop": ["d9b84a", "7a5a30", "c9c4b0"],
		"bait_shop": ["4a6a8a", "8a6a46", "a4cc7a"], "funeral_home": ["efe8dc", "6b4a5a", "3a3a44"]}
	var tints: Array = goods.get(lot_id, ["b5533c", "4a7a8a", "d9b84a"])
	for sx in [-2.9, -1.2]:
		var sc := Vector3(sx, 0, -2.75)
		_m.box(sc + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 0.4), wood.darkened(0.3), 0.2)
		for r in 4:
			_m.box(sc + Vector3(0, 0.3 + float(r) * 0.45, 0.02), Vector3(1.3, 0.38, 0.34), wood.darkened(0.55), 1.0)
			for k in 5:
				var col := _c(tints[(r + k) % tints.size()], 0.25)
				var h := _rng.randf_range(0.14, 0.3)
				_m.box(sc + Vector3(-0.52 + float(k) * 0.26, 0.15 + float(r) * 0.45 + h * 0.5, 0.05), Vector3(0.2, h, 0.22), col, 1.0)
	if lot_id == "clock_shop":
		for k in 2:
			var cx := 2.6 + float(k) * 0.6
			_m.box(Vector3(cx, 1.0, -2.8), Vector3(0.45, 2.0, 0.35), _c("5b3a24"), 0.2)
			_g.cyl(Vector3(cx, 1.55, -2.6), 0.15, 0.03, Color("f4ecd0"), 12, 1.0)
	for k in 3:
		_m.box(Vector3(2.8 + float(k % 2) * 0.1, 0.22 + float(k) * 0.4, 1.6), Vector3(0.7, 0.4, 0.7), _c("a98a5c", 0.15), 0.2, 0.15 * float(k))
	_plant(Vector3(3.1, 0, 0.0))
	_g.box(Vector3(0.6, 2.2, -D * 0.5 + 0.06), Vector3(2.0, 0.5, 0.02), _c(pal["accent"]), 1.0)


func _library(pal: Dictionary) -> void:
	for k in 4:
		_shelf(Vector3(-2.9 + float(k) * 1.5, 0, -D * 0.5 + 0.3), 1.35, 2.3, 0.0)
	for k in 3:
		_shelf(Vector3(-W * 0.5 + 0.3, 0, -1.2 + float(k) * 1.4), 1.2, 2.2, PI * 0.5)
	_table(Vector3(0.8, 0, 0.6), 2.0, 0.9, _c("6b4a2e"))
	for k in 3:
		_chair(Vector3(0.1 + float(k) * 0.7, 0, 1.3), PI, _c("6b4a2e"))
	_lamp(Vector3(1.4, 0.8, 0.6), 0.4)
	for k in 3:
		_m.box(Vector3(0.1 + float(k) * 0.55, 0.82, 0.5), Vector3(0.28, 0.04, 0.2), Color.from_hsv(_rng.randf(), 0.4, 0.6), 1.0, _rng.randf_range(-0.3, 0.3))


func _school(pal: Dictionary) -> void:
	_m.box(Vector3(0.2, 1.5, -D * 0.5 + 0.03), Vector3(4.2, 1.2, 0.04), _c("2f4a3c"), 1.0)
	_m.box(Vector3(0.2, 0.88, -D * 0.5 + 0.1), Vector3(4.2, 0.04, 0.12), _c("c9c0a8"), 1.0)
	_table(Vector3(1.8, 0, -2.2), 1.5, 0.7, _c("8a6a46"))
	_chair(Vector3(1.8, 0, -2.9), 0.0, _c("8a6a46"))
	for r in 2:
		for k in 3:
			var p := Vector3(-2.5 + float(k) * 1.6, 0, -0.5 + float(r) * 1.5)
			_table(p, 0.8, 0.55, _c("b79a6a"), 0.7)
			_chair(p + Vector3(0, 0, 0.6), PI, _c("7a5a3a"))
			_m.box(p + Vector3(0.1, 0.76, 0), Vector3(0.24, 0.03, 0.18), Color.from_hsv(_rng.randf(), 0.3, 0.8), 1.0)
	_g.cyl(Vector3(-3.1, 1.9, -D * 0.5 + 0.1), 0.22, 0.04, Color("f4ecd0"), 12, 1.0)


func _clinic(pal: Dictionary) -> void:
	for k in 2:
		var p := Vector3(-2.6 + float(k) * 1.9, 0, 1.6 - 3.4 * float(k % 2))
		_m.box(p + Vector3(0, 0.38, 0), Vector3(0.9, 0.12, 2.0), _c("e9eeee"), 1.0)
		for dx in [-1, 1]:
			for dz in [-1, 1]:
				_m.box(p + Vector3(dx * 0.4, 0.18, dz * 0.9), Vector3(0.05, 0.36, 0.05), _c("8a9494"), 0.1)
		_m.box(p + Vector3(0, 0.52, -0.1), Vector3(0.86, 0.16, 1.6), _c("a8cbc4"), 1.0)
		_m.box(p + Vector3(0, 0.6, -0.8), Vector3(0.5, 0.1, 0.3), Color("ffffff"), 1.0)
	_m.box(Vector3(1.8, 0.95, -2.7), Vector3(1.8, 1.9, 0.5), _c("e9eeee"), 1.0)
	for k in 6:
		_g.box(Vector3(1.0 + float(k) * 0.32, 1.35, -2.44), Vector3(0.12, 0.2, 0.02), Color.from_hsv(_rng.randf(), 0.4, 0.8), 1.0)
	_table(Vector3(2.5, 0, 0.8), 1.1, 0.6, _c("dfe4e2"), 0.8)
	_g.box(Vector3(0.3, 1.9, -D * 0.5 + 0.06), Vector3(0.7, 0.7, 0.02), Color("e04545"), 1.0)
	_g.box(Vector3(0.3, 1.9, -D * 0.5 + 0.06), Vector3(0.2, 0.55, 0.025), Color("ffffff"), 1.0)
	_g.box(Vector3(0.3, 1.9, -D * 0.5 + 0.06), Vector3(0.55, 0.2, 0.025), Color("ffffff"), 1.0)


func _chapel(pal: Dictionary) -> void:
	var wood := _c("6b4a2e")
	for r in 4:
		for sx in [-1.9, 1.3]:
			_m.box(Vector3(sx + 0.0, 0.45, 2.0 - float(r) * 1.1), Vector3(2.2, 0.08, 0.45), wood, 0.2)
			_m.box(Vector3(sx, 0.8, 2.2 - float(r) * 1.1), Vector3(2.2, 0.8, 0.07), wood, 0.2)
			_m.box(Vector3(sx - 1.0, 0.22, 2.0 - float(r) * 1.1), Vector3(0.08, 0.44, 0.4), wood.darkened(0.2), 0.2)
			_m.box(Vector3(sx + 1.0, 0.22, 2.0 - float(r) * 1.1), Vector3(0.08, 0.44, 0.4), wood.darkened(0.2), 0.2)
	_m.box(Vector3(0, 0.12, -2.6), Vector3(4.6, 0.24, 1.4), wood.darkened(0.1), 0.2)
	_m.box(Vector3(0, 0.75, -2.8), Vector3(1.2, 1.0, 0.5), _c("e8e0d0"), 1.0)
	_m.box(Vector3(0, 2.0, -D * 0.5 + 0.04), Vector3(0.12, 1.1, 0.06), wood.darkened(0.3), 0.2)
	_m.box(Vector3(0, 2.2, -D * 0.5 + 0.04), Vector3(0.6, 0.12, 0.06), wood.darkened(0.3), 0.2)
	for sx in [-0.8, 0.8]:
		_m.cyl(Vector3(sx, 1.45, -2.8), 0.04, 0.3, Color("efe8d8"), 6, 0.5)
		_g.cyl(Vector3(sx, 1.66, -2.8), 0.035, 0.08, Color("ffd070"), 6, 1.0)


func _office(pal: Dictionary, lot_id: String) -> void:
	var wood := _c("6a5236")
	_table(Vector3(0.6, 0, -1.4), 1.9, 0.9, wood)
	_chair(Vector3(0.6, 0, -2.3), 0.0, _c("3a3a44"))
	_chair(Vector3(0.6, 0, -0.5), PI, _c("5a4a36"))
	for k in 4:
		_m.box(Vector3(0.0 + float(k) * 0.28, 0.81, -1.4 + _rng.randf_range(-0.15, 0.15)), Vector3(0.22, 0.02, 0.3), Color("efe8d0"), 1.0, _rng.randf_range(-0.4, 0.4))
	_lamp(Vector3(1.3, 0.8, -1.6), 0.36)
	for k in 3:
		_m.box(Vector3(2.6 + float(k) * 0.55, 0.65, -D * 0.5 + 0.4), Vector3(0.5, 1.3, 0.55), _c("8a9099"), 0.1)
	_m.box(Vector3(-2.8, 1.5, -D * 0.5 + 0.04), Vector3(1.3, 0.9, 0.04), _c("8a6a3a"), 0.2)
	for k in 6:
		_m.box(Vector3(-3.25 + float(k % 3) * 0.45, 1.3 + float(k / 3) * 0.4, -D * 0.5 + 0.07), Vector3(0.3, 0.26, 0.02), Color("efe8d0"), 1.0, _rng.randf_range(-0.15, 0.15))
	if lot_id == "sheriff":
		for k in 9:
			_m.box(Vector3(-W * 0.5 + 0.9 + float(k) * 0.14, 1.1, 1.2), Vector3(0.025, 2.2, 0.025), _c("2a2a30"), 0.1)
		_m.box(Vector3(-W * 0.5 + 1.5, 2.2, 1.2), Vector3(1.4, 0.05, 0.05), _c("2a2a30"), 0.1)
		_m.box(Vector3(-W * 0.5 + 0.9, 0.12, 1.2), Vector3(1.4, 0.05, 0.05), _c("2a2a30"), 0.1)
	_plant(Vector3(-3.1, 0, 2.2))


func _hall(pal: Dictionary) -> void:
	var wood := _c("7a5a38")
	for k in 3:
		var z := -1.8 + float(k) * 1.7
		_table(Vector3(0.4, 0, z), 3.4, 0.8, wood)
		_m.box(Vector3(0.4, 0.44, z - 0.7), Vector3(3.2, 0.06, 0.3), wood.darkened(0.15), 0.2)
		_m.box(Vector3(0.4, 0.44, z + 0.7), Vector3(3.2, 0.06, 0.3), wood.darkened(0.15), 0.2)
	_m.box(Vector3(0, 0.2, -D * 0.5 + 0.5), Vector3(W - 0.6, 0.4, 1.0), wood.darkened(0.3), 0.2)
	_m.box(Vector3(-2.3, 1.6, -D * 0.5 + 0.1), Vector3(1.2, 2.4, 0.2), _c(pal["accent"]), 1.0)
	_m.box(Vector3(2.7, 1.6, -D * 0.5 + 0.1), Vector3(1.2, 2.4, 0.2), _c(pal["accent"]), 1.0)
	for k in 5:
		_g.cyl(Vector3(-2.6 + float(k) * 1.3, H - 0.4, 0.2), 0.12, 0.2, Color("ffd890"), 8, 1.0)
		_m.cyl(Vector3(-2.6 + float(k) * 1.3, H - 0.15, 0.2), 0.012, 0.3, _c("3a3028"), 4, 0.1)


# ------------------------------------------------------------------ the crime scene
func _crime_scene() -> void:
	var chalk := Color("f4f1e8")
	var o := Vector3(-0.4, 0.045, -0.1)
	_m.box(o + Vector3(0, 0, 0.0), Vector3(0.5, 0.012, 0.9), Color(0.2, 0.16, 0.14), 1.0)       # where the body lay
	for p in [[Vector3(0, 0, -0.5), Vector3(0.62, 0.02, 0.03)], [Vector3(0, 0, 0.5), Vector3(0.62, 0.02, 0.03)],
			[Vector3(-0.31, 0, 0), Vector3(0.03, 0.02, 1.0)], [Vector3(0.31, 0, 0), Vector3(0.03, 0.02, 1.0)],
			[Vector3(-0.55, 0, -0.2), Vector3(0.5, 0.02, 0.03)], [Vector3(0.55, 0, -0.35), Vector3(0.5, 0.02, 0.03)],
			[Vector3(-0.15, 0, 0.8), Vector3(0.03, 0.02, 0.6)], [Vector3(0.15, 0, 0.8), Vector3(0.03, 0.02, 0.6)]]:
		_m.box(o + (p[0] as Vector3), p[1], chalk, 1.0)
	_m.box(o + Vector3(0, 0, -0.78), Vector3(0.28, 0.02, 0.03), chalk, 1.0)
	for sp in [Vector3(1.2, 0, 0.6), Vector3(-1.6, 0, -0.9), Vector3(0.9, 0, -1.3)]:
		_m.add("prism", Transform3D(Basis.from_scale(Vector3(0.14, 0.2, 0.09)), o + sp + Vector3(0, 0.1, 0)), Color("f5c518"))
	# an overturned chair
	_m.box(Vector3(1.1, 0.25, 1.8), Vector3(0.44, 0.06, 0.44), _c("8a5e38"), 0.2, 0.7)
	_m.box(Vector3(1.0, 0.1, 1.55), Vector3(0.44, 0.6, 0.05), _c("8a5e38"), 0.2, 0.7)
	# tape across the doorway
	_m.box(Vector3(W * 0.5 - 0.2, 1.1, 1.9), Vector3(0.03, 0.07, 1.2), Color("f5c518"), 1.0)
	_m.box(Vector3(W * 0.5 - 0.2, 0.85, 1.9), Vector3(0.03, 0.07, 1.2), Color("f5c518"), 1.0, 0.0)


# ------------------------------------------------------------------ camera
## The room's camera pose in world space at time t (a slow drift so it breathes).
func pose(t: float) -> Transform3D:
	var p := global_position + cam_pos + Vector3(sin(t * 0.21) * 0.12, sin(t * 0.33) * 0.03, cos(t * 0.17) * 0.08)
	var look := global_position + cam_look + Vector3(sin(t * 0.13) * 0.2, 0, 0)
	var t3 := Transform3D(Basis.IDENTITY, p)
	return t3.looking_at(look, Vector3.UP)
