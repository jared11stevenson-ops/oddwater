extends SceneTree
## Fresh-game empty states, newcomers, large text, accusation confirm, a regular night card.
const UiKit = preload("res://scripts/ui/ui_kit.gd")
var prefix := ""
func snap(name: String, frames: int = 6) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png(prefix + "_" + name + ".png")
func _initialize() -> void:
	prefix = OS.get_environment("SHOT")
	UiKit.cfg_path = "user://ui_shot.cfg"
	DirAccess.remove_absolute("user://ui_shot.cfg")
	UiKit.loaded = false
	UiKit.data["tutorial_done"] = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = await main._detective_3d(31)
	hud.card_body.visible_ratio = 1.0
	await snap("f_card", 10)
	hud._after_wake()
	var g: RefCounted = hud.game
	hud.show_case("notebook"); await snap("f_notes_empty")
	hud.show_case("news"); await snap("f_news_empty")
	hud.show_case("people"); await snap("f_people")
	g._welcome_newcomer()
	g._welcome_newcomer()
	hud.show_case("people"); await snap("f_people_new")
	hud.show_case("cctv"); await snap("f_cctv")
	hud.show_case("accuse")
	hud._pick("culprit", g.suspects()[0]); hud._pick("motive", "money"); hud._pick("method", "knife")
	hud._accuse_tap(); await snap("f_accuse_armed")
	hud.show_case("court"); await snap("f_court")
	hud.close_panel()
	UiKit.data["text_scale"] = 1.3
	hud._layout()
	hud.show_case("case"); await snap("f_case_big")
	hud.show_talk(g._truth["found_by"]); await snap("f_talk_big")
	hud.close_panel(); await snap("f_hud_big", 20)
	UiKit.data["text_scale"] = 1.0
	hud._layout()
	hud.travel_to_objective()
	await snap("f_travelled", 20)
	g.det.points = 0
	g.sim.advance(40)
	g.phase = "day"
	hud.world.end_of_day()
	await snap("f_night", 12)
	quit()
