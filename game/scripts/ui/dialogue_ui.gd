extends Control
## Comic caption + big touch-friendly choice buttons. Gamepad focus works out of the box.

signal finished(npc: String)

const Dialogue = preload("res://scripts/core/dialogue.gd")

var dlg: RefCounted
var npc := ""
var who_label: Label
var text_label: Label
var aside_label: Label
var box: VBoxContainer


func setup(state: RefCounted, file: String, id: String) -> void:
	dlg = Dialogue.new()
	dlg.start(state, file, id)
	npc = dlg.convo["npc"]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ffe9a8"); sb.border_color = Color("14121c"); sb.set_border_width_all(6); sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(140, 90)
	panel.custom_minimum_size = Vector2(1640, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	who_label = _label(v, 40, Color("e23d3d"))
	text_label = _label(v, 38, Color("14121c"))
	aside_label = _label(v, 28, Color("4a3f7a"))
	box = VBoxContainer.new()
	box.position = Vector2(140, 560)
	box.custom_minimum_size = Vector2(1640, 0)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	_show()


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1560, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _show() -> void:
	var n: Dictionary = dlg.current()
	who_label.text = n.get("speaker", "")
	text_label.text = n["text"]
	aside_label.text = n.get("aside", "")
	for c in box.get_children():
		c.queue_free()
	if dlg.finished:
		var b := Button.new(); b.text = "Next patient"
		b.custom_minimum_size = Vector2(700, 96)
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(func(): finished.emit(npc))
		box.add_child(b)
		b.grab_focus()
		return
	var cs: Array = dlg.choices()
	for i in cs.size():
		var b := Button.new(); b.text = cs[i]["text"]
		b.custom_minimum_size = Vector2(1640, 96)   # big target, one-thumb
		b.add_theme_font_size_override("font_size", 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(pick.bind(i))
		box.add_child(b)
	if box.get_child_count() > 0:
		(box.get_child(0) as Button).grab_focus.call_deferred()


func pick(i: int) -> void:
	dlg.choose(i)
	_show()
