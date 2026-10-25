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
					evs.append({"t": h, "who": id, "text": "%s %s" % [(CaseEngine.name_of(sim, id) if hd else "Someone you can place as %s" % CaseEngine.name_of(sim, id)), "arrives"], "ident": true, "arrival": true, "pos": cp, "dir": Vector2.ZERO})
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
				best_ev = {"t": when, "who": who, "text": tx, "ident": face, "pos": cp, "dir": (b - a).normalized()}
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


## The recording as a series of frames, for scrubbing: every `step` hours from `from_h` to `to_h`, who the camera would have on tape and where
## (metres from the camera, +x east, +y south). Only what the camera records: a figure is in a frame only inside its radius, a name only
## where footage() would give one, and the stamp is the camera's own clock. Returns {frames: [{at, figures: [{key, x, y, dx, dy, ident,
## who, note}]}], clock_checked, radius, step}. (How far out the clock is stays hidden until it has been checked.) `key` is an opaque track id so a dot can be followed.
static func frames(sim: RefCounted, c: Dictionary, cam_id: String, from_h: float, to_h: float, step: float, calibrated: bool, recognised: Array = []) -> Dictionary:
	var cam: Dictionary = camera(c, cam_id)
	if cam.is_empty() or step <= 0.0:
		return {"frames": [], "clock_checked": calibrated, "radius": 0.0, "step": step}
	var cp: Vector2 = door_point(cam["lot"])
	var hd: bool = cam["quality"] == "hd"
	var rad := float(cam["radius"])
	var shown := 0.0 if calibrated else float(cam["offset"]) / 60.0
	var k: String = c["killer"]
	var tracks: Array = []        # [{key, who, ident, note, pts: [Vector2], t: [hour at each point]}]
	var wi := 0
	for w in walks(sim, c):
		wi += 1
		if w["who"] == k and c.get("avoids_cams", false):
			continue
		var pts: Array = w["pts"]
		var ts: Array = []
		var t := float(w["t0"])
		for i in pts.size():
			ts.append(t)
			if i < pts.size() - 1:
				t += ((pts[i] as Vector2).distance_to(pts[i + 1]) / WALK_MPS) / 3600.0
		tracks.append({"key": "f%d" % (absi(hash("%s|%d|%s" % [w["who"], wi, cam_id])) % 9000), "who": String(w["who"]), "pts": pts, "t": ts, "trait": _trait_of(c, String(w["who"]))})
	var arrivals: Array = []      # [{who, h}]
	var d: int = int(c["day"])
	for tk in range(1, int(sim.tuning["ticks_per_day"])):
		var h := 6.0 + float(tk) * 0.5
		if h < from_h - 0.3 or h > to_h:
			continue
		if not (hd or not recognised.is_empty()):
			break
		for id in sim.order:
			if (hd or recognised.has(id)) and sim.where_was(id, d, tk) == cam["lot"] and sim.where_was(id, d, tk - 1) != cam["lot"]:
				arrivals.append({"who": id, "h": h})
	var out: Array = []
	var n := int(floor((to_h - from_h) / step + 0.0001))
	for si in range(n + 1):
		var h := from_h + float(si) * step
		var figs: Array = []
		for tr in tracks:
			var ts2: Array = tr["t"]
			var pts2: Array = tr["pts"]
			if pts2.size() < 2 or h < float(ts2[0]) or h > float(ts2[ts2.size() - 1]):
				continue
			var j := 0
			while j < ts2.size() - 2 and float(ts2[j + 1]) < h:
				j += 1
			var span := float(ts2[j + 1]) - float(ts2[j])
			var u := 0.0 if span <= 0.0 else clampf((h - float(ts2[j])) / span, 0.0, 1.0)
			var a: Vector2 = pts2[j]
			var b: Vector2 = pts2[j + 1]
			var pos := a.lerp(b, u)
			var dist := pos.distance_to(cp)
			if dist > rad:
				continue
			var face: bool = hd and dist <= rad * 0.7
			var dir := (b - a).normalized()
			figs.append({"key": tr["key"], "x": pos.x - cp.x, "y": pos.y - cp.y, "dx": dir.x, "dy": dir.y, "ident": face,
				"who": tr["who"] if face else "", "note": "" if face else "a figure with %s" % tr["trait"]})
		for ar in arrivals:
			if h >= float(ar["h"]) and h < float(ar["h"]) + 0.2:
				figs.append({"key": "a%d" % (absi(hash("%s|%s" % [ar["who"], cam_id])) % 9000), "x": 0.0, "y": -rad * 0.12, "dx": 0.0, "dy": 1.0, "ident": true, "who": String(ar["who"]), "note": ""})
		out.append({"at": h + shown, "figures": figs})
	return {"frames": out, "clock_checked": calibrated, "radius": rad, "step": step}


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
	# what the player can scrub through: the times as the camera's own clock shows them, a dot's place and heading, and a name only where the
	# picture was good enough to give one (the same facts the text above already states)
	var shown := 0.0 if cal else float(cam["offset"]) / 60.0
	var tape: Array = []
	for ev in f["events"]:
		var ident: bool = bool(ev["ident"])
		tape.append({"t": float(ev["t"]) + shown, "ident": ident, "who": String(ev["who"]) if ident else "", "text": String(ev["text"]),
			"x": (ev["pos"] as Vector2).x, "y": (ev["pos"] as Vector2).y, "dx": (ev["dir"] as Vector2).x, "dy": (ev["dir"] as Vector2).y})
	return {"text": entry["text"], "learned": learned, "minutes": 30, "tape": tape, "cam": {"x": door_point(cam["lot"]).x, "y": door_point(cam["lot"]).y, "radius": float(cam["radius"]), "calibrated": cal}}


## Check a camera's clock against a real one. After this its footage times are true.
static func calibrate(sim: RefCounted, c: Dictionary, det: RefCounted, cam_id: String) -> Dictionary:
	var cam: Dictionary = camera(c, cam_id)
	if cam.is_empty():
		return {"text": "No such camera.", "minutes": 0}
	det.calibrated[cam_id] = true
	var o: int = int(cam["offset"])
	var txt := "The camera's clock is %s." % ("exactly right" if o == 0 else "%d minutes %s" % [absi(o), "fast" if o > 0 else "slow"])
	return {"text": txt, "minutes": 10}
