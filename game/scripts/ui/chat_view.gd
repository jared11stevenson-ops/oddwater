extends ScrollContainer
## An interview as a chat: short bubbles, the detective on the right, the other person on the left with their portrait. A long answer is
## cut short and opens when you tap it. Also here: the two small pieces of the "show them evidence" gesture, a notebook card you can drag
## (EvChip) and the portrait you drop it on (DropZone).

signal bubble_opened(index: int)

const Ptr = preload("res://scripts/ui/ptr.gd")
const Portrait = preload("res://scripts/art/portrait.gd")
const INK := Color("14121c")
const PAPER := Color("fffaf0")
const MINE := Color("f5b82e")
const THEIRS := Color("fffaf0")
const NEW := Color("3f7a4f")
const SHORT := 96

var list: VBoxContainer
var bubbles: Array = []           # [{side, text, label, open}]
var font_px := 20


class Bubble extends PanelContainer:
	var chat: Control
	var idx := 0
	var _press := Vector2.INF

	func _gui_input(e: InputEvent) -> void:
		var ev: Dictionary = Ptr.read(e)
		if ev.is_empty():
			return
		if ev["down"]:
			_press = ev["p"]
		elif ev["up"] and _press != Vector2.INF:
			if (ev["p"] as Vector2).distance_to(_press) < 12.0:
				chat.toggle(idx)
			_press = Vector2.INF


class EvChip extends Button:
	var eid := ""
	var title := ""

	func _get_drag_data(_at: Vector2) -> Variant:
		var pv := Label.new()
		pv.text = "  " + title + "  "
		pv.add_theme_font_size_override("font_size", 20)
		pv.add_theme_color_override("font_color", Color("14121c"))
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("f5b82e")
		sb.set_border_width_all(3)
		sb.border_color = Color("14121c")
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		pc.add_theme_stylebox_override("panel", sb)
		pc.add_child(pv)
		set_drag_preview(pc)
		return {"evidence": eid}


class DropZone extends Control:
	signal dropped(eid: String)
	signal tapped
	var armed := false            # a card is picked: say where it goes
	var over := false
	var _press := Vector2.INF

	func _init() -> void:
		name = "PortraitDrop"
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		over = data is Dictionary and (data as Dictionary).has("evidence")
		queue_redraw()
		return over

	func _drop_data(_at: Vector2, data: Variant) -> void:
		over = false
		queue_redraw()
		dropped.emit(String((data as Dictionary)["evidence"]))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			over = false
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		var ev: Dictionary = Ptr.read(e)
		if ev.is_empty():
			return
		if ev["down"]:
			_press = ev["p"]
		elif ev["up"] and _press != Vector2.INF:
			if (ev["p"] as Vector2).distance_to(_press) < 14.0:
				tapped.emit()
			_press = Vector2.INF

	func _draw() -> void:
		if armed or over:
			draw_rect(Rect2(Vector2.ZERO, size), Color("f5b82e"), false, 5.0 if over else 3.0)


func _init() -> void:
	name = "Chat"
	custom_minimum_size = Vector2(0, 250)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)


## side: "me" | "them" | "note" (a small aside, such as an Empathy read). `who` is a Portrait source for "them".
func add_bubble(side: String, text: String, p: RefCounted = null, expr: String = "", fresh: bool = false) -> void:
	var idx := bubbles.size()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(row)
	if side == "them" and p != null:
		var av: Control = Portrait.new()
		av.custom_minimum_size = Vector2(44, 57)
		av.setup(p, expr)
		av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(av)
	if side == "me":
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sp)
	var b := Bubble.new()
	b.chat = self
	b.idx = idx
	b.name = "Bubble_%d" % idx
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = MINE if side == "me" else (THEIRS if side == "them" else Color("e8e0cb"))
	sb.border_color = NEW if fresh else INK
	sb.set_border_width_all(4 if fresh else 3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("panel", sb)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END if side == "me" else Control.SIZE_SHRINK_BEGIN
	row.add_child(b)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_px if side != "note" else font_px - 3)
	l.add_theme_color_override("font_color", INK)
	b.add_child(l)
	if side == "them":
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sp2)
	bubbles.append({"side": side, "text": text, "label": l, "open": false})
	_set_text(idx)
	_to_bottom.call_deferred()


func _short(t: String) -> String:
	if t.length() <= SHORT:
		return t
	var cut := t.substr(0, SHORT)
	var sp := cut.rfind(" ")
	return (cut.substr(0, sp) if sp > 40 else cut) + "...  (tap)"


func _set_text(i: int) -> void:
	var bb: Dictionary = bubbles[i]
	var l: Label = bb["label"]
	var t: String = bb["text"] if bb["open"] else _short(String(bb["text"]))
	l.text = t
	var font := ThemeDB.fallback_font
	var fs: int = l.get_theme_font_size("font_size")
	var w := clampf(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0, 60.0, 270.0)
	l.custom_minimum_size = Vector2(w, 0)


func toggle(i: int) -> void:
	if i < 0 or i >= bubbles.size():
		return
	bubbles[i]["open"] = not bubbles[i]["open"]
	_set_text(i)
	bubble_opened.emit(i)
	(func(): if bubbles[i]["open"]: ensure_control_visible(bubbles[i]["label"])).call_deferred()


func is_cut(i: int) -> bool:
	return String(bubbles[i]["text"]).length() > SHORT


func _to_bottom() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	scroll_vertical = int(get_v_scroll_bar().max_value)
