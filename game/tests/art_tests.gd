extends SceneTree
## godot --headless --path game -s tests/art_tests.gd : every resident has a stable, distinct face in the game's style.

const Portrait = preload("res://scripts/art/portrait.gd")
const World = preload("res://scripts/sim/sim_world.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var w := World.new(7, true)
	var seen: Dictionary = {}
	var skins: Dictionary = {}
	var styles: Dictionary = {}
	var hats := 0; var glasses := 0; var beards := 0; var kids_ok := true; var elders_grey := 0; var elders := 0
	for id in w.order:
		var p: RefCounted = w.people[id]
		ok(p.age > 0 and p.group != "" and p.hobby != "", "%s has an age, group and hobby" % id) if checks < 5 or p.age == 0 else null
		var t: Dictionary = Portrait.traits_for(p)
		var again: Dictionary = Portrait.traits_for(p)
		if str(t) != str(again):
			ok(false, "face of %s is stable" % id)
		seen[str([t["skin"], t["hair"], t["style"], t["cloth"], t["glasses"], t["beard"], t["hat"]])] = true
		skins[t["skin"]] = true
		styles[t["style"]] = true
		hats += 1 if t["hat"] != "" else 0
		glasses += 1 if t["glasses"] else 0
		beards += 1 if t["beard"] > 0 else 0
		if p.group == "child" and (t["beard"] > 0 or t["glasses"] == null):
			kids_ok = false
		if t["elder"]:
			elders += 1
			var h: Color = t["hair"]
			if h.get_luminance() > 0.5:
				elders_grey += 1
	var n: int = w.order.size()
	ok(seen.size() >= n * 0.9, "faces are distinct: %d of %d" % [seen.size(), n])
	ok(skins.size() >= 6 and styles.size() >= 7, "a wide range of skin tones and hair styles (%d, %d)" % [skins.size(), styles.size()])
	ok(hats > 5 and glasses > 15 and beards > 10, "hats, glasses and beards all appear (%d, %d, %d)" % [hats, glasses, beards])
	ok(kids_ok, "children have no beards")
	ok(elders > 15 and elders_grey > elders * 0.5, "most elders have grey or white hair (%d of %d)" % [elders_grey, elders])
	# clothes follow work
	var nurse := ""
	var baker := ""
	for id in w.order:
		var j: String = w.people[id].job
		if nurse == "" and j == "nurse": nurse = id
		if baker == "" and j in ["baker", "line cook", "cook"]: baker = id
	if nurse != "":
		ok(Portrait.traits_for(w.people[nurse])["outfit"] == "vneck", "nurses wear scrubs")
	if baker != "":
		ok(Portrait.traits_for(w.people[baker])["outfit"] == "apron", "cooks wear aprons")
	# expressions follow mood and tone
	ok(Portrait.expression_for_mood("desperate") == "tired" and Portrait.expression_for_mood("radiant") == "happy", "mood sets the expression")
	ok(Portrait.expression_for_tone("cold") == "cross" and Portrait.expression_for_tone("warm") == "happy", "tone sets the expression")
	for e in Portrait.EXPR:
		ok(Portrait.EXPR[e].has("brow") and Portrait.EXPR[e].has("mouth"), "expression %s is complete" % e)
	# the authored cast got everyday detail too
	ok(w.people["mags"].age >= 20 and w.people["mags"].hobby != "" and not w.people["mags"].haunts.is_empty(), "the authored cast has ages, hobbies and haunts")
	print("art_tests: %d checks, %d failed" % [checks, fails])
	quit(fails)
