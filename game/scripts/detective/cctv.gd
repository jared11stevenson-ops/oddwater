extends RefCounted
## Surveillance. The town's cameras and the neighbours' doorbell cameras record two things from the sim's own truth: who really
## went in and out of a place, and who really walked past it that night (routes along the sidewalks, with timestamps).
## Cameras are imperfect: some only see a figure, and their clocks are rarely right to the minute.

const Prose = preload("res://scripts/detective/prose.gd")
const Data = preload("res://scripts/core/data.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const PathGrid = preload("res://scripts/world3d/path_grid.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Claims = preload("res://scripts/detective/claims.gd")

const WALK_MPS := 1.4


static func cameras(c: Dictionary) -> Array:
	var out: Array = []
	for cam in Prose.json("detective/cameras.json"):
		out.append(cam)
	for cam in c.get("cameras", []):
		out.append(cam)
	return out


static func camera(c: Dictionary, id: String) -> Dictionary:
	for cam in cameras(c):
		if cam["id"] == id:
			return cam
	return {}


## The point on the sidewalk in front of a lot's door, in town metres (x, z).
static func door_point(lot: String) -> Vector2:
	var layout: RefCounted = Brief.layout()
	var l: Dictionary = layout.by_id.get(lot, {})
	if l.is_empty():
		return Vector2.ZERO
	var sy := 0.0
	for st in layout.spec["streets"]:
		if st["id"] == l["street"]:
			sy = float(st["y"])
	var sgn := 1.0 if int(l.get("side", 1)) == 1 else -1.0
	return Vector2(float(l["x"]), sy + sgn * 6.4)


static func _trait_of(c: Dictionary, id: String) -> String:
	if id == c["killer"]:
		return c["trait"]
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var traits: Array = cb["traits"].filter(func(t): return t != c["trait"])
	return traits[absi(hash(id)) % traits.size()]


## The night's walks: {who, pts: [Vector2], t0 (hour the walk starts)}. Killer to the scene and back; red herrings to their secrets.
static func walks(sim: RefCounted, c: Dictionary) -> Array:
	var out: Array = []
	var hk: float = c["hour"]
	var grid: RefCounted = PathGrid.new(Brief.layout().spec)
	var k: String = c["killer"]
	var kh: Vector2 = door_point(sim.people[k].home)
	var sc: Vector2 = door_point(c["scene"])
	out.append({"who": k, "pts": _route(grid, kh, sc), "t0": hk - 0.5})
	out.append({"who": k, "pts": _route(grid, sc, kh), "t0": hk + 0.3})
	for sid in c["suspects"]:
		var pr: Dictionary = c["profiles"][sid]
		if pr.get("alibi", "") == "secret" and pr["secret_lot"] != sim.people[sid].home:
			var h: Vector2 = door_point(sim.people[sid].home)
			var d: Vector2 = door_point(pr["secret_lot"])
			out.append({"who": sid, "pts": _route(grid, h, d), "t0": hk - 2.4})
			out.append({"who": sid, "pts": _route(grid, d, h), "t0": hk + 1.4})
	return out


static func _route(grid: RefCounted, a: Vector2, b: Vector2) -> Array:
	var pts: Array = []
	for p in grid.route(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y)):
		pts.append(Vector2((p as Vector3).x, (p as Vector3).z))
	return pts


static func _dir_word(from: Vector2, to: Vector2) -> String:
	var d := to - from
	if absf(d.x) > absf(d.y):
		return "east" if d.x > 0 else "west"
	return "south" if d.y > 0 else "north"


static func _closest(a: Vector2, b: Vector2, p: Vector2) -> Dictionary:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 0.0001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	var q := a + ab * t
	return {"d": q.distance_to(p), "along": t * ab.length()}


## View one camera over a window (hours, 24+ = after midnight). `recognised` is who the detective could pick out by sight on a poor
## picture (people already in the notebook). Returns {events, text, claims (templates), offset}.
static func footage(sim: RefCounted, c: Dictionary, cam_id: String, from_h: float, to_h: float, calibrated: bool, recognised: Array = []) -> Dictionary:
	var cam: Dictionary = camera(c, cam_id)
	if cam.is_empty():
		return {"events": [], "text": "No such camera.", "claims": []}
	var cp: Vector2 = door_point(cam["lot"])
	var hd: bool = cam["quality"] == "hd"
	var shown := 0.0 if calibrated else float(cam["offset"]) / 60.0
	var evs: Array = []
	var k: String = c["killer"]
	# 1. people entering and leaving the place that evening (from the sim's history)
	var d: int = int(c["day"])
	var crowd := 0
	for t in range(1, int(sim.tuning["ticks_per_day"])):
		var h := 6.0 + float(t) * 0.5
		if h < from_h or h > to_h:
			continue
		for id in sim.order:
			var now: String = sim.where_was(id, d, t)
			var before: String = sim.where_was(id, d, t - 1)
			if now == cam["lot"] and before != cam["lot"]:
				if hd or recognised.has(id):
					evs.append({"t": h, "who": id, "text": "%s %s" % [(CaseEngine.name_of(sim, id) if hd else "Someone you can place as %s" % CaseEngine.name_of(sim, id)), "arrives"], "ident": true, "arrival": true})
				else:
					crowd += 1
	# 2. the night's walks
	for w in walks(sim, c):
		if w["who"] == k and c.get("avoids_cams", false):
			continue         # a careful killer keeps to the dark between the cameras
		var pts: Array = w["pts"]
		var t := float(w["t0"])
		var best_ev: Dictionary = {}
		var best_d := 1e9
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var seg: float = a.distance_to(b)
			var cl: Dictionary = _closest(a, b, cp)
			var when: float = t + (float(cl["along"]) / WALK_MPS) / 3600.0
			if float(cl["d"]) <= float(cam["radius"]) and when >= from_h and when <= to_h and float(cl["d"]) < best_d:
				var face: bool = hd and float(cl["d"]) <= float(cam["radius"]) * 0.7
				var who: String = w["who"]
				var dirw := _dir_word(a, b)
				var tx := ""
				if face:
					tx = "%s walks past heading %s." % [CaseEngine.name_of(sim, who), dirw]
				else:
					tx = "A figure with %s passes heading %s. The face is not visible." % [_trait_of(c, who), dirw]
				best_d = float(cl["d"])
				best_ev = {"t": when, "who": who, "text": tx, "ident": face}
			t += (seg / WALK_MPS) / 3600.0
		if not best_ev.is_empty():
			evs.append(best_ev)

	evs.sort_custom(func(x, y): return x["t"] < y["t"])
	var lines: Array = []
	for e in evs:
		lines.append("%s - %s" % [Brief.clock_text(fposmod(float(e["t"]) + shown, 24.0)), e["text"]])
	if crowd > 0:
		lines.append("(and %d other people come and go)" % crowd)
	var text := "\n".join(lines) if not lines.is_empty() else "Nothing on this camera in that window."
	var off_txt := ""
	if not calibrated:
		off_txt = "\n(The camera's own clock has not been checked against a real one.)"
	# what each sighting claims. A clock nobody has checked makes every time on the tape less certain; a clock that is badly out puts the
	# figure at the wrong hour: the court (and only the court) knows when that happened.
	var lies: bool = (not calibrated) and absi(int(cam["offset"])) >= 25
	var claims: Array = []
	for ev in evs:
		var seen_at: float = float(ev["t"]) + shown          # hours, 24+ is after midnight
		var cert: float = (0.95 if ev["ident"] else 0.8) * (1.0 if calibrated else 0.7)
		var tag := "misleading" if lies else "true"
		if ev["ident"]:
			var at_scene: bool = ev.get("arrival", false) and cam["lot"] == c["scene"]
			var pred := "seen_at_scene" if at_scene else ("arrived_at" if ev.get("arrival", false) else "seen_out_at_night")
			claims.append(Claims.make("recorded", String(ev["who"]), pred, String(cam["lot"]), seen_at, "", cert, tag))
		else:
			claims.append(Claims.make("recorded", "", "figure_seen", String(cam["lot"]), seen_at, _trait_of(c, String(ev["who"])), cert, tag))
	return {"events": evs, "text": text + off_txt, "claims": claims, "offset": int(cam["offset"])}


## Open a camera's recording for a window and put what it shows in the notebook.
static func view(sim: RefCounted, c: Dictionary, det: RefCounted, cam_id: String, from_h: float, to_h: float, recognised: Array = []) -> Dictionary:
	var cam: Dictionary = camera(c, cam_id)
	if cam.is_empty():
		return {"text": "No such camera.", "learned": [], "minutes": 0}
	var cal: bool = det.calibrated.get(cam_id, false)
	var f: Dictionary = footage(sim, c, cam_id, from_h, to_h, cal, recognised)
	var id := "cctv_%s_%d_%d%s" % [cam_id, int(from_h * 10), int(to_h * 10), "_c" if cal else ""]
	var learned: Array = []
	var entry := {"id": id, "title": "CCTV: %s" % cam["label"], "text": "%s (%s to %s)\n%s" % [cam["label"], Brief.clock_text(fposmod(from_h, 24.0)), Brief.clock_text(fposmod(to_h, 24.0)), f["text"]],
		"kind": "cctv", "source": cam["lot"], "day": int(sim.day), "calibrated": cal, "camera": cam_id}
	entry["claims"] = Claims.emit(c, f["claims"] if not (f["claims"] as Array).is_empty() else [Claims.make("recorded", "", "observation", String(cam["lot"]))], String(cam["lot"]), String(entry["text"]))
	if not f["events"].is_empty() and det.learn(entry):
		learned.append(entry)
		det.gain_xp(15)
	return {"text": entry["text"], "learned": learned, "minutes": 30}


## Check a camera's clock against a real one. After this its footage times are true.
static func calibrate(sim: RefCounted, c: Dictionary, det: RefCounted, cam_id: String) -> Dictionary:
	var cam: Dictionary = camera(c, cam_id)
	if cam.is_empty():
		return {"text": "No such camera.", "minutes": 0}
	det.calibrated[cam_id] = true
	var o: int = int(cam["offset"])
	var txt := "The camera's clock is %s." % ("exactly right" if o == 0 else "%d minutes %s" % [absi(o), "fast" if o > 0 else "slow"])
	return {"text": txt, "minutes": 10}
