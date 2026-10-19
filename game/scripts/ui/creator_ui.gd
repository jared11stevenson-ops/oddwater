extends Control
## Make your character: this is who you are in every body. Name, pronouns, how you talk, what you say when you're nervous.

signal finished(result: Dictionary)

const Data = preload("res://scripts/core/data.gd")

var cfg: Dictionary
var name_edit: LineEdit
var pronoun := "they"
var archetype := "dry"
var catchphrase := ""
var sample: Label
var buttons: Dictionary = {}


func setup() -> void:
	cfg = Data.load_json("persona.json")
	catchphrase = cfg["catchphrases"][0]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label("WHO ARE YOU?", Vector2(80, 40), 52, Color("14121c"))
	_label("Your name", Vector2(80, 150), 30, Color("4a3f7a"))
	name_edit = LineEdit.new()
	name_edit.text = "Alex"
	name_edit.position = Vector2(80, 195)
	name_edit.custom_minimum_size = Vector2(520, 70)
	name_edit.add_theme_font_size_override("font_size", 34)
	name_edit.max_length = 14
	add_child(name_edit)
	_label("Pronouns", Vector2(760, 150), 30, Color("4a3f7a"))
	var x := 760
	for pr in cfg["pronouns"]:
		_choice("pron_" + pr["id"], "%s/%s" % [pr["subj"], pr["obj"]], Vector2(x, 195), pick_pronoun.bind(pr["id"]), 200)
		x += 215
	_label("How you talk", Vector2(80, 320), 30, Color("4a3f7a"))
	x = 80
	for a in cfg["archetypes"]:
		_choice("arch_" + a, cfg["archetypes"][a]["label"], Vector2(x, 365), pick_archetype.bind(a), 220)
		x += 235
	sample = _label("", Vector2(80, 470), 34, Color("14121c"), 1700)
	_label("What you say when you're stalling", Vector2(80, 580), 30, Color("4a3f7a"))
	var y := 625
	var i := 0
	for c in cfg["catchphrases"]:
		_choice("catch_%d" % i, "\"%s\"" % c, Vector2(80, y), pick_catch.bind(c), 1100)
		y += 80
		i += 1
	var go := Button.new(); go.text = "This is me"
	go.position = Vector2(1400, 940)
	go.custom_minimum_size = Vector2(440, 100)
	go.add_theme_font_size_override("font_size", 36)
	go.pressed.connect(finish)
	add_child(go)
	_refresh()


func _label(t: String, pos: Vector2, size: int, col: Color, w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	if w > 0.0:
		l.custom_minimum_size = Vector2(w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _choice(id: String, text: String, pos: Vector2, cb: Callable, w: float) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(w, 64)
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	add_child(b)
	buttons[id] = b


func pick_pronoun(id: String) -> void:
	pronoun = id
	_refresh()


func pick_archetype(id: String) -> void:
	archetype = id
	_refresh()


func pick_catch(c: String) -> void:
	catchphrase = c
	_refresh()


func _refresh() -> void:
	for id in buttons:
		var b: Button = buttons[id]
		if id.begins_with("pron_"):
			b.button_pressed = id == "pron_" + pronoun
		elif id.begins_with("arch_"):
			b.button_pressed = id == "arch_" + archetype
		elif id.begins_with("catch_"):
			b.button_pressed = b.text == "\"%s\"" % catchphrase
	sample.text = "That's how you sound:  %s" % cfg["archetypes"][archetype]["sample"]


func finish() -> void:
	finished.emit({"name": name_edit.text, "pronoun": pronoun, "archetype": archetype, "catch": catchphrase})
