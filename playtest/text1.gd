extends SceneTree
const DG = preload("res://scripts/detective/detective_game.gd")
const Bot = preload("res://tests/case_bot.gd")
func _initialize() -> void:
	for s in [25, 7]:
		var g = DG.new(s)
		var c: Dictionary = g.case
		print("##### seed ", s, " scene=", c["scene"], " kind=", c["scene_kind"], " victim job=", g.sim.people[c["victim"]].job)
		print(g.opening())
		var bot = Bot.new(g.sim, c, g.det)
		bot.examine_scene(); bot.interview(c["found_by"])
		for s2 in c["suspects"]: bot.interview(s2)
		for eid in g.det.order.slice(0, 40):
			var e = g.det.known[eid]
			if String(eid).begins_with("cctv"): continue
			print("- [", eid, "] ", e.get("title",""), ": ", String(e.get("text","")).replace("\n", " / ").substr(0, 330))
		for st in g.det.statements.slice(0, 14): print("  ST ", st["npc"], "/", st["topic"], ": ", String(st["text"]).replace("\n"," / ").substr(0, 300))
		while g.beats_seen.size() < 0: pass
		for b in 4:
			var bt = g.take_beat()
			if not bt.is_empty(): print("BEAT ", bt["title"], ": ", String(bt["text"]).substr(0, 400))
	quit()
