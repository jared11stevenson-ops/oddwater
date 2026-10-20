extends Control
## A floating on-screen stick for the left thumb. Appears where you touch, anywhere in its zone. Works with touch and mouse.

signal moved(v: Vector2)

var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var radius := 90.0
var active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_origin = t.position
			_knob = _origin
			active = true
			queue_redraw()
		elif not t.pressed and t.index == _touch:
			_release()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _touch:
			_drag(d.position)
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		var m := e as InputEventMouseButton
		if m.pressed:
			_touch = 99
			_origin = m.position
			_knob = _origin
			active = true
			queue_redraw()
		elif _touch == 99:
			_release()
	elif e is InputEventMouseMotion and _touch == 99:
		_drag((e as InputEventMouseMotion).position)


func _drag(p: Vector2) -> void:
	var off := p - _origin
	if off.length() > radius:
		off = off.normalized() * radius
	_knob = _origin + off
	moved.emit(Vector2(off.x, -off.y) / radius)
	queue_redraw()


func _release() -> void:
	_touch = -1
	active = false
	moved.emit(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	draw_circle(_origin, radius, Color(0.08, 0.07, 0.11, 0.28))
	draw_arc(_origin, radius, 0.0, TAU, 32, Color(0.96, 0.91, 0.82, 0.8), 4.0, true)
	draw_circle(_knob, radius * 0.42, Color(0.96, 0.72, 0.18, 0.85))
	draw_arc(_knob, radius * 0.42, 0.0, TAU, 20, Color("14121c"), 3.0, true)
