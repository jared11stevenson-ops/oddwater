extends SceneTree
func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	for i in 5: await process_frame
	var w: Node3D = hud.world
	print("lots ", w.game.layout.lots.size(), " streets ", w.game.layout.spec["streets"])
	var n := 0
	for id in w.builder.doors:
		if n < 6: print(id, " ", w.builder.doors[id]); n += 1
	print("player ", w.player.global_position, " hour ", w.hour(), " weather ", w._weather)
	print("scene ", w.game.scene_lot())
	print(w.game.layout.lots[0])
	var kinds := {}
	for l in w.game.layout.lots: kinds[l["kind"]] = kinds.get(l["kind"], 0) + 1
	print(kinds)
	print("clock ", w.game.sim.clock, " ", w.game.sim.hour_now())
	root.get_viewport().get_texture().get_image().save_png("/home/user/oddwater/playtest/shots/00_first.png")
	quit()
