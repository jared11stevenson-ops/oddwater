extends Node3D
## Style lab: a tiny Little Mercy diorama to judge the INK / WASH look.
## godot --path game res://scenes/style_lab.tscn -- --hush=1 --truth=0 --shot=out.png

const TOON := preload("res://shaders/toon_ink.gdshader")
const OUTLINE := preload("res://shaders/ink_outline.gdshader")
const POST := preload("res://shaders/page_post.gdshader")

# Palette tokens (see 03-art/00-art-direction.md)
const INK := Color("14121c")
const PAPER := Color("f3e9d2")
const LAKE := Color("2f8f9d")
const LAKE_DEEP := Color("14455a")
const MERCY_RED := Color("e23d3d")
const MARIGOLD := Color("f5b82e")
const GRASS := Color("71915a")
const ROOF := Color("b4584a")
const WALL := Color("efe0bd")

var post_mat: ShaderMaterial
var hush := 1.0
var truth := 0.0
var impact := 0.0
var shot := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hush="): hush = float(a.substr(7))
		elif a.begins_with("--truth="): truth = float(a.substr(8))
		elif a.begins_with("--impact="): impact = float(a.substr(9))
		elif a.begins_with("--shot="): shot = a.substr(7)
	_world()
	_post()
	_comic_ui()
	if shot != "":
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func toon(color: Color, wobble := 0.0, line := 0.0035, tr := truth) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("truth", tr)
	m.set_shader_parameter("shadow_tint", color.darkened(0.45).lerp(Color("4a3f7a"), 0.35))
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("width", line)
	o.set_shader_parameter("wobble", wobble)
	m.next_pass = o
	return m


func mesh(parent: Node, m: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func house(at: Vector3, wall: Color, roof: Color, w := 2.0, d := 1.6, h := 1.3) -> void:
	var g := Node3D.new()
	g.position = at
	add_child(g)
	var b := BoxMesh.new(); b.size = Vector3(w, h, d)
	mesh(g, b, toon(wall), Vector3(0, h / 2, 0))
	var r := PrismMesh.new(); r.size = Vector3(w + 0.3, 0.9, d + 0.3)
	mesh(g, r, toon(roof), Vector3(0, h + 0.45, 0))
	var door := BoxMesh.new(); door.size = Vector3(0.4, 0.7, 0.06)
	mesh(g, door, toon(MERCY_RED), Vector3(0, 0.35, d / 2 + 0.02))
	var win := BoxMesh.new(); win.size = Vector3(0.35, 0.35, 0.05)
	mesh(g, win, toon(MARIGOLD, 0.0, 0.002), Vector3(-0.65, 0.8, d / 2 + 0.02))
	mesh(g, win, toon(MARIGOLD, 0.0, 0.002), Vector3(0.65, 0.8, d / 2 + 0.02))


func person(at: Vector3, skin: Color, hair: Color, shirt: Color, pants: Color, wobble := 0.0, face := 0.0) -> void:
	# Ordinary proportions, simple shapes. Acting is in posture and brows, not in the model.
	var g := Node3D.new()
	g.position = at
	g.rotation_degrees.y = face
	g.scale = Vector3(1.55, 1.55, 1.55)
	add_child(g)
	var leg := CapsuleMesh.new(); leg.radius = 0.09; leg.height = 0.55
	mesh(g, leg, toon(pants, wobble, 0.003), Vector3(-0.1, 0.28, 0))
	mesh(g, leg, toon(pants, wobble, 0.003), Vector3(0.1, 0.28, 0))
	var body := CapsuleMesh.new(); body.radius = 0.2; body.height = 0.7
	mesh(g, body, toon(shirt, wobble, 0.003), Vector3(0, 0.82, 0))
	var head := SphereMesh.new(); head.radius = 0.19; head.height = 0.38
	mesh(g, head, toon(skin, wobble, 0.003), Vector3(0, 1.32, 0))
	var hairm := SphereMesh.new(); hairm.radius = 0.2; hairm.height = 0.3
	mesh(g, hairm, toon(hair, wobble, 0.003), Vector3(0, 1.4, -0.03))
	# dot eyes + a short brow line: simple, readable at handheld size
	var dot := SphereMesh.new(); dot.radius = 0.022; dot.height = 0.044
	var inkm := StandardMaterial3D.new(); inkm.albedo_color = INK; inkm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh(g, dot, inkm, Vector3(-0.07, 1.34, 0.17))
	mesh(g, dot, inkm, Vector3(0.07, 1.34, 0.17))
	var brow := BoxMesh.new(); brow.size = Vector3(0.09, 0.012, 0.01)
	mesh(g, brow, inkm, Vector3(-0.07, 1.4, 0.18), Vector3(0, 0, -4))
	mesh(g, brow, inkm, Vector3(0.07, 1.4, 0.18), Vector3(0, 0, 4))


func _world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("f1dfc0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.6)
	e.ambient_light_energy = 0.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.6
	sun.light_color = Color("fff1d6")
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 26.0   # long lens: diorama / tilt-shift feel
	cam.position = Vector3(9.5, 7.0, 11.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.4, -0.5))

	# ridge (the Rise)
	var ground := CylinderMesh.new(); ground.top_radius = 6.0; ground.bottom_radius = 6.4; ground.height = 0.6
	mesh(self, ground, toon(GRASS), Vector3(0, -0.3, 0))
	# the lake: always present, always a different language (wash)
	var lake := CylinderMesh.new(); lake.top_radius = 4.6; lake.bottom_radius = 4.6; lake.height = 0.05
	var lake_mat := toon(LAKE, 0.0, 0.002, maxf(truth, 0.35))
	mesh(self, lake, lake_mat, Vector3(-1.2, 0.0, -6.6), Vector3.ZERO, Vector3(1.6, 1, 0.8))
	var deep := CylinderMesh.new(); deep.top_radius = 3.0; deep.bottom_radius = 3.0; deep.height = 0.06
	mesh(self, deep, toon(LAKE_DEEP, 0.0, 0.0), Vector3(-1.2, 0.02, -6.6), Vector3.ZERO, Vector3(1.4, 1, 0.55))

	house(Vector3(-3.6, 0, 0.0), WALL, ROOF)
	house(Vector3(-0.2, 0, 0.5), Color("d9e6c8"), Color("5f7d95"), 2.2, 1.7, 1.5)
	house(Vector3(3.6, 0, 0.9), Color("f1cfc4"), Color("7a5c8a"))
	# the Chapel on the Rise
	var ch := Node3D.new(); ch.position = Vector3(2.4, 0, -2.4); add_child(ch)
	var cb := BoxMesh.new(); cb.size = Vector3(1.8, 1.4, 2.2)
	mesh(ch, cb, toon(WALL.lightened(0.15)), Vector3(0, 0.7, 0))
	var tower := BoxMesh.new(); tower.size = Vector3(0.7, 2.2, 0.7)
	mesh(ch, tower, toon(WALL), Vector3(0.0, 1.5, 1.4))
	var spire := CylinderMesh.new(); spire.top_radius = 0.0; spire.bottom_radius = 0.5; spire.height = 1.0
	mesh(ch, spire, toon(ROOF), Vector3(0.0, 3.1, 1.4))
	# lamp post (the lantern-bearer's lamp, in miniature)
	var post := CylinderMesh.new(); post.top_radius = 0.04; post.bottom_radius = 0.05; post.height = 1.6
	mesh(self, post, toon(INK.lightened(0.15), 0.0, 0.002), Vector3(-1.3, 0.8, 2.9))
	var lamp := SphereMesh.new(); lamp.radius = 0.16; lamp.height = 0.32
	var lamp_mat := StandardMaterial3D.new(); lamp_mat.albedo_color = MARIGOLD; lamp_mat.emission_enabled = true; lamp_mat.emission = MARIGOLD; lamp_mat.emission_energy_multiplier = 1.6
	mesh(self, lamp, lamp_mat, Vector3(-1.3, 1.7, 2.9))
	var omni := OmniLight3D.new(); omni.position = Vector3(-1.3, 1.7, 2.9); omni.light_color = MARIGOLD; omni.light_energy = 1.2; omni.omni_range = 4.0
	add_child(omni)
	# Blue Line: the flood mark painted round the lower town
	var band := TorusMesh.new(); band.inner_radius = 5.6; band.outer_radius = 5.8
	mesh(self, band, toon(Color("3b78c4"), 0.0, 0.0), Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.3, 1))

	# people: simple, normal, a little different from one another
	person(Vector3(-1.6, 0, 3.0), Color("e8b894"), Color("5a3b2a"), Color("4c8b9a"), Color("3a3f5c"), 0.0, 25)   # Mags
	person(Vector3(0.6, 0, 3.2), Color("c98e68"), Color("20181a"), MARIGOLD, Color("5b4a3a"), 0.0, -25)          # patient
	person(Vector3(2.6, 0, 2.8), Color("f0cdb0"), Color("b9b1a8"), Color("8a4a4a"), Color("3a3a3a"), 1.0, -40)  # a walk-on: wet, unsteady line
	# a red ribbon: the first clue
	var rib := TorusMesh.new(); rib.inner_radius = 0.07; rib.outer_radius = 0.11
	mesh(self, rib, toon(MERCY_RED, 0.0, 0.002), Vector3(-1.45, 0.9, 3.55), Vector3(90, 0, 0))
	# the cat
	var cat := SphereMesh.new(); cat.radius = 0.17; cat.height = 0.28
	mesh(self, cat, toon(Color("e08a3c")), Vector3(-3.0, 0.17, 3.4))
	var ch2 := SphereMesh.new(); ch2.radius = 0.11; ch2.height = 0.22
	mesh(self, ch2, toon(Color("e08a3c")), Vector3(-2.85, 0.3, 3.4))


func _post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST
	post_mat.set_shader_parameter("hush", hush)
	post_mat.set_shader_parameter("truth", truth)
	post_mat.set_shader_parameter("impact", impact)
	rect.material = post_mat
	layer.add_child(rect)


func _comic_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ffe9a8")
	sb.border_color = INK
	sb.set_border_width_all(5)
	sb.set_content_margin_all(18)
	cap.add_theme_stylebox_override("panel", sb)
	cap.position = Vector2(60, 48)
	var l := Label.new()
	l.text = "TUESDAY. 6:31 A.M.\nSomeone tied a ribbon on the door."
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_size_override("font_size", 34)
	cap.add_child(l)
	layer.add_child(cap)
	var sfx := Label.new()
	sfx.text = "shhh…"
	sfx.add_theme_font_size_override("font_size", 130)
	sfx.add_theme_color_override("font_color", MERCY_RED)
	sfx.add_theme_color_override("font_outline_color", INK)
	sfx.add_theme_constant_override("outline_size", 18)
	sfx.rotation_degrees = -7
	sfx.position = Vector2(1330, 700)
	layer.add_child(sfx)
