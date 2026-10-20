extends RefCounted
## The town's named buildings: shops, civic buildings and the chapel. Brick or plaster fronts with storefront glass, cornices, tilted
## awnings, a sign board (and a near-only Label3D name), side windows, roof clutter, and a landmark-specific silhouette.

const Scenery = preload("res://scripts/world3d/scenery.gd")
const HouseKit = preload("res://scripts/world3d/house_kit.gd")

var b: Node3D


func _init(builder: Node3D) -> void:
	b = builder


func landmark(l: Dictionary) -> void:
	var id := String(l["id"])
	var h := hash(id)
	var r := RandomNumberGenerator.new()
	r.seed = h
	var cx: float = l["x"]
	var cz: float = l["y"]
	var face: float = b._side_sign(l)
	var span := float(l["w"])
	var B = b.body
	var D = b.detail
	var G = b.ground
	var fw := span * 0.86
	var fd := float(l["d"]) * 0.62
	var hh := 5.4 + float(h % 4) * 0.8 + (2.6 if span > 60.0 else 0.0)
	var wt := (h >> 3) % 3
	var wall: Color
	var wpat := 0.7
	if wt == 0:
		wall = Color(HouseKit.BRICK[(h >> 5) % HouseKit.BRICK.size()])
		wpat = 0.8
	elif wt == 1:
		wall = Color(HouseKit.PLASTER[(h >> 5) % HouseKit.PLASTER.size()])
	else:
		wall = Color(HouseKit.SIDING[(h >> 5) % HouseKit.SIDING.size()])
		wpat = 0.9
	var roof := Color(["c9573f", "2f8f9d", "d19a2e", "6d5a9a", "4f8a5f", "b85a7a", "3d5a80"][h % 7])
	var trim := Color("f6f1e4")
	var lot_front := cz + face * float(l["d"]) / 2.0
	var hz := lot_front - face * (3.6 + fd / 2.0)
	var yaw_f := 0.0 if face > 0.0 else PI
	var door_z := hz + face * (fd / 2.0)
	# forecourt paving
	G.box(Vector3(cx, 0.05, lot_front - face * 1.9), Vector3(span - 0.6, 0.1, 3.8), Color("cfc7b6"), 0.4)
	# the body, a plinth and a cornice
	B.box(Vector3(cx, 0.35, hz), Vector3(fw + 0.4, 0.7, fd + 0.4), wall.darkened(0.25), 0.4)
	B.box(Vector3(cx, hh / 2.0 + 0.2, hz), Vector3(fw, hh - 0.4, fd), wall, wpat)
	D.box(Vector3(cx, hh - 0.1, hz), Vector3(fw + 0.7, 0.4, fd + 0.7), trim.darkened(0.04))
	D.box(Vector3(cx, 4.05, hz + face * (fd / 2.0 + 0.03)), Vector3(fw + 0.2, 0.25, 0.14), trim.darkened(0.08))       # the sign band
	for sx in [-1.0, 1.0]:
		D.box(Vector3(cx + sx * (fw / 2.0 + 0.04), hh / 2.0, door_z - face * 0.04), Vector3(0.4, hh, 0.4), trim.darkened(0.05))     # pilasters
	# roof: flat with a parapet, or a low gable on some
	if h % 3 == 0:
		B.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(fd + 1.6, 2.8, fw + 1.2)), Vector3(cx, hh + 1.4, hz)), roof, 0.6)
		b.kit._gable_end(cx + fw / 2.0 + 0.6 + 0.01, hh, hz, fd + 1.6, 2.8, Vector3(1, 0, 0), wall, wpat)
		b.kit._gable_end(cx - fw / 2.0 - 0.6 - 0.01, hh, hz, fd + 1.6, 2.8, Vector3(-1, 0, 0), wall, wpat)
	else:
		B.box(Vector3(cx, hh + 0.3, hz), Vector3(fw + 0.8, 0.7, fd + 0.8), roof, 0.6)
		B.box(Vector3(cx, hh + 0.7, hz), Vector3(fw - 0.6, 0.15, fd - 0.6), roof.darkened(0.25), 0.6)
		for k in 2:
			D.box(Vector3(cx - fw * 0.25 + float(k) * fw * 0.5, hh + 1.2, hz - face * 1.0), Vector3(1.6, 0.9, 1.6), Color("9a9fa6"), 0.1)       # rooftop units
		D.box(Vector3(cx + fw * 0.1, hh + 1.8, hz), Vector3(0.12, 2.2, 0.12), Color("3a3d46"))
	# the door, double leaves with a frame, and a lamp
	D.box(Vector3(cx, 1.4, door_z + face * 0.02), Vector3(2.9, 2.8, 0.14), trim)
	B.box(Vector3(cx - 0.52, 1.3, door_z + face * 0.08), Vector3(0.95, 2.6, 0.1), Color("5f4632"), 0.9)
	B.box(Vector3(cx + 0.52, 1.3, door_z + face * 0.08), Vector3(0.95, 2.6, 0.1), Color("5f4632"), 0.9)
	b.lamp.cyl(Vector3(cx + 1.9, 2.9, door_z + face * 0.3), 0.15, 0.3, Color("fff1c8"), 6)
	b.add_halo(Vector3(cx + 1.9, 2.9, door_z + face * 0.4), 2.2, 70.0)
	b.add_halo(Vector3(cx - 1.9, 2.9, door_z + face * 0.4), 2.2, 70.0)
	b.lamp.cyl(Vector3(cx - 1.9, 2.9, door_z + face * 0.3), 0.15, 0.3, Color("fff1c8"), 6)
	# a striped awning, tilted, over the entrance and the shop windows
	var stripes := maxi(6, int(fw / 1.2))
	var ac := Color(["e23d3d", "2f8f9d", "3f7a52", "d9a23a"][h % 4])
	for i in stripes:
		var sx2 := cx - fw / 2.0 + (float(i) + 0.5) * fw / float(stripes)
		D.add("box", Transform3D(Basis(Vector3.UP, yaw_f) * Basis(Vector3.RIGHT, 0.32) * Basis.from_scale(Vector3(fw / float(stripes), 0.08, 1.9)), Vector3(sx2, 3.35, door_z + face * 0.95)), ac if i % 2 == 0 else Color("f6f0e0"))
	# storefront windows either side of the door, upper windows above, and side windows
	var n_ground := maxi(2, int(fw / 6.0))
	for k in n_ground:
		var wx := cx - fw / 2.0 + (float(k) + 0.5) * fw / float(n_ground)
		if absf(wx - cx) < 2.6:
			continue
		var thr := r.randf_range(0.05, 0.9) if (h >> k) % 4 != 0 else 0.0
		b.glass.upright(Vector3(wx, 2.0, door_z + face * 0.06), 2.8, 2.0, Color("f0e2c0"), yaw_f, thr)
		D.box(Vector3(wx, 0.85, door_z + face * 0.1), Vector3(3.0, 0.14, 0.2), trim.darkened(0.1))
	var floors_up := int((hh - 4.6) / 3.0)
	for f in floors_up:
		var y := 5.6 + float(f) * 3.0
		for k in maxi(2, int(fw / 4.0)):
			var wx2 := cx - fw / 2.0 + (float(k) + 0.5) * fw / float(maxi(2, int(fw / 4.0)))
			var thr2 := r.randf_range(0.05, 0.95) if r.randf() < 0.65 else 0.0
			b.glass.upright(Vector3(wx2, y, door_z + face * 0.06), 1.4, 1.7, Color("e8d9b0"), yaw_f, thr2)
			D.box(Vector3(wx2, y - 0.95, door_z + face * 0.1), Vector3(1.7, 0.1, 0.2), trim.darkened(0.1))
			D.box(Vector3(wx2, y + 0.95, door_z + face * 0.08), Vector3(1.7, 0.12, 0.12), trim.darkened(0.05))
	for sgn in [-1.0, 1.0]:
		for f in maxi(1, floors_up + 1):
			var thr3 := r.randf_range(0.05, 0.9) if r.randf() < 0.7 else 0.0
			b.glass.upright(Vector3(cx + sgn * (fw / 2.0 + 0.05), 2.4 + float(f) * 3.2, hz), 1.5, 1.6, Color("e8d9b0"), sgn * PI / 2.0, thr3)
	# planters and a bench out the front
	for sx3 in [-1.0, 1.0]:
		D.box(Vector3(cx + sx3 * 4.2, 0.4, lot_front - face * 2.2), Vector3(1.4, 0.8, 0.8), Color("8a6a4a"), 0.2)
		for k in 3:
			D.blob(Vector3(cx + sx3 * 4.2 + (float(k) - 1.0) * 0.4, 1.0, lot_front - face * 2.2), Vector3(0.5, 0.5, 0.5), Color(HouseKit.FLOWERS[(k + h) % HouseKit.FLOWERS.size()]), 5)
	D.box(Vector3(cx - fw * 0.28, 0.5, lot_front - face * 1.5), Vector3(2.0, 0.12, 0.55), Color("8a6a4a"), 0.2)
	D.box(Vector3(cx - fw * 0.28, 0.25, lot_front - face * 1.5), Vector3(1.8, 0.5, 0.4), Color("3a3d46"))
	# the name above the door, near only
	var lab := Label3D.new()
	lab.text = String(l["name"]).to_upper()
	lab.font = load("res://assets/fonts/Bangers-Regular.ttf")
	lab.font_size = 96
	lab.pixel_size = 0.0085
	lab.outline_size = 22
	lab.modulate = Color("fff6d8")
	lab.outline_modulate = Color("14121c")
	lab.position = Vector3(cx, 4.55, door_z + face * 0.2)
	lab.rotation = Vector3(0, 0.0 if face < 0.0 else PI, 0)
	lab.double_sided = false
	lab.visibility_range_end = 75.0
	lab.name = "Sign_" + id
	b.add_child(lab)
	D.box(Vector3(cx, 4.55, door_z + face * 0.08), Vector3(minf(fw - 2.0, float(String(l["name"]).length()) * 0.78 + 1.6), 1.05, 0.12), Color("2a2430"))
	# specials
	match id:
		"chapel":
			B.box(Vector3(cx - fw * 0.3, hh + 3.0, hz), Vector3(3.4, 8.0, 3.4), wall, wpat)
			B.add("cone:4", Transform3D(Basis(Vector3.UP, PI / 4.0) * Basis.from_scale(Vector3(4.8, 6.0, 4.8)), Vector3(cx - fw * 0.3, hh + 10.0, hz)), Color("6d5a9a"), 0.6)
			D.box(Vector3(cx - fw * 0.3, hh + 13.8, hz), Vector3(0.2, 1.8, 0.2), Color("f6f0e0"))
			D.box(Vector3(cx - fw * 0.3, hh + 14.1, hz), Vector3(1.0, 0.2, 0.2), Color("f6f0e0"))
			b.glass.upright(Vector3(cx - fw * 0.3, hh + 5.0, hz + face * 1.72), 1.0, 2.0, Color("c9a0e0"), yaw_f, 0.6)
		"town_hall":
			B.box(Vector3(cx, hh + 3.8, hz), Vector3(5.4, 8.0, 5.4), wall, wpat)
			B.add("cyl:20", Transform3D(Basis(Vector3.UP, 0.0) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(3.6, 0.3, 3.6)), Vector3(cx, hh + 5.4, hz + face * 2.75)), Color("f6f0e0"))
			D.box(Vector3(cx, hh + 5.4, hz + face * 2.93), Vector3(0.1, 1.2, 0.04), Color("1f2530"))
			D.box(Vector3(cx + 0.35, hh + 5.4, hz + face * 2.93), Vector3(0.7, 0.1, 0.04), Color("1f2530"))
			B.add("cone:4", Transform3D(Basis(Vector3.UP, PI / 4.0) * Basis.from_scale(Vector3(7.6, 3.8, 7.6)), Vector3(cx, hh + 9.9, hz)), Color("3d5a80"), 0.6)
			for k in 4:
				D.box(Vector3(cx - 4.5 + float(k) * 3.0, 2.6, door_z + face * 1.3), Vector3(0.55, 5.2, 0.55), trim)       # columns
		"school":
			D.add("taper:6", Transform3D(Basis.from_scale(Vector3(0.22, 9.0, 0.22)), Vector3(cx + fw * 0.35, hh + 4.5, hz + face * 6.0)), Color("d6d6dc"))
			B.box(Vector3(cx + fw * 0.35 + 0.9, hh + 8.0, hz + face * 6.0), Vector3(1.6, 1.0, 0.05), Color("e23d3d"))
			G.box(Vector3(cx, 0.06, lot_front + face * 4.0), Vector3(span * 0.6, 0.12, 6.0), Color("8a8e96"), 0.5)
		"clinic", "lakeview_rest":
			D.box(Vector3(cx + fw * 0.3, hh + 0.9, hz + face * (fd / 2.0 + 0.05)), Vector3(1.8, 0.5, 0.1), Color("e23d3d"))
			D.box(Vector3(cx + fw * 0.3, hh + 0.9, hz + face * (fd / 2.0 + 0.05)), Vector3(0.5, 1.8, 0.1), Color("e23d3d"))
		"dam_house":
			B.box(Vector3(cx + 40.0, 4.0, cz - face * 4.0), Vector3(80.0, 8.0, 6.0), Color("b7b4aa"), 0.4)
		"sheriff":
			Scenery.car(D, Vector3(cx + fw * 0.34, 0.0, lot_front - face * 0.3), 0.0 if face > 0.0 else PI, Color("22262e"), true)
		"rising_loaf", "pink_heron", "low_water":
			D.box(Vector3(cx + 3.0, 0.8, lot_front - face * 1.2), Vector3(0.9, 1.4, 0.06), Color("f2e2b8"))     # an A-frame board
	b.collider(Vector3(cx, hh / 2.0, hz), Vector3(fw, hh, fd))
	var sy: float = b._street_y(l)
	var sgn2 := 1.0 if int(l.get("side", 1)) == 1 else -1.0
	b.doors[id] = {"door": Vector3(cx, 0.0, sy + sgn2 * 6.4), "front": Vector3(cx, 0.0, door_z + face * 2.2), "yaw": 0.0 if face < 0.0 else PI, "face": face}
