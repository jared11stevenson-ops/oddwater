extends RefCounted
## Test-side helpers. Tests (not the bot) may read the truth; these are the few places they do it for the bot's sake.
const Cctv = preload("res://scripts/detective/cctv.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Claims = preload("res://scripts/detective/claims.gd")

static func call_calibrate(sim: RefCounted, c: Dictionary, det: RefCounted, cam_id: String) -> void:
	Cctv.calibrate(sim, c, det, cam_id)


## What the court makes of a bot's plan, without making the accusation.
static func judged(g: RefCounted, plan: Dictionary) -> Dictionary:
	return CaseOps.judge(g.sim, g._truth, g.det, plan["accused"], plan["motive"], plan["method"])


## A notebook entry that makes a case against someone (a lie or a mistake, tagged so for the court): enough to be charged, not enough to be right.
static func frame(g: RefCounted, person: String, id: String = "frame_x") -> void:
	g.det.learn({"id": id, "title": "x", "text": "x", "kind": "testimony", "source": "", "day": 1,
		"claims": Claims.emit(g._truth, [Claims.make("seen", person, "seen_going_out", "", 25.0, "", 1.0, "false", 26.0), Claims.make("said", person, "motive_quarrel", "", -1.0, "", 1.0, "false")], "", "x")})
