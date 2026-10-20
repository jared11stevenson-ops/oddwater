extends Node3D
## A normal human, built from primitives and driven by the same traits as the 2D portrait: same skin, hair, glasses, clothes and
## expression, so the face you saw in the conversation is the person walking down the street. Normal proportions (a stylised
## 5.5-heads figure), chunky and soft, no exaggeration. Origin is at the feet; the figure faces -Z.

const Portrait = preload("res://scripts/art/portrait.gd")
const Kit = preload("res://scripts/world3d/mesh_kit.gd")

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}

var traits: Dictionary = {}
var height := 1.75
var phase := 0.0
var speed := 0.0                  # metres per second; drives the walk cycle
var talking := false
var expression := "neutral"
var person_id := ""
var _hips: Node3D
var _legs: Array = []
var _arms: Array = []
var _head: Node3D
var _brows: Array = []
var _eyes: Array = []
var _mouth: Array = []
var _bob := 0.0
var _gest := 0.0


static func _mesh(kind: String) -> Mesh:
	if _mesh_cache.has(kind):
		return _mesh_cache[kind]
	var m: Mesh
	match kind:
		"box": m = Kit.box_mesh()
		"sphere": m = Kit.sphere_mesh(12)
		"hemi":
			var s := Kit.sphere_mesh(12)
			s.is_hemisphere = true
			m = s
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = 0.5
			c.height = 2.0
			c.radial_segments = 10
			c.rings = 4
			m = c
		"cyl": m = Kit.cylinder_mesh(12)
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = 0.42
			t.outer_radius = 0.5
			t.rings = 14
			t.ring_segments = 6
			m = t
	_mesh_cache[kind] = m
	return m


static func _mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.9
		m.metallic_specular = 0.2
		_mat_cache[key] = m
	return _mat_cache[key]


func _part(parent: Node3D, kind: String, col: Color, pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = _mat(col)
	mi.transform = Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos)
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## Build the body for a SimPerson (anything with the portrait's fields).
func setup(p: RefCounted, expr: String = "") -> void:
	person_id = p.id
	traits = Portrait.traits_for(p)
	expression = expr if expr != "" else Portrait.expression_for_mood(p.mood_word())
	var r := RandomNumberGenerator.new()
	r.seed = hash(p.id + "body")
	var scale_v := 1.0
	if traits["kid"]:
		scale_v = 0.64
	elif traits["teen"]:
		scale_v = 0.9
	else:
		scale_v = r.randf_range(0.95, 1.06) * (0.98 if traits["elder"] else 1.0)
	var broad := r.randf_range(0.92, 1.12)
	height = 1.75 * scale_v
	scale = Vector3(scale_v, scale_v, scale_v)
	var skin: Color = traits["skin"]
	var skin_d: Color = skin.darkened(0.14)
	var cloth: Color = traits["cloth"]
	var hair: Color = traits["hair"]
	var trouser := Color(["3d4a63", "5a5248", "2f3a4a", "6b5b45", "444a55", "5c3f3f"][r.randi() % 6])
	if traits["outfit"] == "apron":
		trouser = Color("3a3a42")
	_hips = _pivot(self, Vector3(0, 0.92, 0))
	_part(_hips, "capsule", trouser, Vector3(0, 0.02, 0), Vector3(0.38 * broad, 0.34, 0.26))                     # pelvis
	_part(_hips, "capsule", cloth, Vector3(0, 0.34, 0), Vector3(0.4 * broad, 0.5, 0.27))                        # torso
	var sleeves: bool = traits["outfit"] != "apron"
	for sx in [-1.0, 1.0]:
		var leg := _pivot(_hips, Vector3(sx * 0.1 * broad, -0.02, 0))
		_part(leg, "capsule", trouser, Vector3(0, -0.4, 0), Vector3(0.18, 0.5, 0.18))
		_part(leg, "box", Color("2b2724"), Vector3(0, -0.88, -0.04), Vector3(0.14, 0.1, 0.26))
		_legs.append(leg)
		var arm := _pivot(_hips, Vector3(sx * (0.25 * broad + 0.04), 0.6, 0))
		_part(arm, "capsule", cloth if sleeves else skin, Vector3(0, -0.22, 0), Vector3(0.14, 0.36, 0.14))
		_part(arm, "capsule", skin, Vector3(0, -0.5, 0), Vector3(0.12, 0.26, 0.12))
		_part(arm, "sphere", skin, Vector3(0, -0.64, 0), Vector3(0.13, 0.13, 0.13))
		_arms.append(arm)
	# outfit details
	match traits["outfit"]:
		"apron":
			_part(_hips, "box", Color("f6f0e0"), Vector3(0, 0.22, -0.14), Vector3(0.3, 0.62, 0.03))
		"collar":
			_part(_hips, "box", Color("f6f0e0"), Vector3(-0.06, 0.62, -0.1), Vector3(0.1, 0.05, 0.06), Vector3(0, 0, 0.6))
			_part(_hips, "box", Color("f6f0e0"), Vector3(0.06, 0.62, -0.1), Vector3(0.1, 0.05, 0.06), Vector3(0, 0, -0.6))
		"vneck":
			_part(_hips, "box", skin_d, Vector3(0, 0.62, -0.135), Vector3(0.1, 0.12, 0.02), Vector3(0, 0, 0.0))
		"hood":
			_part(_hips, "torus", cloth.darkened(0.2), Vector3(0, 0.64, 0.02), Vector3(0.3, 0.12, 0.3), Vector3(PI / 2.0, 0, 0))
	# neck and head
	_part(_hips, "cyl", skin_d, Vector3(0, 0.68, 0), Vector3(0.1, 0.1, 0.1))
	_head = _pivot(_hips, Vector3(0, 0.87, 0))
	_head.scale = Vector3(1.26, 1.26, 1.26)          # a touch big: faces read at a distance, and it keeps the look friendly
	_part(_head, "sphere", skin, Vector3.ZERO, Vector3(0.28, 0.32, 0.29))
	_part(_head, "sphere", skin_d, Vector3(-0.14, -0.01, 0), Vector3(0.05, 0.08, 0.05))
	_part(_head, "sphere", skin_d, Vector3(0.14, -0.01, 0), Vector3(0.05, 0.08, 0.05))
	_part(_head, "sphere", skin_d, Vector3(0, -0.035, -0.14), Vector3(0.045, 0.05, 0.05))            # nose
	var eye_gap := (float(traits["eye_gap"]) - 19.0) / 7.0 * 0.012 + 0.052
	for sx in [-1.0, 1.0]:
		var white := _part(_head, "sphere", Color("fbf8f0"), Vector3(sx * eye_gap, 0.025, -0.122), Vector3(0.05, 0.056, 0.03))
		var pupil := _part(_head, "sphere", Color("15131c"), Vector3(sx * eye_gap, 0.025, -0.137), Vector3(0.028, 0.034, 0.02))
		_eyes.append([white, pupil])
		var brow := _part(_head, "box", hair.darkened(0.3), Vector3(sx * eye_gap, 0.075, -0.13), Vector3(0.06, 0.012, 0.012))
		_brows.append(brow)
	for i in 3:
		_mouth.append(_part(_head, "box", Color("8a3b3b"), Vector3(0, -0.08, -0.135), Vector3(0.03, 0.012, 0.012)))
	_hair_and_extras(hair, skin)
	set_expression(expression)


func _hair_and_extras(hair: Color, skin: Color) -> void:
	var t := traits
	var style: String = t["style"]
	# hair: a hemisphere cap, set back so the forehead shows; long styles add volume behind
	if style != "bald":
		_part(_head, "hemi", hair, Vector3(0, 0.035, 0.015), Vector3(0.31, 0.3, 0.32))
		if style in ["long", "bob", "ponytail", "bun"]:
			_part(_head, "capsule", hair, Vector3(0, -0.05, 0.075), Vector3(0.28, 0.3 if style != "long" else 0.46, 0.14))
		if style == "bun":
			_part(_head, "sphere", hair, Vector3(0, 0.17, 0.05), Vector3(0.14, 0.14, 0.14))
		if style == "ponytail":
			_part(_head, "capsule", hair, Vector3(0.0, -0.1, 0.17), Vector3(0.08, 0.28, 0.08), Vector3(-0.5, 0, 0))
		if style == "curls":
			for i in 7:
				var a := TAU * float(i) / 7.0
				_part(_head, "sphere", hair, Vector3(cos(a) * 0.12, 0.1 + 0.02 * sin(a * 2.0), sin(a) * 0.1 + 0.02), Vector3(0.1, 0.1, 0.1))
		if style == "side":
			_part(_head, "box", hair, Vector3(-0.07, 0.1, -0.1), Vector3(0.14, 0.05, 0.06), Vector3(0, 0, 0.3))
	elif t["elder"]:
		_part(_head, "capsule", Color("d9d9de"), Vector3(-0.14, 0.0, 0.03), Vector3(0.04, 0.12, 0.08))
		_part(_head, "capsule", Color("d9d9de"), Vector3(0.14, 0.0, 0.03), Vector3(0.04, 0.12, 0.08))
	if int(t["beard"]) > 0:
		_part(_head, "sphere", hair, Vector3(0, -0.095, -0.055), Vector3(0.24, 0.1 if int(t["beard"]) == 2 else 0.06, 0.15))
	if t["glasses"]:
		var eg := (float(t["eye_gap"]) - 19.0) / 7.0 * 0.012 + 0.052
		for sx in [-1.0, 1.0]:
			_part(_head, "torus", Color("2a2630"), Vector3(sx * eg, 0.025, -0.145), Vector3(0.085, 0.085, 0.085), Vector3(PI / 2.0, 0, 0))
		_part(_head, "box", Color("2a2630"), Vector3(0, 0.03, -0.147), Vector3(0.04, 0.01, 0.01))
	match String(t["hat"]):
		"cap":
			_part(_head, "hemi", Color("2f8f9d"), Vector3(0, 0.055, 0.0), Vector3(0.325, 0.28, 0.335))
			_part(_head, "box", Color("266f7a"), Vector3(0, 0.075, -0.17), Vector3(0.22, 0.02, 0.12))
		"sun":
			_part(_head, "cyl", Color("e0c27a"), Vector3(0, 0.1, 0), Vector3(0.52, 0.015, 0.52))
			_part(_head, "hemi", Color("d4b266"), Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3))
		"band":
			_part(_head, "torus", Color("e23d3d"), Vector3(0, 0.09, 0), Vector3(0.3, 0.2, 0.3))


## Brow tilt, eye openness and mouth curve from the same table the portraits use.
func set_expression(e: String) -> void:
	expression = e
	var ex: Dictionary = Portrait.EXPR.get(e, Portrait.EXPR["neutral"])
	var tilt: float = float(ex["brow"])
	for i in _brows.size():
		var sx := -1.0 if i == 0 else 1.0
		(_brows[i] as Node3D).rotation = Vector3(0, 0, -sx * tilt * 0.45)
		(_brows[i] as Node3D).position.y = 0.075 + (0.012 if float(ex["eye"]) > 1.1 else 0.0)
	for pair in _eyes:
		(pair[0] as Node3D).scale.y = 0.056 * clampf(float(ex["eye"]), 0.3, 1.25)
		(pair[1] as Node3D).scale.y = 0.034 * clampf(float(ex["eye"]), 0.3, 1.25)
	var curve: float = float(ex["mouth"])
	for i in _mouth.size():
		var m: Node3D = _mouth[i]
		var f := float(i) - 1.0
		m.position = Vector3(f * 0.03, -0.085 - curve * (-0.008 if i == 1 else 0.004) * -1.0 + (0.0 if i == 1 else curve * 0.007), -0.135)
		m.rotation = Vector3(0, 0, -f * curve * 0.55)


# ------------------------------------------------------------------ motion
func set_speed(v: float) -> void:
	speed = v


func _process(delta: float) -> void:
	if _hips == null:
		return
	var s := clampf(speed / 1.6, 0.0, 3.0)
	phase += delta * (4.0 + s * 3.2) * (1.0 if speed > 0.05 else 0.0)
	var amp := clampf(s, 0.0, 1.0) * (0.75 if speed < 3.4 else 1.0)
	var swing := sin(phase)
	for i in _legs.size():
		(_legs[i] as Node3D).rotation.x = swing * amp * (1.0 if i == 0 else -1.0)
	for i in _arms.size():
		var base := 0.0
		if talking:
			_gest += delta
			base = -0.9 + sin(_gest * 3.0 + float(i) * 2.0) * 0.35
		(_arms[i] as Node3D).rotation.x = (-swing * amp * 0.9 * (1.0 if i == 0 else -1.0)) if not talking else base * (1.0 if i == 1 else 0.3)
		(_arms[i] as Node3D).rotation.z = (0.0 if i == 0 else 0.0)
	_bob = absf(sin(phase)) * 0.045 * amp
	_hips.position.y = 0.92 + _bob
	if speed < 0.05:
		_hips.position.y = 0.92 + sin(Time.get_ticks_msec() * 0.002 + float(hash(person_id) % 7)) * 0.004
	if _head != null:
		_head.rotation.y = lerpf(_head.rotation.y, 0.0, delta * 3.0)


func face_dir(dir: Vector3, delta: float, rate: float = 10.0) -> void:
	if dir.length() < 0.001:
		return
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(delta * rate, 0.0, 1.0))


func look_at_point(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)
