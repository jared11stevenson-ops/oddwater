extends Control
## THE LONG NIGHT: you can't be anyone tonight, but you can change tonight. Calm or unsettle people.
## Whoever the Cause finds most ready to change at 4:12 is who you wake up as.

signal finished(result: Dictionary)

var state: RefCounted
var sim: RefCounted
var cause: RefCounted
var budget := 2
var picked := ""
var status: Label
var left_label: Label
var edge_box: VBoxContainer
var people_box: VBoxContainer
var used: Array = []
var eligible: Array = []
var watching := false
var predict_label: Label
var predict_box: HFlowContainer


func setup(game_state: RefCounted, world: RefCounted, the_cause: RefCounted, who_can_be_taken: Array = []) -> void:
	eligible = who_can_be_taken
	state = game_state
	sim = world
	cause = the_cause
	budget = int(cause.cfg["night_actions"])
	state.casefile.open_night(cause.edge_report(sim, eligible))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "THE LONG NIGHT"
	title.position = Vector2(70, 30)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("f6ecd2"))
	add_child(title)
	var sub := Label.new()
	sub.text = "You can't be anyone tonight. But you can change someone's night. At 4:12 it takes whoever is most ready to change."
	sub.position = Vector2(70, 92)
	sub.custom_minimum_size = Vector2(1780, 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color("b8b0d8"))
	add_child(sub)
	left_label = Label.new()
	left_label.position = Vector2(1500, 30)
	left_label.add_theme_font_size_override("font_size", 32)
	left_label.add_theme_color_override("font_color", Color("f5b82e"))
	add_child(left_label)
	var h1 := Label.new(); h1.text = "People who looked on the edge today"
	h1.position = Vector2(70, 170); h1.add_theme_font_size_override("font_size", 28)
	h1.add_theme_color_override("font_color", Color("f5b82e")); add_child(h1)
	edge_box = VBoxContainer.new(); edge_box.position = Vector2(70, 215); add_child(edge_box)
	var h2 := Label.new(); h2.text = "Visit someone"
	h2.position = Vector2(1000, 170); h2.add_theme_font_size_override("font_size", 28)
	h2.add_theme_color_override("font_color", Color("f5b82e")); add_child(h2)
	people_box = VBoxContainer.new(); people_box.position = Vector2(1000, 215)
	people_box.add_theme_constant_override("separation", 6); add_child(people_box)
	status = Label.new()
	status.position = Vector2(70, 900)
	status.custom_minimum_size = Vector2(1300, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 28)
	status.add_theme_color_override("font_color", Color("f6ecd2"))
	add_child(status)
	var watch := Button.new(); watch.text = "Stay up and watch the street (uses a visit)"
	watch.position = Vector2(70, 800)
	watch.custom_minimum_size = Vector2(900, 70)
	watch.add_theme_font_size_override("font_size", 26)
	watch.pressed.connect(watch_street)
	add_child(watch)
	predict_label = Label.new()
	predict_label.position = Vector2(70, 500)
	predict_label.custom_minimum_size = Vector2(880, 0)
	predict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	predict_label.add_theme_font_size_override("font_size", 24)
	predict_label.add_theme_color_override("font_color", Color("7fd0d8"))
	add_child(predict_label)
	predict_box = HFlowContainer.new()
	predict_box.position = Vector2(70, 660)
	predict_box.custom_minimum_size = Vector2(880, 0)
	predict_box.add_theme_constant_override("h_separation", 8)
	predict_box.add_theme_constant_override("v_separation", 8)
	add_child(predict_box)
	_refresh_predict()
	var done := Button.new(); done.text = "Go to sleep"
	done.position = Vector2(1500, 950)
	done.custom_minimum_size = Vector2(340, 90)
	done.add_theme_font_size_override("font_size", 30)
	done.pressed.connect(finish)
	add_child(done)
	_refresh()


func _refresh() -> void:
	left_label.text = "Visits left: %d" % budget
	for c in edge_box.get_children():
		c.queue_free()
	var edges: Array = cause.edge_report(sim, eligible)
	if edges.is_empty():
		var l := Label.new(); l.text = "Nobody. The town seems calm tonight."
		l.add_theme_font_size_override("font_size", 26); l.add_theme_color_override("font_color", Color("b8b0d8"))
		edge_box.add_child(l)
	for e in edges.slice(0, 7):
		var l := Label.new(); l.text = "%s %s" % [e["name"], e["tell"]]
		l.add_theme_font_size_override("font_size", 26); l.add_theme_color_override("font_color", Color("f6ecd2"))
		edge_box.add_child(l)
	for c in people_box.get_children():
		c.queue_free()
	var ids: Array = []
	for id in sim.order:
		if sim.alive(sim.people[id]):
			ids.append(id)
	ids.sort_custom(func(a, b): return sim.people[a].needs["restless"] > sim.people[b].needs["restless"])
	for id in ids.slice(0, 9):
		var row := HBoxContainer.new()
		var n := Label.new(); n.text = sim.people[id].display
		n.custom_minimum_size = Vector2(300, 0)
		n.add_theme_font_size_override("font_size", 24); n.add_theme_color_override("font_color", Color("f6ecd2"))
		row.add_child(n)
		for a in [["comfort", "Sit with them"], ["unsettle", "Unsettle"]]:
			var b := Button.new(); b.text = a[1]
			b.custom_minimum_size = Vector2(240, 54)
			b.add_theme_font_size_override("font_size", 22)
			b.disabled = budget <= 0
			b.pressed.connect(night_do.bind(a[0], id))
			row.add_child(b)
		people_box.add_child(row)


func night_do(action: String, target: String) -> Dictionary:
	if budget <= 0:
		return {"ok": false, "text": "It's nearly dawn."}
	var r: Dictionary = cause.night_action(sim, action, target)
	if r["ok"]:
		budget -= 1
		used.append({"action": action, "target": target})
		state.notoriety += 2.0 if action == "unsettle" else 0.0
	status.text = r["text"]
	_refresh()
	return r


## Sit at the window instead of visiting anyone: you will see who gets marked, but only after your last chance to change it.
func watch_street() -> bool:
	if budget <= 0 or watching:
		return false
	watching = true
	budget -= 1
	status.text = "You pull a chair to the window and settle in for the night."
	_refresh()
	return true


func finish() -> void:
	finished.emit({"visits": used, "watched": watching})


func _name_of(id: String) -> String:
	return sim.people[id].display if sim.people.has(id) else id


## Who will it be? One guess a night, free. Two right and the Rule is proven.
func _refresh_predict() -> void:
	for c in predict_box.get_children():
		c.queue_free()
	var fc: Array = state.casefile.forecast(cause, sim, eligible, _name_of)
	var head := "Who will it be tomorrow? Your guess: %s." % (_name_of(state.casefile.guess_for_tonight) if state.casefile.guess_for_tonight != "" else "none yet")
	head += "  (Right so far: %d. %s)" % [state.casefile.hits(), "THE RULE IS PROVEN" if state.casefile.rule_proven else "Two right proves the Rule"]
	if not fc.is_empty():
		head += "\nThe Rule says the order tonight is: " + ", ".join(fc) + "."
	predict_label.text = head
	for id in eligible:
		if cause.used.has(id) or not sim.alive(sim.people[id]):
			continue
		var b := Button.new(); b.text = _name_of(id)
		b.custom_minimum_size = Vector2(170, 54)
		b.add_theme_font_size_override("font_size", 22)
		b.toggle_mode = true
		b.button_pressed = state.casefile.guess_for_tonight == id
		b.pressed.connect(predict.bind(id))
		predict_box.add_child(b)


func predict(id: String) -> void:
	state.casefile.predict(id)
	_refresh_predict()
