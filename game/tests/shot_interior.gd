extends SceneTree
## SHOT=/path/prefix xvfb-run godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --path . -s tests/shot_interior.gd
const DetectiveGame = preload("res://scripts/detective/detective_game.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
var prefix := ""

func snap(name: String, frames: int = 8) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefix + "_" + name + ".png")

func _initialize() -> void:
	prefix = OS.get_environment("SHOT")
	UiKit.cfg_path = "user://ui_shot.cfg"
	UiKit.loaded = false
	UiKit.data["tutorial_done"] = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	hud._after_wake()
	var w: Node3D = hud.world
	for pair in [["scene", hud.game.scene_lot()], ["library", "library"], ["pub", "low_water"]]:
		w.arrive_at(pair[1])
		w.interact()
		await snap(pair[0], 10)
	w.sky.set_hour(22.0)
	w.leave()
	w.arrive_at("library"); w.interact()
	await snap("library_night", 10)
	quit()
