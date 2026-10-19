extends Control
## The day loop, driven entirely by data/days.json:
## WAKE (snoop) -> PERFORM (steps) -> STEP OFF (Remnant) -> NIGHT (snoop + event) -> Case Board -> SLACK -> next day.

const GameState = preload("res://scripts/core/game_state.gd")
const Data = preload("res://scripts/core/data.gd")
const Snoop = preload("res://scripts/ui/snoop.gd")
const DialogueUI = preload("res://scripts/ui/dialogue_ui.gd")
const DentalUI = preload("res://scripts/ui/dental_ui.gd")
const RhythmUI = preload("res://scripts/ui/rhythm_ui.gd")
const EavesdropUI = preload("res://scripts/ui/eavesdrop_ui.gd")
const SpeechUI = preload("res://scripts/ui/speech_ui.gd")
const RadioUI = preload("res://scripts/ui/radio_ui.gd")
const BoardUI = preload("res://scripts/ui/board_ui.gd")
const SlackUI = preload("res://scripts/ui/slack_ui.gd")
const FreeUI = preload("res://scripts/ui/free_ui.gd")
const SimWorld = preload("res://scripts/sim/sim_world.gd")
const Cause = preload("res://scripts/sim/cause.gd")
const DuskUI = preload("res://scripts/ui/dusk_ui.gd")
const CreatorUI = preload("res://scripts/ui/creator_ui.gd")
const TutorialUI = preload("res://scripts/ui/tutorial_ui.gd")
const Persona = preload("res://scripts/core/persona.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")
const POST := preload("res://shaders/page_post.gdshader")

var state: RefCounted
var sim: RefCounted
var cause: RefCounted
var briefed := false
var days: Dictionary
var days_by_life: Dictionary = {}
var snoop: Control
var queue: Array = []
var stage: Control            # backgrounds / world (gets the print pass)
var ui: Control               # all readable UI sits above the print pass
var post_mat: ShaderMaterial
var lenient := 1.0            # accessibility: rhythm timing leniency


func _ready() -> void:
	state = GameState.new()
	sim = SimWorld.new(1961)
	cause = Cause.new()
	days = Data.load_json("days.json")
	for k in days:
		days_by_life[days[k]["life"]] = days[k]
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	var layer := CanvasLayer.new(); layer.layer = 50; add_child(layer)
	var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new(); post_mat.shader = POST; rect.material = post_mat
	layer.add_child(rect)
	var ui_layer := CanvasLayer.new(); ui_layer.layer = 60; add_child(ui_layer)
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.theme = UITheme.build(); ui_layer.add_child(ui)
	_title()


func _process(_d: float) -> void:
	# the look follows the game: town mood -> hush, proven seals -> truth
	post_mat.set_shader_parameter("hush", state.hush_strength())
	post_mat.set_shader_parameter("truth", float(state.board.seals.size()) / 40.0)


func _clear() -> void:
	for c in stage.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()


func _bg(color: Color) -> void:
	var bg := ColorRect.new(); bg.color = color; bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(bg)


func _text(t: String, pos: Vector2, size: int = 44, color: Color = Color("14121c"), width: float = 1480.0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.custom_minimum_size = Vector2(width, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	ui.add_child(l)
	return l


func _button(t: String, pos: Vector2, cb: Callable, w: float = 520.0) -> Button:
	var b := Button.new()
	b.text = t
	b.position = pos
	b.custom_minimum_size = Vector2(w, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(cb)
	ui.add_child(b)
	b.grab_focus()
	return b


func day_def() -> Dictionary:
	return days_by_life[state.current_life()["id"]]


## Who the Cause may take: lives with authored days, not yet hosted.
func eligible_hosts() -> Array:
	return days_by_life.keys().filter(func(id): return not cause.used.has(id))


# ---------------------------------------------------------------- title / wake
func _title() -> void:
	_clear()
	_bg(Color("f1dfc0"))
	_text("UNDERSTUDY\n\nEvery morning someone in Little Mercy vanishes.\nEvery morning you wake up as them.", Vector2(300, 300), 48)
	_button("Begin", Vector2(300, 700), _creator, 360.0)


## Make your character. This is who you are in every body.
func _creator() -> void:
	_clear()
	_bg(Color("f1dfc0"))
	var c := CreatorUI.new()
	ui.add_child(c)
	c.setup()
	c.finished.connect(func(r):
		state.persona = Persona.make(r["name"], r["pronoun"], r["archetype"], r["catch"])
		sim.people["player"].display = state.persona.name
		_intro())


## Day one, in your own life. Nothing is wrong yet.
func _intro() -> void:
	_clear()
	_bg(Color("f1dfc0"))
	var p: RefCounted = state.persona
	_text(p.inner("{you}, you moved to Little Mercy three weeks ago: a small town on a lake, a rented house, a new start. Everyone here is kind, and slightly vague about everything.\n\nToday is an ordinary day. Have breakfast. Meet the neighbours. Make up your mind about something you've been putting off."), Vector2(240, 260), 40)
	_button("Start the day", Vector2(240, 760), start_day)


func start_day() -> void:
	_clear()
	_bg(Color("2b2a3a"))
	var life: Dictionary = state.current_life()
	sim.start_day()
	sim.take_control(life["id"])
	cause.mark_used(life["id"])
	state.board.new_day_film()
	if state.day > 1:
		state.hush_dawn()   # overnight, quietly, the Hush edits your case file
	snoop = Snoop.new()
	ui.add_child(snoop)
	var hint: Dictionary = {}
	if life["id"] == "player":
		hint = {}
	elif state.host_history.size() == 2:
		hint = {"voice": "self", "text": state.persona.inner("That's not my hand. That's not my... okay. Okay, {you}. Look around. Don't say anything stupid. Don't say anything at all, if you can help it.")}
	else:
		hint = state.pick_hint()
	snoop.setup(state, day_def()["home"], 1.0, hint)
	snoop.finished.connect(_perform)


# ---------------------------------------------------------------- perform
func _perform(result: Dictionary) -> void:
	state.advance()   # WAKE -> PERFORM
	if result["vague_brief"]:
		for step in day_def()["perform"]:
			if step["type"] == "convo":
				state.suspicion.raise(_npc_of(step), 15)   # a half-known self is noticeable
	queue = day_def()["perform"].duplicate(true)
	_next_step()


func _npc_of(step: Dictionary) -> String:
	return String(step.get("id", ""))


func _next_step() -> void:
	_clear()
	_bg(Color("c9d8d4"))
	if queue.is_empty():
		_step_off()
		return
	var s: Dictionary = queue.pop_front()
	match s["type"]:
		"convo":
			var d := DialogueUI.new()
			ui.add_child(d)
			d.setup(state, s["file"], s["id"], sim)
			d.finished.connect(func(npc): _after_convo(npc, s))
		"vignette":
			match s["kind"]:
				"rhythm": _rhythm(s)
				"small_paths": _eavesdrop(s)
				"speech": _speech(s)
				"radio": _radio(s)
				_:
					_next_step()
		"free_time":
			_free()
		"tutorial":
			_tutorial(s)
		"event":
			if s["kind"] == "hymn":
				_hymn()
			else:
				_next_step()
		_:
			_next_step()


func _after_convo(npc: String, step: Dictionary) -> void:
	var after: Dictionary = step.get("after", {})
	if not after.is_empty() and state.board.evidence.has(after.get("if_evidence", "")) and after.get("vignette", "") == "dental":
		_clear()
		_bg(Color("e9e4d4"))
		var d := DentalUI.new()
		ui.add_child(d)
		d.setup(after["case"])
		d.finished.connect(_after_overlay)
		return
	_next_step()


func _after_overlay(result: Dictionary) -> void:
	if result["proven"] and result["seal"] != "":
		for e in ["LF-055", "LF-056"]:
			state.board.pin(e, "who")
		state.notes.add("curiosity", 10)
		if state.board.complete_test(result["seal"], state.day):
			_stamp(result["seal"], result["verdict"])
			return
	_next_step()


func _rhythm(step: Dictionary) -> void:
	_clear()
	var r := RhythmUI.new()
	ui.add_child(r)
	r.setup(step["song"], lenient, false)
	r.finished.connect(func(res):
		state.notes.add("nerve", 5 * res["stars"])
		state.notes.add("warmth", 3 * res["stars"])
		_applause(res["stars"], "The set is over.", _next_step))


func _eavesdrop(step: Dictionary) -> void:
	_clear()
	_bg(Color("efe4c8"))
	var e := EavesdropUI.new()
	ui.add_child(e)
	e.setup(state, step["map"])
	e.finished.connect(func(_r): _next_step())


func _tutorial(step: Dictionary) -> void:
	_clear()
	_bg(Color("efe4c8"))
	var tu := TutorialUI.new()
	ui.add_child(tu)
	tu.setup(state, sim, step["kind"])
	tu.finished.connect(func(_r): _next_step())


func _free() -> void:
	_clear()
	_bg(Color("efe4c8"))
	var f := FreeUI.new()
	ui.add_child(f)
	f.setup(state, sim, state.current_life()["id"])
	f.finished.connect(func(_r): _next_step())


func _speech(step: Dictionary) -> void:
	_clear()
	_bg(Color("d9cfb5"))
	var sp := SpeechUI.new()
	ui.add_child(sp)
	sp.setup(state, step["speech"])
	sp.finished.connect(func(_r): _next_step())


func _radio(step: Dictionary) -> void:
	_clear()
	_bg(Color("1b1a2e"))
	var r := RadioUI.new()
	ui.add_child(r)
	r.setup(step["set"])
	r.finished.connect(func(res):
		state.notes.add("warmth", 3 * res["stars"])
		state.notes.add("curiosity", 4 * res["stars"])
		if res["spells"] and state.board.evidence.has("LF-022"):
			state.board.pin("LF-022", "what")
			if state.board.complete_test("S12", state.day):
				_stamp("S12", "The first letters of Vern's dedications, week after week, spell FAIR WATER. Someone has been sending a message down the radio for a very long time.")
				return
		_next_step())


## The Act I climax: Vern's last show. Does the hymn go out?
func _hymn() -> void:
	_clear()
	_bg(Color("0e0d1a"))
	_text("11:58 p.m. The last record is spinning down.\n\nThe reel is cued: four rising notes, then the Low Mercy Chapel choir, 1959. Hymn 212. It has not been heard in this valley for sixty-one years.\n\nIf it goes out, everyone in the valley will hear it. Everyone.", Vector2(260, 200), 40, Color("f6ecd2"))
	_button("Air Hymn 212", Vector2(260, 700), func(): _hymn_result(true), 560.0)
	var b2 := Button.new(); b2.text = "Play something else"
	b2.position = Vector2(900, 700); b2.custom_minimum_size = Vector2(560, 100)
	b2.add_theme_font_size_override("font_size", 34)
	b2.pressed.connect(func(): _hymn_result(false))
	ui.add_child(b2)


func _hymn_result(aired: bool) -> void:
	state.apply_hymn(aired)
	state.notes.add("nerve", 25 if aired else -10)
	_clear()
	_bg(Color("0e0d1a"))
	_text("You open the fader.\n\nFour notes. Then a roomful of voices from sixty-one years ago, breathing in at once.\n\nOutside, the lake goes very still." if aired else "You let it spin down. The hymn stays on the reel. You tell yourself you will play it tomorrow.", Vector2(260, 260), 42, Color("7fd0d8") if aired else Color("b8b0d8"))
	_button("Sign off", Vector2(260, 760), _next_step)


func _applause(stars: int, line: String, cont: Callable) -> void:
	_clear()
	_bg(Color("f1dfc0"))
	_text("%s\n\n%s" % [line, "★".repeat(stars) + "☆".repeat(3 - stars)], Vector2(260, 300), 52)
	_button("Keep going", Vector2(260, 700), cont)


## A red Seal stamp: a proven truth.
func _stamp(seal: String, verdict: String) -> void:
	_clear()
	_bg(Color("f1dfc0"))
	_text("SEAL  %s\n\n%s\n\n(One piece of the Model is placed. Something small and dry in your head says: \"Told you.\")" % [seal, verdict], Vector2(220, 240), 42, Color("e23d3d"))
	_button("Carry on", Vector2(220, 820), _next_step)


# ---------------------------------------------------------------- step off / night
func _step_off() -> void:
	var life: Dictionary = state.current_life()
	var person: RefCounted = sim.people[life["id"]]
	state.close_day(person.mood())
	sim.release_control(state.notes.to_dict())
	sim.simulate_rest_of_day()      # the town carries on without you
	state.advance()   # PERFORM -> STEP_OFF
	state.advance()   # STEP_OFF -> NIGHT (Remnant forms)
	_clear()
	_bg(Color("2b2a3a"))
	if life["id"] == "player":
		_text(state.persona.inner("Dusk. A good day, {you}. A real one. You made up your mind about something, and it feels like lighter luggage. The Gazette is on the doormat."), Vector2(260, 260), 40, Color("f6ecd2"))
	else:
		var r: Dictionary = state.remnants.by_life.get(life["id"], {}).get("notes", {})
		_text("Dusk. You step out of %s's life.\n\nThey stay behind, and they're now a little:\n%s" % [life["name"].split(" ")[0], _describe(r)], Vector2(260, 220), 40, Color("f6ecd2"))
	_button("Read the Gazette", Vector2(260, 800), _report, 620.0)


## The Town Report: the Gazette (a propaganda organ) and, underneath, what actually happened.
func _report() -> void:
	_clear()
	_bg(Color("e8dcc0"))
	var gaz: Array = sim.gazette()
	var led: Array = sim.ledger().filter(func(s): return not s.contains("rumour about") or true).slice(0, 8)
	_text("THE MERCY GAZETTE\n\n" + "\n".join(gaz.slice(0, 6)), Vector2(200, 100), 38)
	_text("What you actually saw:\n" + ("\n".join(led) if not led.is_empty() else "(nothing out of the ordinary. Or nothing you were able to see.)"), Vector2(200, 500), 26, Color("4a3f7a"), 1500.0)
	_button("Night", Vector2(200, 900), _night)


func _night() -> void:
	if day_def()["night"] == "":
		_night_event()
		return
	_clear()
	_bg(Color("1b1a2e"))
	snoop = Snoop.new()
	ui.add_child(snoop)
	snoop.setup(state, day_def()["night"])
	snoop.finished.connect(func(_r): _night_event())


func _night_event() -> void:
	var ev: Dictionary = day_def().get("night_event", {})
	if ev.get("type", "") == "prelude":
		_slack([], true)
		return
	if ev.get("type", "") == "reply" and state.board.evidence.has(ev["if_evidence"]):
		_clear()
		_bg(Color("0e0d1a"))
		_text("4:10 a.m. The tape recorder is running by itself. The pipes have stopped dripping. Something is waiting for you to begin.", Vector2(260, 240), 40, Color("f6ecd2"))
		_button("Play the Mercy Roll", Vector2(260, 700), _reply)
		return
	_board()


func _reply() -> void:
	_clear()
	var r := RhythmUI.new()
	ui.add_child(r)
	r.setup("reply", lenient, true)
	r.finished.connect(func(res):
		_clear()
		_bg(Color("0e0d1a"))
		if res["answered"]:
			state.board.pin("LF-047", "what")
			state.board.complete_test("S20", state.day)
			_text("You stop. The room is very quiet.\n\nThen, from under the floor, from under the lake, 212 slow strokes of a bell answer you. One for each of them.", Vector2(260, 240), 42, Color("7fd0d8"))
		else:
			_text("You stop. Somewhere below, something almost answers. Not yet. The roll wants a steadier hand.", Vector2(260, 240), 42, Color("b8b0d8"))
		_button("Pack up", Vector2(260, 760), _board))


func _board() -> void:
	_clear()
	_bg(Color("efe4c8"))
	var b := BoardUI.new()
	ui.add_child(b)
	b.setup(state)
	b.finished.connect(_dusk_watch)


## STEER: the player's lever on tomorrow.
func _dusk_watch() -> void:
	_clear()
	_bg(Color("14121c"))
	var d := DuskUI.new()
	ui.add_child(d)
	d.setup(state, sim, cause, eligible_hosts())
	d.finished.connect(func(r): _slack([], false, r.get("watched", false)))


func _slack(_unused: Array = [], prelude: bool = false, watched: bool = false) -> void:
	_clear()
	_bg(Color("14121c"))
	state.advance()   # NIGHT -> SLACK
	var gone: Array = sim.slack()
	state.next_host = cause.pick(sim, eligible_hosts())
	var next_life: Dictionary = state.life_by_id(state.next_host if state.next_host != "" else state.baseline_next_id())
	var s := SlackUI.new()
	ui.add_child(s)
	if prelude:
		s.setup_lines(_prelude_lines(next_life))
		s.finished.connect(_new_day)
		return
	var extra: Array = []
	if watched:
		extra.append("You stayed up and watched the street. At 3:10 a.m. a red ribbon was tied on %s's door. Nobody was holding it." % next_life["name"])
	var se: Dictionary = day_def().get("slack_extra", {})
	if not se.is_empty():
		extra = se.get("hymn_aired" if state.flags.get("hymn_aired", false) else "hymn_declined", [])
	for id in gone:
		extra.append("%s is gone. By morning the Gazette will say they have relocated." % sim.people[id].display)
	s.setup(next_life, next_life["decision_time"], extra)
	s.finished.connect(_new_day)


func _new_day() -> void:
	state.advance()   # SLACK -> next day's WAKE (or ENDED)
	if days_by_life.has(state.current_life()["id"]) and state.phase == 0:
		start_day()
		return
	_clear()
	_bg(Color("f1dfc0"))
	var life: Dictionary = state.current_life()
	_text("DAY %d\n\nYou wake up as %s.\n\n(Their bedroom is built next pass.)\n\nSeals so far: %d / 40" % [state.day, life["name"], state.board.seals.size()], Vector2(260, 280), 46)


func _describe(n: Dictionary) -> String:
	var words := {"warmth": ["cold", "warm"], "candor": ["guarded", "candid"], "nerve": ["timid", "bold"],
		"curiosity": ["incurious", "curious"], "fidelity": ["off-script", "in character"]}
	var out: Array = []
	for k in words:
		var v := int(n[k])
		if absi(v) >= 8:
			out.append("  %s (%+d)" % [words[k][1 if v > 0 else 0], v])
	return "\n".join(out) if not out.is_empty() else "  unremarkable. A quiet day."


## The tutorial night: every beat here is something a sharp player can use later. None of it is explained.
func _prelude_lines(next_life: Dictionary) -> Array:
	var p: RefCounted = state.persona
	var what: String = state.flags.get("tutorial_decision_text", "You decide.")
	return [
		p.inner("11:58 p.m. %s It's the first sure thing you've done in months. You sleep like someone who has put something down." % what),
		"3:10 a.m. You wake for no reason. The room is very still. Out of the window the street is empty and blue, and the lake is making no sound at all.",
		"There is a red ribbon on your front door. It wasn't there at dusk. You know, because you locked up, and you looked.",
		"4:11. Down the hill the Town Hall clock reaches 4:12, and stops. You can hear it stop. Nothing moves. Not the lake, not the cat, not you.",
		"A minute. You count it: sixty. Sixty-one. Then a sound like a bell heard through a wall. Then nothing.",
		p.inner("Then: coffee. Not yours. Somebody else's kettle, somebody else's ceiling, somebody else's hands. And {you}, lying very still, hoping it's a dream.")]
