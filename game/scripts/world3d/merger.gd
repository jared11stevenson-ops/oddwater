extends RefCounted
## Bakes many transformed primitives into a few chunked ArrayMeshes (one surface per ~100 m cell), so a whole town of walls, roofs,
## fences and kerbs costs a handful of draw calls AND can be frustum-culled chunk by chunk. Geometry is built with native packed-array
## maths (no per-vertex GDScript), so building the town stays fast. Vertex colour = sRGB tint, alpha = a "pattern id" (or "lit
## threshold" for the glass layer) that the town shaders read.

static var _cache: Dictionary = {}


class Chunk extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()

var cell := 96.0
var cells: Dictionary = {}      # Vector2i -> Chunk
var pieces := 0
var verts := 0


# ------------------------------------------------------------------ primitive cache (expanded, unindexed)
static func geo(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var parts := kind.split(":")
	var g: Dictionary
	match parts[0]:
		"box": g = _expand(BoxMesh.new())
		"prism":
			var p := PrismMesh.new()
			p.left_to_right = 0.5
			g = _expand(p)
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5; c.bottom_radius = 0.5; c.height = 1.0
			c.radial_segments = int(parts[1]); c.rings = 1
			g = _expand(c)
		"cone":
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.0; c2.bottom_radius = 0.5; c2.height = 1.0
			c2.radial_segments = int(parts[1]); c2.rings = 1
			g = _expand(c2)
		"taper":      # a cylinder narrower at the top (tree trunks, posts)
			var c3 := CylinderMesh.new()
			c3.top_radius = 0.3; c3.bottom_radius = 0.5; c3.height = 1.0
			c3.radial_segments = int(parts[1]); c3.rings = 1
			g = _expand(c3)
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5; s.height = 1.0
			s.radial_segments = int(parts[1]); s.rings = maxi(3, int(parts[1]) / 2)
			g = _expand(s)
		"hemi":
			var h := SphereMesh.new()
			h.radius = 0.5; h.height = 1.0; h.is_hemisphere = true
			h.radial_segments = int(parts[1]); h.rings = maxi(2, int(parts[1]) / 3)
			g = _expand(h)
		"capsule":
			var cp := CapsuleMesh.new()
			cp.radius = 0.5; cp.height = 2.0
			cp.radial_segments = int(parts[1]); cp.rings = 3
			g = _expand(cp)
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = 0.42; t.outer_radius = 0.5
			t.rings = 14; t.ring_segments = 6
			g = _expand(t)
		"quad":       # unit square in XY, facing +Z, UV 0..1 (windows, signs)
			g = _tris([[Vector3(-.5, -.5, 0), Vector3(.5, -.5, 0), Vector3(.5, .5, 0)], [Vector3(-.5, -.5, 0), Vector3(.5, .5, 0), Vector3(-.5, .5, 0)]],
				[[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)]])
		"flat":       # unit square in XZ, facing up (road paint, chalk, decals)
			g = _tris([[Vector3(-.5, 0, .5), Vector3(.5, 0, .5), Vector3(.5, 0, -.5)], [Vector3(-.5, 0, .5), Vector3(.5, 0, -.5), Vector3(-.5, 0, -.5)]],
				[[Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)]])
		"pyramid":    # square base 1x1 at y=-.5, apex at y=+.5
			var a := Vector3(0, .5, 0)
			var b := [Vector3(-.5, -.5, .5), Vector3(.5, -.5, .5), Vector3(.5, -.5, -.5), Vector3(-.5, -.5, -.5)]
			g = _tris([[b[0], b[1], a], [b[1], b[2], a], [b[2], b[3], a], [b[3], b[0], a], [b[0], b[2], b[1]], [b[0], b[3], b[2]]])
		"hip":        # hip roof: base 1x1 at y=-.5, ridge (ratio r of the length) at y=+.5
			var r := float(parts[1]) * 0.5
			var f0 := Vector3(-.5, -.5, .5); var f1 := Vector3(.5, -.5, .5); var b1 := Vector3(.5, -.5, -.5); var b0 := Vector3(-.5, -.5, -.5)
			var r0 := Vector3(-r, .5, 0); var r1 := Vector3(r, .5, 0)
			g = _tris([[f0, f1, r1], [f0, r1, r0], [b1, b0, r0], [b1, r0, r1], [f1, b1, r1], [b0, f0, r0], [f0, b0, b1], [f0, b1, f1]])
		_: g = _expand(BoxMesh.new())
	_cache[kind] = g
	return g


static func _expand(m: Mesh) -> Dictionary:
	var arr: Array = m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx = arr[Mesh.ARRAY_INDEX]
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var ou := PackedVector2Array()
	if idx == null or (idx as PackedInt32Array).is_empty():
		ov = v; on = n; ou = uv
	else:
		for i in (idx as PackedInt32Array):
			ov.append(v[i]); on.append(n[i])
			ou.append(uv[i] if uv.size() > i else Vector2.ZERO)
	return {"v": ov, "n": on, "uv": ou}


static func _tris(tris: Array, uvs: Array = []) -> Dictionary:
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var ou := PackedVector2Array()
	for k in tris.size():
		var t: Array = tris[k]
		var nn: Vector3 = ((t[1] - t[0]).cross(t[2] - t[0])).normalized()
		for j in 3:
			ov.append(t[j]); on.append(nn)
			ou.append(uvs[k][j] if not uvs.is_empty() else Vector2.ZERO)
	return {"v": ov, "n": on, "uv": ou}


# ------------------------------------------------------------------ adding
func _cell_of(key_pos: Vector3) -> Chunk:
	var key := Vector2i(floori(key_pos.x / cell), floori(key_pos.z / cell))
	if not cells.has(key):
		cells[key] = Chunk.new()
	return cells[key]


func add(kind: String, xf: Transform3D, color: Color, pat: float = 1.0) -> void:
	var g: Dictionary = geo(kind)
	var c: Chunk = _cell_of(xf.origin)
	var gv: PackedVector3Array = g["v"]
	var nb := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
	c.v.append_array(xf * gv)
	c.n.append_array(nb * (g["n"] as PackedVector3Array))
	c.uv.append_array(g["uv"])
	var cols := PackedColorArray()
	cols.resize(gv.size())
	cols.fill(Color(color.r, color.g, color.b, pat))
	c.c.append_array(cols)
	pieces += 1
	verts += gv.size()


## An axis-aligned (then yawed) box: the workhorse. `size` is full extents.
func box(center: Vector3, size: Vector3, color: Color, pat: float = 1.0, yaw: float = 0.0) -> void:
	add("box", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center), color, pat)


## A box standing on the ground, from y0 to y1.
func column(x: float, z: float, y0: float, y1: float, sx: float, sz: float, color: Color, pat: float = 1.0, yaw: float = 0.0) -> void:
	box(Vector3(x, (y0 + y1) * 0.5, z), Vector3(sx, y1 - y0, sz), color, pat, yaw)


func cyl(center: Vector3, radius: float, height: float, color: Color, sides: int = 8, pat: float = 1.0) -> void:
	add("cyl:%d" % sides, Transform3D(Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0)), center), color, pat)


## A flat decal-like quad lying on the ground (XZ), rotated by yaw.
func flat(center: Vector3, size_x: float, size_z: float, color: Color, pat: float = 1.0, yaw: float = 0.0) -> void:
	add("flat", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size_x, 1.0, size_z)), center), color, pat)


## A quad standing up (XY plane), facing +Z before yaw (windows, signs).
func upright(center: Vector3, size_x: float, size_y: float, color: Color, yaw: float = 0.0, pat: float = 1.0) -> void:
	add("quad", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size_x, size_y, 1.0)), center), color, pat)


## A lumpy ellipsoid: leaf clumps, shrubs, rocks.
func blob(center: Vector3, size: Vector3, color: Color, sides: int = 7, yaw: float = 0.0, pat: float = 1.0) -> void:
	add("sphere:%d" % sides, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center), color, pat)


## Raw world-space triangles (tape, chalk outlines, ropes). Flat normal from the winding.
func tri(a: Vector3, b: Vector3, c_: Vector3, color: Color, pat: float = 1.0) -> void:
	var c: Chunk = _cell_of((a + b + c_) / 3.0)
	var nn := ((b - a).cross(c_ - a)).normalized()
	var cc := Color(color.r, color.g, color.b, pat)
	c.v.append_array(PackedVector3Array([a, b, c_]))
	c.n.append_array(PackedVector3Array([nn, nn, nn]))
	c.uv.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]))
	c.c.append_array(PackedColorArray([cc, cc, cc]))
	pieces += 1
	verts += 3


## A triangle with a colour at each corner (grass blades: dark root, pale tip).
func tri_c(a: Vector3, b: Vector3, c_: Vector3, ca: Color, cb: Color, cc: Color, pat: float = 1.0) -> void:
	var c: Chunk = _cell_of((a + b + c_) / 3.0)
	var nn := ((b - a).cross(c_ - a)).normalized()
	c.v.append_array(PackedVector3Array([a, b, c_]))
	c.n.append_array(PackedVector3Array([nn, nn, nn]))
	c.uv.append_array(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]))
	c.c.append_array(PackedColorArray([Color(ca.r, ca.g, ca.b, pat), Color(cb.r, cb.g, cb.b, pat), Color(cc.r, cc.g, cc.b, pat)]))
	pieces += 1
	verts += 3


func quad4(a: Vector3, b: Vector3, c_: Vector3, d: Vector3, color: Color, pat: float = 1.0) -> void:
	tri(a, b, c_, color, pat)
	tri(a, c_, d, color, pat)


# ------------------------------------------------------------------ output
func triangle_count() -> int:
	return verts / 3


## One MeshInstance3D per non-empty cell. `vis_end` > 0 hides each chunk beyond that distance.
func build(parent: Node3D, node_name: String, material: Material, shadows: bool = true, vis_end: float = 0.0, with_uv: bool = false) -> Array:
	var out: Array = []
	var keys: Array = cells.keys()
	keys.sort()
	for key in keys:
		var c: Chunk = cells[key]
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = c.v
		arr[Mesh.ARRAY_NORMAL] = c.n
		arr[Mesh.ARRAY_COLOR] = c.c
		if with_uv:
			arr[Mesh.ARRAY_TEX_UV] = c.uv
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = material
		mi.name = "%s_%d_%d" % [node_name, key.x, key.y]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
		parent.add_child(mi)
		out.append(mi)
	return out


## Everything in one ArrayMesh (a single cell, ignoring chunking): composite props like trees and people.
func to_mesh(with_uv: bool = false) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	for key in cells:
		var c: Chunk = cells[key]
		v.append_array(c.v); n.append_array(c.n); col.append_array(c.c); uv.append_array(c.uv)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = col
	if with_uv:
		arr[Mesh.ARRAY_TEX_UV] = uv
	var am := ArrayMesh.new()
	if v.size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am
