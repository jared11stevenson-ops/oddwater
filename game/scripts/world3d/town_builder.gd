extends Node3D
## Builds the 3D town from the same lot layout the sim uses. Scale is metres; the town is ~960 x 620 m.
## Static geometry is baked into chunked meshes (Merger) and chunked MultiMeshes (trees, grass, smoke), so the phone only draws what is
## on screen. Houses, gardens, roads, lamps, the lake shore, pier and marina are all procedural and deterministic.

const Kit = preload("res://scripts/world3d/mesh_kit.gd")
const Merge = preload("res://scripts/world3d/merger.gd")
const Scenery = preload("res://scripts/world3d/scenery.gd")
const HouseKit = preload("res://scripts/world3d/house_kit.gd")
const LandmarkKit = preload("res://scripts/world3d/landmark_kit.gd")
const TownLayout = preload("res://scripts/core/town_layout.gd")
const WATER = preload("res://shaders/water3d.gdshader")
const TERRAIN = preload("res://shaders/terrain3d.gdshader")
const WINDOW = preload("res://shaders/window3d.gdshader")
const SOLID = preload("res://shaders/town_solid.gdshader")
const LAMP = preload("res://shaders/lamp3d.gdshader")
const FOLIAGE = preload("res://shaders/foliage3d.gdshader")
const PUFF = preload("res://shaders/puff3d.gdshader")
const GLOW = preload("res://shaders/glow3d.gdshader")

const GRASS := ["6d9a48", "76a34c", "7fa852", "6a9444"]
const SHORE_Z := -123.0
const CELL := 96.0
const FAR_BODY := 950.0
const FAR_DETAIL := 240.0
const FAR_GLASS := 280.0

var layout: RefCounted
var doors: Dictionary = {}          # lot id -> {door: Vector3 (on the sidewalk), front: Vector3 (facing out), yaw: float, face: float}
var window_mat: ShaderMaterial
var water_mat: ShaderMaterial
var solid_mat: ShaderMaterial
var terrain_mat: ShaderMaterial
var lamp_mat: ShaderMaterial
var foliage_mat: ShaderMaterial
var puff_mat: ShaderMaterial
var halo_mat: ShaderMaterial
var pool_mat: ShaderMaterial
var colliders: StaticBody3D
var lamp_positions: PackedVector3Array = PackedVector3Array()     # where the street lamps are (for the pooled real lights)
var body                       # Merger: walls, roofs, big solid things (cast shadows)
var detail                     # Merger: trim, fences, small props (near only, no shadows)
var ground                     # Merger: roads, paths, markings (no shadows)
var glass                      # Merger: windows (shader)
var lamp                       # Merger: lamp bulbs
var stats: Dictionary = {}
var kit: RefCounted
var chimney_count := 0
var _streets: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}    # kind -> Kit.Batch
var _halos: Kit.Batch
var _pools: Kit.Batch
var _hn: FastNoiseLite


func build(town_layout: RefCounted) -> void:
	layout = town_layout
	_rng.seed = 1961
	for st in layout.spec["streets"]:
		_streets[st["id"]] = float(st["y"])
	colliders = StaticBody3D.new()
	colliders.name = "Colliders"
	add_child(colliders)
	_materials()
	body = _merger()
	detail = _merger()
	ground = _merger()
	glass = _merger()
	lamp = _merger()
	kit = HouseKit.new(self)
	_halos = Kit.Batch.new(_quad_mesh(1.0), halo_mat, false, 128.0, 120.0)
	_halos.srgb = false
	_pools = Kit.Batch.new(_flat_mesh(1.0), pool_mat, false, 128.0, 70.0)
	_pools.srgb = false
	_terrain()
	_lake()
	_streets_and_sidewalks()
	for l in layout.lots:
		match String(l["kind"]):
			"green": kit.green(l)
			"park": kit.park(l)
			"landmark": LandmarkKit.new(self).landmark(l)
			_: _house(l)
	_infill()
	_street_furniture()
	_forest()
	_shore()
	_pier_and_marina()
	_walls()
	_finish()


# ------------------------------------------------------------------ materials and helpers
func _merger():
	var m = Merge.new()
	m.cell = CELL
	return m


func _quad_mesh(s: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	return q


func _flat_mesh(s: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(s, s)
	return p


func _materials() -> void:
	solid_mat = ShaderMaterial.new()
	solid_mat.shader = SOLID
	window_mat = ShaderMaterial.new()
	window_mat.shader = WINDOW
	lamp_mat = ShaderMaterial.new()
	lamp_mat.shader = LAMP
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN
	foliage_mat = ShaderMaterial.new()
	foliage_mat.shader = FOLIAGE
	puff_mat = ShaderMaterial.new()
	puff_mat.shader = PUFF
	halo_mat = ShaderMaterial.new()
	halo_mat.shader = GLOW
	halo_mat.set_shader_parameter("billboard", true)
	halo_mat.set_shader_parameter("strength", 0.7)
	pool_mat = ShaderMaterial.new()
	pool_mat.shader = GLOW
	pool_mat.set_shader_parameter("billboard", false)
	pool_mat.set_shader_parameter("strength", 0.45)
	pool_mat.set_shader_parameter("fade_near", 1.0)
	pool_mat.set_shader_parameter("fade_far", 60.0)
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER
	water_mat.set_shader_parameter("shore_z", SHORE_Z)


## Every material the sky keeps in step with the clock and the weather.
func sky_materials() -> Array:
	return [window_mat, water_mat, solid_mat, terrain_mat, lamp_mat, foliage_mat, puff_mat, halo_mat, pool_mat]


func collider(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	colliders.add_child(cs)


func _batch(kind: String) -> Kit.Batch:
	if not _batches.has(kind):
		var shadows := kind in ["oak", "oak2", "maple", "pine", "poplar", "bush", "rock", "fir_far"]
		var vis := 0.0
		var cell := 128.0
		match kind:
			"tuft": vis = 60.0; cell = 64.0
			"tall_tuft": vis = 90.0; cell = 64.0
			"reed": vis = 160.0; cell = 96.0
			"puff": vis = 170.0; cell = 128.0
			"bush": vis = 420.0
			"rock": vis = 500.0
			"fir_far": vis = 0.0; cell = 256.0
			_: vis = 1100.0
		var bt := Kit.Batch.new(Scenery.mesh(kind), puff_mat if kind == "puff" else foliage_mat, shadows, cell, vis)
		bt.srgb = false
		_batches[kind] = bt
	return _batches[kind]


func add_tree(p: Vector3, s: float = 1.0, kind: String = "oak") -> void:
	var r := _rng.randf()
	var tint := Color(1.0 + (r - 0.5) * 0.14, 1.0 + (_rng.randf() - 0.5) * 0.12, 1.0 + (_rng.randf() - 0.5) * 0.14)
	var sc := s * (0.92 + _rng.randf() * 0.2)
	(_batch(kind) as Kit.Batch).add(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * (0.95 + _rng.randf() * 0.15), sc)), p), tint)
	collider_tree(p, s)


func collider_tree(p: Vector3, s: float) -> void:
	pass          # trees you can walk through keep the walking easy on a thumb stick


func add_bush(p: Vector3, s: float = 1.0) -> void:
	(_batch("bush") as Kit.Batch).add(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), p), Color.from_hsv(0.0, 0.0, 0.9 + _rng.randf() * 0.2))


func add_tuft(p: Vector3, s: float = 1.0, tall: bool = false) -> void:
	var tint := Color(0.85 + _rng.randf() * 0.3, 0.9 + _rng.randf() * 0.2, 0.8 + _rng.randf() * 0.3)
	(_batch("tall_tuft" if tall else "tuft") as Kit.Batch).add(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), p), tint)


func add_rock(p: Vector3, s: float = 1.0) -> void:
	var tint := Color.from_hsv(0.0, 0.0, 0.85 + _rng.randf() * 0.25)
	(_batch("rock") as Kit.Batch).add(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * (0.7 + _rng.randf() * 0.6), s * (0.8 + _rng.randf() * 0.5))), p), tint)


func add_reed(p: Vector3, s: float = 1.0) -> void:
	(_batch("reed") as Kit.Batch).add(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s * (0.8 + _rng.randf() * 0.5)), p), Color(0.9 + _rng.randf() * 0.2, 0.95 + _rng.randf() * 0.1, 0.85 + _rng.randf() * 0.2))


## Chimney smoke: four puffs that rise on their own timers (see puff3d.gdshader).
func add_puff(p: Vector3, seed_v: float = 0.0) -> void:
	chimney_count += 1
	for i in 4:
		(_batch("puff") as Kit.Batch).add(Transform3D(Basis.from_scale(Vector3.ONE * (0.8 + 0.1 * float(i))), p), Color(1, 1, 1, 1))


func add_halo(p: Vector3, size: float, vis: float = 120.0) -> void:
	_halos.add(Transform3D(Basis.from_scale(Vector3(size, size, size)), p), Color(1, 1, 1, 1))


func add_pool(p: Vector3, radius: float) -> void:
	_pools.add(Transform3D(Basis.from_scale(Vector3(radius * 2.0, 1.0, radius * 2.0)), Vector3(p.x, 0.12, p.z)), Color(1, 1, 1, 1))


## A street lamp: pole, arm, hood, bulb, a halo around the bulb and a pool of light on the ground.
func add_lamp(p: Vector3, height: float = 4.8, arm_dir: float = 0.0) -> void:
	detail.add("taper:6", Transform3D(Basis.from_scale(Vector3(0.2, height, 0.2)), p + Vector3(0, height / 2.0, 0)), Color("3a3d46"), 1.0)
	detail.box(p + Vector3(0, 0.15, 0), Vector3(0.34, 0.3, 0.34), Color("30333b"))
	var off := Vector3(0, 0, 0.5 * arm_dir)
	if arm_dir != 0.0:
		detail.box(p + Vector3(0, height - 0.05, off.z * 0.5), Vector3(0.1, 0.1, 0.5 * absf(arm_dir) + 0.02), Color("3a3d46"))
	var head := p + Vector3(0, height + 0.05, off.z)
	detail.box(head + Vector3(0, 0.12, 0), Vector3(0.6, 0.12, 0.42), Color("30333b"))
	lamp.add("cyl:6", Transform3D(Basis.from_scale(Vector3(0.38, 0.2, 0.3)), head - Vector3(0, 0.02, 0)), Color("fff2c8"))
	add_halo(head, 3.4, 130.0)
	add_pool(Vector3(p.x, 0, p.z + off.z), 5.2)
	lamp_positions.append(head)


func add_pond(p: Vector3, rx: float, rz: float) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(rx * 2.0, rz * 2.0)
	m.mesh = pm
	m.material_override = water_mat
	m.position = Vector3(p.x, 0.07, p.z)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = 260.0
	m.name = "Pond"
	add_child(m)


func _side_sign(l: Dictionary) -> float:
	return -1.0 if int(l.get("side", 1)) == 1 else 1.0      # which way the street is from the lot (z direction)


func _street_y(l: Dictionary) -> float:
	return float(_streets.get(String(l["street"]), 0.0))


func noise_for_height() -> FastNoiseLite:
	if _hn == null:
		_hn = FastNoiseLite.new()
		_hn.seed = 77
		_hn.frequency = 0.004
		_hn.fractal_octaves = 3
	return _hn


func _finish() -> void:
	var tris := 0
	var chunks := 0
	for pair in [[body, solid_mat, true, FAR_BODY, false, "Body"], [detail, solid_mat, false, FAR_DETAIL, false, "Detail"], [ground, solid_mat, false, 720.0, false, "Ground"],
			[glass, window_mat, false, FAR_GLASS, true, "Glass"], [lamp, lamp_mat, false, FAR_GLASS, false, "Lamps"]]:
		var mg = pair[0]
		var made: Array = mg.build(self, pair[5], pair[1], pair[2], pair[3], pair[4])
		tris += mg.triangle_count()
		chunks += made.size()
	var nb := 0
	for k in _batches:
		var bt: Kit.Batch = _batches[k]
		bt.build(self, "MM_" + k)
		nb += bt.count()
	_halos.build(self, "Halos")
	_pools.build(self, "LightPools")
	stats = {"static_tris": tris, "chunks": chunks, "instances": nb, "colliders": colliders.get_child_count(), "lamps": lamp_positions.size(), "chimneys": chimney_count}


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
	return h


func ground_height(x: float, z: float) -> float:
	return _height(x, z, noise_for_height())


func _terrain() -> void:
	var noise := noise_for_height()
	# a fine grid under and around the town, a coarse one out to the far hills; each region is cut into tiles so they can be culled
	_terrain_region(-1000.0, 1000.0, -500.0, 900.0, 20.0, 500.0, noise)
	_terrain_region(-2200.0, -1000.0, -2000.0, 1800.0, 50.0, 1200.0, noise)
	_terrain_region(1000.0, 2200.0, -2000.0, 1800.0, 50.0, 1200.0, noise)
	_terrain_region(-1000.0, 1000.0, -2000.0, -500.0, 50.0, 1000.0, noise)
	_terrain_region(-1000.0, 1000.0, 900.0, 1800.0, 50.0, 1000.0, noise)
	# a walkable floor under the whole town
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1200, 2, 760)
	cs.shape = bs
	cs.position = Vector3(0, -1.0, 170)
	floor_body.add_child(cs)
	add_child(floor_body)


func _terrain_region(xa: float, xb: float, za: float, zb: float, step: float, tile: float, noise: FastNoiseLite) -> void:
	var tx := ceili((xb - xa) / tile)
	var tz := ceili((zb - za) / tile)
	for j in tz:
		for i in tx:
			var x0 := xa + float(i) * (xb - xa) / float(tx)
			var x1 := xa + float(i + 1) * (xb - xa) / float(tx)
			var z0 := za + float(j) * (zb - za) / float(tz)
			var z1 := za + float(j + 1) * (zb - za) / float(tz)
			_terrain_tile(x0, x1, z0, z1, step, noise)


func _terrain_tile(x0: float, x1: float, z0: float, z1: float, step: float, noise: FastNoiseLite) -> void:
	var nx := maxi(1, int(round((x1 - x0) / step)))
	var nz := maxi(1, int(round((z1 - z0) / step)))
	var sx := (x1 - x0) / float(nx)
	var sz := (z1 - z0) / float(nz)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize((nx + 1) * (nz + 1))
	norms.resize((nx + 1) * (nz + 1))
	cols.resize((nx + 1) * (nz + 1))
	var k := 0
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + float(i) * sx
			var z := z0 + float(j) * sz
			var y := _height(x, z, noise)
			var n := Vector3(_height(x - sx, z, noise) - _height(x + sx, z, noise), sx * 2.0, _height(x, z - sz, noise) - _height(x, z + sz, noise)).normalized()
			verts[k] = Vector3(x, y, z)
			norms[k] = n
			cols[k] = _land_color(Vector3(x, y, z), n).srgb_to_linear()
			k += 1
	var idx := PackedInt32Array()
	idx.resize(nx * nz * 6)
	var q := 0
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + (nx + 1)
			var d := c + 1
			idx[q] = a; idx[q + 1] = b; idx[q + 2] = d
			idx[q + 3] = a; idx[q + 4] = d; idx[q + 5] = c
			q += 6
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Terrain_%d_%d" % [int(x0), int(z0)]
	add_child(mi)


func _land_color(v: Vector3, n: Vector3) -> Color:
	var base := Color(GRASS[(int(floorf(v.x / 60.0)) + int(floorf(v.z / 60.0)) + 40) % GRASS.size()]).lerp(Color("74a24c"), 0.5)
	if v.y < 0.9 and v.z < SHORE_Z + 25.0:
		return Color("e9d9a6").lerp(base, clampf((v.y + 2.0) / 3.0, 0.0, 1.0)) if v.y > -3.0 else Color("8aa89a")
	if v.y < -3.0:
		return Color("6f9a96")
	var steep := 1.0 - n.y
	var c := base.lerp(Color("4f7f45"), clampf(v.y / 60.0, 0.0, 0.7))
	if v.y > 70.0:
		c = c.lerp(Color("8a8f86"), clampf((v.y - 70.0) / 60.0, 0.0, 1.0))
	c = c.lerp(Color("8a8f86"), clampf(steep * 3.0 - 0.5, 0.0, 0.8))
	if v.y > 135.0:
		c = c.lerp(Color("f4f6f8"), clampf((v.y - 135.0) / 30.0, 0.0, 1.0))
	# the forest floor is darker
	if absf(v.x) > 540.0 or v.z > 575.0:
		c = c.lerp(Color("3f6a3a"), 0.3)
	return c


func _lake() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1500.0, 800.0)
	pm.subdivide_width = 48
	pm.subdivide_depth = 28
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
	collider(Vector3(-530, 5, 190), Vector3(w, 12, 760))
	collider(Vector3(530, 5, 190), Vector3(w, 12, 760))
	collider(Vector3(0, 5, 560), Vector3(1100, 12, w))
	collider(Vector3(-60, 5, -126), Vector3(840, 12, 3))
	collider(Vector3(0, 5, -150), Vector3(1100, 12, w))


# ------------------------------------------------------------------ streets
func _strip_x(x0: float, x1: float, z: float, w: float, y: float, h: float, col: Color, pat: float, piece: float = 80.0) -> void:
	var n := maxi(1, ceili((x1 - x0) / piece))
	for i in n:
		var a := x0 + (x1 - x0) * float(i) / float(n)
		var c := x0 + (x1 - x0) * float(i + 1) / float(n)
		ground.box(Vector3((a + c) / 2.0, y, z), Vector3(c - a + 0.01, h, w), col, pat)


func _strip_z(z0: float, z1: float, x: float, w: float, y: float, h: float, col: Color, pat: float, piece: float = 80.0) -> void:
	var n := maxi(1, ceili((z1 - z0) / piece))
	for i in n:
		var a := z0 + (z1 - z0) * float(i) / float(n)
		var c := z0 + (z1 - z0) * float(i + 1) / float(n)
		ground.box(Vector3(x, y, (a + c) / 2.0), Vector3(w, h, c - a + 0.01), col, pat)


func _streets_and_sidewalks() -> void:
	var spec: Dictionary = layout.spec
	var road := Color("5d636e")
	var walk := Color("cfc7b6")
	var kerb := Color("e2dccd")
	var paint := Color("efe3a8")
	var white := Color("e8e4d8")
	var ys: Array = spec["streets"].map(func(s): return float(s["y"]))
	var y0: float = ys[0]
	var y1: float = ys[-1]
	var x_min: float = float(spec["streets"][0]["x0"])
	var x_max: float = float(spec["streets"][0]["x1"])
	var cross: Array = spec["cross_x"].map(func(v): return float(v))
	# asphalt: one strip per street and per cross street
	for y in ys:
		_strip_x(x_min - 5.0, x_max + 5.0, y, 10.0, 0.03, 0.1, road, 0.5)
	for cx in cross:
		_strip_z(y0 - 5.0, y1 + 5.0, cx, 10.0, 0.031, 0.1, road, 0.5)
	# sidewalks with a kerb, broken at every crossing street
	var seg_a: Array = [x_min - 5.0] + cross.map(func(v): return v + 5.0)
	var seg_b: Array = cross.map(func(v): return v - 5.0) + [x_max + 5.0]
	for y in ys:
		for sgn in [-1.0, 1.0]:
			for i in seg_a.size():
				var sx0: float = seg_a[i]
				var sx1: float = seg_b[i]
				if sx1 - sx0 < 1.0:
					continue
				_strip_x(sx0, sx1, y + sgn * 6.4, 2.6, 0.09, 0.18, walk, 0.4)
				_strip_x(sx0, sx1, y + sgn * 5.2, 0.28, 0.1, 0.2, kerb, 0.4)
	for cx in cross:
		for sgn in [-1.0, 1.0]:
			for i in ys.size() - 1:
				var z0: float = ys[i] + 5.0
				var z1: float = ys[i + 1] - 5.0
				_strip_z(z0, z1, cx + sgn * 6.4, 2.6, 0.091, 0.18, walk, 0.4)
				_strip_z(z0, z1, cx + sgn * 5.2, 0.28, 0.101, 0.2, kerb, 0.4)
	# paint: dashed centre lines, solid edge lines, crosswalks, stop bars, manholes, drains
	for y in ys:
		var x := x_min + 4.0
		while x < x_max:
			if _near_cross(x, cross, 6.5) < 0.0:
				ground.flat(Vector3(x, 0.082, y), 3.0, 0.2, paint, 1.0)
			x += 7.0
		for sgn in [-1.0, 1.0]:
			var segs := _gaps(x_min, x_max, cross, 6.0)
			for sg in segs:
				_strip_x(sg[0], sg[1], y + sgn * 4.4, 0.14, 0.081, 0.002, white, 1.0, 120.0)
		var mx := x_min + 31.0
		while mx < x_max:
			if _near_cross(mx, cross, 8.0) < 0.0:
				ground.add("cyl:10", Transform3D(Basis.from_scale(Vector3(0.95, 0.02, 0.95)), Vector3(mx, 0.083, y + 1.6)), Color("3d4048"), 0.1)
				ground.box(Vector3(mx + 17.0, 0.083, y - 4.2), Vector3(0.7, 0.02, 0.35), Color("2d2f35"), 0.1)
			mx += 66.0
	for cx in cross:
		var z := y0 + 4.0
		while z < y1:
			if _near_y(z, ys, 6.5) < 0.0:
				ground.flat(Vector3(cx, 0.083, z), 0.2, 3.0, paint, 1.0)
			z += 7.0
		for sgn in [-1.0, 1.0]:
			for i in ys.size() - 1:
				_strip_z(ys[i] + 6.0, ys[i + 1] - 6.0, cx + sgn * 4.4, 0.14, 0.082, 0.002, white, 1.0, 120.0)
		# the four crosswalks and stop bars at every crossing
		for y in ys:
			for sgn in [-1.0, 1.0]:
				# across the cross street, on either side of the main street
				for k in 10:
					ground.flat(Vector3(cx - 4.5 + float(k) * 1.0, 0.085, y + sgn * 6.6), 0.5, 2.4, white, 1.0)
				# across the main street, on either side of the cross street
				for k in 10:
					ground.flat(Vector3(cx + sgn * 6.6, 0.085, y - 4.5 + float(k) * 1.0), 2.4, 0.5, white, 1.0)
				ground.flat(Vector3(cx + sgn * 8.8, 0.084, y + sgn * -2.0), 0.4, 4.2, white, 1.0)
				ground.flat(Vector3(cx + sgn * 2.0, 0.084, y + sgn * 8.8), 4.2, 0.4, white, 1.0)
	# the shore road's lake side: a gravel verge, a kerb and a line of bollards
	var sy: float = ys[0]
	_strip_x(x_min - 5.0, x_max + 5.0, sy - 9.6, 4.0, 0.04, 0.08, Color("b9b098"), 0.4)
	var bx := x_min
	while bx < x_max:
		if absf(bx - (-270.0)) > 7.0:
			detail.cyl(Vector3(bx, 0.45, sy - 11.4), 0.13, 0.9, Color("6a5a48"), 6)
		bx += 7.0


func _near_cross(x: float, cross: Array, half: float) -> float:
	for cx in cross:
		if absf(x - float(cx)) < half:
			return 1.0
	return -1.0


func _near_y(z: float, ys: Array, half: float) -> float:
	for y in ys:
		if absf(z - float(y)) < half:
			return 1.0
	return -1.0


## The stretches of [x0,x1] that are not within `half` of a crossing street.
func _gaps(x0: float, x1: float, cross: Array, half: float) -> Array:
	var out: Array = []
	var start := x0
	for cx in cross:
		var c := float(cx)
		out.append([start, c - half])
		start = c + half
	out.append([start, x1])
	return out


# ------------------------------------------------------------------ street furniture
func _street_furniture() -> void:
	var spec: Dictionary = layout.spec
	var si := 0
	for st in spec["streets"]:
		var y: float = float(st["y"])
		var x := -470.0
		var i := 0
		while x < 470.0:
			if i % 2 == 0:
				var side := 1.0 if (i / 2) % 2 == 0 else -1.0
				add_lamp(Vector3(x, 0.0, y + side * 7.5), 4.8, -side * 0.6)
			x += 34.0
			i += 1
		# hydrants and bins along the walk, a bench or two
		var hx := -440.0 + float(si) * 13.0
		while hx < 450.0:
			var side2 := 1.0 if int(hx) % 2 == 0 else -1.0
			var p := Vector3(hx, 0.0, y + side2 * 5.9)
			detail.cyl(p + Vector3(0, 0.35, 0), 0.16, 0.7, Color("c0392b"), 6)
			detail.cyl(p + Vector3(0, 0.75, 0), 0.2, 0.12, Color("a02f24"), 6)
			detail.box(p + Vector3(0.0, 0.5, 0.0), Vector3(0.4, 0.1, 0.1), Color("a02f24"))
			hx += 88.0
		var bxx := -400.0 + float(si) * 37.0
		while bxx < 440.0:
			var sd := -1.0 if (int(bxx) / 7) % 2 == 0 else 1.0
			var bp := Vector3(bxx, 0.0, y + sd * 7.2)
			detail.box(bp + Vector3(0, 0.5, 0), Vector3(1.8, 0.1, 0.5), Color("8a6a4a"), 0.2)
			detail.box(bp + Vector3(0, 0.8, sd * 0.28), Vector3(1.8, 0.4, 0.06), Color("8a6a4a"), 0.2)
			detail.box(bp + Vector3(-0.8, 0.25, 0), Vector3(0.1, 0.5, 0.4), Color("3a3d46"))
			detail.box(bp + Vector3(0.8, 0.25, 0), Vector3(0.1, 0.5, 0.4), Color("3a3d46"))
			detail.cyl(bp + Vector3(2.0, 0.45, 0), 0.28, 0.9, Color("4a6a5a"), 8)       # a bin
			bxx += 112.0
		si += 1
	# street-name signs at every crossing
	var cross: Array = spec["cross_x"]
	for st in spec["streets"]:
		var y2: float = float(st["y"])
		for cx in cross:
			var sp := Vector3(float(cx) + 7.0, 0.0, y2 + 7.4)
			detail.box(sp + Vector3(0, 1.2, 0), Vector3(0.08, 2.4, 0.08), Color("8a8e96"))
			detail.box(sp + Vector3(0, 2.3, 0.0), Vector3(1.0, 0.26, 0.04), Color("2f6a5a"))
			detail.box(sp + Vector3(0, 2.0, 0.0), Vector3(0.3, 0.26, 1.0), Color("2f6a5a"))
	# utility poles with sagging wires along every second street
	var yy: Array = spec["streets"].map(func(s): return float(s["y"]))
	for si2 in yy.size():
		var pz: float = yy[si2] + (8.6 if si2 % 2 == 0 else -8.6)
		var px := -468.0
		var prev := Vector3.ZERO
		var have := false
		while px < 470.0:
			var pt := Vector3(px, 0, pz)
			detail.add("taper:6", Transform3D(Basis.from_scale(Vector3(0.3, 8.2, 0.3)), pt + Vector3(0, 4.1, 0)), Color("5a4634"))
			detail.box(pt + Vector3(0, 7.7, 0), Vector3(0.12, 0.12, 2.0), Color("4a3a2a"))
			if have:
				for lane in [-0.9, 0.0, 0.9]:
					_wire(prev + Vector3(0, 7.7, lane), pt + Vector3(0, 7.7, lane), 0.55)
			prev = pt
			have = true
			px += 46.0


func _wire(a: Vector3, c: Vector3, sag: float) -> void:
	var m := (a + c) * 0.5 - Vector3(0, sag, 0)
	for pair in [[a, m], [m, c]]:
		var p0: Vector3 = pair[0]
		var p1: Vector3 = pair[1]
		var d := p1 - p0
		var len := d.length()
		var bs := Basis.looking_at(d.normalized(), Vector3.UP)
		detail.add("box", Transform3D(bs * Basis.from_scale(Vector3(0.035, 0.035, len)), (p0 + p1) * 0.5), Color("25262c"))


# ------------------------------------------------------------------ lots
func _house(l: Dictionary) -> void:
	var id := String(l["id"])
	var h := hash(id)
	var cx: float = l["x"]
	var cz: float = l["y"]
	var face := _side_sign(l)
	var res: Dictionary = kit.house(cx, cz, face, float(l["w"]), float(l["d"]), h)
	var sy := _street_y(l)
	var sgn := 1.0 if int(l.get("side", 1)) == 1 else -1.0
	var hx: float = res["door_x"]
	var door_z: float = res["door_z"]
	doors[id] = {"door": Vector3(hx, 0.0, sy + sgn * 6.4), "front": Vector3(hx, 0.0, door_z + face * 1.6), "yaw": 0.0 if face < 0.0 else PI, "face": face}


## Fill the gaps between the lots, and the back-yard strips between streets, so the town reads as lived in.
func _infill() -> void:
	var rows: Dictionary = {}
	for l in layout.lots:
		var key := "%s|%d" % [l["street"], int(l["side"])]
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(l)
	var cross: Array = layout.spec["cross_x"].map(func(v): return float(v))
	var n := 0
	for key in rows:
		var arr: Array = rows[key]
		arr.sort_custom(func(a, c): return float(a["x"]) < float(c["x"]))
		for i in arr.size() - 1:
			var a: Dictionary = arr[i]
			var c: Dictionary = arr[i + 1]
			var ax1 := float(a["x"]) + float(a["w"]) / 2.0
			var bx0 := float(c["x"]) - float(c["w"]) / 2.0
			var gap := bx0 - ax1
			if gap < 12.0:
				continue
			var gc := (ax1 + bx0) / 2.0
			if _near_cross(gc, cross, 4.0) > 0.0:
				continue
			n += 1
			_gap(gc, float(a["y"]), _side_sign(a), gap, float(a["d"]), hash("gap%d" % n))
	_back_yards()
	_meadows()


func _gap(gc: float, cz: float, face: float, gap: float, depth: float, hsh: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hsh
	var roll := r.randf()
	if roll < 0.58:
		kit.house(gc, cz, face, gap, depth, hsh, minf(1.0, (gap - 3.5) / 18.0), false)
	elif roll < 0.74:
		# a walled garden with trees and beds
		for i in 3:
			add_tree(Vector3(gc + r.randf_range(-gap / 2.0 + 2.0, gap / 2.0 - 2.0), 0, cz + r.randf_range(-depth / 2.0 + 3.0, depth / 2.0 - 3.0)), r.randf_range(0.9, 1.3), ["oak", "maple", "oak2"][r.randi() % 3])
		for i in 2:
			detail.box(Vector3(gc, 0.18, cz - 4.0 + float(i) * 6.0), Vector3(gap - 6.0, 0.36, 2.0), Color("5a3f2a"), 0.3)
			for k in 5:
				detail.blob(Vector3(gc - (gap - 8.0) / 2.0 + float(k) * (gap - 8.0) / 4.0, 0.5, cz - 4.0 + float(i) * 6.0), Vector3(0.6, 0.6, 0.6), Color(["6aa84f", "8fb84a", "c9573f", "d9a23a", "b86ad8"][(i + k) % 5]), 5)
	elif roll < 0.88:
		# a shared drive with parked cars
		ground.box(Vector3(gc, 0.05, cz + face * (depth / 2.0 - 8.0)), Vector3(gap - 4.0, 0.1, 16.0), Color("a9a49a"), 0.4)
		Scenery.car(detail, Vector3(gc - 3.0, 0, cz + face * (depth / 2.0 - 4.0)), 0.0 if face > 0.0 else PI, Color(HouseKit.CARS[r.randi() % HouseKit.CARS.size()]))
		if r.randf() < 0.7:
			Scenery.car(detail, Vector3(gc + 3.0, 0, cz + face * (depth / 2.0 - 5.5)), 0.0 if face > 0.0 else PI, Color(HouseKit.CARS[r.randi() % HouseKit.CARS.size()]))
		add_tree(Vector3(gc, 0, cz - face * 6.0), 1.2, "poplar")
	else:
		add_tree(Vector3(gc, 0, cz), r.randf_range(1.2, 1.7), ["oak", "oak2"][r.randi() % 2])
		add_bush(Vector3(gc + 3.0, 0, cz + 2.0))
		add_bush(Vector3(gc - 3.0, 0, cz - 2.0))
	for i in 14:
		add_tuft(Vector3(gc + r.randf_range(-gap / 2.0, gap / 2.0), 0, cz + r.randf_range(-depth / 2.0, depth / 2.0)), r.randf_range(0.8, 1.4))


## The strips behind the lots between streets: tree lines, hedgerows, sheds, and tall grass.
func _back_yards() -> void:
	var ys: Array = layout.spec["streets"].map(func(s): return float(s["y"]))
	var cross: Array = layout.spec["cross_x"].map(func(v): return float(v))
	var r := RandomNumberGenerator.new()
	r.seed = 515
	for i in ys.size() - 1:
		var za: float = ys[i] + 7.0 + 32.0 + 1.5
		var zb: float = ys[i + 1] - 7.0 - 32.0 - 1.5
		if zb - za < 8.0:
			continue
		var x := -470.0
		while x < 470.0:
			var xx := x + r.randf_range(0.0, 20.0)
			x += 20.0
			if _near_cross(xx, cross, 9.0) > 0.0:
				continue
			var z := r.randf_range(za, zb)
			var roll := r.randf()
			if roll < 0.5:
				add_tree(Vector3(xx, 0, z), r.randf_range(1.0, 1.5), ["oak", "oak2", "maple", "poplar", "pine"][r.randi() % 5])
			elif roll < 0.7:
				# hedgerow
				var len := r.randf_range(8.0, 18.0)
				detail.box(Vector3(xx, 0.6, z), Vector3(len, 1.2, 1.0), Color("4f8a43"), 0.3)
				for k in int(len / 2.2):
					detail.blob(Vector3(xx - len / 2.0 + (float(k) + 0.5) * len / floorf(len / 2.2), 1.15, z), Vector3(2.0, 0.8, 1.1), Color("5f9a4c").lightened(r.randf_range(-0.05, 0.05)), 5)
			elif roll < 0.82:
				var sc := Color(["a8483a", "6f8a9a", "8a7a5a", "5f7a5a", "d9d4c4"][r.randi() % 5])
				body.box(Vector3(xx, 1.2, z), Vector3(3.4, 2.4, 2.8), sc, 0.9)
				body.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(3.2, 1.0, 3.8)), Vector3(xx, 2.9, z)), Color("5b5b64"), 0.6)
				collider(Vector3(xx, 1.2, z), Vector3(3.4, 2.4, 2.8))
			elif roll < 0.9:
				add_rock(Vector3(xx, 0, z), r.randf_range(1.0, 1.8))
			for k in 8:
				add_tuft(Vector3(xx + r.randf_range(-8.0, 8.0), 0, r.randf_range(za, zb)), r.randf_range(1.0, 1.7), r.randf() < 0.4)


## The open ground at the edges of town: a meadow with a barn, a paddock and haystacks to the south; tall grass and rocks elsewhere.
func _meadows() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 733
	# south of the back lane: a farmstead
	var bz := 470.0
	body.box(Vector3(-310.0, 3.6, bz), Vector3(16.0, 7.2, 11.0), Color("a8483a"), 0.9)
	body.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(12.4, 4.4, 17.2)), Vector3(-310.0, 9.4, bz)), Color("6a4a3a"), 0.6)
	detail.box(Vector3(-310.0, 2.2, bz - 5.53), Vector3(5.0, 4.4, 0.12), Color("f1ead8"))
	detail.box(Vector3(-310.0, 2.2, bz - 5.6), Vector3(0.15, 4.4, 0.1), Color("a8483a"))
	collider(Vector3(-310.0, 3.6, bz), Vector3(16.0, 7.2, 11.0))
	body.add("cyl:10", Transform3D(Basis.from_scale(Vector3(4.2, 12.0, 4.2)), Vector3(-294.0, 6.0, bz + 9.0)), Color("c9c4b4"), 1.0)
	body.add("cone:10", Transform3D(Basis.from_scale(Vector3(4.6, 2.6, 4.6)), Vector3(-294.0, 13.3, bz + 9.0)), Color("8a8e96"), 1.0)
	collider(Vector3(-294.0, 6.0, bz + 9.0), Vector3(4.2, 12.0, 4.2))
	for i in 4:
		body.add("cyl:8", Transform3D(Basis.from_scale(Vector3(2.4, 2.0, 2.4)), Vector3(-336.0 + float(i) * 4.5, 1.0, bz + 4.0)), Color("d9b64a"), 1.0)
	# paddock fence
	var pw := 40.0
	for k in 2:
		detail.box(Vector3(-262.0, 0.5, bz - 12.0 + float(k) * 24.0), Vector3(pw, 1.0, 0.05), Color("a8885a"), 0.0)
		detail.box(Vector3(-262.0 - pw / 2.0 + float(k) * pw, 0.5, bz), Vector3(0.05, 1.0, 24.0), Color("a8885a"), 0.0)
	# the lake-side lawn and the eastern and western ends: tufts, rocks, scattered trees
	for i in 260:
		var x := r.randf_range(-515.0, 515.0)
		var z := r.randf_range(-118.0, 555.0)
		if (z > -100.0 and z < 410.0) and absf(x) < 485.0:
			continue
		add_tuft(Vector3(x, ground_height(x, z), z), r.randf_range(1.0, 1.8), r.randf() < 0.5)
	for i in 36:
		var x2 := r.randf_range(-515.0, 515.0)
		var z2 := r.randf_range(415.0, 552.0)
		if absf(x2 + 300.0) < 40.0 and z2 < 500.0:
			continue
		add_tree(Vector3(x2, 0, z2), r.randf_range(1.0, 1.6), ["oak", "oak2", "maple", "pine", "poplar"][r.randi() % 5])
	for i in 24:
		var x3 := r.randf_range(-515.0, 515.0)
		var z3 := r.randf_range(415.0, 552.0)
		add_rock(Vector3(x3, 0, z3), r.randf_range(0.9, 2.2))
	for side in [-1.0, 1.0]:
		for i in 14:
			add_tree(Vector3(side * r.randf_range(488.0, 522.0), 0, r.randf_range(-100.0, 410.0)), r.randf_range(1.1, 1.7), ["oak", "oak2", "maple", "pine"][r.randi() % 4])


func _forest() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.012
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var placed := 0
	var tries := 0
	var hn := noise_for_height()
	while placed < 760 and tries < 7000:
		tries += 1
		var x := r.randf_range(-1300.0, 1300.0)
		var z := r.randf_range(-100.0, 1100.0)
		if absf(x) < 540.0 and z < 575.0:
			continue
		if noise.get_noise_2d(x, z) < -0.05:
			continue
		var y := _height(x, z, hn)
		if y < 0.3:
			continue
		var kind: String = "pine" if y > 18.0 and r.randf() < 0.7 else (["oak", "oak2", "maple", "poplar"][r.randi() % 4])
		var far := absf(x) > 900.0 or z > 800.0
		if far:
			kind = "fir_far"
		add_tree(Vector3(x, y - 0.2, z), r.randf_range(1.2, 2.2), kind)
		placed += 1
	# a ring of far firs on the high slopes: the hills read as wooded from town
	var far_placed := 0
	var ftries := 0
	while far_placed < 520 and ftries < 6000:
		ftries += 1
		var x2 := r.randf_range(-2100.0, 2100.0)
		var z2 := r.randf_range(-1900.0, 1700.0)
		if absf(x2) < 700.0 and z2 > -300.0 and z2 < 800.0:
			continue
		var y2 := _height(x2, z2, hn)
		if y2 < 6.0 or y2 > 150.0:
			continue
		add_tree(Vector3(x2, y2 - 0.3, z2), r.randf_range(3.0, 5.5), "fir_far")
		far_placed += 1


## Reeds, rocks and driftwood along the lake's edge, and a little rocky island with pines out in the water.
func _shore() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 321
	var hn := noise_for_height()
	var x := -500.0
	while x < 500.0:
		var cluster := r.randf() < 0.55
		if cluster and absf(x - (-270.0)) > 9.0 and absf(x - (-422.0)) > 36.0:
			var cz := SHORE_Z + r.randf_range(-3.0, 2.0)
			for i in r.randi_range(3, 7):
				var px := x + r.randf_range(-3.0, 3.0)
				var pz := cz + r.randf_range(-2.5, 1.5)
				add_reed(Vector3(px, _height(px, pz, hn), pz), r.randf_range(0.8, 1.4))
		if r.randf() < 0.3:
			var rz := SHORE_Z + r.randf_range(-1.0, 3.0)
			add_rock(Vector3(x + r.randf_range(-3.0, 3.0), _height(x, rz, hn), rz), r.randf_range(0.7, 1.8))
		x += 9.0 + r.randf() * 6.0
	# the island
	var ip := Vector3(70.0, 0.0, -330.0)
	for k in 6:
		var a := TAU * float(k) / 6.0
		add_rock(ip + Vector3(cos(a) * 7.0, -0.4, sin(a) * 5.5), r.randf_range(2.5, 3.8))
	body.blob(ip + Vector3(0, 0.0, 0), Vector3(17.0, 3.2, 13.0), Color("7c8a58"), 8)
	body.blob(ip + Vector3(0, 0.6, 0), Vector3(12.0, 2.6, 9.0), Color("6a9a48"), 8, 0.0, 0.3)
	for k in 5:
		add_tree(ip + Vector3(r.randf_range(-4.0, 4.0), 1.1, r.randf_range(-3.0, 3.0)), r.randf_range(1.0, 1.6), "pine")
	for k in 8:
		add_reed(ip + Vector3(cos(float(k)) * 8.5, -0.2, sin(float(k)) * 6.8))
	# buoys out in the water
	for k in 7:
		var bp := Vector3(-380.0 + float(k) * 95.0 + r.randf_range(-10, 10), -0.25, -190.0 - r.randf_range(0.0, 60.0))
		body.add("sphere:8", Transform3D(Basis.from_scale(Vector3(0.8, 0.9, 0.8)), bp), Color("d9382a") if k % 2 == 0 else Color("f4efe2"))
		body.add("cyl:6", Transform3D(Basis.from_scale(Vector3(0.12, 1.0, 0.12)), bp + Vector3(0, 0.8, 0)), Color("3a3d46"))


# ------------------------------------------------------------------ pier and marina
func _pier_and_marina() -> void:
	var lq: Dictionary = layout.by_id.get("launch_quay", {})
	var x: float = float(lq["x"]) if not lq.is_empty() else -276.0
	var plank := Color("a07c52")
	# the pier: a deck, posts with rope, lamps, crates, barrels and a boat
	for i in 14:
		ground.box(Vector3(x, 0.3, SHORE_Z - 4.0 - float(i) * 2.0), Vector3(4.2, 0.18, 1.95), plank if i % 2 == 0 else plank.darkened(0.1), 0.2)
	for i in 7:
		for s in [-2.0, 2.0]:
			detail.add("taper:6", Transform3D(Basis.from_scale(Vector3(0.4, 2.6, 0.4)), Vector3(x + s, -0.5, SHORE_Z - 4.0 - float(i) * 4.0)), Color("5a4a3a"))
			detail.box(Vector3(x + s * 1.01, 0.3, SHORE_Z - 4.0 - float(i) * 4.0), Vector3(0.12, 0.5, 2.0), Color("5a4a3a"))
	for i in 3:
		var lz := SHORE_Z - 8.0 - float(i) * 10.0
		add_lamp(Vector3(x - 2.2, 0.3, lz), 3.0, 0.0)
		add_lamp(Vector3(x + 2.2, 0.3, lz - 5.0), 3.0, 0.0)
	# rope between the posts
	for i in 6:
		var za := SHORE_Z - 4.0 - float(i) * 4.0
		_rope(Vector3(x - 1.95, 0.95, za), Vector3(x - 1.95, 0.95, za - 4.0))
		_rope(Vector3(x + 1.95, 0.95, za), Vector3(x + 1.95, 0.95, za - 4.0))
	for k in 5:
		detail.box(Vector3(x - 1.2 + float(k % 2) * 0.9, 0.7 + float(k / 3) * 0.55, SHORE_Z - 12.0 - float(k) * 0.2), Vector3(0.8, 0.55, 0.8), Color("b0884f"), 0.2, 0.3 * float(k))
	detail.add("cyl:8", Transform3D(Basis.from_scale(Vector3(0.7, 0.95, 0.7)), Vector3(x + 1.3, 0.8, SHORE_Z - 18.0)), Color("3f5a7a"))
	detail.add("cyl:8", Transform3D(Basis.from_scale(Vector3(0.7, 0.95, 0.7)), Vector3(x + 1.5, 0.8, SHORE_Z - 19.1)), Color("8a3a3a"))
	# the Mercy Ann, tied up at the end
	Scenery.boat(body, Vector3(x + 5.0, -0.05, SHORE_Z - 24.0), 0.05, Color("f6f0e0"), 10.0)
	body.box(Vector3(x + 5.0, 1.35, SHORE_Z - 22.5), Vector3(2.6, 1.4, 3.6), Color("2f8f9d"), 0.9)
	body.box(Vector3(x + 5.0, 2.15, SHORE_Z - 22.5), Vector3(2.9, 0.15, 3.9), Color("f6f0e0"))
	body.box(Vector3(x + 5.0, 1.4, SHORE_Z - 20.68), Vector3(1.9, 0.7, 0.05), Color("1f2530"))
	_rope(Vector3(x + 2.1, 0.5, SHORE_Z - 20.0), Vector3(x + 4.2, 0.4, SHORE_Z - 20.2))
	# the marina: a long boardwalk with finger piers, moored boats, posts and nets
	var mx := -422.0
	var mp = ground
	for i in 22:
		mp.box(Vector3(mx, 0.3, SHORE_Z - 3.0 - float(i) * 2.0), Vector3(3.2, 0.18, 1.95), plank if i % 2 == 0 else plank.darkened(0.1), 0.2)
	for f in 4:
		var fz := SHORE_Z - 10.0 - float(f) * 10.0
		for s in [-1.0, 1.0]:
			for i in 6:
				mp.box(Vector3(mx + s * (3.0 + float(i) * 1.9), 0.3, fz), Vector3(1.9, 0.16, 1.7), plank if i % 2 == 0 else plank.darkened(0.1), 0.2)
			var boat_x: float = mx + float(s) * 8.2
			var colr: Color = [Color("f4efe2"), Color("2f8f9d"), Color("c9573f"), Color("d9a23a"), Color("3d5a80")][(f + int(s + 1.0)) % 5]
			Scenery.boat(body, Vector3(boat_x + s * 1.5, -0.1, fz - 4.5), 0.08 * s, colr, 5.5 if f % 2 == 0 else 7.0, f % 2 == 1)
			for q in 3:
				detail.add("taper:6", Transform3D(Basis.from_scale(Vector3(0.32, 2.4, 0.32)), Vector3(mx + s * (3.0 + float(q) * 5.0), -0.4, fz + 1.2)), Color("5a4a3a"))
	for i in 8:
		detail.add("taper:6", Transform3D(Basis.from_scale(Vector3(0.36, 2.5, 0.36)), Vector3(mx + (-1.9 if i % 2 == 0 else 1.9), -0.4, SHORE_Z - 3.0 - float(i) * 5.4)), Color("5a4a3a"))
	for i in 4:
		add_lamp(Vector3(mx - 1.6, 0.3, SHORE_Z - 6.0 - float(i) * 10.0), 3.2, 0.0)
	for k in 6:
		detail.box(Vector3(mx + 3.0 + float(k % 3) * 0.9, 0.7 + float(k / 3) * 0.55, SHORE_Z - 5.0 - float(k) * 0.3), Vector3(0.8, 0.55, 0.8), Color("b0884f"), 0.2, 0.25 * float(k))
	# a boathouse on the shore
	body.box(Vector3(mx + 14.0, 2.1, SHORE_Z + 4.0), Vector3(9.0, 4.2, 6.5), Color("6f8a9a"), 0.9)
	body.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(7.8, 2.2, 10.0)), Vector3(mx + 14.0, 5.3, SHORE_Z + 4.0)), Color("8a4a3a"), 0.6)
	collider(Vector3(mx + 14.0, 2.1, SHORE_Z + 4.0), Vector3(9.0, 4.2, 6.5))


func _rope(a: Vector3, c: Vector3) -> void:
	var m := (a + c) * 0.5 - Vector3(0, 0.22, 0)
	for pair in [[a, m], [m, c]]:
		var p0: Vector3 = pair[0]
		var p1: Vector3 = pair[1]
		var d := p1 - p0
		var bs := Basis.looking_at(d.normalized(), Vector3.UP)
		detail.add("box", Transform3D(bs * Basis.from_scale(Vector3(0.05, 0.05, d.length())), (p0 + p1) * 0.5), Color("d9c9a0"))
