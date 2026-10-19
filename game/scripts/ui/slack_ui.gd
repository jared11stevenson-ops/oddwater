extends Control
## 4:12 a.m. The Slack: the Hush loosens for sixty seconds, the lake waves back, and the Take.

signal finished

var lines: Array = []
var label: Label
var idx := 0
var btn: Button


func setup(next_life: Dictionary, decision_time: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	lines = [
		"4:11 a.m.",
		"The Town Hall clock reaches 4:12, and stops. It is taking its minute.",
		"On the lake, the ripples come in step. They are waving back.",
		"%s hit send at %s last night. A decision. A small one, the size of a life." % [next_life["name"], decision_time],
		"A sound like a church bell heard through a wall. The bed is empty. The kettle is already on.",
		"Someone tied a red ribbon on a doorknob.",
		"Tomorrow you will be:\n\n%s, %s." % [next_life["name"], next_life["role"].to_lower()]]
	label = Label.new()
	label.position = Vector2(240, 280)
	label.custom_minimum_size = Vector2(1440, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color("f6ecd2"))
	add_child(label)
	btn = Button.new()
	btn.position = Vector2(240, 820)
	btn.custom_minimum_size = Vector2(520, 100)
	btn.add_theme_font_size_override("font_size", 34)
	btn.pressed.connect(next_line)
	add_child(btn)
	_show()
	btn.grab_focus()


func _show() -> void:
	label.text = lines[idx]
	btn.text = "Wake up" if idx == lines.size() - 1 else "..."
	if idx == lines.size() - 1:
		label.add_theme_color_override("font_color", Color("f5b82e"))


func next_line() -> void:
	if idx >= lines.size() - 1:
		finished.emit()
		return
	idx += 1
	_show()
