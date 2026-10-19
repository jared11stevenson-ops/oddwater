extends Control
## The Case Board: cards -> pin to Who/What/When/Why -> string two together -> test Seals.

signal finished

const Data = preload("res://scripts/core/data.gd")
const QUESTIONS := ["who", "what", "when", "why"]

var state: RefCounted
var defs: Dictionary
var cards: Dictionary = {}
var selected: Array = []
var info: Label
var ties_label: Label
var seal_box: VBoxContainer
var grid: GridContainer


func setup(game_state: RefCounted) -> void:
	state = game_state
	defs = Data.load_json("evidence.json")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "THE CASE BOARD"
	title.position = Vector2(70, 36)
	title.add_theme_font_size_override("font_size", 46)
	add_child(title)
	var help := Label.new()
	help.text = "Pick a card, pin it to a question. Pick two pinned cards, then tie them together."
	help.position = Vector2(70, 100)
	help.add_theme_font_size_override("font_size", 26)
	help.add_theme_color_override("font_color", Color("4a3f7a"))
	add_child(help)
	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(70, 160)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	add_child(grid)
	var row := HBoxContainer.new()
	row.position = Vector2(70, 600)
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	for q in QUESTIONS:
		var b := Button.new(); b.text = "Pin: " + q.capitalize() + "?"
		b.custom_minimum_size = Vector2(240, 84)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(pin_selected.bind(q))
		row.add_child(b)
	var tie := Button.new(); tie.text = "Tie together"
	tie.custom_minimum_size = Vector2(260, 84)
	tie.add_theme_font_size_override("font_size", 28)
	tie.pressed.connect(tie_selected)
	row.add_child(tie)
	info = Label.new()
	info.position = Vector2(70, 700)
	info.custom_minimum_size = Vector2(1780, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 28)
	add_child(info)
	ties_label = Label.new()
	ties_label.position = Vector2(70, 440)
	ties_label.custom_minimum_size = Vector2(1780, 0)
	ties_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ties_label.add_theme_font_size_override("font_size", 26)
	ties_label.add_theme_color_override("font_color", Color("e23d3d"))
	add_child(ties_label)
	seal_box = VBoxContainer.new()
	seal_box.position = Vector2(70, 790)
	seal_box.add_theme_constant_override("separation", 8)
	add_child(seal_box)
	var done := Button.new(); done.text = "Close the board"
	done.position = Vector2(1400, 960)
	done.custom_minimum_size = Vector2(440, 84)
	done.add_theme_font_size_override("font_size", 30)
	done.pressed.connect(func(): finished.emit())
	add_child(done)
	_refresh()


func _card_text(id: String) -> String:
	var d: Dictionary = defs.get(id, {"title": id})
	var s: String = d["title"]
	if state.board.pins.has(id):
		s += "\n[" + String(state.board.pins[id]).to_upper() + "?]"
	return s


func _refresh() -> void:
	for c in grid.get_children():
		c.queue_free()
	cards.clear()
	var ids: Array = state.board.evidence.keys()
	ids.sort()
	for id in ids:
		var b := Button.new()
		b.text = _card_text(id)
		b.custom_minimum_size = Vector2(430, 110)
		b.add_theme_font_size_override("font_size", 24)
		b.toggle_mode = true
		b.button_pressed = selected.has(id)
		b.pressed.connect(toggle_card.bind(id))
		grid.add_child(b)
		cards[id] = b
	var lines: Array = []
	for l in state.board.links:
		lines.append("%s  ———  %s" % [defs.get(l[0], {"title": l[0]})["title"], defs.get(l[1], {"title": l[1]})["title"]])
	ties_label.text = ("Red strings:\n" + "\n".join(lines)) if not lines.is_empty() else "No strings yet."
	for c in seal_box.get_children():
		c.queue_free()
	for sid in state.board.testable():
		var truth: String = state.board.seal_defs[sid]["truth"]
		var b := Button.new()
		b.text = "Test %s: %s" % [sid, truth]
		b.custom_minimum_size = Vector2(1780, 64)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(test_seal.bind(sid))
		seal_box.add_child(b)


func toggle_card(id: String) -> void:
	if selected.has(id):
		selected.erase(id)
	else:
		selected.append(id)
		if selected.size() > 2:
			selected.pop_front()
	_refresh()


func pin_selected(question: String) -> bool:
	if selected.is_empty():
		info.text = "Pick a card first."
		return false
	var okp := false
	for id in selected:
		okp = state.board.pin(id, question) or okp
	info.text = "Pinned to %s?" % question.capitalize()
	_refresh()
	return okp


func tie_selected() -> bool:
	if selected.size() != 2:
		info.text = "Pick exactly two cards to tie together."
		return false
	var okl: bool = state.board.link(selected[0], selected[1])
	info.text = "You tie a red string between them. Interesting." if okl else "Pin both cards first (or they are already tied)."
	_refresh()
	return okl


func test_seal(sid: String) -> bool:
	var sealed: bool = state.board.try_link_test(sid, state.day)
	if sealed:
		info.text = "SEAL %s. %s" % [sid, state.board.seal_defs[sid]["truth"]]
	else:
		info.text = "The strings don't hold yet. Something isn't joined up."
	_refresh()
	return sealed
