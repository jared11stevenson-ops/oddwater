extends RefCounted
## The briefing you get when you wake in somebody: who they are, who they live with, what their day looks like,
## who loves and who avoids them. Built entirely from the sim, so it works for every resident.

const TownLayout = preload("res://scripts/core/town_layout.gd")

static var _layout: RefCounted = null


static func layout() -> RefCounted:
	if _layout == null:
		_layout = TownLayout.new()
	return _layout


static func place_name(sim: RefCounted, place: String, who: String = "") -> String:
	if place == "":
		return "nowhere"
	if who != "" and sim.people.has(who) and place == sim.people[who].home:
		return "home"
	var l: Dictionary = layout().by_id.get(place, {})
	if l.is_empty():
		return place
	if l.get("kind", "") == "house" or l.get("kind", "") == "home":
		for id in sim.order:
			if sim.people[id].home == place:
				return "%s's place" % String(sim.people[id].display).split(" ")[-1] if who != id else "home"
	return l["name"]


static func clock_text(h: float) -> String:
	var hh := int(floor(h)) % 24
	var mm := int(round((h - floor(h)) * 60.0)) % 60
	return "%d:%02d %s" % [(hh + 11) % 12 + 1, mm, "am" if hh < 12 else "pm"]


static func _role(a: RefCounted, b: RefCounted) -> String:
	var ak: bool = a.group in ["child", "teen"]
	var bk: bool = b.group in ["child", "teen"]
	if ak and not bk:
		return "parent"
	if bk and not ak:
		return "child"
	if ak and bk:
		return "sibling"
	if a.household in ["couple", "family", "elder_couple"] and a.household == b.household:
		return "partner"
	return "housemate"


static func make(sim: RefCounted, id: String) -> Dictionary:
	var p: RefCounted = sim.people[id]
	var b := {"id": id, "name": p.display, "age": p.age, "job": p.job, "quirk": p.quirk, "hobby": p.hobby, "money": int(p.money),
		"mood": p.mood_word(), "home": place_name(sim, p.home, id), "work": place_name(sim, p.work, id) if p.work != "" else ""}
	b["household"] = []
	for oid in sim.order:
		var o: RefCounted = sim.people[oid]
		if oid != id and o.home == p.home and sim.alive(o):
			b["household"].append({"id": oid, "name": o.display, "role": _role(p, o)})
	b["routine"] = routine_line(p)
	b["plan"] = plan(sim, p)
	# who they love and who they avoid
	var ties: Array = []
	for oid in p.rel:
		if sim.people.has(oid) and sim.alive(sim.people[oid]):
			ties.append({"id": oid, "name": sim.people[oid].display, "aff": p.affinity(oid), "trust": p.trust(oid)})
	ties.sort_custom(func(x, y): return x["aff"] > y["aff"])
	b["close"] = ties.filter(func(t): return t["aff"] >= 25.0).slice(0, 3)
	var rivals: Array = ties.filter(func(t): return t["aff"] <= -10.0)
	rivals.reverse()
	b["strained"] = rivals.slice(0, 2)
	b["needs"] = {"energy": int(p.needs["energy"]), "hunger": int(p.needs["hunger"]), "social": int(p.needs["social"]), "fun": int(p.needs["fun"])}
	b["worry"] = worry(p)
	b["memories"] = p.memories.slice(-2)
	return b


static func routine_line(p: RefCounted) -> String:
	var s := "Up around %s." % clock_text(p.wake)
	if p.employed and p.work != "":
		var days := "every day" if p.days_off.is_empty() else "weekdays" if p.days_off.has(5) and p.days_off.has(6) else "most days"
		s += " %s %s-%s, %s." % [("School" if p.job == "student" else "Works"), clock_text(p.work_start), clock_text(p.work_end), days]
	elif p.job == "retired":
		s += " Retired; the days are their own."
	elif p.job == "unemployed":
		s += " Between jobs."
	return s


## A rough shape of their day: what they will do if left alone.
static func plan(sim: RefCounted, p: RefCounted) -> Array:
	var out: Array = []
	out.append("%s  wake at home" % clock_text(p.wake))
	if sim.on_shift(p, p.work_start) and p.work != "" and p.work != p.home:
		out.append("%s  %s at %s" % [clock_text(p.work_start), "class" if p.job == "student" else "work", place_name(sim, p.work, p.id)])
		out.append("%s  finish" % clock_text(p.work_end))
	elif p.work == p.home and p.employed:
		out.append("%s  work from home" % clock_text(p.work_start))
	else:
		out.append("   free day")
	if not p.haunts.is_empty():
		out.append("evening  usually at %s" % place_name(sim, p.haunts[0], p.id))
	return out


static func worry(p: RefCounted) -> String:
	var n: Dictionary = p.needs
	if float(n["restless"]) >= 75.0:
		return "They have been restless for days. Something has to change."
	if p.money < 25.0 and p.job != "student" and p.group != "child":
		return "Money is very tight."
	if float(n["social"]) < 25.0:
		return "They're lonely."
	if float(n["energy"]) < 25.0:
		return "They are exhausted."
	if float(n["hunger"]) < 25.0:
		return "They haven't eaten properly."
	if float(n["fun"]) < 25.0:
		return "They're bored out of their mind."
	return ""


static func text(sim: RefCounted, b: Dictionary) -> String:
	var s := "%s, %d. %s.\n" % [b["name"], b["age"], String(b["job"]).capitalize()]
	if b["quirk"] != "":
		s += "%s. %s.\n" % [String(b["quirk"]).capitalize(), String(b["hobby"]).capitalize()]
	s += b["routine"] + "\n"
	if not b["household"].is_empty():
		s += "Lives with " + ", ".join(b["household"].map(func(m): return "%s (%s)" % [m["name"], m["role"]])) + ".\n"
	else:
		s += "Lives alone.\n"
	if not b["close"].is_empty():
		s += "Close to " + ", ".join(b["close"].map(func(t): return t["name"])) + ".\n"
	if not b["strained"].is_empty():
		s += "Tension with " + ", ".join(b["strained"].map(func(t): return t["name"])) + ".\n"
	s += "Mood: %s.  Money: %d.\n" % [b["mood"], b["money"]]
	if b["worry"] != "":
		s += b["worry"] + "\n"
	return s
