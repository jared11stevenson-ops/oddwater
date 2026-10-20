extends RefCounted
## One simulated person. Needs are 0..100 (100 = fully satisfied) except restless (100 = on the edge of a Decision).

var id := ""
var display := ""
var home := ""
var work := ""
var job := ""
var wake := 7.0
var work_start := 9.0
var work_end := 17.0
var faction := ""
var walkon := false
var traits: Dictionary = {}
var secret := ""
var money := 0.0
var needs: Dictionary = {"energy": 80.0, "hunger": 70.0, "social": 60.0, "fun": 60.0, "comfort": 60.0, "purpose": 60.0, "restless": 20.0}
var location := ""
var activity := "sleep"
var struck := false
var taken := false
var jailed := false           # convicted and held in the county jail
var dead := false             # killed (a crime), as opposed to taken or struck
var employed := true
var routine_streak := 0
var last_activity := ""
var memories: Array = []      # {day, who, what, weight}
var rel: Dictionary = {}      # other id -> {affinity, trust}
var notes: Dictionary = {}    # personality imprint from the Chorus (warmth, candor, nerve, curiosity, fidelity)
var contentment := 0.0
# everyday-resident detail (generated population; empty for the authored cast)
var age := 0
var group := ""               # child | teen | adult | elder
var hobby := ""
var quirk := ""
var days_off: Array = []      # weekday indices (0 = Monday) with no work or school
var haunts: Array = []        # favourite places, in order of preference
var household := ""
var pay := 0.0                # hourly


static func from_data(d: Dictionary) -> RefCounted:
	var p: RefCounted = load("res://scripts/sim/sim_person.gd").new()
	p.id = d["id"]; p.display = d["name"]; p.home = d["home"]; p.work = d["work"]; p.job = d["job"]
	p.wake = float(d["wake"]); p.work_start = float(d["work_start"]); p.work_end = float(d["work_end"])
	p.faction = d["faction"]; p.walkon = d["walkon"]; p.traits = d["traits"].duplicate(); p.secret = d["secret"]
	p.money = float(d["money"]); p.location = p.home
	p.employed = float(d["work_end"]) > float(d["work_start"])
	p.age = int(d.get("age", 0)); p.group = d.get("group", ""); p.hobby = d.get("hobby", ""); p.quirk = d.get("quirk", "")
	p.days_off = d.get("days_off", []).duplicate(); p.haunts = d.get("haunts", []).duplicate(); p.household = d.get("household", "")
	p.pay = float(d.get("pay", 0.0))
	return p


func trait_of(k: String) -> float:
	return float(traits.get(k, 0.5))


func mood() -> float:
	var n := needs
	var m := (float(n["energy"]) + float(n["hunger"]) + float(n["social"]) + float(n["fun"]) + float(n["comfort"]) + float(n["purpose"])) / 6.0
	return clampf(m - float(n["restless"]) * 0.25, 0.0, 100.0)


func mood_word() -> String:
	var m := mood()
	return "radiant" if m >= 75 else ("content" if m >= 55 else ("flat" if m >= 40 else ("low" if m >= 25 else "desperate")))


func affinity(other: String) -> float:
	return float(rel.get(other, {"affinity": 0.0})["affinity"])


func trust(other: String) -> float:
	return float(rel.get(other, {"trust": 0.0})["trust"])


func bump(other: String, d_aff: float, d_trust: float) -> void:
	var r: Dictionary = rel.get(other, {"affinity": 0.0, "trust": 0.0})
	r["affinity"] = clampf(float(r["affinity"]) + d_aff, -100.0, 100.0)
	r["trust"] = clampf(float(r["trust"]) + d_trust, -100.0, 100.0)
	rel[other] = r


func remember(day: int, who: String, what: String, weight: float) -> void:
	memories.append({"day": day, "who": who, "what": what, "weight": weight})
	if memories.size() > 60:
		memories.pop_front()


func to_dict() -> Dictionary:
	return {"id": id, "money": money, "needs": needs.duplicate(), "location": location, "activity": activity, "struck": struck,
		"taken": taken, "dead": dead, "jailed": jailed, "employed": employed, "rel": rel.duplicate(true), "memories": memories.duplicate(true), "notes": notes.duplicate(),
		"streak": routine_streak, "last": last_activity, "contentment": contentment, "traits": traits.duplicate(), "job": job, "pay": pay}


func load_dict(d: Dictionary) -> void:
	money = float(d["money"]); needs = d["needs"].duplicate(); location = d["location"]; activity = d["activity"]
	struck = d["struck"]; taken = d["taken"]; dead = d.get("dead", false); jailed = d.get("jailed", false); employed = d["employed"]; rel = d["rel"].duplicate(true)
	memories = d["memories"].duplicate(true); notes = d["notes"].duplicate(); routine_streak = int(d["streak"])
	if d.has("traits"):
		traits = d["traits"].duplicate()
	job = d.get("job", job); pay = float(d.get("pay", pay))
	last_activity = d["last"]; contentment = float(d["contentment"])
