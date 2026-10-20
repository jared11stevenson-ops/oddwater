extends RefCounted
## Builds the town's buildings and gardens out of baked primitives: houses with their own walls (siding, brick or plaster), roofs
## (gable, cross-gable, hip, front-gable, flat), porches, chimneys, shutters, fences and hedges, garages with cars, back-yard props.
## Everything is chosen from the lot's hash, so the town is the same every run. The builder owns the meshes; this only fills them.

const Scenery = preload("res://scripts/world3d/scenery.gd")

const SIDING := ["f2dcb3", "e8c9a0", "d9e4c6", "c9dbe8", "f0cfc4", "e6e0cf", "c7d8c0", "e9d7ee", "f4e4a8", "dfc7b0", "b9d0d6", "e8b7a0", "9fb8a8", "d6c3a3"]
const BRICK := ["b5654a", "a65a44", "c07a5a", "9c5a48", "b8836a", "8e5a4a"]
const PLASTER := ["f1e6cf", "e8d5b5", "f0d9d0", "d7e2d0", "e6efe8", "efe0a8", "f4ead8", "dcd0c0"]
const ROOFS := ["b4584a", "a3483c", "6e7fa0", "5b7a5e", "8a6a4a", "c98b4e", "7a5a8a", "3d5a80", "9a4a3a", "55555e", "6b4a3a", "7c8a6a"]
const DOORS := ["a8483a", "5f4632", "2f6a8a", "3f7a52", "d9a23a", "7a3a5a", "2f3a4a", "c9573f"]
const SHUTTERS := ["3f6a52", "2f4a6a", "8a3a3a", "4a4a52", "6a4a2a"]
const TRIM := ["f6f1e4", "f0ead8", "fffaf0"]
const FLOWERS := ["e8506a", "f4c542", "f2f2f2", "b86ad8", "ff8a3d"]
const CARS := ["c9573f", "2f6a8a", "d9d4c4", "3f4a52", "6a8a52", "d9a23a", "8a3a3a", "a9b0b8"]

var b: Node3D            # the builder: .body .detail .ground .glass .lamp (Mergers), batch helpers


func _init(builder: Node3D) -> void:
	b = builder


func _col(list: Array, idx: int) -> Color:
	return Color(list[idx % list.size()])


func _win(x: float, y: float, z: float, w: float, h: float, yaw: float, r: RandomNumberGenerator, lit_p: float = 0.8) -> void:
	var thr := r.randf_range(0.06, 0.95) if r.randf() < lit_p else 0.0
	var curt := Color(["e8d9b0", "c9d6e8", "d7b0b0", "bfd8bf", "f0e6d0", "d9c0e0"][r.randi() % 6])
	b.glass.upright(Vector3(x, y, z), w, h, curt, yaw, thr)


## A front window with a sill, head trim and (sometimes) shutters or a flower box. `n` is the outward normal (0,0,+-1) or (+-1,0,0).
func _window_set(x: float, y: float, z: float, w: float, h: float, nrm: Vector3, trim: Color, r: RandomNumberGenerator, dress: bool) -> void:
	var yaw := atan2(nrm.x, nrm.z)
	_win(x + nrm.x * 0.05, y, z + nrm.z * 0.05, w, h, yaw, r)
	var side := Vector3(nrm.z, 0, -nrm.x)          # along the wall
	var sill_size := Vector3(w + 0.3, 0.09, 0.2) if absf(nrm.z) > 0.5 else Vector3(0.2, 0.09, w + 0.3)
	b.detail.box(Vector3(x + nrm.x * 0.1, y - h * 0.5 - 0.05, z + nrm.z * 0.1), sill_size, trim)
	var head_size := Vector3(w + 0.2, 0.1, 0.12) if absf(nrm.z) > 0.5 else Vector3(0.12, 0.1, w + 0.2)
	b.detail.box(Vector3(x + nrm.x * 0.06, y + h * 0.5 + 0.05, z + nrm.z * 0.06), head_size, trim.darkened(0.04))
	if not dress:
		return
	var k := r.randf()
	if k < 0.38:
		var sc := Color(SHUTTERS[r.randi() % SHUTTERS.size()])
		for s in [-1.0, 1.0]:
			var p: Vector3 = Vector3(x, y, z) + side * float(s) * (w * 0.5 + 0.22) + nrm * 0.06
			var sz := Vector3(0.38, h, 0.06) if absf(nrm.z) > 0.5 else Vector3(0.06, h, 0.38)
			b.detail.box(p, sz, sc, 9.0 / 10.0)
	elif k < 0.55:
		var p2 := Vector3(x, y - h * 0.5 - 0.2, z) + nrm * 0.2
		var bs := Vector3(w * 0.95, 0.22, 0.3) if absf(nrm.z) > 0.5 else Vector3(0.3, 0.22, w * 0.95)
		b.detail.box(p2, bs, Color("7a5a3a"))
		for i in 5:
			var off := side * (float(i) - 2.0) * w * 0.2
			b.detail.blob(p2 + off + Vector3(0, 0.2, 0), Vector3(0.28, 0.26, 0.28), Color(FLOWERS[(i + r.randi()) % FLOWERS.size()]), 5)


## ---------------------------------------------------------------- the house
## Builds one house. Returns {hx, hz, door_x, door_z, hh}. `decor` houses (infill) are scenery: no door registered by the caller.
func house(cx: float, cz: float, face: float, lot_w: float, lot_d: float, hsh: int, size_k: float = 1.0, allow_garage: bool = true) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hsh
	var fw := r.randf_range(12.5, 18.0) * size_k
	var fd := r.randf_range(8.5, 11.5) * size_k
	var floors := 2 if r.randf() < 0.45 else 1
	var hh := 3.1 * floors + 0.3
	var front_gap := 4.8
	var lot_front := cz + face * lot_d / 2.0
	var hz := lot_front - face * (front_gap + fd / 2.0)
	var hx := cx + r.randf_range(-1.5, 1.5)
	var wt := (hsh >> 3) % 100
	var wall: Color
	var wpat := 0.9
	if wt < 42:
		wall = _col(SIDING, hsh >> 5)
		wpat = 0.9
	elif wt < 62:
		wall = _col(BRICK, hsh >> 5)
		wpat = 0.8
	elif wt < 92:
		wall = _col(PLASTER, hsh >> 5)
		wpat = 0.7
	else:
		wall = Color("6f7f8f").lerp(Color("8a6a4a"), r.randf())
		wpat = 0.9
	var trim := _col(TRIM, hsh >> 9)
	var roof := _col(ROOFS, hsh >> 7)
	var yaw_f := 0.0 if face > 0.0 else PI
	var nrm := Vector3(0, 0, face)
	var B = b.body
	var D = b.detail
	# garage on the side with the chimney opposite
	var garage := r.randf() < 0.3 and fw < 15.0 and allow_garage
	var gx_side := 1.0 if r.randf() < 0.5 else -1.0
	# foundation and walls
	B.box(Vector3(hx, 0.27, hz), Vector3(fw + 0.25, 0.54, fd + 0.25), wall.darkened(0.28), 0.4)
	B.box(Vector3(hx, hh / 2.0 + 0.1, hz), Vector3(fw, hh - 0.2, fd), wall, wpat)
	# corner boards and belt course
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			D.box(Vector3(hx + sx * (fw / 2.0 + 0.02), hh / 2.0 + 0.1, hz + sz * (fd / 2.0 + 0.02)), Vector3(0.2, hh - 0.1, 0.2), trim)
	if floors == 2:
		D.box(Vector3(hx, 3.25, hz), Vector3(fw + 0.14, 0.16, fd + 0.14), trim)
	# roof
	var rtype := (hsh >> 11) % 100
	var base_w := fd + 1.6
	var rh := base_w * r.randf_range(0.2, 0.28)
	var chim_x := hx + gx_side * -1.0 * fw * 0.26
	var top_y := hh + rh
	if rtype < 36:        # gable, ridge along x
		B.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(base_w, rh, fw + 0.8)), Vector3(hx, hh + rh / 2.0, hz)), roof, 0.6)
		_gable_end(hx + fw / 2.0 + 0.4 + 0.01, hh, hz, base_w, rh, Vector3(1, 0, 0), wall, wpat)
		_gable_end(hx - fw / 2.0 - 0.4 - 0.01, hh, hz, base_w, rh, Vector3(-1, 0, 0), wall, wpat)
		if r.randf() < 0.55:      # a window in the gable
			_win(hx + fw / 2.0 + 0.45, hh + rh * 0.35, hz, 0.8, 0.8, PI / 2.0, r, 0.6)
	elif rtype < 54:      # front gable, ridge along z
		var bw := fw + 1.4
		rh = bw * r.randf_range(0.16, 0.22)
		top_y = hh + rh
		B.add("prism", Transform3D(Basis.from_scale(Vector3(bw, rh, fd + 1.4)), Vector3(hx, hh + rh / 2.0, hz)), roof, 0.6)
		_gable_end(hz + (fd + 1.4) / 2.0 + 0.01, hh, hx, bw, rh, Vector3(0, 0, 1), wall, wpat, true)
		_gable_end(hz - (fd + 1.4) / 2.0 - 0.01, hh, hx, bw, rh, Vector3(0, 0, -1), wall, wpat, true)
	elif rtype < 76:      # hip
		rh = base_w * r.randf_range(0.2, 0.26)
		top_y = hh + rh
		B.add("hip:%.2f" % r.randf_range(0.4, 0.6), Transform3D(Basis.from_scale(Vector3(fw + 1.5, rh, fd + 1.5)), Vector3(hx, hh + rh / 2.0, hz)), roof, 0.6)
	elif rtype < 90:      # cross gable
		B.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(base_w, rh, fw + 0.8)), Vector3(hx, hh + rh / 2.0, hz)), roof, 0.6)
		_gable_end(hx + fw / 2.0 + 0.4 + 0.01, hh, hz, base_w, rh, Vector3(1, 0, 0), wall, wpat)
		_gable_end(hx - fw / 2.0 - 0.4 - 0.01, hh, hz, base_w, rh, Vector3(-1, 0, 0), wall, wpat)
		var gw := fw * 0.36
		var gl := fd * 0.5 + 1.4
		var grh := gw * 0.5 * 0.85
		var gxo := hx + (r.randf_range(-0.2, 0.2) * fw)
		var gz := hz + face * (fd / 2.0 + 0.7 - gl / 2.0)
		B.add("prism", Transform3D(Basis.from_scale(Vector3(gw + 1.2, grh, gl)), Vector3(gxo, hh + grh / 2.0 + 0.4, gz)), roof.lightened(0.04), 0.6)
		_gable_end(hz + face * (fd / 2.0 + 0.7) + face * 0.01, hh + 0.4, gxo, gw + 1.2, grh, Vector3(0, 0, face), wall, wpat, true)
	else:                 # flat roof with a parapet
		rh = 0.55
		top_y = hh + rh
		B.box(Vector3(hx, hh + 0.1, hz), Vector3(fw + 0.5, 0.3, fd + 0.5), roof.darkened(0.25), 0.6)
		for k in 4:
			var along_x := k < 2
			var sgn := -1.0 if k % 2 == 0 else 1.0
			var sz := Vector3(fw + 0.5, 0.5, 0.25) if along_x else Vector3(0.25, 0.5, fd + 0.5)
			var pp := Vector3(hx, hh + 0.45, hz + sgn * (fd / 2.0 + 0.13)) if along_x else Vector3(hx + sgn * (fw / 2.0 + 0.13), hh + 0.45, hz)
			B.box(pp, sz, wall.lightened(0.06), wpat)
	# chimney (not on flat roofs), with smoke
	if rtype < 90 and r.randf() < 0.6:
		var ch := top_y - hh + 1.5
		B.box(Vector3(chim_x, hh + ch / 2.0 - 0.3, hz), Vector3(0.95, ch, 0.95), Color("94604a"), 0.8)
		D.box(Vector3(chim_x, top_y + 1.15, hz), Vector3(1.15, 0.16, 1.15), Color("6f6a64"))
		b.add_puff(Vector3(chim_x, top_y + 1.35, hz), r.randf())
	# door and porch
	var door_x := hx + (r.randf_range(-0.22, 0.22) * fw if r.randf() < 0.7 else 0.0)
	var door_z := hz + face * (fd / 2.0 + 0.04)
	var dcol := _col(DOORS, hsh >> 13)
	D.box(Vector3(door_x, 1.15, door_z + face * 0.02), Vector3(1.5, 2.3, 0.1), trim)
	B.box(Vector3(door_x, 1.05, door_z + face * 0.06), Vector3(1.1, 2.1, 0.1), dcol, 0.9)
	D.box(Vector3(door_x + 0.38 * -1.0, 1.0, door_z + face * 0.13), Vector3(0.08, 0.08, 0.06), Color("d9b64a"))
	var porch := (hsh >> 15) % 100
	var step_depth := 1.2
	if porch < 28:          # small stoop and canopy
		D.box(Vector3(door_x, 0.1, door_z + face * 0.8), Vector3(2.2, 0.2, 1.4), Color("c9c1b0"), 0.4)
		D.box(Vector3(door_x, 2.65, door_z + face * 0.7), Vector3(2.0, 0.12, 1.3), roof.darkened(0.1))
		for s in [-1.0, 1.0]:
			D.box(Vector3(door_x + s * 0.9, 1.35, door_z + face * 1.25), Vector3(0.1, 2.5, 0.1), trim)
	elif porch < 56:        # a deep porch the width of the house, with railing
		var pw := minf(fw * 0.8, 9.0)
		var pd := 2.0
		D.box(Vector3(door_x, 0.14, door_z + face * (pd / 2.0)), Vector3(pw, 0.28, pd), Color("b5a48a"), 0.2)
		for k in 4:
			var px := door_x - pw / 2.0 + 0.15 + float(k) * (pw - 0.3) / 3.0
			D.box(Vector3(px, 1.4, door_z + face * (pd - 0.15)), Vector3(0.16, 2.6, 0.16), trim)
		D.box(Vector3(door_x, 2.78, door_z + face * (pd / 2.0)), Vector3(pw + 0.3, 0.14, pd + 0.4), roof.darkened(0.12), 0.6)
		D.box(Vector3(door_x - pw * 0.28, 0.85, door_z + face * (pd - 0.15)), Vector3(pw * 0.42, 0.08, 0.08), trim)
		D.box(Vector3(door_x + pw * 0.28, 0.85, door_z + face * (pd - 0.15)), Vector3(pw * 0.42, 0.08, 0.08), trim)
		step_depth = 2.0
	elif porch < 78:        # gabled portico
		D.box(Vector3(door_x, 0.12, door_z + face * 0.9), Vector3(2.8, 0.24, 1.8), Color("c9c1b0"), 0.4)
		for s in [-1.0, 1.0]:
			D.box(Vector3(door_x + s * 1.2, 1.4, door_z + face * 1.7), Vector3(0.18, 2.6, 0.18), trim)
		D.add("prism", Transform3D(Basis.from_scale(Vector3(3.2, 0.9, 2.2)) , Vector3(door_x, 2.95, door_z + face * 1.0)), roof, 0.6)
		step_depth = 1.8
	else:                   # striped awning
		var ac := Color("d65a4a") if (hsh >> 17) % 2 == 0 else Color("3f7a9a")
		for i in 6:
			var sx := door_x - 1.25 + (float(i) + 0.5) * 0.42
			D.add("box", Transform3D(Basis(Vector3.UP, yaw_f) * Basis(Vector3.RIGHT, 0.34) * Basis.from_scale(Vector3(0.42, 0.07, 1.4)), Vector3(sx, 2.6, door_z + face * 0.62)), ac if i % 2 == 0 else Color("f6f0e0"))
		D.box(Vector3(door_x, 0.09, door_z + face * 0.6), Vector3(2.0, 0.18, 1.1), Color("c9c1b0"), 0.4)
	# porch light
	b.lamp.cyl(Vector3(door_x + 1.0, 2.35, door_z + face * 0.18), 0.12, 0.26, Color("fff1c8"), 6)
	b.add_halo(Vector3(door_x + 1.0, 2.35, door_z + face * 0.3), 1.7, 55.0)
	# front windows
	var slots := clampi(int(fw / 3.6), 2, 5)
	for f in floors:
		var y := 1.85 + 3.0 * float(f)
		for k in slots:
			var wx := hx - fw / 2.0 + (float(k) + 0.5) * fw / float(slots)
			if f == 0 and absf(wx - door_x) < 1.9:
				continue
			if f == 0 and garage and false:
				continue
			_window_set(wx, y, door_z, 1.25, 1.35, nrm, trim, r, true)
		# sides and back
		_window_set(hx + fw / 2.0 + 0.04, y, hz, 1.2, 1.3, Vector3(1, 0, 0), trim, r, false)
		_window_set(hx - fw / 2.0 - 0.04, y, hz, 1.2, 1.3, Vector3(-1, 0, 0), trim, r, false)
		_window_set(hx - fw * 0.25, y, hz - face * (fd / 2.0 + 0.04), 1.2, 1.3, Vector3(0, 0, -face), trim, r, false)
		_window_set(hx + fw * 0.25, y, hz - face * (fd / 2.0 + 0.04), 1.2, 1.3, Vector3(0, 0, -face), trim, r, false)
	# garage with its driveway and maybe a car
	var gw2 := 4.6
	var gx := hx + gx_side * (fw / 2.0 + gw2 / 2.0 - 0.2)
	if garage:
		var gd := fd - 1.5
		var gz := hz + face * (fd / 2.0 - gd / 2.0)
		B.box(Vector3(gx, 1.5, gz), Vector3(gw2, 3.0, gd), wall.darkened(0.04), wpat)
		B.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(gd + 1.0, 1.1, gw2 + 0.8)), Vector3(gx, 3.55, gz)), roof.darkened(0.08), 0.6)
		D.box(Vector3(gx, 1.15, gz + face * (gd / 2.0 + 0.04)), Vector3(3.8, 2.3, 0.1), Color("ded9cc"), 0.9)
		var dw_ = b.ground
		dw_.box(Vector3(gx, 0.05, gz + face * (gd / 2.0 + 2.6)), Vector3(4.0, 0.1, 5.4), Color("b9b4a8"), 0.4)
		b.collider(Vector3(gx, 1.5, gz), Vector3(gw2, 3.0, gd))
		if r.randf() < 0.55:
			Scenery.car(D, Vector3(gx, 0.0, gz + face * (gd / 2.0 + 3.2)), 0.0 if face > 0.0 else PI, _col(CARS, r.randi()))
	else:
		# a simple drive and path
		b.ground.box(Vector3(door_x, 0.05, door_z + face * (front_gap - 0.3) / 2.0 + face * 0.4), Vector3(1.7, 0.1, front_gap + 0.2), Color("d9ceb6"), 0.4)
		if r.randf() < 0.35:
			Scenery.car(D, Vector3(hx + gx_side * (fw / 2.0 + 2.2), 0.0, hz + face * (fd / 2.0 + 1.5)), 0.5 * face + r.randf_range(-0.1, 0.1), _col(CARS, r.randi()))
	# front boundary: fence, hedge, wall or nothing
	var fz := lot_front - face * 0.7
	var span := lot_w - 2.0
	var fence := (hsh >> 19) % 100
	var fx0 := cx - span / 2.0
	if fence < 30:         # white picket fence with a gap at the path
		var left := door_x - 0.9 - fx0
		var right := fx0 + span - (door_x + 0.9)
		if left > 1.0:
			D.box(Vector3(fx0 + left / 2.0, 0.5, fz), Vector3(left, 1.0, 0.05), Color("fbf8ee"), 0.0)
		if right > 1.0:
			D.box(Vector3(door_x + 0.9 + right / 2.0, 0.5, fz), Vector3(right, 1.0, 0.05), Color("fbf8ee"), 0.0)
	elif fence < 52:       # clipped hedge
		for seg in 2:
			var s0 := fx0 if seg == 0 else door_x + 1.0
			var s1 := door_x - 1.0 if seg == 0 else fx0 + span
			if s1 - s0 < 1.0:
				continue
			D.box(Vector3((s0 + s1) / 2.0, 0.55, fz), Vector3(s1 - s0, 1.1, 0.9), Color("4f8a43"), 0.3)
			var n := int((s1 - s0) / 2.0)
			for i in n:
				D.blob(Vector3(s0 + (float(i) + 0.5) * (s1 - s0) / float(n), 1.05, fz), Vector3(1.8, 0.7, 1.0), Color("5f9a4c").lightened(r.randf_range(-0.05, 0.05)), 5)
	elif fence < 64:       # low stone wall
		D.box(Vector3(cx, 0.35, fz), Vector3(span, 0.7, 0.35), Color("a9a398"), 0.4)
		D.box(Vector3(cx, 0.72, fz), Vector3(span, 0.08, 0.45), Color("c4beb2"), 0.4)
	# mailbox
	var mx := door_x + 2.3
	D.box(Vector3(mx, 0.55, fz + face * 0.1), Vector3(0.08, 1.1, 0.08), Color("4a3a2a"))
	D.box(Vector3(mx, 1.18, fz + face * 0.1), Vector3(0.3, 0.26, 0.5), Color("2f5a8a") if (hsh >> 21) % 2 == 0 else Color("a8483a"))
	# garden: trees, shrubs and flowerbeds
	var trees := r.randi() % 3
	for i in trees:
		var side := 1.0 if (i + (hsh >> 23)) % 2 == 0 else -1.0
		var tx := cx + side * (fw / 2.0 + r.randf_range(2.6, 5.0))
		tx = clampf(tx, cx - lot_w / 2.0 + 1.6, cx + lot_w / 2.0 - 1.6)
		var tk: String = ["oak", "oak2", "maple", "poplar"][r.randi() % 4]
		b.add_tree(Vector3(tx, 0, hz + r.randf_range(-3.0, 3.0)), r.randf_range(0.8, 1.25), tk)
	if r.randf() < 0.7:
		b.add_bush(Vector3(hx + fw / 2.0 - 1.2, 0, door_z + face * 0.9), r.randf_range(0.8, 1.2))
		b.add_bush(Vector3(hx - fw / 2.0 + 1.2, 0, door_z + face * 0.9), r.randf_range(0.8, 1.2))
	if r.randf() < 0.6:     # a flowerbed under the front windows
		var bx := hx + (fw * 0.3 if door_x < hx else -fw * 0.3)
		D.box(Vector3(bx, 0.1, door_z + face * 0.5), Vector3(3.2, 0.2, 0.9), Color("5a3f2a"), 0.3)
		for i in 7:
			D.blob(Vector3(bx - 1.3 + float(i) * 0.43, 0.32, door_z + face * (0.5 + r.randf_range(-0.2, 0.2))), Vector3(0.3, 0.3, 0.3), Color(FLOWERS[r.randi() % FLOWERS.size()]), 5)
	# back yard: a shed, a trampoline, a table, a clothes line, a bin
	var back_z := hz - face * (fd / 2.0 + 3.5)
	var prop := r.randi() % 6
	match prop:
		0, 1:
			var sx2 := cx + r.randf_range(-6.0, 6.0)
			var sc := Color(["a8483a", "6f8a9a", "8a7a5a", "5f7a5a"][r.randi() % 4])
			B.box(Vector3(sx2, 1.05, back_z - face * 2.5), Vector3(3.0, 2.1, 2.4), sc, 0.9)
			B.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(2.8, 0.9, 3.4)), Vector3(sx2, 2.55, back_z - face * 2.5)), Color("5b5b64"), 0.6)
			D.box(Vector3(sx2, 0.95, back_z - face * 2.5 + face * 1.22), Vector3(0.9, 1.8, 0.06), Color("ded4c0"))
			b.collider(Vector3(sx2, 1.05, back_z - face * 2.5), Vector3(3.0, 2.1, 2.4))
		2:
			var tx2 := cx + r.randf_range(-5.0, 5.0)
			D.cyl(Vector3(tx2, 0.85, back_z), 1.8, 0.12, Color("2f2f38"), 10)
			D.cyl(Vector3(tx2, 0.5, back_z), 1.9, 0.02, Color("2f6a8a"), 10)
			for k in 4:
				var a := TAU * float(k) / 4.0 + 0.4
				D.box(Vector3(tx2 + cos(a) * 1.5, 0.42, back_z + sin(a) * 1.5), Vector3(0.08, 0.84, 0.08), Color("aab0b8"))
		3:
			var lx := cx + r.randf_range(-4.0, 4.0)
			for s in [-1.0, 1.0]:
				D.box(Vector3(lx + s * 3.0, 1.2, back_z), Vector3(0.08, 2.4, 0.08), Color("6a6a72"))
			D.box(Vector3(lx, 2.2, back_z), Vector3(6.0, 0.02, 0.02), Color("e8e8e8"))
			for i in 5:
				D.box(Vector3(lx - 2.2 + float(i) * 1.1, 1.8, back_z), Vector3(0.7, 0.8, 0.02), Color(FLOWERS[(i + 1) % FLOWERS.size()]).lerp(Color.WHITE, 0.4))
		4:
			var px := cx + r.randf_range(-4.0, 4.0)
			D.box(Vector3(px, 0.75, back_z), Vector3(1.8, 0.08, 0.8), Color("8a6a4a"), 0.2)
			D.box(Vector3(px, 0.4, back_z - 0.8), Vector3(1.8, 0.06, 0.3), Color("8a6a4a"), 0.2)
			D.box(Vector3(px, 0.4, back_z + 0.8), Vector3(1.8, 0.06, 0.3), Color("8a6a4a"), 0.2)
			D.add("prism", Transform3D(Basis.from_scale(Vector3(2.4, 0.6, 2.4)), Vector3(px, 2.5, back_z)), Color("d65a4a"), 0.6)
			D.box(Vector3(px, 1.2, back_z), Vector3(0.08, 2.4, 0.08), Color("e8e8e8"))
		_:
			pass
	# tufts of grass around the yard
	for i in 14:
		var gx2 := cx + r.randf_range(-lot_w / 2.0 + 0.5, lot_w / 2.0 - 0.5)
		var gz2 := cz + r.randf_range(-lot_d / 2.0 + 0.5, lot_d / 2.0 - 0.8)
		if absf(gx2 - hx) < fw / 2.0 + 0.7 and absf(gz2 - hz) < fd / 2.0 + 0.7:
			continue
		if absf(gx2 - door_x) < 1.2 and (gz2 - hz) * face > 0.0:
			continue
		b.add_tuft(Vector3(gx2, 0, gz2), r.randf_range(0.7, 1.3))
	b.collider(Vector3(hx, hh / 2.0, hz), Vector3(fw, hh, fd))
	return {"hx": hx, "hz": hz, "door_x": door_x, "door_z": door_z, "hh": hh, "front_gap": front_gap, "step": step_depth}


## A triangular gable wall on the end of a roof. `at` is the coordinate along the roof's ridge axis (x for ridge-along-x), `c` the
## centre across it. `nrm` points outward.
func _gable_end(at: float, base_y: float, c: float, base_w: float, rh: float, nrm: Vector3, wall: Color, pat: float, on_z: bool = false) -> void:
	var a: Vector3
	var apex: Vector3
	var z: Vector3
	if on_z:       # the face lies in an XZ-plane at z = at, spanning x = c +- base_w/2
		a = Vector3(c - base_w / 2.0, base_y, at)
		z = Vector3(c + base_w / 2.0, base_y, at)
		apex = Vector3(c, base_y + rh, at)
		if nrm.z > 0.0:
			b.body.tri(a, z, apex, wall, pat)
		else:
			b.body.tri(z, a, apex, wall, pat)
	else:          # lies in the YZ-plane at x = at, spanning z = c +- base_w/2
		a = Vector3(at, base_y, c - base_w / 2.0)
		z = Vector3(at, base_y, c + base_w / 2.0)
		apex = Vector3(at, base_y + rh, c)
		if nrm.x > 0.0:
			b.body.tri(a, apex, z, wall, pat)
		else:
			b.body.tri(z, apex, a, wall, pat)


## ---------------------------------------------------------------- gardens, greens, parks
func green(l: Dictionary) -> void:
	var id := String(l["id"])
	var h := hash(id)
	var r := RandomNumberGenerator.new()
	r.seed = h
	var cx: float = l["x"]
	var cz: float = l["y"]
	var w: float = l["w"]
	var d: float = l["d"]
	var kind := h % 3
	var D = b.detail
	match kind:
		0:      # a small orchard in rows
			for i in 4:
				for j in 3:
					b.add_tree(Vector3(cx - 8.0 + float(i) * 5.4, 0, cz - 9.0 + float(j) * 8.0), 0.78, "oak2")
			D.box(Vector3(cx, 0.4, cz + d / 2.0 - 0.8), Vector3(w - 2.0, 0.8, 0.12), Color("a8885a"), 0.2)
		1:      # allotments: raised beds with crops, and a tool shed
			for i in 4:
				for j in 2:
					var bx := cx - 8.5 + float(i) * 5.6
					var bz := cz - 6.0 + float(j) * 9.0
					D.box(Vector3(bx, 0.18, bz), Vector3(4.4, 0.36, 2.2), Color("5a3f2a"), 0.3)
					for k in 6:
						D.blob(Vector3(bx - 1.8 + float(k) * 0.72, 0.5, bz + (r.randf() - 0.5) * 0.6), Vector3(0.5, 0.5, 0.5), Color(["6aa84f", "8fb84a", "c9573f", "d9a23a"][(i + k + j) % 4]), 5)
			b.body.box(Vector3(cx + 8.0, 1.05, cz + 12.0), Vector3(3.0, 2.1, 2.4), Color("8a7a5a"), 0.9)
			b.body.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis.from_scale(Vector3(2.8, 0.9, 3.4)), Vector3(cx + 8.0, 2.55, cz + 12.0)), Color("5b5b64"), 0.6)
			b.collider(Vector3(cx + 8.0, 1.05, cz + 12.0), Vector3(3.0, 2.1, 2.4))
		_:      # a little playground
			b.ground.box(Vector3(cx, 0.06, cz), Vector3(14.0, 0.12, 12.0), Color("d9c58a"), 0.4)
			for s in [-1.0, 1.0]:
				D.box(Vector3(cx - 3.0 + s * 1.6, 1.3, cz), Vector3(0.12, 2.6, 0.12), Color("c9573f"))
			D.box(Vector3(cx - 3.0, 2.5, cz), Vector3(3.4, 0.12, 0.12), Color("c9573f"))
			D.box(Vector3(cx - 3.0, 1.0, cz + 0.1), Vector3(0.7, 0.06, 0.3), Color("2f2f38"))
			D.add("prism", Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.RIGHT, 0.5) * Basis.from_scale(Vector3(1.2, 1.8, 3.2)), Vector3(cx + 3.5, 1.1, cz)), Color("d9a23a"), 0.4)
			D.box(Vector3(cx + 3.5, 1.05, cz - 1.6), Vector3(1.4, 2.0, 1.4), Color("2f8f9d"), 0.9)
			D.box(Vector3(cx + 3.0, 0.12, cz + 4.6), Vector3(3.0, 0.24, 3.0), Color("e0cf9a"))
	for i in 3:
		b.add_tree(Vector3(cx + r.randf_range(-w / 2.0 + 2.0, w / 2.0 - 2.0), 0, cz + r.randf_range(-d / 2.0 + 2.0, -d / 2.0 + 5.0)), r.randf_range(0.8, 1.2), ["oak", "maple", "poplar"][r.randi() % 3])
	for i in 18:
		b.add_tuft(Vector3(cx + r.randf_range(-w / 2.0, w / 2.0), 0, cz + r.randf_range(-d / 2.0, d / 2.0)), r.randf_range(0.8, 1.4))


func park(l: Dictionary) -> void:
	var id := String(l["id"])
	var cx: float = l["x"]
	var cz: float = l["y"]
	var w: float = l["w"]
	var d: float = l["d"]
	var r := RandomNumberGenerator.new()
	r.seed = hash(id)
	var G = b.ground
	var D = b.detail
	G.box(Vector3(cx, 0.06, cz), Vector3(w - 4.0, 0.12, 3.0), Color("e0d3ae"), 0.4)       # paths
	G.box(Vector3(cx, 0.06, cz), Vector3(3.0, 0.12, d - 3.0), Color("e0d3ae"), 0.4)
	for i in 14:
		var p := Vector3(cx + r.randf_range(-w / 2.0 + 3.0, w / 2.0 - 3.0), 0.0, cz + r.randf_range(-d / 2.0 + 3.0, d / 2.0 - 3.0))
		if absf(p.x - cx) < 3.5 or absf(p.z - cz) < 3.5:
			continue
		b.add_tree(p, r.randf_range(0.9, 1.3), ["oak", "oak2", "maple", "poplar"][r.randi() % 4])
	for i in 60:
		var q := Vector3(cx + r.randf_range(-w / 2.0, w / 2.0), 0.0, cz + r.randf_range(-d / 2.0, d / 2.0))
		if absf(q.x - cx) < 2.0 or absf(q.z - cz) < 2.0:
			continue
		b.add_tuft(q, r.randf_range(0.8, 1.5))
	# pond with a stone rim and reeds
	var pp := Vector3(cx + w * 0.28, 0.0, cz + d * 0.22)
	b.add_pond(pp, 6.0, 4.6)
	for i in 10:
		var a := TAU * float(i) / 10.0
		b.add_rock(pp + Vector3(cos(a) * 6.3, 0, sin(a) * 4.9), r.randf_range(0.5, 0.9))
	for i in 5:
		var a2 := TAU * float(i) / 5.0 + 0.3
		b.add_reed(pp + Vector3(cos(a2) * 5.4, 0, sin(a2) * 4.2))
	# gazebo
	for k in 6:
		var a3 := TAU * float(k) / 6.0
		D.box(Vector3(cx + cos(a3) * 3.0, 1.6, cz + sin(a3) * 3.0), Vector3(0.22, 3.2, 0.22), Color("f1ead8"))
	b.body.add("cone:6", Transform3D(Basis.from_scale(Vector3(8.4, 2.4, 8.4)), Vector3(cx, 4.4, cz)), Color("c9573f"), 0.6)
	D.cyl(Vector3(cx, 0.15, cz), 3.4, 0.3, Color("c9c1b0"), 6, 0.4)
	# benches, bins and lamps along the paths
	for k in 4:
		var bx := cx + (k - 1.5) * 9.0
		D.box(Vector3(bx, 0.5, cz + 5.0), Vector3(2.2, 0.15, 0.7), Color("8a6a4a"), 0.2)
		D.box(Vector3(bx, 0.28, cz + 5.0), Vector3(2.0, 0.5, 0.5), Color("5a4a3a"))
		D.box(Vector3(bx, 0.95, cz + 5.35), Vector3(2.2, 0.5, 0.1), Color("8a6a4a"), 0.2)
	for k in 4:
		b.add_lamp(Vector3(cx + (k - 1.5) * 12.0, 0, cz - 4.0), 4.2)
	# a playground corner
	D.box(Vector3(cx - w * 0.3, 1.3, cz - d * 0.25), Vector3(0.12, 2.6, 0.12), Color("2f8f9d"))
	D.box(Vector3(cx - w * 0.3 + 2.4, 1.3, cz - d * 0.25), Vector3(0.12, 2.6, 0.12), Color("2f8f9d"))
	D.box(Vector3(cx - w * 0.3 + 1.2, 2.55, cz - d * 0.25), Vector3(2.6, 0.12, 0.12), Color("2f8f9d"))
