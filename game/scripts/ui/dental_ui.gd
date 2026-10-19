extends Control
## X-ray overlay: tap the teeth whose restoration matches the old chart. Cozy: wrong taps only add "doubt".

signal finished(result: Dictionary)

const Dental = preload("res://scripts/core/dental.gd")

var dental: RefCounted
var buttons: Dictionary = {}
var status: Label
var done_btn: Button
var wren_said := false


func setup(case_id: String) -> void:
	dental = Dental.new(case_id)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var c: Dictionary = dental.case_def
	var title := Label.new()
	title.text = "Overlay: %s  over  %s" % [c["patient"], c["record_name"]]
	title.position = Vector2(80, 50)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("14121c"))
	add_child(title)
	var how := Label.new()
	how.text = "Tap the teeth where the X-ray and the old chart show the SAME work (same type, metal and maker's mark)."
	how.position = Vector2(80, 115)
	how.add_theme_font_size_override("font_size", 28)
	how.add_theme_color_override("font_color", Color("4a3f7a"))
	add_child(how)
	for t in range(1, 33):
		var row := 0 if t <= 16 else 1
		var col := (t - 1) if t <= 16 else (32 - t)   # lower arch runs right-to-left
		var b := Button.new()
		b.text = "%d\nX-ray\n%s\nfilm\n%s" % [t, _glyph(dental.tooth_current(t)), _glyph(dental.tooth_record(t))]
		b.clip_text = true
		b.position = Vector2(60 + col * 112, 230 + row * 250)
		b.custom_minimum_size = Vector2(106, 220)
		b.size = Vector2(106, 220)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(flag_tooth.bind(t))
		add_child(b)
		buttons[t] = b
	status = Label.new()
	status.position = Vector2(80, 760)
	status.add_theme_font_size_override("font_size", 34)
	status.add_theme_color_override("font_color", Color("14121c"))
	status.custom_minimum_size = Vector2(1700, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	done_btn = Button.new()
	done_btn.text = "Put the film away"
	done_btn.position = Vector2(80, 920)
	done_btn.custom_minimum_size = Vector2(520, 96)
	done_btn.add_theme_font_size_override("font_size", 34)
	done_btn.pressed.connect(finish)
	add_child(done_btn)
	_update()
	buttons[1].grab_focus()


func _glyph(r: Dictionary) -> String:
	if r.is_empty():
		return "-"
	var m: String = {"gold": "Au", "amalgam": "Am", "composite": "Co", "porcelain": "Pc"}.get(r["material"], "?")
	var k: String = {"crown": "Cr", "filling": "Fi", "inlay": "In"}.get(r["kind"], "?")
	return "%s %s %s" % [m, k, r["mark"]]


func flag_tooth(t: int) -> String:
	var res: String = dental.flag(t)
	var b: Button = buttons[t]
	if res == "match":
		b.add_theme_stylebox_override("normal", _hl(Color("f5b82e")))
		b.add_theme_stylebox_override("focus", _hl(Color("f5b82e")))
	elif res == "miss":
		b.add_theme_stylebox_override("normal", _hl(Color("f2a0a0")))
		b.add_theme_stylebox_override("focus", _hl(Color("f2a0a0")))
	_update()
	return res


func _update() -> void:
	var need: int = dental.case_def["need"]
	var s := "Matches: %d / %d     Doubt: %d" % [dental.flagged.size(), need, dental.doubt]
	if dental.proven():
		s += "\n" + dental.verdict()
		done_btn.text = "Stamp it"
	elif dental.doubt >= 3 and not wren_said:
		wren_said = true
		s += "\n\"Look for the little CP stamp,\" says a small, dry voice in your head."
	elif dental.doubt >= 3:
		s += "\n\"Look for the little CP stamp.\""
	status.text = s


func finish() -> void:
	var proven: bool = dental.proven()
	finished.emit({"proven": proven, "clean": dental.is_clean_case(), "doubt": dental.doubt,
		"seal": dental.case_def["seal"], "verdict": dental.verdict(), "npc": dental.case_def["npc"]})


func _hl(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = Color("14121c")
	s.set_border_width_all(4)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s
