extends Node3D
## Whole-town diorama from the layout data. godot --path game res://scenes/town_overview.tscn -- --shot=out.png

const Town = preload("res://scripts/core/town_layout.gd")
const TOON := preload("res://shaders/toon_ink.gdshader")
const OUTLINE := preload("res://shaders/ink_outline.gdshader")
const POST := preload("res://shaders/page_post.gdshader")
const KIND := {
	"house": [Color("efe0bd"), 3.2], "home": [Color("f1cfc4"), 3.4], "landmark": [Color("d9e6c8"), 4.5],
	"park": [Color("86a85a"), 0.2], "green": [Color("7fa05c"), 0.2]}
const ROOFS := [Color("b4584a"), Color("5f7d95"), Color("7a5c8a"), Color("a87a3c")]


func toon(c: Color, line := 0.0018) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = TOON
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("halftone_px", 6.0)
	m.set_shader_parameter("shadow_tint", c.darkened(0.45).lerp(Color("4a3f7a"), 0.35))
	if line > 0.0:
		var o := ShaderMaterial.new(); o.shader = OUTLINE; o.set_shader_parameter("width", line)
		m.next_pass = o
	return m


func box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new(); b.size = size
	var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = mat; mi.position = pos
	add_child(mi)


func _ready() -> void:
	var t := Town.new()
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.substr(7)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("f1dfc0")
	e.ambient_light_energy = 0.0; env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); sun.light_energy = 1.6; add_child(sun)
	var b: Dictionary = t.spec["bounds"]
	var cx := (float(b["x0"]) + float(b["x1"])) / 2.0
	var cz := (float(b["y0"]) + float(b["y1"])) / 2.0
	# land, streets, lake (world z = layout y)
	box(Vector3(float(b["x1"]) - float(b["x0"]), 2, float(b["y1"]) - float(b["y0"])), Vector3(cx, -1, cz), toon(Color("71915a"), 0.0))
	box(Vector3(1300, 0.5, 260), Vector3(cx, -0.2, -260), toon(Color("2f8f9d"), 0.0))
	box(Vector3(1300, 0.5, 140), Vector3(cx, -0.1, -290), toon(Color("14455a"), 0.0))
	for st in t.spec["streets"]:
		box(Vector3(960, 0.3, 12), Vector3(cx, 0.1, st["y"]), toon(Color("cfc3a6"), 0.0))
	for x in t.spec["cross_x"]:
		box(Vector3(12, 0.3, 620), Vector3(x, 0.12, cz), toon(Color("cfc3a6"), 0.0))
	var k := 0
	for l in t.lots:
		var def: Array = KIND[l["kind"]]
		var h: float = def[1] * (1.0 + 0.25 * float((k * 7) % 3)) if l["kind"] == "house" else def[1]
		var col: Color = def[0]
		if l["kind"] == "landmark":
			col = [Color("f5b82e"), Color("e23d3d"), Color("3b78c4"), Color("e8d9b0"), Color("d98a5a")][abs(hash(l["id"])) % 5]
			h *= 1.5
		if l["kind"] == "house": col = col.lerp(Color("d8cdb0"), float((k * 5) % 4) / 6.0)
		if l["kind"] == "landmark": h *= 1.6 if l["w"] > 30 else 1.0
		box(Vector3(l["w"] * 0.7, h, l["d"] * 0.7), Vector3(l["x"], h / 2.0, l["y"]), toon(col))
		if l["kind"] in ["house", "home", "landmark"]:
			var pm := PrismMesh.new(); pm.size = Vector3(l["w"] * 0.8, 2.2, l["d"] * 0.8)
			var mi := MeshInstance3D.new(); mi.mesh = pm; mi.material_override = toon(ROOFS[k % ROOFS.size()])
			mi.position = Vector3(l["x"], h + 1.1, l["y"]); add_child(mi)
		if l["id"] == "chapel":
			box(Vector3(5, 18, 5), Vector3(l["x"], 9, l["y"] + 10), toon(Color("efe0bd")))
		if l["id"] == "town_hall":
			box(Vector3(5, 20, 5), Vector3(l["x"], 10, l["y"]), toon(Color("e8d9b0")))
		k += 1
	var cam := Camera3D.new(); cam.fov = 34.0
	cam.position = Vector3(cx + 200, 760, cz + 900); add_child(cam)
	cam.look_at(Vector3(cx, 0, cz - 90))
	var layer := CanvasLayer.new(); add_child(layer)
	var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pm2 := ShaderMaterial.new(); pm2.shader = POST; rect.material = pm2; layer.add_child(rect)
	if shot != "":
		for i in 3: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()
