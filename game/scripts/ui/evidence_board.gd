extends Control
## The evidence board: claims from the notebook as cards on a corkboard (grouped by place and time, coloured by channel), the people you
## are looking at as portrait pins along the bottom. MOVE mode drags cards (a tap expands one); STRING mode drags a string from a card to a
## person (or back) to record your theory. Red threads join claims the rules of evidence say cannot both stand. The board only draws and
## reports: the HUD writes the theory through the game and persists card positions.

signal string_made(claim: String, person: String)
signal moved(claim: String, nx: float, ny: float)
signal pin_tapped(person: String)

const Ptr = preload("res://scripts/ui/ptr.gd")
const Portrait = preload("res://scripts/art/portrait.gd")
const INK := Color("14121c")
const PAPER := Color("fffaf0")
const MARIGOLD := Color("f5b82e")
const RED := Color("e23d3d")
const CORK := Color("b98a58")
const CHANNEL := {"physical": Color("a8412f"), "testimony": Color("2f6f8f"), "records": Color("7b5a9e"), "lab": Color("3f7a4f")}
const CARD := Vector2(130, 68)
const CARD_OPEN := Vector2(236, 168)
const PIN := Vector2(64, 96)

var mode := "move"                # "move" | "string"
var cards: Dictionary = {}        # claim id -> Card
var pins: Dictionary = {}         # person id -> Pin
var links: Array = []             # [{claim, person}]
var red: Array = []               # [{a: claim id, b: claim id, why}]
var heads: Array = []             # [{text, pos}]
var selected_pin := ""
var _from: Control = null         # the card or pin a string is being pulled from
var _tip := Vector2.ZERO


class Card extends Control:
	var data: Dictionary = {}
	var open := false
	var board: Control
	var _press := Vector2.INF
	var _grab := Vector2.ZERO
	var _dragged := false

	func _init(d: Dictionary, b: Control) -> void:
		data = d
		board = b
		name = "Card_" + String(d["cid"])
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2(130, 68)
		custom_minimum_size = size
		clip_contents = true

	func toggle() -> void:
		open = not open
		size = Vector2(236, 168) if open else Vector2(130, 68)
		position = Vector2(clampf(position.x, 0.0, maxf(board.size.x - size.x, 0.0)), clampf(position.y, 0.0, maxf(board.size.y - size.y, 0.0)))
		move_to_front()
		board.queue_redraw()
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		var ev: Dictionary = Ptr.read(e)
		if ev.is_empty():
			return
		var p: Vector2 = ev["p"]
		var bp: Vector2 = position + p
		if ev["down"]:
			_press = bp
			_grab = p
			_dragged = false
			move_to_front()
			if board.mode == "string":
				board._begin_string(self, bp)
			accept_event()
		elif ev["move"] and _press != Vector2.INF:
			if board.mode == "string":
				board._pull_string(bp)
			else:
				if not _dragged and bp.distance_to(_press) > 10.0:
					_dragged = true
				if _dragged:
					position = Vector2(clampf(bp.x - _grab.x, 0.0, maxf(board.size.x - size.x, 0.0)), clampf(bp.y - _grab.y, 0.0, maxf(board.size.y - size.y, 0.0)))
					board.queue_redraw()
			accept_event()
		elif ev["up"] and _press != Vector2.INF:
			_press = Vector2.INF
			if board.mode == "string":
				board._end_string(bp)
			elif _dragged:
				board.moved.emit(String(data["cid"]), position.x / maxf(board.size.x, 1.0), position.y / 1000.0)
			else:
				toggle()
			accept_event()

	func _draw() -> void:
		var col: Color = board.CHANNEL.get(data["channel"], Color("7b5a9e"))
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(Vector2.ZERO, size), board.PAPER)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 8)), col)
		draw_rect(Rect2(Vector2.ZERO, size), board.INK, false, 2.0)
		draw_circle(Vector2(size.x / 2.0, 6), 6.0, board.RED)
		var w := size.x - 14.0
		var tl: PackedStringArray = _wrap(String(data["title"]), font, w, 16)
		for i in mini(tl.size(), 2):
			draw_string(font, Vector2(7, 28 + i * 18), tl[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, board.INK)
		if not open:
			draw_string(font, Vector2(7, 62), _elide(String(data["sub"]), font, w, 15), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col.darkened(0.1))
		else:
			var sy := 28 + 18 * mini(tl.size(), 2) + 2
			draw_string(font, Vector2(7, sy), String(data["sub"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col.darkened(0.1))
			var lines: PackedStringArray = _wrap(String(data["text"]), font, w, 16)
			for i in mini(lines.size(), 5):
				draw_string(font, Vector2(7, sy + 24 + i * 18), lines[i] + ("..." if i == 4 and lines.size() > 5 else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, board.INK)

	static func _elide(t: String, font: Font, w: float, fs: int) -> String:
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return t
		var out := t
		while out.length() > 1 and font.get_string_size(out + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			out = out.substr(0, out.length() - 1)
		return out + "..."

	static func _wrap(t: String, font: Font, w: float, fs: int) -> PackedStringArray:
		var out := PackedStringArray()
		var cur := ""
		for word in t.replace("\n", " ").split(" "):
			var trial := word if cur == "" else cur + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = trial
		if cur != "":
			out.append(cur)
		return out


class Pin extends Control:
	var person := ""
	var label := ""
	var board: Control
	var _press := false

	func _init(id: String, nm: String, p: RefCounted, b: Control) -> void:
		person = id
		label = nm
		board = b
		name = "Pin_" + id
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2(64, 96)
		custom_minimum_size = size
		var pt: Control = Portrait.new()
		pt.custom_minimum_size = Vector2(56, 70)
		pt.size = Vector2(56, 70)
		pt.position = Vector2(4, 8)
		pt.setup(p, "")
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pt)

	func _gui_input(e: InputEvent) -> void:
		var ev: Dictionary = Ptr.read(e)
		if ev.is_empty():
			return
		var bp: Vector2 = position + (ev["p"] as Vector2)
		if ev["down"]:
			_press = true
			if board.mode == "string":
				board._begin_string(self, bp)
			accept_event()
		elif ev["move"] and _press:
			if board.mode == "string":
				board._pull_string(bp)
			accept_event()
		elif ev["up"] and _press:
			_press = false
			if board.mode == "string":
				board._end_string(bp)
			else:
				board.selected_pin = "" if board.selected_pin == person else person
				board.pin_tapped.emit(board.selected_pin)
				board.queue_redraw()
				queue_redraw()
			accept_event()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var sel: bool = board.selected_pin == person
		draw_rect(Rect2(Vector2.ZERO, Vector2(64, 78)), Color("fffaf0") if not sel else MARIGOLD_C)
		draw_rect(Rect2(Vector2.ZERO, Vector2(64, 78)), board.INK, false, 2.0)
		draw_circle(Vector2(32, 4), 6.0, board.RED)
		draw_string(font, Vector2(0, 92), label, HORIZONTAL_ALIGNMENT_CENTER, 64, 16, board.INK)

	const MARIGOLD_C := Color("f5b82e")


func _init() -> void:
	name = "EvidenceBoard"
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 560)
	clip_contents = true


## cards: DetectiveGame.board_cards(); people: [{id, name, p}]; positions: {claim id: [x / width, y / 1000 px]}. The board grows to fit its cards.
func set_data(card_list: Array, people: Array, theory: Array, contradictions: Array, positions: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	cards.clear()
	pins.clear()
	heads.clear()
	links = theory
	red = []
	var sz := size if size.x > 10.0 and size.y > 200.0 else Vector2(436, 560)
	var per_row := maxi(int((sz.x - 8.0) / (PIN.x + 6.0)), 1)
	var rows := maxi(int(ceil(float(people.size()) / float(per_row))), 1)
	var strip := float(rows) * (PIN.y + 6.0) + 6.0
	# cards flow in rows under a heading for each place
	var y := 8.0
	var last := ""
	var x := 6.0
	var gap := (sz.x - 12.0 - 3.0 * CARD.x) / 2.0
	var col := 0
	for cd in card_list:
		if cd["group"] != last:
			last = cd["group"]
			if col != 0:
				y += CARD.y + 8.0
				col = 0
			heads.append({"text": String(last).to_upper(), "pos": Vector2(8, y + 14)})
			y += 22.0
		var card := Card.new(cd, self)
		var def := Vector2(x + float(col) * (CARD.x + gap), y)
		if positions.has(cd["cid"]):
			var pp: Array = positions[cd["cid"]]
			def = Vector2(float(pp[0]) * sz.x, float(pp[1]) * 1000.0)
		card.position = def
		add_child(card)
		cards[cd["cid"]] = card
		col += 1
		if col == 3:
			col = 0
			y += CARD.y + 8.0
	if col != 0:
		y += CARD.y + 8.0
	var h := maxf(y + strip + 8.0, 520.0)
	custom_minimum_size = Vector2(0, h)
	size = Vector2(sz.x, h)
	for cid in cards:
		cards[cid].position.y = clampf(cards[cid].position.y, 0.0, h - strip - CARD.y)
	for i in people.size():
		var pin := Pin.new(String(people[i]["id"]), String(people[i]["name"]), people[i]["p"], self)
		pin.position = Vector2(6.0 + float(i % per_row) * (PIN.x + 6.0), h - strip + float(i / per_row) * (PIN.y + 6.0))
		add_child(pin)
		pins[people[i]["id"]] = pin
	for k in contradictions:
		var ca := _card_of_entry(String(k["a"]))
		var cb := _card_of_entry(String(k["b"]))
		if ca != "" and cb != "":
			red.append({"a": ca, "b": cb, "why": String(k["why"]), "who": String(k.get("who", ""))})
	queue_redraw()


func _card_of_entry(eid: String) -> String:
	for cid in cards:
		if cards[cid].data["eid"] == eid:
			return cid
	return ""


func set_mode(m: String) -> void:
	mode = m
	queue_redraw()


# ---- strings
func _begin_string(from: Control, p: Vector2) -> void:
	_from = from
	_tip = p
	queue_redraw()


func _pull_string(p: Vector2) -> void:
	_tip = p
	queue_redraw()


func _end_string(p: Vector2) -> void:
	var from := _from
	_from = null
	if from == null:
		return
	var hit := _control_at(p, from)
	if hit != null:
		if from is Card and hit is Pin:
			link_up(String(from.data["cid"]), String(hit.person))
		elif from is Pin and hit is Card:
			link_up(String(hit.data["cid"]), String(from.person))
	queue_redraw()


func _control_at(p: Vector2, skip: Control) -> Control:
	var best: Control = null
	for c in get_children():
		if c == skip or not (c is Card or c is Pin):
			continue
		if Rect2(c.position, c.size).grow(10.0).has_point(p):
			if best == null or (c is Card and best is Pin):
				best = c
	return best


## Record (or cut) a string from a claim to a person.
func link_up(claim: String, person: String) -> void:
	string_made.emit(claim, person)


func card_rect(cid: String) -> Rect2:
	var c: Control = cards.get(cid)
	return Rect2(c.position, c.size) if c != null else Rect2()


func _sag(a: Vector2, b: Vector2, amount: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var mid := (a + b) / 2.0 + Vector2(0, amount)
	for i in 13:
		var t := float(i) / 12.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), CORK)
	# cork speckle and a wooden frame
	for i in 90:
		var h := hash(i * 7919)
		draw_circle(Vector2(float(h % 1000) / 1000.0 * size.x, float((h / 1000) % 1000) / 1000.0 * size.y), 2.0 + float(h % 3), Color("8f6a3f", 0.35))
	draw_rect(Rect2(Vector2.ZERO, size), Color("5a3d22"), false, 8.0)
	for h2 in heads:
		draw_string(font, h2["pos"], h2["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("3a2814", 0.8))
	for l in links:
		var c: Control = cards.get(l["claim"])
		var p: Control = pins.get(l["person"])
		if c != null and p != null:
			var a := c.position + Vector2(c.size.x / 2.0, 6.0)
			var b := p.position + Vector2(32, 4)
			draw_polyline(_sag(a, b, 22.0), Color("f1e2b8"), 4.0, true)
			draw_polyline(_sag(a, b, 22.0), Color("6b5a3a"), 1.5, true)
	for r in red:
		var ca: Control = cards.get(r["a"])
		var cb: Control = cards.get(r["b"])
		if ca != null and cb != null:
			var a2 := ca.position + Vector2(ca.size.x / 2.0, 6.0)
			var b2 := cb.position + Vector2(cb.size.x / 2.0, 6.0)
			draw_polyline(_sag(a2, b2, 16.0), RED, 5.0, true)
			var mid := (a2 + b2) / 2.0 + Vector2(0, 12)
			draw_circle(mid, 13.0, RED)
			draw_string(font, mid + Vector2(-4, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
	if _from != null:
		var a3: Vector2 = _from.position + Vector2(_from.size.x / 2.0, 6.0)
		draw_polyline(_sag(a3, _tip, 14.0), MARIGOLD, 5.0, true)
		draw_circle(_tip, 9.0, MARIGOLD)
