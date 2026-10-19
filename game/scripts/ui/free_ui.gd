extends Control
## FREE TIME: the Sims half. You have a few hours inside someone else's life. Do anything. It all sticks.
## Decisions are irrevocable and get the Remnant Struck at 4:12: the screen says so, in red.

signal finished(result: Dictionary)

var state: RefCounted
var sim: RefCounted
var pid := ""
var budget := 3
var picked_action := ""
var status: Label
var needs_label: Label
var left_label: Label
var targets_box: VBoxContainer
var actions_box: GridContainer
var log: Array = []

const ACTIONS := [
	{"id": "work", "label": "Work a shift", "target": false, "decision": false, "notes": {"fidelity": 8}},
	{"id": "eat", "label": "Eat properly", "target": false, "decision": false, "notes": {"fidelity": 4}},
	{"id": "relax", "label": "Do nothing, pleasantly", "target": false, "decision": false, "notes": {"fidelity": 2, "warmth": 2}},
	{"id": "sleep", "label": "Nap", "target": false, "decision": false, "notes": {"fidelity": 2}},
	{"id": "socialize", "label": "Chat with...", "target": true, "decision": false, "notes": {"warmth": 6}},
	{"id": "praise", "label": "Praise...", "target": true, "decision": false, "notes": {"warmth": 8}},
	{"id": "gift", "label": "Give money to... ($50)", "target": true, "decision": false, "notes": {"warmth": 10}, "args": {"amount": 50}},
	{"id": "insult", "label": "Insult...", "target": true, "decision": false, "notes": {"warmth": -12, "candor": 6, "fidelity": -8}, "notoriety": 3},
	{"id": "steal", "label": "Steal from... ($100)", "target": true, "decision": false, "notes": {"nerve": 12, "candor": -10, "fidelity": -15}, "args": {"amount": 100}, "notoriety": 8},
	{"id": "spread_rumor", "label": "Start a rumour about... (they're the one taking people)", "target": true, "decision": false, "notes": {"nerve": 6, "candor": -6, "curiosity": 4}, "notoriety": 4},
	{"id": "burn_diary", "label": "Burn their diary", "target": false, "decision": false, "notes": {"fidelity": -10, "nerve": 5}},
	{"id": "quit_job", "label": "QUIT THEIR JOB", "target": false, "decision": true, "notes": {"nerve": 20, "fidelity": -20}, "notoriety": 15},
	{"id": "sell_house", "label": "SELL THEIR HOUSE", "target": false, "decision": true, "notes": {"nerve": 20, "fidelity": -20}, "notoriety": 15},
	{"id": "confess", "label": "CONFESS EVERYTHING", "target": false, "decision": true, "notes": {"candor": 25, "nerve": 20, "fidelity": -15}, "notoriety": 12},
	{"id": "propose", "label": "PROPOSE to...", "target": true, "decision": true, "notes": {"warmth": 15, "nerve": 20, "fidelity": -15}, "notoriety": 10},
	{"id": "leave_town", "label": "BUY A TICKET OUT", "target": false, "decision": true, "notes": {"nerve": 25, "fidelity": -25}, "notoriety": 18}]


func setup(game_state: RefCounted, world: RefCounted, person_id: String, hours: int = 3) -> void:
	state = game_state
	sim = world
	pid = person_id
	budget = hours
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var p: RefCounted = sim.people[pid]
	var title := Label.new()
	title.text = "FREE TIME as %s" % p.display
	title.position = Vector2(70, 30)
	title.add_theme_font_size_override("font_size", 44)
	add_child(title)
	needs_label = Label.new()
	needs_label.position = Vector2(70, 92)
	needs_label.custom_minimum_size = Vector2(1780, 0)
	needs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs_label.add_theme_font_size_override("font_size", 26)
	needs_label.add_theme_color_override("font_color", Color("4a3f7a"))
	add_child(needs_label)
	left_label = Label.new()
	left_label.position = Vector2(1450, 30)
	left_label.add_theme_font_size_override("font_size", 34)
	add_child(left_label)
	actions_box = GridContainer.new()
	actions_box.columns = 2
	actions_box.position = Vector2(70, 190)
	actions_box.add_theme_constant_override("h_separation", 12)
	actions_box.add_theme_constant_override("v_separation", 10)
	add_child(actions_box)
	for a in ACTIONS:
		var b := Button.new()
		b.text = a["label"]
		b.custom_minimum_size = Vector2(760, 66)
		b.add_theme_font_size_override("font_size", 24)
		if a["decision"]:
			b.add_theme_color_override("font_color", Color("e23d3d"))
			b.add_theme_color_override("font_hover_color", Color("e23d3d"))
			b.add_theme_color_override("font_focus_color", Color("e23d3d"))
		b.pressed.connect(choose_action.bind(a["id"]))
		actions_box.add_child(b)
	targets_box = VBoxContainer.new()
	targets_box.position = Vector2(1620, 190)
	targets_box.add_theme_constant_override("separation", 6)
	add_child(targets_box)
	status = Label.new()
	status.position = Vector2(70, 880)
	status.custom_minimum_size = Vector2(1500, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 30)
	status.text = "Anything you like. The town keeps living after you leave. (Red actions are Decisions: irrevocable.)"
	add_child(status)
	var done := Button.new(); done.text = "Done: dusk"
	done.position = Vector2(1560, 960)
	done.custom_minimum_size = Vector2(300, 84)
	done.add_theme_font_size_override("font_size", 30)
	done.pressed.connect(finish)
	add_child(done)
	_refresh()


func action_def(id: String) -> Dictionary:
	for a in ACTIONS:
		if a["id"] == id:
			return a
	return {}


func _refresh() -> void:
	var p: RefCounted = sim.people[pid]
	var n: Dictionary = p.needs
	needs_label.text = "Mood: %s   Money: %d   Energy %d  Hunger %d  Social %d  Fun %d  Restless %d" % [p.mood_word(), int(p.money), int(n["energy"]), int(n["hunger"]), int(n["social"]), int(n["fun"]), int(n["restless"])]
	left_label.text = "Hours left: %d" % budget
	for c in targets_box.get_children():
		c.queue_free()
	if picked_action != "":
		var t := Label.new(); t.text = "Who?"; t.add_theme_font_size_override("font_size", 28)
		targets_box.add_child(t)
		for oid in contacts():
			var b := Button.new(); b.text = sim.people[oid].display
			b.custom_minimum_size = Vector2(280, 56)
			b.add_theme_font_size_override("font_size", 22)
			b.pressed.connect(do_action.bind(picked_action, oid))
			targets_box.add_child(b)


## Everyone this person knows, warmest first.
func contacts() -> Array:
	var p: RefCounted = sim.people[pid]
	var ids: Array = []
	for oid in p.rel.keys():
		if sim.people.has(oid) and sim.alive(sim.people[oid]):
			ids.append(oid)
	ids.sort_custom(func(a, b): return p.affinity(a) > p.affinity(b))
	return ids.slice(0, 7)


func choose_action(id: String) -> void:
	var a := action_def(id)
	if a.is_empty() or budget <= 0:
		return
	if a["target"]:
		picked_action = id
		_refresh()
	else:
		do_action(id, "")


## Perform an action as the controlled person. Returns the sim result.
func do_action(id: String, target: String) -> Dictionary:
	var a := action_def(id)
	if a.is_empty() or budget <= 0:
		return {"ok": false, "text": "no time"}
	var args: Dictionary = a.get("args", {}).duplicate()
	if target != "":
		args["target"] = target
	if id == "spread_rumor":
		args["subject"] = target
		args["claim"] = "%s is the one who's been taking people." % sim.people[target].display
		args["truth"] = false
		args["severity"] = 4
	var res: Dictionary = sim.player_act(pid, id, args)
	picked_action = ""
	if res["ok"]:
		budget -= 1
		for k in a["notes"]:
			state.notes.add(k, int(a["notes"][k]))
		state.notoriety += float(a.get("notoriety", 0))
		log.append({"action": id, "target": target, "decision": res["decision"]})
	status.text = res["text"]
	if res["decision"]:
		status.add_theme_color_override("font_color", Color("e23d3d"))
	else:
		status.add_theme_color_override("font_color", Color("14121c"))
	_refresh()
	return res


func finish() -> void:
	finished.emit({"log": log, "decisions": log.filter(func(l): return l["decision"]).size()})
