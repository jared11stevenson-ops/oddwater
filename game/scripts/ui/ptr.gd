extends RefCounted
## One pointer for mouse and touch. With "emulate mouse from touch" on (the project default) a finger arrives as mouse events, so only those
## are read; if it is turned off, the raw touch events are read instead. Never both, so a tap is never counted twice.
## Returns {p, down, up, move} or {} for anything else.

static func read(e: InputEvent) -> Dictionary:
	var emu: bool = bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	if emu:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			return {"p": e.position, "down": e.pressed, "up": not e.pressed, "move": false}
		if e is InputEventMouseMotion:
			return {"p": e.position, "down": false, "up": false, "move": true}
	else:
		if e is InputEventScreenTouch:
			return {"p": e.position, "down": e.pressed, "up": not e.pressed, "move": false}
		if e is InputEventScreenDrag:
			return {"p": e.position, "down": false, "up": false, "move": true}
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			return {"p": e.position, "down": e.pressed, "up": not e.pressed, "move": false}
		if e is InputEventMouseMotion:
			return {"p": e.position, "down": false, "up": false, "move": true}
	return {}
