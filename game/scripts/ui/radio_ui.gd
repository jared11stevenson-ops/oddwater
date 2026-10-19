extends Control
## Dedication Hour: five callers, four records each. Pick what to play. Watch the first letters.

signal finished(result: Dictionary)

const Radio = preload("res://scripts/core/radio.gd")

var core: RefCounted
var slot := 0
var header: Label
var ask: Label
var letters_label: Label
var box: VBoxContainer


func setup(set_id: String) -> void:
	core = Radio.new(set_id)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	header = Label.new()
	header.position = Vector2(70, 36)
	header.add_theme_font_size_override("font_size", 40)
	header.add_theme_color_override("font_color", Color("f5b82e"))
	add_child(header)
	ask = Label.new()
	ask.position = Vector2(70, 150)
	ask.custom_minimum_size = Vector2(1780, 0)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.add_theme_font_size_override("font_size", 36)
	ask.add_theme_color_override("font_color", Color("f6ecd2"))
	add_child(ask)
	letters_label = Label.new()
	letters_label.position = Vector2(70, 820)
	letters_label.add_theme_font_size_override("font_size", 56)
	letters_label.add_theme_color_override("font_color", Color("e23d3d"))
	add_child(letters_label)
	box = VBoxContainer.new()
	box.position = Vector2(70, 330)
	box.custom_minimum_size = Vector2(1780, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_show()


func _show() -> void:
	header.text = "ON AIR: " + core.def["title"]
	letters_label.text = "  ".join(Array(core.letters().split("")))
	for c in box.get_children():
		c.queue_free()
	if slot >= core.slot_count():
		var msg := "The hour is over."
		if core.spells():
			msg += "\nYou look at the letters you've played tonight. F. A. I. R. W. And on Vern's sheet, next week: A. T. E. R."
		ask.text = msg
		var b := Button.new(); b.text = "Sign off"
		b.custom_minimum_size = Vector2(520, 100)
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(finish)
		box.add_child(b)
		b.grab_focus()
		return
	var s: Dictionary = core.def["slots"][slot]
	ask.text = "Caller: %s\n%s" % [s["caller"], s["dedication"]]
	for i in s["options"].size():
		var b := Button.new(); b.text = s["options"][i]
		b.custom_minimum_size = Vector2(1780, 100)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 32)
		b.pressed.connect(pick_option.bind(slot, i))
		box.add_child(b)
	(box.get_child(0) as Button).grab_focus.call_deferred()


func pick_option(s: int, opt: int) -> bool:
	if s != slot:
		return false
	var right: bool = core.choose(s, opt)
	slot += 1
	_show()
	return right


func finish() -> void:
	finished.emit({"spells": core.spells(), "stars": core.stars(), "letters": core.letters()})
