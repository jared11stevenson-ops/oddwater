extends RefCounted
## A robot detective. It works a case the way a patient human would, using only what the operations let it do.

const CaseOps = preload("res://scripts/detective/case_ops.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Detective = preload("res://scripts/detective/detective.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const CaseOpsRef = preload("res://tests/case_bot_helpers.gd")

var sim: RefCounted
var c: Dictionary
var det: RefCounted
var log: Array = []


func _init(world: RefCounted, case_dict: Dictionary, detective: RefCounted = null) -> void:
	sim = world
	c = case_dict
	det = detective if detective != null else Detective.new()


func examine_scene() -> void:
	for s in CaseOps.spots_at(sim, c, c["scene"]):
		CaseOps.examine(sim, c, det, c["scene"], s["id"])


func interview(npc: String) -> void:
	for t in ["victim", "suspects", "saw"]:
		CaseOps.ask(sim, c, det, npc, t)
	CaseOps.ask(sim, c, det, npc, "alibi")
	for s in c["suspects"]:
		CaseOps.ask(sim, c, det, npc, "alibi", s)


func canvass(lot: String, n: int) -> void:
	for id in CaseEngine.neighbors(sim, lot, n, [c["victim"]]):
		interview(id)


func press_everyone() -> void:
	for id in c["suspects"] + c["owner_item_knowers"] + [c["found_by"]]:
		for e in det.order.duplicate():
			CaseOps.present(sim, c, det, id, e)


func records_and_sites() -> void:
	for id in c["clues"]:
		var cl: Dictionary = c["clues"][id]
		if cl["spot"] == "records":
			CaseOps.examine(sim, c, det, cl["lot"], "records")
		if cl["spot"] == "weapon" and c["weapon_at"]["public"]:
			CaseOps.examine(sim, c, det, cl["lot"], "weapon")


## Every camera over three windows, clocks checked; every surface dusted; every suspect fingerprinted and compared.
func surveillance_and_prints() -> void:
	for cam in Cctv.cameras(c):
		CaseOpsRef.call_calibrate(sim, c, det, cam["id"])
		for w in [[18.0, 24.0], [24.0, 27.0], [27.0, 30.0]]:
			Cctv.view(sim, c, det, cam["id"], w[0], w[1])
	for spot in ["door", "phone", "desk", "floor", "garden"]:
		Prints.dust(sim, c, det, c["scene"], spot)
	for s in c["suspects"] + [c["found_by"], c["victim"]]:
		Prints.take_sample(sim, c, det, s)
	for eid in det.order.duplicate():
		if det.known[eid].get("latent", "") != "":
			for s in c["suspects"] + [c["found_by"], c["victim"]]:
				Prints.submit_compare(sim, c, det, eid, s)


func lab() -> void:
	for id in c["clues"]:
		if det.has(id) and c["clues"][id].get("lab", false):
			CaseOps.submit_to_lab(sim, c, det, id)
	CaseOps.lab_results(sim, c, det, int(sim.day) + 1)


func warrant_and_search(target: String) -> void:
	var r: Dictionary = CaseOps.request_warrant(sim, c, det, target)
	if r["ok"]:
		CaseOps.examine(sim, c, det, sim.people[target].home, "search")


## The full job.
func solve() -> Dictionary:
	examine_scene()
	for s in c["suspects"]:
		interview(s)
	interview(c["found_by"])
	canvass(c["scene"], 6)
	for s in c["suspects"]:
		canvass(sim.people[s].home, 4)
	surveillance_and_prints()
	for pass_i in 2:
		press_everyone()
		for s in c["suspects"]:
			interview(s)
		records_and_sites()
	lab()
	press_everyone()
	# a detective accuses whoever the notebook points at hardest
	var best := ""
	var best_t := -1
	for s in c["suspects"]:
		var pr: Dictionary = det.proof_against(s)
		var t: int = int(pr["opportunity"]) + int(pr["means"]) + int(pr["motive"]) + int(pr["link"]) - int(pr["exonerate"]) * 2
		if t > best_t:
			best_t = t
			best = s
	warrant_and_search(best)
	lab()
	return {"accused": best, "result": CaseOps.judge(sim, c, det, best, c["motive"], c["method"])}


## A lazy detective: the scene, one chat, and a guess.
func lazy() -> Dictionary:
	examine_scene()
	interview(c["found_by"])
	var guess: String = c["suspects"][0] if c["suspects"][0] != c["killer"] else c["suspects"][1]
	return {"accused": c["killer"], "result": CaseOps.judge(sim, c, det, c["killer"], c["motive"], c["method"])}
