extends Control
## A modal settings sheet: text size, sound, haptics, graphics quality, and replaying the tutorial. Used by the title and the in-game menu.
## Values live in UiKit (persisted to user://ui_settings.cfg); `changed` fires after any of them moves so the host can re-apply.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal closed
signal changed
signal replay_tutorial

var show_replay := true
var _box: VBoxContainer


func _init() -> void:
	name = "SettingsPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP


func open() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	UiKit.fade_in(self, 0.15)


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new()
	add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.PAPER, UiKit.INK, 5, 12, 22))
	pc.custom_minimum_size = Vector2(620, 0)
	cc.add_child(pc)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	pc.add_child(outer)
	var sc := ScrollContainer.new()          # a long sheet scrolls rather than running off the screen; Done stays pinned below it
	sc.name = "SettingsScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_box)
	var foot := VBoxContainer.new()
	foot.name = "SettingsFoot"
	foot.add_theme_constant_override("separation", 10)
	outer.add_child(foot)
	_fit.call_deferred(sc, foot)
	var h := Label.new()
	h.text = "SETTINGS"
	h.add_theme_font_override("font", load("res://assets/fonts/Bangers-Regular.ttf"))
	h.add_theme_font_size_override("font_size", 46)
	h.add_theme_color_override("font_color", UiKit.RED)
	_box.add_child(h)
	# text size
	var ts := float(UiKit.get_v("text_scale"))
	var r1 := _row("Text size")
	var dn := _mk(r1, "A-", func(): _step_scale(-1), 28)
	dn.name = "TextSmaller"
	dn.custom_minimum_size.x = 76
	dn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var pct := Label.new()
	pct.text = "%d%%" % int(round(ts * 100.0))
	pct.name = "TextPct"
	pct.custom_minimum_size = Vector2(84, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct.add_theme_font_size_override("font_size", 26)
	pct.add_theme_color_override("font_color", UiKit.INK)
	r1.add_child(pct)
	var up := _mk(r1, "A+", func(): _step_scale(1), 28)
	up.name = "TextLarger"
	up.custom_minimum_size.x = 76
	up.size_flags_horizontal = Control.SIZE_SHRINK_END
	# toggles
	var r2 := _row("Sound")
	var sb := _mk(r2, "On" if bool(UiKit.get_v("sound")) else "Off", _toggle_sound, 26)
	sb.name = "SoundToggle"
	sb.custom_minimum_size.x = 200
	sb.size_flags_horizontal = Control.SIZE_SHRINK_END
	for v in [["Master volume", "vol_master"], ["Effects", "vol_sfx"], ["Music and tension", "vol_music"]]:
		var rv := _row(v[0])
		var sl := HSlider.new()
		sl.name = "Slider_" + String(v[1])
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(UiKit.get_v(v[1]))
		sl.custom_minimum_size = Vector2(300, 48)
		sl.size_flags_horizontal = Control.SIZE_SHRINK_END
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value_changed.connect(_set_vol.bind(String(v[1])))
		rv.add_child(sl)
	var r3 := _row("Vibration")
	var hb := _mk(r3, "On" if bool(UiKit.get_v("haptics")) else "Off", _toggle_haptics, 26)
	hb.name = "HapticsToggle"
	hb.custom_minimum_size.x = 200
	hb.size_flags_horizontal = Control.SIZE_SHRINK_END
	# quality
	var r4 := _row("Graphics")
	for q in UiKit.QUALITIES:
		var qb := _mk(r4, UiKit.QUALITY_NAMES[q], _set_quality.bind(q), 24)
		qb.name = "Quality_" + q
		qb.size_flags_horizontal = Control.SIZE_SHRINK_END
		qb.custom_minimum_size.x = 116
		if String(UiKit.get_v("quality")) == q:
			UiKit.set_button_style(qb, UiKit.INK, UiKit.MARIGOLD, UiKit.PAPER)
	var r5 := _row("Reduce interaction")
	var cm := _mk(r5, "Classic menus" if bool(UiKit.get_v("classic")) else "Hands-on", _toggle_classic, 24)
	cm.name = "ClassicToggle"
	cm.custom_minimum_size.x = 230
	cm.size_flags_horizontal = Control.SIZE_SHRINK_END
	var r6 := _row("Screen flicker")
	var fb := _mk(r6, "Reduced" if bool(UiKit.get_v("calm")) else "As written", _toggle_calm, 24)
	fb.name = "CalmToggle"
	fb.custom_minimum_size.x = 230
	fb.size_flags_horizontal = Control.SIZE_SHRINK_END
	if show_replay:
		var rb := _mk(foot, "Replay the tutorial", func(): replay_tutorial.emit(); close(), 26)
		rb.name = "ReplayTutorial"
	var cb := _mk(foot, "Done", close, 32)
	cb.name = "SettingsDone"
	UiKit.set_button_style(cb, UiKit.INK, UiKit.INK, UiKit.PAPER)
	cb.custom_minimum_size.y = 68


func _fit(sc: ScrollContainer, foot: Control) -> void:
	if not is_instance_valid(sc) or not is_instance_valid(_box) or not is_instance_valid(foot):
		return
	var want: float = _box.get_combined_minimum_size().y
	var room: float = size.y - 44.0 - 44.0 - foot.get_combined_minimum_size().y - 10.0
	sc.custom_minimum_size = Vector2(0, minf(want, maxf(room, 240.0)))


func _toggle_calm() -> void:
	UiKit.set_v("calm", not bool(UiKit.get_v("calm")))
	changed.emit()
	_build()


func _toggle_classic() -> void:
	UiKit.set_v("classic", not bool(UiKit.get_v("classic")))
	changed.emit()
	_build()


func _row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	_box.add_child(r)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", UiKit.INK)
	r.add_child(l)
	return r


func _mk(parent: Control, text: String, cb: Callable, size_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size_px)
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(cb)
	UiKit.press_fx(b)
	parent.add_child(b)
	return b


func _step_scale(dir: int) -> void:
	var cur := float(UiKit.get_v("text_scale"))
	var i := 0
	for k in UiKit.TEXT_SCALES.size():
		if absf(float(UiKit.TEXT_SCALES[k]) - cur) < absf(float(UiKit.TEXT_SCALES[i]) - cur):
			i = k
	i = clampi(i + dir, 0, UiKit.TEXT_SCALES.size() - 1)
	UiKit.set_v("text_scale", float(UiKit.TEXT_SCALES[i]))
	_build()
	changed.emit()


func _toggle_sound() -> void:
	UiKit.set_v("sound", not bool(UiKit.get_v("sound")))
	UiKit.apply_sound()
	_build()
	changed.emit()


func _set_vol(v: float, key: String) -> void:
	UiKit.set_v(key, v)
	UiKit.apply_sound()
	changed.emit()


func _toggle_haptics() -> void:
	UiKit.set_v("haptics", not bool(UiKit.get_v("haptics")))
	if bool(UiKit.get_v("haptics")):
		UiKit.haptic(40)
	_build()
	changed.emit()


func _set_quality(q: String) -> void:
	UiKit.set_v("quality", q)
	_build()
	changed.emit()


func close() -> void:
	closed.emit()
	queue_free()
