extends SceneTree
## godot --headless --path game -s tests/persona_tests.gd : the player's own voice across bodies.

const Persona = preload("res://scripts/core/persona.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Dialogue = preload("res://scripts/core/dialogue.gd")
var fails := 0
var checks := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  FAIL: ", m)

func _initialize() -> void:
	var p = Persona.make("  Sam ", "she", "blunt", "Noted.")
	ok(p.name == "Sam" and p.pronouns()["subj"] == "she" and p.archetype == "blunt", "creator trims and stores")
	var blank = Persona.make("   ", "zzz", "nonsense", "")
	ok(blank.name == "Alex" and blank.pronoun_id == "they" and blank.archetype == "dry", "bad input falls back safely")
	ok(p.inner("{you} looks at {poss} hands. {subj} swallows.") == "Sam looks at her hands. she swallows.", "inner voice uses the persona's pronouns")
	# voice is deterministic and consistent: the same line always comes out the same
	var line := "\"I don't think that's true.\""
	ok(p.voice(line) == p.voice(line), "the same line sounds the same every time")
	ok(p.voice(line) != line and p.voice(line).begins_with("\"") and p.voice(line).ends_with("\""), "voice colours the line and keeps its quotes: %s" % p.voice(line))
	ok(p.voice("(Nod.)") == "(Nod.)", "stage directions are left alone")
	var other = Persona.make("Sam", "she", "warm", "Noted.")
	ok(p.voice(line) != other.voice(line), "different archetypes sound different")
	# style distance
	ok(p.distance_to("blunt") == 0.0 and p.distance_to("self") == 0.0, "no distance from your own voice")
	ok(p.distance_to("warm") == other.distance_to("blunt"), "distance is symmetric")
	ok(p.self_risk("warm") > p.self_risk("dry"), "sounding like yourself costs more around people unlike you (%d vs %d)" % [p.self_risk("warm"), p.self_risk("dry")])
	ok(p.self_risk("self") == 0, "no risk in your own body")
	ok(Persona.from_dict(p.to_dict()).to_dict() == p.to_dict(), "round-trips")

	# ---- dialogue modes, in a host's body
	var g := GameState.new()
	g.persona = Persona.make("Sam", "she", "blunt", "Noted.")
	g.next_host = "mags"
	for i in 5: g.advance()             # Day 2: Mags
	ok(g.current_life()["id"] == "mags", "Day 2 is Mags")
	var d := Dialogue.new()
	d.start(g, "day01.json", "silas")
	var cs: Array = d.choices()
	ok(d.mode_of(cs[0]) == "cover" and d.mode_of(cs[1]) == "self", "'Open wide' is cover; 'do I know you?' is yourself")
	ok(d.display_text(cs[1]) != cs[1]["text"], "your own lines wear your voice")
	ok(d.display_text(cs[0]) == cs[0]["text"], "cover lines are written as the host")
	var before: int = g.suspicion.get_s("silas")
	d.choose(0)                         # cover
	ok(g.cover_lines == 1 and g.suspicion.get_s("silas") == before, "cover costs no suspicion; it's counted")
	var d2 := Dialogue.new()
	d2.start(g, "day01.json", "silas")
	d2.choose(1)                        # self
	ok(g.self_lines == 1 and g.suspicion.get_s("silas") >= g.persona.self_risk("wry"), "speaking as yourself costs suspicion in proportion to the mismatch")
	# identity: a day of cover wears you down; a day as yourself holds
	var cover_day := GameState.new()
	cover_day.cover_lines = 8
	cover_day.close_day(60.0)
	var self_day := GameState.new()
	self_day.self_lines = 8
	self_day.close_day(60.0)
	ok(cover_day.drift > self_day.drift, "a day in cover erodes you; a day as yourself holds (%.1f vs %.1f)" % [cover_day.drift, self_day.drift])
	ok(cover_day.identity() < self_day.identity(), "identity is the other side of drift")
	# in your own body (the tutorial) lines are always yours and cost nothing
	var t := GameState.new()
	t.persona = Persona.make("Sam", "she", "blunt", "Noted.")
	var td := Dialogue.new()
	td.start(t, "day01.json", "silas")
	ok(td.mode_of(td.choices()[0]) == "self" and t.self_lines == 0, "in your own body everything is you")
	td.choose(0)
	ok(t.suspicion.get_s("silas") == 0 and t.cover_lines == 0, "and nobody raises an eyebrow")
	var saved := GameState.new(); saved.persona = Persona.make("Sam", "she", "wry", "Noted.")
	saved.save_to("user://persona.json")
	var loaded := GameState.new()
	ok(loaded.load_from("user://persona.json") and loaded.persona.name == "Sam" and loaded.persona.archetype == "wry", "persona survives a save")
	print("%d checks, %d failed" % [checks, fails])
	quit(fails)
