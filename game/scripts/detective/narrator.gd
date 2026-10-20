extends RefCounted
## The storyteller. Every case is also a told story: a quiet cold open, a slow build of details that do not add up, a turn, a twist,
## and a reflective close. The shape is borrowed from the best of true-crime and strange-stories narration: the voice is calm, the
## details are specific, the dread is in what is left unsaid. Nothing here gives the answer away; it frames what you already found.

const Data = preload("res://scripts/core/data.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


static func _pick(options: Array, seed_text: String) -> String:
	return String(options[absi(hash(seed_text)) % options.size()])


static func title(sim: RefCounted, c: Dictionary) -> String:
	var place: String = Brief.place_name(sim, c["scene"], "")
	var adjectives := ["Quiet", "Last", "Unlocked", "Silent", "Borrowed", "Long"]
	var nouns := ["Death", "Night", "Visitor", "Knock", "Debt", "Promise"]
	var a: String = _pick(adjectives, c["id"] + "a")
	var n: String = _pick(nouns, c["id"] + "n")
	return "The %s %s at %s" % [a, n, place]


## The cold open. It sets the mood, introduces the dead as a person, tells you what was found, and leaves one thing hanging.
static func cold_open(sim: RefCounted, c: Dictionary) -> String:
	var cb: Dictionary = Data.load_json("detective/casebook.json")
	var v: RefCounted = sim.people[c["victim"]]
	var f: String = CaseEngine.name_of(sim, c["found_by"])
	var wx: String = sim.weather_today()
	var weather_line: String = {"clear": "The morning was clear and mild.", "cloudy": "The sky sat low and grey over the lake.", "rain": "It had rained all night, and it was still coming down.", "fog": "A thick fog had come in off the water and not left."}.get(wx, "The morning was still.")
	var p1: String = _pick(cb["openers"], c["id"])
	var p2 := "%s was %d, a %s. They knew the names of the dogs on their street, they paid their bills on the day they were due, and if you had asked anyone in town to describe %s, they would have said the same word: harmless." % [CaseEngine.first(sim, c["victim"]), v.age, String(v.job).to_lower(), CaseEngine.first(sim, c["victim"])]
	var p3 := "%s At about %s, %s found %s at %s. They did not scream. They said later that they had never heard the place so quiet." % [weather_line, CaseEngine.discovery_time(c), f, CaseEngine.first(sim, c["victim"]), Brief.place_name(sim, c["scene"], "")]
	var p4 := "The next few days will put four people in front of you, and every one of them will have something to hide. Only one of them is a killer. But it is not the killer that will keep you awake. It is one small detail, at the scene, that nobody can explain."
	return "\n\n".join([p1, p2, p3, p4])


## Short narrated interludes, fired once when the story reaches a moment. Returns "" if the moment has not come.
static func beat(kind: String, sim: RefCounted, c: Dictionary, det: RefCounted) -> Dictionary:
	var v := CaseEngine.first(sim, c["victim"])
	match kind:
		"first_scene":
			if det.has("c_body"):
				return {"title": "THE SCENE", "text": "You have stood over the dead before. But never somewhere this ordinary: a kitchen that smelled of toast, a calendar with a dentist's appointment circled for Thursday. %s had plans. That is always the part that stays with you." % v}
		"odd_detail":
			if det.has("c_odd"):
				return {"title": "THE DETAIL THAT DIDN'T FIT", "text": "And then you saw it. %s.\n\nYou looked at it for a long time. The Sheriff, who is not given to drama, lowered their voice. 'Don't write that anywhere anyone can read it.'\n\nWhoever did this wanted it noticed. Or wanted it kept. And you are not yet sure which is worse." % c["held_back"]}
		"lie_caught":
			for eid in det.order:
				if eid.begins_with("cover_") or eid == "f_h1_secret":
					return {"title": "EVERYONE LIES", "text": "Everyone lies to a detective. The real skill is knowing which lies are about the dead, and which are about the living. This one was about the living: someone ashamed, someone afraid, someone protecting a person they love. It would have been so easy to mistake it for the thing you were looking for."}
		"footage":
			for eid in det.order:
				if eid.begins_with("cctv_") and det.known[eid]["supports"].size() > 0:
					return {"title": "THE FOOTAGE", "text": "The picture was grainy and the clock on it was wrong by a few minutes, which is exactly the kind of thing a good lawyer lives for. But there it was: a figure on a doorstep, at an hour when no honest person in Little Mercy is awake. They did not hurry. That, more than anything, bothered you."}
		"turn":
			var best := 0
			for s in c["suspects"]:
				var pr: Dictionary = det.proof_against(s)
				var cats := 0
				for k in ["opportunity", "means", "motive", "link"]:
					if int(pr[k]) > 0:
						cats += 1
				best = maxi(best, cats)
			if best >= 3:
				return {"title": "THE TURN", "text": "There is a moment in every case when the pieces stop being separate. For two days you have been looking at strangers. Now you look at your notebook and it is no longer a list. It is a shape. You know how it ends. What you do not yet know is whether you can prove it."}
	return {}


static func _verdict_line(res: Dictionary) -> String:
	match String(res["verdict"]):
		"convicted": return "And so it ended, the way these things are supposed to, which is to say: not well for anyone, but properly."
		"released": return "It was the right name, and not enough proof, which in a small town is the worst combination there is. They walked out of that room knowing exactly how close you had come."
		"insufficient": return "You said the name. You could not back it up. There is a particular silence that follows that, and you will remember it."
		"wrong": return "You were wrong. It is the thing every detective is afraid of, because the person you were wrong about has to go on living in the same small town as everyone who heard you say it."
	return ""


## The finished story, written up like an episode: a title, what happened, how it turned, and a closing thought.
static func episode(sim: RefCounted, c: Dictionary, det: RefCounted, res: Dictionary) -> Dictionary:
	var cb: Dictionary = Data.load_json("detective/casebook.json")
	var v: String = CaseEngine.first(sim, c["victim"])
	var k: String = CaseEngine.name_of(sim, c["killer"])
	var parts: Array = []
	parts.append(cold_open(sim, c))
	parts.append("YOU WORKED IT LIKE THIS.\n" + _how(sim, c, det))
	if res["right_person"]:
		parts.append("THE TRUTH.\n%s killed %s. It was %s: %s. They went out at about %s and came back before dawn, and told everyone they had been in bed." % [k, v, cb["motives"][c["motive"]]["label"], c["motive_thing"], _clock(float(c["hour"]) - 0.5)])
		parts.append("THE DETAIL.\nThe one that didn't fit: %s. %s" % [c["held_back"], _detail_meaning(c)])
	else:
		parts.append("THE TRUTH.\nIt was not who you said. It was %s, and %s walked free for as long as it took you to notice." % [k, k])
	var missed := _missed(c, det)
	if missed != "":
		parts.append("WHAT YOU MISSED.\n" + missed)
	parts.append(_verdict_line(res))
	parts.append(String(cb["closers"][c["motive"]]))
	return {"id": c["id"], "title": title(sim, c), "day": int(sim.day), "verdict": res["verdict"], "score": res["score"], "text": "\n\n".join(parts)}


static func _clock(h: float) -> String:
	return Brief.clock_text(fposmod(h, 24.0))


static func _how(sim: RefCounted, c: Dictionary, det: RefCounted) -> String:
	var bits: Array = []
	bits.append("You read the scene (%d things written down), spoke to %d people, and took %d statements." % [det.order.filter(func(e): return det.known[e]["kind"] == "physical").size(), _people_spoken(det), det.statements.size()])
	var cctv: int = det.order.filter(func(e): return det.known[e]["kind"] == "cctv").size()
	if cctv > 0:
		bits.append("You watched %d hours of grainy footage." % cctv)
	if det.order.any(func(e): return String(e).begins_with("cmp_")):
		bits.append("The lab compared the prints.")
	if det.order.any(func(e): return String(e).begins_with("cover_") or String(e) == "f_h1_secret"):
		bits.append("You broke at least one lie that had nothing to do with the crime.")
	return " ".join(bits)


static func _people_spoken(det: RefCounted) -> int:
	var seen := {}
	for st in det.statements:
		seen[st["npc"]] = true
	return seen.size()


static func _detail_meaning(c: Dictionary) -> String:
	if String(c["held_back"]).contains("4:12"):
		return "Nobody in Little Mercy would say it out loud, but everyone knew what hour that was. Some things in this town are older than the people who live in it."
	return "It was a signature of a kind: not planned, not hidden. A little ritual the killer needed in order to walk out of that room."


static func _missed(c: Dictionary, det: RefCounted) -> String:
	var n := 0
	for id in c["clues"]:
		if not det.has(id):
			n += 1
	for fid in c["facts"]:
		if not det.has(fid):
			n += 1
	if n == 0:
		return ""
	return "%d things you never found, including some you walked right past. In a town this size, someone always saw something." % n
