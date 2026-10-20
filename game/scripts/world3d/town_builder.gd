extends Node3D
## Builds the 3D town from the same lot layout the sim uses. Everything static is batched. Scale is metres; the town is ~960 x 620 m.
## Looks to hit: chunky stylised buildings, saturated soft-lit colour, warm windows at night, a real lake, hills in the haze.

const Kit = preload("res://scripts/world3d/mesh_kit.gd")
const TownLayout = preload("res://scripts/core/town_layout.gd")
const WATER = preload("res://shaders/water3d.gdshader")
const TERRAIN = preload("res://shaders/terrain3d.gdshader")
const WINDOW = preload("res://shaders/window3d.gdshader")

const WALLS := ["f2dcb3", "e8c9a0", "d9e4c6", "c9dbe8", "f0cfc4", "e6e0cf", "c7d8c0", "e9d7ee", "f4e4a8", "dfc7b0"]
const ROOFS := ["b4584a", "a3483c", "6e7fa0", "5b7a5e", "8a6a4a", "c98b4e", "7a5a8a", "3d5a80", "9a4a3a"]
const LAND_ROOFS := ["c9573f", "2f8f9d", "d19a2e", "6d5a9a", "4f8a5f", "b85a7a", "3d5a80"]
const GRASS := ["6d9a48", "76a34c", "7fa852", "6a9444"]
const SHORE_Z := -123.0

var layout: RefCounted
var doors: Dictionary = {}          # lot id -> {door: Vector3 (on the sidewalk), front: Vector3 (facing out), yaw: float}
var window_mat: ShaderMaterial
var water_mat: ShaderMaterial
var colliders: StaticBody3D
var _streets: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _b: Dictionary = {}              # name -> Kit.Batch


func build(town_layout: RefCounted) -> void:
	layout = town_layout
	_rng.seed = 1961
	for st in layout.spec["streets"]:
		_streets[st["id"]] = float(st["y"])
	colliders = StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)
	var box := Kit.box_mesh()
	var solid := Kit.matte()
	window_mat = ShaderMaterial.new()
	window_mat.shader = WINDOW
	_b["wall"] = Kit.Batch.new(box, solid)
	_b["roof"] = Kit.Batch.new(Kit.prism_mesh(), solid)
	_b["flat"] = Kit.Batch.new(box, solid)                       # roads, lawns, trim
	_b["flat_ns"] = Kit.Batch.new(box, solid, false)             # things that don't need shadows
	_b["win"] = Kit.Batch.new(box, window_mat, false)
	(_b["win"] as Kit.Batch).srgb = false
	
	_b["trunk"] = Kit.Batch.new(Kit.cylinder_mesh(6), solid)
	_b["leaf"] = Kit.Batch.new(Kit.sphere_mesh(8), solid)
	_b["pine"] = Kit.Batch.new(Kit.cone_mesh(7), solid)
	_b["pole"] = Kit.Batch.new(Kit.cylinder_mesh(6), solid)
	_b["lamp"] = Kit.Batch.new(Kit.sphere_mesh(6), window_mat, false)
	(_b["lamp"] as Kit.Batch).srgb = false
	_b["cyl"] = Kit.Batch.new(Kit.cylinder_mesh(14), solid)
	_b["cone"] = Kit.Batch.new(Kit.cone_mesh(12), solid)
	_terrain()
	_lake()
	_streets_and_sidewalks()
	for l in layout.lots:
		match String(l["kind"]):
			"green": _green(l)
			"park": _park(l)
			"landmark": _landmark(l)
			_: _house(l)
	_street_trees_and_lamps()
	_forest()
	_pier()
	for k in _b:
		(_b[k] as Kit.Batch).build(self, k)
	_walls()


# ------------------------------------------------------------------ helpers
func _side_sign(l: Dictionary) -> float:
	return -1.0 if int(l.get("side", 1)) == 1 else 1.0      # which way the street is from the lot (z direction)


func _street_y(l: Dictionary) -> float:
	return float(_streets.get(String(l["street"]), 0.0))


func _add_collider(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	colliders.add_child(cs)


func _wall(center: Vector3, size: Vector3, col: Color, yaw: float = 0.0) -> void:
	(_b["wall"] as Kit.Batch).add(Kit.xf(center, size, yaw), col)


func _flat(center: Vector3, size: Vector3, col: Color, shadows: bool = true) -> void:
	(_b["flat" if shadows else "flat_ns"] as Kit.Batch).add(Kit.xf(center, size), col)


func _window(center: Vector3, size: Vector3, lit: bool) -> void:
	(_b["win"] as Kit.Batch).add(Kit.xf(center, size), Color(0.55, 0.7, 0.8, 1.0 if lit else 0.0))


func _tree(p: Vector3, scale_v: float = 1.0, kind: int = -1) -> void:
	var r := _rng
	var k := kind if kind >= 0 else (r.randi() % 3)
	var trunk_h := 2.2 * scale_v
	(_b["trunk"] as Kit.Batch).add(Kit.xf(p + Vector3(0, trunk_h / 2.0, 0), Vector3(0.45, trunk_h, 0.45) * scale_v), Color("7a5a3a"))
	if k == 2:       # pine
		for i in 3:
			var w := (3.6 - i * 0.9) * scale_v
			(_b["pine"] as Kit.Batch).add(Kit.xf(p + Vector3(0, trunk_h + 0.6 + i * 1.5 * scale_v, 0), Vector3(w, 2.4 * scale_v, w)), Color("3f7a4a").lightened(r.randf_range(-0.05, 0.1)))
	else:
		var col := Color("6aa84f").lerp(Color("4f8f45"), r.randf()) if k == 0 else Color("8fb84a").lerp(Color("c9a93a"), r.randf() * 0.35)
		(_b["leaf"] as Kit.Batch).add(Kit.xf(p + Vector3(0, trunk_h + 1.6 * scale_v, 0), Vector3(3.6, 3.2, 3.6) * scale_v), col)
		(_b["leaf"] as Kit.Batch).add(Kit.xf(p + Vector3(0.8 * scale_v, trunk_h + 2.4 * scale_v, 0.4 * scale_v), Vector3(2.4, 2.2, 2.4) * scale_v), col.lightened(0.08))


func _bush(p: Vector3, s: float = 1.0) -> void:
	(_b["leaf"] as Kit.Batch).add(Kit.xf(p + Vector3(0, 0.45 * s, 0), Vector3(1.5, 0.95, 1.4) * s), Color("5f9a4a").lightened(_rng.randf_range(-0.05, 0.08)))


# ------------------------------------------------------------------ the land
func _height(x: float, z: float, noise: FastNoiseLite) -> float:
	# flat plateau under the town, hills rising out of the haze, a basin for the lake in the north
	var dx := maxf(absf(x) - 560.0, 0.0)
	var dz := maxf(maxf(z - 560.0, -140.0 - z), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	var hills := smoothstep(0.0, 420.0, d) * (30.0 + 120.0 * (noise.get_noise_2d(x * 0.9, z * 0.9) * 0.5 + 0.5)) 
	hills += smoothstep(0.0, 900.0, d) * 90.0 * (noise.get_noise_2d(x * 0.35 + 90.0, z * 0.35) * 0.5 + 0.5)
	var h := hills
	# the lake: a wide basin north of the shore road, ringed by hills further out
	var in_lake := smoothstep(SHORE_Z + 2.0, SHORE_Z - 10.0, z) * (1.0 - smoothstep(560.0, 760.0, absf(x))) * (1.0 - smoothstep(-760.0, -900.0, z))
	h = lerpf(h, -7.0, in_lake)
	if z < SHORE_Z + 1.0 and in_lake > 0.0 and in_lake < 1.0:
		h = lerpf(h, 0.2, 0.0)
	return h


func _terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.004
	noise.fractal_octaves = 3
	var step := 20.0
	var x0 := -2200.0
	var x1 := 2200.0
	var z0 := -2000.0
	var z1 := 1800.0
	var nx := int((x1 - x0) / step)
	var nz := int((z1 - z0) / step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs: Array = []
	for j in nz + 1:
		var row: Array = []
		for i in nx + 1:
			row.append(_height(x0 + i * step, z0 + j * step, noise))
		hs.append(row)
	for j in nz:
		for i in nx:
			var p00 := Vector3(x0 + i * step, hs[j][i], z0 + j * step)
			var p10 := Vector3(x0 + (i + 1) * step, hs[j][i + 1], z0 + j * step)
			var p01 := Vector3(x0 + i * step, hs[j + 1][i], z0 + (j + 1) * step)
			var p11 := Vector3(x0 + (i + 1) * step, hs[j + 1][i + 1], z0 + (j + 1) * step)
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var n: Vector3 = ((tri[1] - tri[0]).cross(tri[2] - tri[0])).normalized()
				n = -n if n.y < 0.0 else n               # clockwise from above is front-facing; the light normal points up
				for v in tri:
					st.set_normal(n)
					st.set_color(_land_color(v, n).srgb_to_linear())
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var tm := ShaderMaterial.new()
	tm.shader = TERRAIN
	mi.material_override = tm
	mi.name = "Terrain"
	add_child(mi)
	# a walkable floor under the whole town
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1200, 2, 760)
	cs.shape = bs
	cs.position = Vector3(0, -1.0, 170)
	floor_body.add_child(cs)
	add_child(floor_body)


func _land_color(v: Vector3, n: Vector3) -> Color:
	var base := Color(GRASS[(int(floorf(v.x / 60.0)) + int(floorf(v.z / 60.0)) + 40) % GRASS.size()])
	if v.y < 0.9 and v.z < SHORE_Z + 25.0:
		return Color("e9d9a6").lerp(base, clampf((v.y + 2.0) / 3.0, 0.0, 1.0)) if v.y > -3.0 else Color("a8c3b0")
	if v.y < -3.0:
		return Color("7fa9a4")
	var steep := 1.0 - n.y
	var c := base.lerp(Color("4f7f45"), clampf(v.y / 60.0, 0.0, 0.7))
	if v.y > 70.0:
		c = c.lerp(Color("8a8f86"), clampf((v.y - 70.0) / 60.0, 0.0, 1.0))
	c = c.lerp(Color("8a8f86"), clampf(steep * 3.0 - 0.5, 0.0, 0.8))
	if v.y > 135.0:
		c = c.lerp(Color("f4f6f8"), clampf((v.y - 135.0) / 30.0, 0.0, 1.0))
	return c


func _lake() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1500.0, 800.0)
	pm.subdivide_width = 60
	pm.subdivide_depth = 40
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER
	water_mat.set_shader_parameter("shore_z", SHORE_Z)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position = Vector3(0, -0.35, SHORE_Z - 395.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Lake"
	add_child(mi)


func _walls() -> void:
	# keep the player in the town: invisible walls, and the lake's edge (with a gap at the pier)
	var w := 8.0
	_add_collider(Vector3(-530, 5, 190), Vector3(w, 12, 760))
	_add_collider(Vector3(530, 5, 190), Vector3(w, 12, 760))
	_add_collider(Vector3(0, 5, 560), Vector3(1100, 12, w))
	_add_collider(Vector3(-60, 5, -126), Vector3(840, 12, 3))
	_add_collider(Vector3(0, 5, -150), Vector3(1100, 12, w))


# ------------------------------------------------------------------ streets
func _streets_and_sidewalks() -> void:
	var spec: Dictionary = layout.spec
	var road := Color("5d636e")
	var walk := Color("cfc7b6")
	var y0: float = float(spec["streets"][0]["y"])
	var y1: float = float(spec["streets"][-1]["y"])
	var x_min: float = float(spec["streets"][0]["x0"])
	var x_max: float = float(spec["streets"][0]["x1"])
	for st in spec["streets"]:
		var y: float = float(st["y"])
		var len_x := x_max - x_min
		_flat(Vector3((x_min + x_max) / 2.0, 0.03, y), Vector3(len_x, 0.1, 10.0), road)
		for sgn in [-1.0, 1.0]:
			_flat(Vector3((x_min + x_max) / 2.0, 0.08, y + sgn * 6.4), Vector3(len_x, 0.18, 2.6), walk, false)
		var x := x_min + 4.0
		while x < x_max:
			_flat(Vector3(x, 0.1, y), Vector3(3.0, 0.03, 0.3), Color("efe6c6"), false)
			x += 7.0
	for cx in spec["cross_x"]:
		var cxf: float = float(cx)
		var ln := y1 - y0 + 10.0
		_flat(Vector3(cxf, 0.031, (y0 + y1) / 2.0), Vector3(10.0, 0.1, ln), road)
		for sgn in [-1.0, 1.0]:
			_flat(Vector3(cxf + sgn * 6.4, 0.081, (y0 + y1) / 2.0), Vector3(2.6, 0.18, ln - 14.0), walk, false)
		var z := y0 + 8.0
		while z < y1 - 6.0:
			_flat(Vector3(cxf, 0.1, z), Vector3(0.3, 0.03, 3.0), Color("efe6c6"), false)
			z += 7.0


func _street_trees_and_lamps() -> void:
	var spec: Dictionary = layout.spec
	for st in spec["streets"]:
		var y: float = float(st["y"])
		var x := -470.0
		var i := 0
		while x < 470.0:
			if i % 2 == 0:
				var side := 1.0 if (i / 2) % 2 == 0 else -1.0
				(_b["pole"] as Kit.Batch).add(Kit.xf(Vector3(x, 2.3, y + side * 7.4), Vector3(0.18, 4.6, 0.18)), Color("3a3d46"))
				(_b["lamp"] as Kit.Batch).add(Kit.xf(Vector3(x, 4.7, y + side * 7.4), Vector3(0.7, 0.7, 0.7)), Color(1, 0.9, 0.6, 1.0))
			x += 34.0
			i += 1


# ------------------------------------------------------------------ lots
func _lawn(l: Dictionary, col: Color) -> void:
	_flat(Vector3(float(l["x"]), 0.03, float(l["y"])), Vector3(float(l["w"]) - 0.8, 0.07, float(l["d"]) - 0.8), col, false)


func _green(l: Dictionary) -> void:
	var h := hash(String(l["id"]))
	var c := Color(GRASS[h % GRASS.size()])
	_lawn(l, c)
	var cx: float = l["x"]; var cz: float = l["y"]
	for i in 2 + h % 3:
		_tree(Vector3(cx + float((h >> (i * 4)) % 13) - 6.0, 0.0, cz + float((h >> (i * 3 + 1)) % 17) - 8.0), 0.9 + float(h % 5) * 0.1)
	for i in 3:
		_bush(Vector3(cx + float((h >> (i * 5)) % 15) - 7.0, 0.0, cz + float((h >> (i * 2 + 3)) % 19) - 9.0))


func _house(l: Dictionary) -> void:
	var id := String(l["id"])
	var h := hash(id)
	var r := RandomNumberGenerator.new()
	r.seed = h
	var cx: float = l["x"]
	var cz: float = l["y"]
	var face := _side_sign(l)                 # direction from the house toward its street
	_lawn(l, Color(GRASS[h % GRASS.size()]))
	var fw := r.randf_range(10.5, 14.5)
	var fd := r.randf_range(8.0, 10.5)
	var floors := 2 if r.randf() < 0.38 else 1
	var hh := 3.0 * floors + 0.4
	var front_gap := 4.8
	var lot_front := cz + face * float(l["d"]) / 2.0
	var hz := lot_front - face * (front_gap + fd / 2.0)
	var hx := cx + r.randf_range(-1.5, 1.5)
	var wall := Color(WALLS[(h >> 3) % WALLS.size()])
	var roof := Color(ROOFS[(h >> 7) % ROOFS.size()])
	_wall(Vector3(hx, hh / 2.0, hz), Vector3(fw, hh, fd), wall)
	# foundation trim
	_wall(Vector3(hx, 0.25, hz), Vector3(fw + 0.3, 0.5, fd + 0.3), wall.darkened(0.2))
	# gable roof, ridge along the longer side
	var roof_h := 2.4 + r.randf() * 0.8
	(_b["roof"] as Kit.Batch).add(Kit.xf(Vector3(hx, hh + roof_h / 2.0, hz), Vector3(fd + 1.4, roof_h, fw + 1.0), PI / 2.0), roof)
	# chimney
	_wall(Vector3(hx + fw * 0.28, hh + roof_h * 0.7, hz), Vector3(0.9, roof_h * 1.3, 0.9), Color("8a5a48"))
	# door on the street side, steps, a porch light
	var door_z := hz + face * (fd / 2.0 + 0.04)
	var door_col := Color("a8483a") if h % 5 == 0 else Color("5f4632")
	_wall(Vector3(hx, 1.05, door_z), Vector3(1.2, 2.1, 0.12), door_col)
	_wall(Vector3(hx, 0.15, door_z + face * 0.7), Vector3(2.4, 0.3, 1.4), Color("c9c1b0"))
	# windows, front and sides, lit at night for some
	var nwin := 2 + (h >> 11) % 2
	for f in floors:
		for k in nwin:
			var wx := hx + (float(k) - (nwin - 1) / 2.0) * (fw * 0.6 / maxf(nwin - 1, 1))
			if f == 0 and absf(wx - hx) < 1.6:
				continue
			_window(Vector3(wx, 1.7 + f * 3.0, door_z + face * 0.02), Vector3(1.2, 1.2, 0.1), r.randf() < 0.7)
		_window(Vector3(hx + fw / 2.0 + 0.04, 1.7 + f * 3.0, hz), Vector3(0.1, 1.2, 1.2), r.randf() < 0.5)
		_window(Vector3(hx - fw / 2.0 - 0.04, 1.7 + f * 3.0, hz), Vector3(0.1, 1.2, 1.2), r.randf() < 0.5)
	# garden: trees, bushes, a path to the door, a fence sometimes
	_flat(Vector3(hx, 0.07, door_z + face * ((front_gap - 0.4) / 2.0 + 0.7)), Vector3(1.6, 0.05, front_gap), Color("d9ceb6"), false)
	if r.randf() < 0.65:
		_tree(Vector3(cx + (1.0 if r.randf() < 0.5 else -1.0) * (fw / 2.0 + 2.8), 0.0, hz + r.randf_range(-2.0, 3.0)), r.randf_range(0.85, 1.2))
	if r.randf() < 0.5:
		_bush(Vector3(hx + fw / 2.0 - 1.0, 0.0, door_z + face * 1.2))
		_bush(Vector3(hx - fw / 2.0 + 1.0, 0.0, door_z + face * 1.2))
	if h % 3 == 0:
		var fz := lot_front - face * 0.6
		_wall(Vector3(cx, 0.45, fz), Vector3(float(l["w"]) - 2.0, 0.9, 0.12), Color("f1ead8"))
	_add_collider(Vector3(hx, hh / 2.0, hz), Vector3(fw, hh, fd))
	var sy := _street_y(l)
	var sgn := 1.0 if int(l.get("side", 1)) == 1 else -1.0
	doors[id] = {"door": Vector3(hx, 0.0, sy + sgn * 6.4), "front": Vector3(hx, 0.0, door_z + face * 1.6), "yaw": 0.0 if face < 0.0 else PI, "face": face}


func _landmark(l: Dictionary) -> void:
	var id := String(l["id"])
	var h := hash(id)
	var cx: float = l["x"]
	var cz: float = l["y"]
	var face := _side_sign(l)
	var span := float(l["w"])
	_lawn(l, Color("c9c3a6"))
	var fw := span * 0.86
	var fd := float(l["d"]) * 0.62
	var hh := 5.2 + float(h % 4) * 0.8 + (2.5 if span > 60.0 else 0.0)
	var roof := Color(LAND_ROOFS[h % LAND_ROOFS.size()])
	var wall := Color(WALLS[(h >> 4) % WALLS.size()]).lightened(0.05)
	var lot_front := cz + face * float(l["d"]) / 2.0
	var hz := lot_front - face * (3.4 + fd / 2.0)
	_wall(Vector3(cx, hh / 2.0, hz), Vector3(fw, hh, fd), wall)
	_wall(Vector3(cx, 0.3, hz), Vector3(fw + 0.4, 0.6, fd + 0.4), wall.darkened(0.22))
	# roof: flat with a parapet, or a low gable on some
	if h % 3 == 0:
		(_b["roof"] as Kit.Batch).add(Kit.xf(Vector3(cx, hh + 1.3, hz), Vector3(fd + 1.4, 2.6, fw + 1.2), PI / 2.0), roof)
	else:
		_wall(Vector3(cx, hh + 0.5, hz), Vector3(fw + 0.8, 1.0, fd + 0.8), roof)
		_wall(Vector3(cx, hh + 1.05, hz), Vector3(fw - 0.6, 0.2, fd - 0.6), roof.darkened(0.15))
	# striped awning over the entrance
	var door_z := hz + face * (fd / 2.0)
	var stripes := maxi(4, int(fw / 1.6))
	for i in stripes:
		var sx := cx - fw / 2.0 + (float(i) + 0.5) * fw / stripes
		_wall(Vector3(sx, 3.2, door_z + face * 0.9), Vector3(fw / stripes, 0.14, 1.9), Color("e23d3d") if i % 2 == 0 else Color("f6f0e0"))
	_wall(Vector3(cx, 1.3, door_z + face * 0.04), Vector3(2.0, 2.6, 0.14), Color("5f4632"))
	for k in maxi(2, int(fw / 6.0)):
		_window(Vector3(cx - fw / 2.0 + 3.0 + k * 6.0, 2.3, door_z + face * 0.03), Vector3(2.4, 1.7, 0.1), (h >> k) % 3 != 0)
		if hh > 7.0:
			_window(Vector3(cx - fw / 2.0 + 3.0 + k * 6.0, 5.6, door_z + face * 0.03), Vector3(2.4, 1.5, 0.1), (h >> (k + 3)) % 2 == 0)
	# the name above the door
	var lab := Label3D.new()
	lab.text = String(l["name"]).to_upper()
	lab.font = load("res://assets/fonts/Bangers-Regular.ttf")
	lab.font_size = 96
	lab.pixel_size = 0.0085
	lab.outline_size = 22
	lab.modulate = Color("fff6d8")
	lab.outline_modulate = Color("14121c")
	lab.position = Vector3(cx, 4.35, door_z + face * 0.5)
	lab.rotation = Vector3(0, 0.0 if face < 0.0 else PI, 0)
	lab.double_sided = false
	lab.name = "Sign_" + id
	add_child(lab)
	# specials
	match id:
		"chapel":
			_wall(Vector3(cx - fw * 0.3, hh + 3.0, hz), Vector3(3.2, 8.0, 3.2), wall)
			(_b["cone"] as Kit.Batch).add(Kit.xf(Vector3(cx - fw * 0.3, hh + 9.8, hz), Vector3(4.0, 6.0, 4.0)), Color("6d5a9a"))
			_wall(Vector3(cx - fw * 0.3, hh + 13.4, hz), Vector3(0.2, 1.6, 0.2), Color("f6f0e0"))
			_wall(Vector3(cx - fw * 0.3, hh + 13.6, hz), Vector3(1.0, 0.2, 0.2), Color("f6f0e0"))
		"town_hall":
			_wall(Vector3(cx, hh + 3.5, hz), Vector3(5.0, 8.0, 5.0), wall)
			(_b["cyl"] as Kit.Batch).add(Kit.xf_rot(Vector3(cx, hh + 5.0, hz + face * 2.55), Vector3(3.4, 0.3, 3.4), Vector3(PI / 2.0, 0, 0)), Color("f6f0e0"))
			(_b["cone"] as Kit.Batch).add(Kit.xf(Vector3(cx, hh + 9.8, hz), Vector3(6.0, 3.6, 6.0)), Color("3d5a80"))
		"school":
			(_b["pole"] as Kit.Batch).add(Kit.xf(Vector3(cx + fw * 0.35, hh + 4.0, hz + face * 6.0), Vector3(0.15, 8.0, 0.15)), Color("d6d6dc"))
			_wall(Vector3(cx + fw * 0.35 + 0.9, hh + 7.0, hz + face * 6.0), Vector3(1.6, 1.0, 0.05), Color("e23d3d"))
		"clinic", "lakeview_rest":
			_wall(Vector3(cx + fw * 0.3, hh + 0.6, hz + face * (fd / 2.0 + 0.05)), Vector3(1.6, 0.4, 0.1), Color("e23d3d"))
			_wall(Vector3(cx + fw * 0.3, hh + 0.6, hz + face * (fd / 2.0 + 0.05)), Vector3(0.4, 1.6, 0.1), Color("e23d3d"))
		"dam_house":
			_wall(Vector3(cx + 40.0, 4.0, cz - face * 4.0), Vector3(80.0, 8.0, 6.0), Color("b7b4aa"))
	_add_collider(Vector3(cx, hh / 2.0, hz), Vector3(fw, hh, fd))
	var sy := _street_y(l)
	var sgn := 1.0 if int(l.get("side", 1)) == 1 else -1.0
	doors[id] = {"door": Vector3(cx, 0.0, sy + sgn * 6.4), "front": Vector3(cx, 0.0, door_z + face * 2.2), "yaw": 0.0 if face < 0.0 else PI, "face": face}


func _park(l: Dictionary) -> void:
	var id := String(l["id"])
	var cx: float = l["x"]
	var cz: float = l["y"]
	var w: float = l["w"]
	var d: float = l["d"]
	_flat(Vector3(cx, 0.03, cz), Vector3(w - 0.6, 0.07, d - 0.6), Color("6f9f4d"), false)
	_flat(Vector3(cx, 0.08, cz), Vector3(w - 4.0, 0.04, 3.0), Color("e0d3ae"), false)       # paths
	_flat(Vector3(cx, 0.08, cz), Vector3(3.0, 0.04, d - 3.0), Color("e0d3ae"), false)
	var r := RandomNumberGenerator.new()
	r.seed = hash(id)
	for i in 14:
		var p := Vector3(cx + r.randf_range(-w / 2.0 + 3.0, w / 2.0 - 3.0), 0.0, cz + r.randf_range(-d / 2.0 + 3.0, d / 2.0 - 3.0))
		if absf(p.x - cx) < 3.0 or absf(p.z - cz) < 3.0:
			continue
		_tree(p, r.randf_range(0.9, 1.3))
	# pond
	(_b["cyl"] as Kit.Batch).add(Kit.xf(Vector3(cx + w * 0.28, 0.06, cz + d * 0.22), Vector3(12.0, 0.1, 9.0)), Color("6fb7c6"))
	# gazebo
	for k in 6:
		var a := TAU * float(k) / 6.0
		(_b["pole"] as Kit.Batch).add(Kit.xf(Vector3(cx + cos(a) * 3.0, 1.6, cz + sin(a) * 3.0), Vector3(0.22, 3.2, 0.22)), Color("f1ead8"))
	(_b["cone"] as Kit.Batch).add(Kit.xf(Vector3(cx, 4.0, cz), Vector3(8.4, 2.4, 8.4)), Color("c9573f"))
	# benches
	for k in 4:
		_wall(Vector3(cx + (k - 1.5) * 9.0, 0.5, cz + 5.0), Vector3(2.2, 0.15, 0.7), Color("8a6a4a"))
		_wall(Vector3(cx + (k - 1.5) * 9.0, 0.28, cz + 5.0), Vector3(2.0, 0.5, 0.5), Color("5a4a3a"))
	doors[id] = {"door": Vector3(cx, 0.0, _street_y(l) + (6.4 if int(l.get("side", 1)) == 1 else -6.4)), "front": Vector3(cx, 0.0, cz), "yaw": 0.0, "face": 0.0}


func _pier() -> void:
	var lq: Dictionary = layout.by_id.get("launch_quay", {})
	var x: float = float(lq["x"]) if not lq.is_empty() else -276.0
	for i in 14:
		_flat(Vector3(x, 0.3, SHORE_Z - 4.0 - float(i) * 2.0), Vector3(4.2, 0.18, 1.9), Color("a07c52") if i % 2 == 0 else Color("8e6c46"))
	for i in 7:
		(_b["pole"] as Kit.Batch).add(Kit.xf(Vector3(x - 2.0, 0.0, SHORE_Z - 4.0 - float(i) * 4.0), Vector3(0.35, 2.2, 0.35)), Color("5a4a3a"))
		(_b["pole"] as Kit.Batch).add(Kit.xf(Vector3(x + 2.0, 0.0, SHORE_Z - 4.0 - float(i) * 4.0), Vector3(0.35, 2.2, 0.35)), Color("5a4a3a"))
	# the Mercy Ann, tied up at the end
	_wall(Vector3(x + 5.0, 0.55, SHORE_Z - 24.0), Vector3(3.4, 1.1, 10.0), Color("f6f0e0"))
	_wall(Vector3(x + 5.0, 1.3, SHORE_Z - 22.5), Vector3(2.6, 1.4, 3.6), Color("2f8f9d"))
	_wall(Vector3(x + 5.0, 1.2, SHORE_Z - 29.0), Vector3(0.1, 0.1, 0.1), Color("e23d3d"))


func _forest() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.012
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var placed := 0
	var tries := 0
	while placed < 700 and tries < 6000:
		tries += 1
		var x := r.randf_range(-1300.0, 1300.0)
		var z := r.randf_range(-100.0, 1100.0)
		if absf(x) < 540.0 and z < 575.0:
			continue
		if noise.get_noise_2d(x, z) < -0.05:
			continue
		var y := _height(x, z, noise_for_height())
		if y < 0.3:
			continue
		_tree(Vector3(x, y, z), r.randf_range(1.2, 2.2), 2 if y > 18.0 and r.randf() < 0.7 else r.randi() % 2)
		placed += 1


var _hn: FastNoiseLite
func noise_for_height() -> FastNoiseLite:
	if _hn == null:
		_hn = FastNoiseLite.new()
		_hn.seed = 77
		_hn.frequency = 0.004
		_hn.fractal_octaves = 3
	return _hn
