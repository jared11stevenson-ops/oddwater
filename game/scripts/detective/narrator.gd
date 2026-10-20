extends RefCounted
## The storyteller. Every case is also a told story: a quiet cold open, a slow build of details that do not add up, a turn, a twist,
## and a reflective close. The shape is borrowed from the best of true-crime and strange-stories narration: the voice is calm, the
## details are specific, the dread is in what is left unsaid. Nothing here gives the answer away; it frames what you already found.

const Data = preload("res://scripts/core/data.gd")
const Brief = preload("res://scripts/sim/brief.gd")
const CaseEngine = preload("res://scripts/detective/case_engine.gd")
const Prose = preload("res://scripts/detective/prose.gd")
const Places = preload("res://scripts/detective/places.gd")

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


static func _salt(c: Dictionary, x: String) -> String:
	return "%s|%s|%s" % [c["id"], c.get("seed", 0), x]


static func _pick(options: Array, seed_text: String) -> String:
	return String(options[absi(hash(seed_text)) % options.size()])


static func title(sim: RefCounted, c: Dictionary) -> String:
	var place: String = Brief.place_name(sim, c["scene"], "")
	var adjectives := ["Quiet", "Last", "Unlocked", "Silent", "Borrowed", "Long"]
	var nouns := ["Death", "Night", "Visitor", "Knock", "Debt", "Promise"]
	var a: String = _pick(adjectives, _salt(c, "a"))
	var n: String = _pick(nouns, _salt(c, "n"))
	return "The %s %s at %s" % [a, n, place]


const OPENERS := [
	"Little Mercy sits on a ridge above a lake that nobody swims in. It is the kind of town where strangers get waved at, doors go unlocked, and nobody, ever, says goodbye.",
	"There is a particular kind of quiet in a small town after rain. Everyone is home. Everyone is listening. And everyone knows exactly whose light is still on.",
	"In Little Mercy the clocks run a little slow, the gossip runs a little fast, and the lake keeps its own counsel. Nothing happens here. That is what everyone will tell you.",
	"The first thing you learn about Little Mercy is that it is kind. The second, a little later, is that the kindness has a shape, like a fence, and that something is meant to stay on the other side of it.",
	"At 4:12 every afternoon the town stops what it is doing for about as long as it takes to draw a breath. Nobody mentions it. A visitor, if there were ever visitors, might take it for a pause in conversation.",
	"They measure the lake in Little Mercy every morning, and every morning they write down the same number. It is the closest thing the town has to a prayer.",
	"If you ask anyone in Little Mercy how long they have lived here they will tell you, a little too quickly, the whole of their lives. Ask them what they did before, and they smile, and ask if you have eaten.",
	"Houses in Little Mercy are built with one window facing the water, and the curtain on it is always drawn. The architects, it is said, were not asked why. They were told."]

const VICTIM_INTRO := [
	"{v} was {age}, {job}. {v} knew the names of the dogs on the street, paid bills on the day they were due, and if you had asked anyone in town to describe {v}, they would have said the same word: harmless.",
	"{v}, {age}, {job}, was the kind of person a street is built around without noticing: always there at the same hour, always with the same nod, so regular that the absence, when it came, felt like a clock stopping.",
	"Everyone had a small story about {v}. {job_cap}, {age}, a borrower of ladders and a returner of them, a person with a lamp that was always the last one off. It was the sort of life that is only really read once it is over.",
	"{v} was {age}, {job}. If you wanted to find a flaw in {v}'s life you would have had to look closely, and the closer you looked, the more the flaws seemed to be things other people had left there."]

const DISCOVERY := [
	"At about {time}, {f}, {v}'s {rel}, found {v} at {place}. {f} did not scream, and said later that the place had never been so quiet.",
	"It was {f}, {v}'s {rel}, who went in at about {time} and found {v} in {room}. {f} stood in the doorway a long while before touching anything, and then touched nothing.",
	"{f}, {v}'s {rel}, came to {place} at about {time} and knew something was wrong from the gate: the quiet was too complete. The door was not locked. {v} was not where {v} should have been.",
	"The finding fell to {f}, {v}'s {rel}, at about {time}. {f} called the Sheriff from the nearest telephone and then went back and sat on the step, because going inside again was more than anyone could ask."]

const HOOK := [
	"The next few days will put {n} people in front of you, and every one of them will have something to hide. Only one of them is a killer. But it is not the killer that will keep you awake. It is one small detail, at the scene, that nobody can explain.",
	"There will be {n} names in your notebook by the end of the week, and not one of them will be what it seems. Some of the lies you hear will be about the dead. Most will be about the living. You will want to know the difference, and it will matter more than the answer.",
	"{n_cap} people will tell you where they were that night. You will believe some of them. You will have a reason for each. And then there will be the small thing in {room} that none of them mentions, because none of them will say they saw it.",
	"You do not know yet how many people in this town knew {v} was afraid. You will. It will be more than you think, and fewer than you hope, and every one of them will say it was somebody else's business."]


static func _season(c: Dictionary) -> String:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	return String(cb["seasons"][int(c.get("seed", 0)) % cb["seasons"].size()])


static func _weekday(sim: RefCounted, c: Dictionary) -> String:
	return DAYS[posmod(int(c["day"]), 7)]


## The weather the morning of the finding (not today's), in words that fit it.
static func weather_line(sim: RefCounted, c: Dictionary) -> String:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var wx: String = Prose.weather_on(sim, int(c["day"]) + 1)
	var pool: Array = cb["weather_lines"].get(wx, cb["weather_lines"]["clear"])
	return _pick(pool, _salt(c, "wx"))


## The cold open. It sets the mood, introduces the dead as a person, tells you what was found and by whom, and leaves one thing hanging.
## Every piece varies with the case, the real weather, the real kind of place and the finder's real tie to the dead.
static func cold_open(sim: RefCounted, c: Dictionary) -> String:
	var v: RefCounted = sim.people[c["victim"]]
	var vf: String = CaseEngine.first(sim, c["victim"])
	var finder: RefCounted = sim.people[c["found_by"]] if sim.people.has(c["found_by"]) else null
	var ff := CaseEngine.name_of(sim, c["found_by"]) if finder != null else "A neighbour"
	var pl: Dictionary = Places.profile(c)
	var place: String = Brief.place_name(sim, c["scene"], "")
	var room: String = Places.where_phrase(sim, c)
	var n: int = (c["suspects"] as Array).size()
	var rep := {"{v}": vf, "{age}": str(v.age), "{job}": Prose.job_np(String(v.job)), "{job_cap}": Prose.sentence(Prose.job_np(String(v.job))),
		"{time}": CaseEngine.discovery_time(c), "{f}": ff, "{rel}": c.get("found_rel", "neighbour"), "{place}": place, "{room}": room,
		"{n}": Prose.count_word(n), "{n_cap}": Prose.sentence(Prose.count_word(n))}
	var p1: String = _pick(OPENERS, _salt(c, "o"))
	var p2: String = _fill(_pick(VICTIM_INTRO, _salt(c, "v")), rep)
	var weather: String = weather_line(sim, c)
	var found: String = _fill(_pick(DISCOVERY, _salt(c, "d")), rep)
	var when: String = "%s, %s. %s" % [_weekday(sim, c), _season(c), weather]
	var p3 := "%s %s" % [when, found]
	var p4: String = _fill(_pick(HOOK, _salt(c, "h")), rep)
	return Prose.clean("\n\n".join([p1, p2, p3, p4]))


static func _fill(t: String, rep: Dictionary) -> String:
	var out := t
	for k in rep:
		out = out.replace(k, String(rep[k]))
	return out


## Short narrated interludes, fired once when the story reaches a moment. Returns "" if the moment has not come.
static func beat(kind: String, sim: RefCounted, c: Dictionary, det: RefCounted) -> Dictionary:
	var v := CaseEngine.first(sim, c["victim"])
	match kind:
		"first_scene":
			if det.has("c_body"):
				var pl: Dictionary = Places.profile(c)
				var lead := ["You have stood over the dead before. But never somewhere this ordinary", "The dead are rarely tidy. This was worse: it was ordinary", "You expected the scene of a crime. What you found was the scene of a Tuesday"]
				var room: String = Places.where_phrase(sim, c)
				var txt := "%s: %s. %s. On the table, %s. %s had plans. That is always the part that stays with you." % [_pick(lead, _salt(c, "fs")), room, pl["sense"], pl["plan"], v]
				return {"title": "THE SCENE", "text": Prose.clean(txt)}
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
		"cold": return "No one was ever arrested. The file went into a drawer, and the drawer into a room that smells of lake water. Some cases end like that, not with an answer but with an absence that learns to sit at the table with you."
		"failure": return "The state police took the file in a cardboard box. They were polite about it. They said the word 'reassigned' and neither of you looked at the other. The killer, as far as anyone knows, is still within a mile of where you are standing."
		"fled": return "The house was found empty one morning, the bed made, the kettle cold. The town said the family had been called away. It is the kind of thing the town says. You know better, and you have nothing to prove it with."
	return ""


## The finished story, written up like an episode: a title, what happened, how it turned, and a closing thought.
static func episode(sim: RefCounted, c: Dictionary, det: RefCounted, res: Dictionary) -> Dictionary:
	var cb: Dictionary = Prose.json("detective/casebook.json")
	var v: String = CaseEngine.first(sim, c["victim"])
	var k: String = CaseEngine.name_of(sim, c["killer"])
	var parts: Array = []
	parts.append(cold_open(sim, c))
	parts.append("YOU WORKED IT LIKE THIS.\n" + _how(sim, c, det))
	if res["right_person"] or res["verdict"] in ["cold", "failure", "fled"]:
		parts.append("THE TRUTH.\n%s killed %s. It was %s: %s. %s went out at about %s and came back before dawn, and told everyone about a night in bed." % [k, v, cb["motives"][c["motive"]]["label"], c["motive_thing"], CaseEngine.first(sim, c["killer"]), _clock(float(c["hour"]) - 0.5)])
		parts.append("THE DETAIL.\nThe one that didn't fit: %s. %s" % [c["held_back"], _detail_meaning(c)])
	else:
		parts.append("THE TRUTH.\nIt was not who you said. It was %s, and %s walked free for as long as it took you to notice." % [k, k])
	var voice_lines: Array = []
	for eid in det.order:
		if String(eid).begins_with("view_"):
			voice_lines.append(String(det.known[eid]["text"]))
	if not voice_lines.is_empty():
		parts.append("THE KILLER'S VOICE.\n%s\n\nYou wrote it down because it was the only honest thing anyone said all week." % voice_lines[0])
	var missed := _missed(c, det)
	if missed != "":
		parts.append("WHAT YOU MISSED.\n" + missed)
	parts.append(_verdict_line(res))
	parts.append(String(cb["closers"][c["motive"]]))
	return {"id": c["id"], "title": title(sim, c), "day": int(sim.day), "verdict": res["verdict"], "score": res["score"], "text": Prose.clean("\n\n".join(parts))}


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
