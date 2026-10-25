extends SceneTree
## godot --headless --path game -s tests/interact_tests.gd : the hands-on parts: the scene plan and the dusting pad.
const SceneView = preload("res://scripts/ui/scene_view.gd")
const DustPad = preload("res://scripts/ui/dust_pad.gd")
var fails := 0
var checks := 0
var tapped := ""
var brushed := false

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var v := SceneView.new()
	v.size = Vector2(620, 340)
	root.add_child(v)
	v.set_spots([{"id": "body", "label": "The body"}, {"id": "door", "label": "The door"}], {})
	v.spot_tapped.connect(func(id: String): tapped = id)
	await process_frame
	await process_frame
	var bp: Vector2 = v._hot["body"]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = bp + Vector2(10, 5)
	v._gui_input(e)
	ok(tapped == "body", "tapping a ring picks that spot: %s" % tapped)
	tapped = ""
	e.position = Vector2(5, 5)
	v._gui_input(e)
	ok(tapped == "", "tapping empty floor does nothing")
	var pad := DustPad.new()
	pad.size = Vector2(620, 280)
	root.add_child(pad)
	pad.brushed.connect(func(_c: float): brushed = true)
	await process_frame
	ok(pad.coverage() == 0.0 and not brushed, "nothing brushed yet")
	var r: Rect2 = pad._rect()
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			pad.brush_at(Vector2(x, y))
			x += 20.0
		y += 18.0
	ok(brushed and pad.coverage() >= 0.6, "brushing enough of the surface completes the dusting: %d%%" % int(pad.coverage() * 100))
	print("interact_tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
