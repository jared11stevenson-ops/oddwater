extends Control
## Boot: title -> Day 1 Wake & Snoop -> brief. Perform / Night follow in later passes.

const GameState = preload("res://scripts/core/game_state.gd")
const Snoop = preload("res://scripts/ui/snoop.gd")

var state: RefCounted
var snoop: Control


func _ready() -> void:
	state = GameState.new()
	_title()


func _clear() -> void:
	for c in get_children():
		c.queue_free()


func _title() -> void:
	_clear()
	var l := Label.new()
	l.text = "UNDERSTUDY\n\nEvery morning someone in Little Mercy vanishes.\nEvery morning you wake up as them."
	l.position = Vector2(300, 300)
	l.add_theme_font_size_override("font_size", 48)
	add_child(l)
	var b := Button.new()
	b.text = "Wake up"
	b.position = Vector2(300, 700)
	b.custom_minimum_size = Vector2(360, 100)
	b.pressed.connect(start_day)
	add_child(b)
	b.grab_focus()


func start_day() -> void:
	_clear()
	snoop = Snoop.new()
	add_child(snoop)
	snoop.setup(state, "homes/%s.json" % state.current_life()["id"])
	snoop.finished.connect(_brief)


func _brief(result: Dictionary) -> void:
	_clear()
	var l := Label.new()
	var life: Dictionary = state.current_life()
	var body := "You are %s, %s.\n\nYou found %d things (%d clues)." % [life["name"], life["role"].to_lower(), result["found"], result["evidence"].size()]
	if result["vague_brief"]:
		body += "\nYou only half know who you are. People will notice."
	else:
		body += "\nYou know enough to get through the morning."
	body += "\n\nSomeone tied a red ribbon on your doorknob. Who?"
	l.text = body
	l.position = Vector2(300, 260)
	l.add_theme_font_size_override("font_size", 44)
	add_child(l)
	var b := Button.new()
	b.text = "Go to work (Perform: next pass)"
	b.position = Vector2(300, 760)
	b.custom_minimum_size = Vector2(520, 100)
	add_child(b)
	b.grab_focus()
