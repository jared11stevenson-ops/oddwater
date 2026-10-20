extends Node3D
## A normal human, built from primitives and driven by the same traits as the 2D portrait: same skin, hair, glasses, clothes and
## expression, so the face you saw in the conversation is the person walking down the street. Normal proportions (a stylised
## 5.5-heads figure), chunky and soft. Origin is at the feet; the figure faces -Z.
## The body is baked into a handful of vertex-coloured meshes (torso, two legs, two arms, head with face and hair), so a person is
## ~8 nodes instead of ~40. The NpcManager drives `animate()` itself (one loop for everybody); the player's own body animates itself.

const Portrait = preload("res://scripts/art/portrait.gd")
const Merge = preload("res://scripts/world3d/merger.gd")

static var _mat: StandardMaterial3D

var traits: Dictionary = {}
var height := 1.75
var phase := 0.0
var speed := 0.0                  # metres per second; drives the walk cycle
var talking := false
var expression := "neutral"
var person_id := ""
var managed := false              # true when an NpcManager calls animate() for us
var look_target := Vector3.ZERO   # world point to glance toward when standing (a conversation partner)
var has_look := false
var _hips: Node3D
var _legs: Array = []
var _arms: Array = []
var _head: Node3D
var _head_mesh: MeshInstance3D
var _bob := 0.0
var _gest := 0.0
var _seed := 0.0
var _skin: Color
var _hair: Color
var _build_cache := {}


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.88
		_mat.metallic_specular = 0.2
	return _mat


static func _new_merge():
	var m = Merge.new()
	m.cell = 1.0e9
	return m


static func _part(m, kind: String, col: Color, pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	m.add(kind, Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos), col)


func _mesh_node(parent: Node3D, m, pos: Vector3, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m.to_mesh()
	mi.material_override = material()
	mi.position = pos
	mi.name = node_name
	parent.add_child(mi)
	return mi


## Build the body for a SimPerson (anything with the portrait's fields).
func setup(p: RefCounted, expr: String = "") -> void:
	person_id = p.id
	traits = Portrait.traits_for(p)
	expression = expr if expr != "" else Portrait.expression_for_mood(p.mood_word())
	var r := RandomNumberGenerator.new()
	r.seed = hash(p.id + "body")
	_seed = float(hash(p.id) % 1000) * 0.013
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
	_skin = traits["skin"]
	_hair = traits["hair"]
	var cloth: Color = traits["cloth"]
	var trouser := Color(["3d4a63", "5a5248", "2f3a4a", "6b5b45", "444a55", "5c3f3f", "4a5a48", "6a6a72"][r.randi() % 8])
	if traits["outfit"] == "apron":
		trouser = Color("3a3a42")
	var shoe := Color(["2b2724", "4a3426", "e8e4dc", "2f3a5a", "5a2f2f"][r.randi() % 5])
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.92, 0)
	_hips.name = "Hips"
	add_child(_hips)
	_build_torso(cloth, trouser, broad, r)
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var leg_m = _new_merge()
		_part(leg_m, "capsule:8", trouser, Vector3(0, -0.4, 0), Vector3(0.18, 0.5, 0.18))
		_part(leg_m, "box", shoe, Vector3(0, -0.89, -0.05), Vector3(0.15, 0.1, 0.29))                # the shoe
		_part(leg_m, "box", shoe.lightened(0.35) if shoe.get_luminance() < 0.5 else Color("cfc8bc"), Vector3(0, -0.945, -0.05), Vector3(0.155, 0.03, 0.3))   # the sole
		_part(leg_m, "sphere:6", shoe, Vector3(0, -0.88, -0.17), Vector3(0.14, 0.1, 0.12))              # the toe cap
		_part(leg_m, "cyl:8", trouser.darkened(0.12), Vector3(0, -0.8, 0), Vector3(0.185, 0.06, 0.185))     # the turn-up
		_legs.append(_mesh_node(_hips, leg_m, Vector3(sx * 0.1 * broad, -0.02, 0), "Leg%d" % i))
		var arm_m = _new_merge()
		var sleeves: bool = traits["outfit"] != "apron"
		var long_sleeves := sleeves and (hash(p.id + "sl") % 3 != 0)
		_part(arm_m, "capsule:8", cloth if sleeves else _skin, Vector3(0, -0.22, 0), Vector3(0.145, 0.36, 0.145))
		_part(arm_m, "capsule:8", cloth.darkened(0.04) if long_sleeves else _skin, Vector3(0, -0.5, 0), Vector3(0.125, 0.26, 0.125))
		if long_sleeves:
			_part(arm_m, "cyl:8", cloth.darkened(0.2), Vector3(0, -0.6, 0), Vector3(0.135, 0.04, 0.135))        # the cuff
		_part(arm_m, "sphere:8", _skin, Vector3(0, -0.67, 0), Vector3(0.12, 0.14, 0.12))                         # the hand
		_part(arm_m, "sphere:6", _skin, Vector3(-sx * 0.045, -0.68, -0.05), Vector3(0.05, 0.08, 0.05), Vector3(0.5, 0, 0))   # the thumb
		_arms.append(_mesh_node(_hips, arm_m, Vector3(sx * (0.25 * broad + 0.04), 0.6, 0), "Arm%d" % i))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.87, 0)
	_head.scale = Vector3(1.26, 1.26, 1.26)          # a touch big: faces read at a distance, and it keeps the look friendly
	_head.name = "Head"
	_hips.add_child(_head)
	_bake_head(r)
	set_process(not managed)


func _build_torso(cloth: Color, trouser: Color, broad: float, r: RandomNumberGenerator) -> void:
	var m = _new_merge()
	var skin_d := _skin.darkened(0.14)
	_part(m, "capsule:10", trouser, Vector3(0, 0.02, 0), Vector3(0.38 * broad, 0.34, 0.26))                      # pelvis
	_part(m, "capsule:10", cloth, Vector3(0, 0.34, 0), Vector3(0.4 * broad, 0.5, 0.27))                          # torso
	_part(m, "cyl:10", cloth.darkened(0.14), Vector3(0, 0.12, 0), Vector3(0.405 * broad, 0.08, 0.275))            # the hem, a shade darker
	_part(m, "cyl:10", Color("2b2724"), Vector3(0, 0.06, 0), Vector3(0.39 * broad, 0.045, 0.27))                  # a belt
	_part(m, "box", Color("c9b26a"), Vector3(0, 0.06, -0.135), Vector3(0.05, 0.05, 0.012))                        # the buckle
	match traits["outfit"]:
		"apron":
			_part(m, "box", Color("f6f0e0"), Vector3(0, 0.22, -0.14), Vector3(0.3, 0.62, 0.03))
			_part(m, "box", Color("e6dccb"), Vector3(0, 0.0, -0.157), Vector3(0.22, 0.12, 0.02))
		"collar":
			_part(m, "box", Color("f6f0e0"), Vector3(-0.06, 0.62, -0.1), Vector3(0.1, 0.05, 0.06), Vector3(0, 0, 0.6))
			_part(m, "box", Color("f6f0e0"), Vector3(0.06, 0.62, -0.1), Vector3(0.1, 0.05, 0.06), Vector3(0, 0, -0.6))
			_part(m, "box", cloth.darkened(0.3), Vector3(0, 0.46, -0.138), Vector3(0.035, 0.34, 0.012))            # a tie or placket
			_part(m, "box", cloth.darkened(0.1), Vector3(0.12, 0.42, -0.135), Vector3(0.08, 0.08, 0.012))          # a pocket
		"vneck":
			_part(m, "box", skin_d, Vector3(0, 0.62, -0.135), Vector3(0.1, 0.12, 0.02))
		"hood":
			_part(m, "torus", cloth.darkened(0.2), Vector3(0, 0.64, 0.02), Vector3(0.3, 0.12, 0.3), Vector3(PI / 2.0, 0, 0))
			_part(m, "box", cloth.darkened(0.12), Vector3(0, 0.3, -0.14), Vector3(0.28, 0.1, 0.02))               # the hoodie pocket
		_:
			if r.randf() < 0.4:   # a stripe across the chest
				_part(m, "cyl:10", cloth.lightened(0.25), Vector3(0, 0.44, 0), Vector3(0.405 * broad, 0.05, 0.275))
	_part(m, "cyl:8", skin_d, Vector3(0, 0.68, 0), Vector3(0.1, 0.1, 0.1))                                         # the neck
	_mesh_node(_hips, m, Vector3.ZERO, "Torso")


func _bake_head(r: RandomNumberGenerator) -> void:
	var m = _new_merge()
	var skin := _skin
	var skin_d := skin.darkened(0.14)
	_part(m, "sphere:12", skin, Vector3.ZERO, Vector3(0.28, 0.32, 0.29))
	_part(m, "sphere:6", skin_d, Vector3(-0.14, -0.01, 0), Vector3(0.05, 0.08, 0.05))
	_part(m, "sphere:6", skin_d, Vector3(0.14, -0.01, 0), Vector3(0.05, 0.08, 0.05))
	_part(m, "sphere:6", skin_d, Vector3(0, -0.035, -0.14), Vector3(0.045, 0.05, 0.05))            # nose
	_part(m, "sphere:8", skin.lightened(0.05), Vector3(0, 0.02, -0.12), Vector3(0.2, 0.2, 0.06))    # a soft brow ridge of lighter skin
	var ex: Dictionary = Portrait.EXPR.get(expression, Portrait.EXPR["neutral"])
	var eye_gap := (float(traits["eye_gap"]) - 19.0) / 7.0 * 0.012 + 0.052
	var tilt: float = float(ex["brow"])
	var eye_k := clampf(float(ex["eye"]), 0.3, 1.25)
	var hair := _hair
	for sx in [-1.0, 1.0]:
		_part(m, "sphere:8", Color("fbf8f0"), Vector3(sx * eye_gap, 0.025, -0.122), Vector3(0.05, 0.056 * eye_k, 0.03))
		_part(m, "sphere:6", Color("15131c"), Vector3(sx * eye_gap, 0.025, -0.137), Vector3(0.028, 0.034 * eye_k, 0.02))
		_part(m, "box", hair.darkened(0.3), Vector3(sx * eye_gap, 0.075 + (0.012 if float(ex["eye"]) > 1.1 else 0.0), -0.13), Vector3(0.06, 0.012, 0.012), Vector3(0, 0, -sx * tilt * 0.45))
	var curve: float = float(ex["mouth"])
	for i in 3:
		var f := float(i) - 1.0
		_part(m, "box", Color("8a3b3b"), Vector3(f * 0.03, -0.085 - curve * (-0.008 if i == 1 else 0.004) * -1.0 + (0.0 if i == 1 else curve * 0.007), -0.135), Vector3(0.03, 0.012, 0.012), Vector3(0, 0, -f * curve * 0.55))
	_hair_and_extras(m, r)
	_head_mesh = _mesh_node(_head, m, Vector3.ZERO, "HeadMesh")


func _hair_and_extras(m, r: RandomNumberGenerator) -> void:
	var t := traits
	var hair := _hair
	var style: String = t["style"]
	# hair: a hemisphere cap, set back so the forehead shows; long styles add volume behind; a lighter second cap gives it depth
	if style != "bald":
		_part(m, "hemi:12", hair, Vector3(0, 0.035, 0.015), Vector3(0.31, 0.3, 0.32))
		_part(m, "hemi:8", hair.lightened(0.12), Vector3(0.02, 0.07, -0.01), Vector3(0.27, 0.22, 0.28))
		if style in ["long", "bob", "ponytail", "bun"]:
			_part(m, "capsule:8", hair, Vector3(0, -0.05, 0.075), Vector3(0.28, 0.3 if style != "long" else 0.46, 0.14))
		if style == "bun":
			_part(m, "sphere:8", hair, Vector3(0, 0.17, 0.05), Vector3(0.14, 0.14, 0.14))
		if style == "ponytail":
			_part(m, "capsule:8", hair, Vector3(0.0, -0.1, 0.17), Vector3(0.08, 0.28, 0.08), Vector3(-0.5, 0, 0))
		if style == "curls":
			for i in 7:
				var a := TAU * float(i) / 7.0
				_part(m, "sphere:6", hair, Vector3(cos(a) * 0.12, 0.1 + 0.02 * sin(a * 2.0), sin(a) * 0.1 + 0.02), Vector3(0.1, 0.1, 0.1))
		if style == "side":
			_part(m, "box", hair, Vector3(-0.07, 0.1, -0.1), Vector3(0.14, 0.05, 0.06), Vector3(0, 0, 0.3))
		if style == "short" and hash(person_id + "sp") % 4 == 0:     # spiky tops
			for i in 6:
				var a2 := TAU * float(i) / 6.0
				_part(m, "cone:5", hair, Vector3(cos(a2) * 0.07, 0.17, sin(a2) * 0.06), Vector3(0.05, 0.1, 0.05), Vector3(sin(a2) * 0.4, 0, -cos(a2) * 0.4))
		if style in ["short", "side"] and hash(person_id + "sb") % 3 == 0:        # sideburns and a fringe
			_part(m, "box", hair, Vector3(-0.135, -0.03, -0.03), Vector3(0.03, 0.1, 0.05))
			_part(m, "box", hair, Vector3(0.135, -0.03, -0.03), Vector3(0.03, 0.1, 0.05))
			_part(m, "box", hair, Vector3(0, 0.105, -0.115), Vector3(0.2, 0.035, 0.05))
	elif t["elder"]:
		_part(m, "capsule:8", Color("d9d9de"), Vector3(-0.14, 0.0, 0.03), Vector3(0.04, 0.12, 0.08))
		_part(m, "capsule:8", Color("d9d9de"), Vector3(0.14, 0.0, 0.03), Vector3(0.04, 0.12, 0.08))
	if int(t["beard"]) > 0:
		_part(m, "sphere:8", hair, Vector3(0, -0.095, -0.055), Vector3(0.24, 0.1 if int(t["beard"]) == 2 else 0.06, 0.15))
	if t["glasses"]:
		var eg := (float(t["eye_gap"]) - 19.0) / 7.0 * 0.012 + 0.052
		for sx in [-1.0, 1.0]:
			_part(m, "torus", Color("2a2630"), Vector3(sx * eg, 0.025, -0.145), Vector3(0.085, 0.085, 0.085), Vector3(PI / 2.0, 0, 0))
		_part(m, "box", Color("2a2630"), Vector3(0, 0.03, -0.147), Vector3(0.04, 0.01, 0.01))
	match String(t["hat"]):
		"cap":
			_part(m, "hemi:12", Color("2f8f9d"), Vector3(0, 0.055, 0.0), Vector3(0.325, 0.28, 0.335))
			_part(m, "box", Color("266f7a"), Vector3(0, 0.075, -0.17), Vector3(0.22, 0.02, 0.12))
		"sun":
			_part(m, "cyl:12", Color("e0c27a"), Vector3(0, 0.1, 0), Vector3(0.52, 0.015, 0.52))
			_part(m, "hemi:12", Color("d4b266"), Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.3))
		"band":
			_part(m, "torus", Color("e23d3d"), Vector3(0, 0.09, 0), Vector3(0.3, 0.2, 0.3))


## Rebake the face for a new expression (the mood changed, or a conversation wants a look).
func set_expression(e: String) -> void:
	if e == expression:
		return
	expression = e
	if _head == null:
		return
	if _head_mesh != null:
		_head_mesh.queue_free()
	var r := RandomNumberGenerator.new()
	r.seed = hash(person_id + "body")
	_bake_head(r)


# ------------------------------------------------------------------ motion
func set_speed(v: float) -> void:
	speed = v


func _process(delta: float) -> void:
	animate(delta)


## Advance the walk cycle, the gestures and the idle sway. The NpcManager calls this for its people; your own body calls it itself.
func animate(delta: float) -> void:
	if _hips == null:
		return
	var s := clampf(speed / 1.6, 0.0, 3.0)
	phase += delta * (4.0 + s * 3.2) * (1.0 if speed > 0.05 else 0.0)
	var amp := clampf(s, 0.0, 1.0) * (0.75 if speed < 3.4 else 1.0)
	var swing := sin(phase)
	for i in _legs.size():
		(_legs[i] as Node3D).rotation.x = swing * amp * (1.0 if i == 0 else -1.0)
	if talking and speed < 0.05:
		_gest += delta
	for i in _arms.size():
		var arm := _arms[i] as Node3D
		if talking and speed < 0.05:
			var base := -0.9 + sin(_gest * 3.0 + float(i) * 2.0) * 0.35
			arm.rotation.x = lerpf(arm.rotation.x, base * (1.0 if i == 1 else 0.3), clampf(delta * 8.0, 0.0, 1.0))
		else:
			var tgt := -swing * amp * 0.9 * (1.0 if i == 0 else -1.0)
			arm.rotation.x = lerpf(arm.rotation.x, tgt, clampf(delta * 14.0, 0.0, 1.0)) if speed < 0.05 else tgt
	_bob = absf(sin(phase)) * 0.045 * amp
	var t := Time.get_ticks_msec() * 0.001
	if speed < 0.05:
		_hips.position.y = 0.92 + sin(t * 2.0 + _seed * 20.0) * 0.004
		_hips.rotation.z = sin(t * 0.7 + _seed * 9.0) * 0.012       # a little weight shift
	else:
		_hips.position.y = 0.92 + _bob
		_hips.rotation.z = lerpf(_hips.rotation.z, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	if _head != null:
		var yaw_goal := 0.0
		if talking:
			_head.rotation.x = sin(t * 3.4 + _seed * 7.0) * 0.05
			yaw_goal = sin(t * 0.9 + _seed * 5.0) * 0.12
		else:
			_head.rotation.x = lerpf(_head.rotation.x, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		_head.rotation.y = lerpf(_head.rotation.y, yaw_goal, clampf(delta * 3.0, 0.0, 1.0))


func face_dir(dir: Vector3, delta: float, rate: float = 10.0) -> void:
	if dir.length() < 0.001:
		return
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(delta * rate, 0.0, 1.0))


## Turn slowly to face a world point (a conversation partner, someone talking to you).
func face_point(p: Vector3, delta: float, rate: float = 3.5) -> void:
	var d := p - global_position
	d.y = 0.0
	face_dir(d, delta, rate)


func look_at_point(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)
