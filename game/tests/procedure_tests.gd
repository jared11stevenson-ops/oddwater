extends SceneTree
## godot --headless --path game -s tests/procedure_tests.gd : CCTV, fingerprints and the people around the suspects.

const World = preload("res://scripts/sim/sim_world.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const CaseOps = preload("res://scripts/detective/case_ops.gd")
const Cctv = preload("res://scripts/detective/cctv.gd")
const Prints = preload("res://scripts/detective/prints.gd")
const Detective = preload("res://scripts/detective/detective.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func make(seed_v: int) -> Array:
	var w := World.new(seed_v, true)
	w.thin_weeks = false
	w.day = 0
	w.start_day()
	var c := CaseEngine.generate(w, seed_v, 0)
	CaseEngine.apply_backstory(w, c)
	w.simulate_rest_of_day()
	CaseEngine.execute(w, c)
	w.slack()
	w.start_day()
	return [w, c]

func _initialize() -> void:
	var N := 24
	var cam_cases := 0
	var k_on_camera := 0
	var id_clear := 0
	var gloved := 0
	var gloved_clean := 0
	var conclusive := 0
	var false_lead := 0
	var covers := 0
	var cracked := 0
	var offset_ok := 0
	for s in range(1, N + 1):
		var wc: Array = make(s)
		var w: RefCounted = wc[0]
		var c: Dictionary = wc[1]
		var k: String = c["killer"]
		var det := Detective.new()
		# ---- CCTV: the killer's real walk shows up on a camera near their street
		var doorbells: Array = c["cameras"]
		if not doorbells.is_empty():
			cam_cases += 1
		var seen_k := false
		var best_supp := 0
		for cam in Cctv.cameras(c):
			for win in [[24.0, 27.0], [27.0, 30.0]]:
				var f: Dictionary = Cctv.footage(w, c, cam["id"], win[0], win[1], true)
				for e in f["events"]:
					if e["who"] == k:
						seen_k = true
				for tc in f["claims"]:
					if tc["subject"] == k:
						best_supp = maxi(best_supp, 3)
		if seen_k:
			k_on_camera += 1
		if best_supp >= 3:
			id_clear += 1
		# ---- the camera clock is not right until you check it
		if not doorbells.is_empty():
			var cam0: Dictionary = doorbells[0]
			var raw: Dictionary = Cctv.footage(w, c, cam0["id"], 24.0, 27.0, false)
			var cal: Dictionary = Cctv.footage(w, c, cam0["id"], 24.0, 27.0, true)
			if int(cam0["offset"]) == 0 or raw["text"] != cal["text"] or raw["events"].is_empty():
				offset_ok += 1
		# ---- prints
		if c["gloves"]:
			gloved += 1
			var any_k := false
			for l in c["latents"]:
				if l["owner"] == k:
					any_k = true
			if not any_k:
				gloved_clean += 1
		else:
			for spot in ["door", "phone", "desk", "floor", "garden"]:
				Prints.dust(w, c, det, c["scene"], spot)
			Prints.take_sample(w, c, det, k)
			if det.samples.get(k, false):
				for eid in det.order.duplicate():
					if det.known[eid].get("latent", "") != "":
						Prints.submit_compare(w, c, det, eid, k)
				CaseOps.lab_results(w, c, det, int(w.day) + 1)
				for eid in det.order:
					if eid.begins_with("cmp_") and det.known[eid]["text"].begins_with("Conclusive") and det.known[eid]["claims"].any(func(cl): return cl["subject"] == k and cl["predicate"] == "print_match"):
						conclusive += 1
						break
			# the partial print can mislead
			var d2 := Detective.new()
			Prints.dust(w, c, d2, c["scene"], "phone")
			var look: String = c.get("lookalike", "")
			if look != "":
				d2.samples[look] = true
				for eid in d2.order.duplicate():
					Prints.submit_compare(w, c, d2, eid, look)
				var res: Array = Prints.compare_results(w, c, d2, int(w.day) + 1)
				for e in res:
					if e["claims"].any(func(cl): return cl["predicate"] == "print_match" and float(cl["certainty"]) < 0.7):
						false_lead += 1
		# ---- families cover for their own, until you break it
		var rel: Array = c["relatives"].get(k, [])
		if not rel.is_empty():
			var d3 := Detective.new()
			var r1: Dictionary = CaseOps.ask(w, c, d3, rel[0], "alibi", k)
			if r1["text"].contains("home with me"):
				covers += 1
				var cctv_e: Dictionary = {}
				for cam in Cctv.cameras(c):
					var v: Dictionary = Cctv.view(w, c, d3, cam["id"], 24.0, 27.0)
					for e in v["learned"]:
						for cl in e["claims"]:
							if cl["subject"] == k or (cl["subject"] == "" and cl["item"] == c["trait"]):
								cctv_e = e
					if not cctv_e.is_empty():
						break
				if not cctv_e.is_empty():
					var pr: Dictionary = CaseOps.present(w, c, d3, rel[0], cctv_e["id"])
					if d3.has("cover_" + rel[0]):
						cracked += 1
	ok(cam_cases >= N - 3, "doorbell cameras exist in almost every case: %d of %d" % [cam_cases, N])
	ok(k_on_camera >= N - 6, "the killer's real walk is on camera in most cases: %d of %d" % [k_on_camera, N])
	ok(offset_ok >= cam_cases - 2, "camera clocks are off until you check them: %d" % offset_ok)
	ok(gloved > 0 and gloved_clean == gloved, "gloves leave nothing of the killer's: %d gloved cases, all clean" % gloved)
	ok(conclusive >= 6, "a good print can be conclusive: %d cases" % conclusive)
	ok(false_lead >= 1, "a partial print can mislead: %d false leads" % false_lead)
	ok(covers >= 5, "families cover for the killer: %d" % covers)
	ok(cracked >= covers - 3, "and the cover breaks when you put the footage in front of them: %d of %d" % [cracked, covers])
	# interviewing connections
	var wc2: Array = make(5)
	var d4 := Detective.new()
	var sus: Array = wc2[1]["suspects"]
	var r: Dictionary = CaseOps.ask(wc2[0], wc2[1], d4, wc2[1]["found_by"], "person", sus[0])
	ok(r["text"].contains(CaseEngine.first(wc2[0], sus[0])), "you can ask anyone about anyone: %s" % r["text"])
	# a refused sample
	var refusals := 0
	for s in range(1, 13):
		var wc3: Array = make(s)
		var d5 := Detective.new()
		wc3[0].people[wc3[1]["killer"]].rel["player"] = {"affinity": -30.0, "trust": 0.0}
		var t: Dictionary = Prints.take_sample(wc3[0], wc3[1], d5, wc3[1]["killer"])
		if not t["ok"]:
			refusals += 1
		var d6 := Detective.new()
		d6.warrants[wc3[1]["killer"]] = true
		ok(Prints.take_sample(wc3[0], wc3[1], d6, wc3[1]["killer"])["ok"], "seed %d: a warrant gets the prints" % s)
	ok(refusals >= 6, "people who don't trust you refuse: %d of 12" % refusals)
	print("procedure_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
