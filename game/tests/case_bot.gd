extends RefCounted
## A robot detective. It works a case the way a patient human would, and it works it through the PUBLIC surface only: the case file
## (`game.case`), the notebook (`game.det`, its claims) and the game's operations. It is never handed the truth, so everything it
## accuses it has to have found out: it follows names from claim to claim, canvasses, watches tape, dusts, searches, waits for the lab,
## weighs the notebook with Reasoning (the rules of evidence) and accuses whoever the notebook points at hardest.

const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const Reasoning = preload("res://scripts/detective/reasoning.gd")

var g: RefCounted
var sim: RefCounted
var det: RefCounted
var log: Array = []
var _spoken: Dictionary = {}       # npc -> number of full interviews
var _shown: Dictionary = {}        # "npc|entry" -> true
var _focus: Array = []


func _init(game: RefCounted) -> void:
	g = game
	sim = game.sim
	det = game.det


func scene() -> String:
	return String(g.case["scene"])


func examine_scene() -> void:
	for s in g.spots(scene()):
		g.examine(scene(), s["id"])


func interview(npc: String) -> void:
	if not sim.people.has(npc) or not sim.alive(sim.people[npc]):
		return
	for t in ["victim", "suspects", "saw", "alibi"]:
		g.ask(npc, t)
	for p in focus():
		if p != npc:
			g.ask(npc, "alibi", p)
			g.ask(npc, "person", p)
	_spoken[npc] = int(_spoken.get(npc, 0)) + 1


## The handful of names worth asking everyone about: the ones the notebook already points at hardest.
func focus() -> Array:
	if _focus.is_empty():
		refresh_focus()
	return _focus


func refresh_focus() -> void:
	_focus = ranking().slice(0, 8).map(func(x): return x["id"])


func canvass(lot: String, n: int) -> void:
	for id in CaseEngine.neighbors(sim, lot, n, [String(g.case["victim"])]):
		interview(id)


## Work through everyone the notebook names, and the neighbours of each, until no new name turns up (or a few rounds have passed).
func follow_names(rounds: int) -> void:
	for r in rounds:
		var ranked: Array = ranking()
		_focus = ranked.slice(0, 8).map(func(x): return x["id"])
		var todo: Array = []
		for i in ranked.size():
			var id: String = ranked[i]["id"]
			# the notebook's own leads: anyone it has something on, and the first names that turn up
			if int(_spoken.get(id, 0)) <= r and (int(ranked[i]["t"]) != 0 or (r == 0 and i < 10) or id == String(g.case["found_by"])):
				todo.append(id)
		if todo.is_empty():
			break
		for p in todo.slice(0, 14):
			interview(p)
			if r == 0 and int(det.proof_against(p)["opportunity"]) + int(det.proof_against(p)["motive"]) + int(det.proof_against(p)["link"]) + int(det.proof_against(p)["means"]) >= 1:
				canvass(sim.people[p].home, 3)


func press_everyone() -> void:
	var people: Array = []
	var ranked: Array = ranking()
	for i in ranked.size():
		if int(ranked[i]["t"]) != 0 or i < 10:
			people.append(ranked[i]["id"])
	for id in _spoken.keys():
		if not people.has(id) and people.size() < 30:
			people.append(id)
	for id in people:
		for e in det.order.duplicate():
			var key := "%s|%s" % [id, e]
			if _shown.has(key) or String(e).begins_with("cmp_"):
				continue
			_shown[key] = true
			g.present(id, e)


## Door to door: nobody in the notebook points anywhere yet, so ask every adult in Little Mercy what they saw and who they distrust.
func sweep_town() -> void:
	for id in sim.order:
		var p: RefCounted = sim.people[id]
		if id == "player" or not sim.alive(p) or not (p.group in ["adult", "elder"]) or id == String(g.case["victim"]):
			continue
		g.ask(id, "saw")
		g.ask(id, "suspects")


func best_total() -> int:
	var r: Array = ranking()
	return int(r[0]["t"]) if not r.is_empty() else 0


## Anything bagged as an object (an item left behind) is shown around town: somebody always knows whose it is.
func show_objects_around() -> void:
	for eid in det.order.duplicate():
		if not det.known[eid].get("lab", false):
			continue
		for id in sim.order:
			var p: RefCounted = sim.people[id]
			if id == "player" or not sim.alive(p) or not (p.group in ["adult", "elder"]):
				continue
			var key := "%s|%s" % [id, eid]
			if _shown.has(key):
				continue
			_shown[key] = true
			g.present(id, eid)


func records_and_sites() -> void:
	for lot in Brief.layout().by_id:
		if lot == scene():
			continue
		for s in g.spots(lot):
			if s["id"] in ["records", "weapon"]:
				g.examine(lot, s["id"])


## Every camera over three windows, clocks checked; every surface dusted; everyone of interest fingerprinted and compared.
func surveillance_and_prints() -> void:
	for cam in g.cameras():
		g.calibrate_camera(cam["id"])
		for w in [[18.0, 24.0], [24.0, 27.0], [27.0, 30.0]]:
			g.view_camera(cam["id"], w[0], w[1])
	for spot in g.dust_spots():
		g.dust(scene(), spot)
	var who: Array = g.persons_of_interest() + [String(g.case["victim"])]
	for s in who:
		g.take_sample(s)
	for eid in det.order.duplicate():
		if det.known[eid].get("latent", "") != "":
			for s in who:
				g.compare_print(eid, s)


## Anyone who has walked in and confessed is held against the scene before the notebook is weighed.
func test_confessions() -> void:
	for eid in det.order.duplicate():
		var e: Dictionary = det.known[eid]
		if e.get("kind", "") == "confession" and not e.get("tested", false):
			for cl in e.get("claims", []):
				if String(cl.get("predicate", "")) == "confessed_story":
					g.check_confession(String(cl["subject"]))


func lab() -> void:
	for eid in det.order.duplicate():
		if det.known[eid].get("lab", false):
			g.submit_lab(eid)


## Who the notebook points at hardest: opportunity, means, motive and link, less twice what clears them.
func ranking() -> Array:
	var out: Array = []
	for s in g.persons_of_interest():
		var pr: Dictionary = det.proof_against(s)
		var t: int = int(pr["opportunity"]) + int(pr["means"]) * 2 + int(pr["motive"]) + int(pr["link"]) - int(pr["exonerate"]) * 2
		out.append({"id": s, "t": t})
	out.sort_custom(func(a, b): return a["t"] > b["t"])
	return out


func warrant_and_search(target: String) -> void:
	var r: Dictionary = g.warrant(target)
	if r["ok"]:
		g.examine(sim.people[target].home, "search")


func theory(best: String) -> Dictionary:
	var motive := Reasoning.motive_guess(det.known, best)
	if motive == "":
		motive = "grudge"
	var method := Reasoning.method_guess(det.known)
	if method == "":
		method = "blunt"
	return {"accused": best, "motive": motive, "method": method}


## The full job. Returns {accused, motive, method}; the caller makes the accusation (g.accuse) and sees what the court makes of it.
func solve() -> Dictionary:
	examine_scene()
	interview(String(g.case["found_by"]))
	canvass(scene(), 8)
	follow_names(3)
	surveillance_and_prints()
	records_and_sites()
	show_objects_around()
	for pass_i in 2:
		press_everyone()
		follow_names(4)
	lab()
	# a night passes: the lab reports in
	g.dawn()
	press_everyone()
	follow_names(4)
	# nobody stands out: go door to door
	if best_total() < 9:
		sweep_town()
		follow_names(3)
		press_everyone()
	test_confessions()
	var ranked: Array = ranking()
	for i in mini(2, ranked.size()):
		warrant_and_search(ranked[i]["id"])
	lab()
	press_everyone()
	ranked = ranking()
	return theory(String(ranked[0]["id"]))


## A lazy detective: the scene, one chat, and a guess at whoever the notebook names first.
func lazy() -> Dictionary:
	examine_scene()
	interview(String(g.case["found_by"]))
	var pois: Array = g.persons_of_interest()
	var guess: String = pois[1] if pois.size() > 1 else pois[0]
	return {"accused": guess, "motive": "money", "method": "blunt"}
