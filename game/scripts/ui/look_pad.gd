extends Control
## The right-hand side of the screen: drag to look around, pinch (or wheel) to zoom the camera. Touch and mouse.

signal dragged(delta: Vector2)
signal zoomed(factor: float)

var _touch := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
		elif not t.pressed and t.index == _touch:
			_touch = -1
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _touch:
			dragged.emit(d.relative)
	elif e is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		var m := e as InputEventMouseMotion
		if m.button_mask & MOUSE_BUTTON_MASK_LEFT or m.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			dragged.emit(m.relative)
	elif e is InputEventMagnifyGesture:
		zoomed.emit(1.0 / maxf((e as InputEventMagnifyGesture).factor, 0.1))
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomed.emit(0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomed.emit(1.1)
