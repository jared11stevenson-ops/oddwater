extends Node3D
## Gives the sim's people bodies. Every resident has a logical position all the time; only the ones near the camera get a 3D body
## (a pool of Humans), so 200+ people cost the price of the few you can actually see. After each sim tick each resident is sent where
## the sim says they are: they walk the streets to get there, then either stand around outdoors (chatting, relaxing, at the market)
## or go in through the door and disappear (working, sleeping, eating at home).
## One loop drives everybody: people with bodies are updated every frame, everyone else in round-robin slices, and the Humans do not
## run their own _process. People standing near each other turn to face one another and take turns to talk.

const Human = preload("res://scripts/world3d/human.gd")
const PathGrid = preload("res://scripts/world3d/path_grid.gd")

const SHOW_RADIUS := 110.0
const HIDE_RADIUS := 135.0
const MAX_VISIBLE := 40
const FAR_ANIM := 32.0            # beyond this many metres a body animates at a third of the rate
const SLICES := 8                 # everyone who has no body is looked at once per this many frames
const OUTDOOR_ACTS := ["socialize", "relax", "worship", "errand"]

var sim: RefCounted
var builder: Node3D            # for door positions
var grid: RefCounted
var agents: Dictionary = {}    # person id -> Agent dict
var focus := Vector3.ZERO      # where the player is
var tick_seconds := 20.0
var skip_id := ""              # the host: the player's own body is not an NPC
var _rng := RandomNumberGenerator.new()
var _roster: Array = []        # ids in a stable order, for the slices
var _bodies: Array = []        # ids of agents that currently have a Human
var _clock := 0.0
var _frame := 0
var _partner_timer := 0.0


func setup(world: RefCounted, town_builder: Node3D, layout_spec: Dictionary) -> void:
	sim = world
	builder = town_builder
	grid = PathGrid.new(layout_spec)
	_rng.seed = 4242
	_ensure_agents()


## Residents can move in while the game runs; give each one a body slot.
func _ensure_agents() -> void:
	for id in sim.order:
		if agents.has(id):
			continue
		var p: RefCounted = sim.people[id]
		agents[id] = {"id": id, "pos": _spot(p.home, id, true), "path": [], "speed": 1.4, "state": "inside", "lot": p.home, "human": null,
			"inside_after": false, "idle": 0.0, "key": "", "last": _clock, "h": absi(hash(id)), "partner": "", "yaw0": float(absi(hash(id + "y")) % 628) / 100.0}
		agents[id]["pos"] = _door_of(p.home)
		_roster.append(id)


func _door_of(lot: String) -> Vector3:
	var d: Dictionary = builder.doors.get(lot, {})
	return d["door"] if not d.is_empty() else Vector3(0, 0, 60)


## A believable place to stand outdoors for a given lot.
func _spot(lot: String, id: String, inside: bool) -> Vector3:
	var d: Dictionary = builder.doors.get(lot, {})
	if d.is_empty():
		return Vector3(0, 0, 60)
	var h := absi(hash(id + lot + str(sim.day)))
	var l: Dictionary = builder.layout.by_id.get(lot, {})
	if not l.is_empty() and (l["kind"] == "park" or lot == "pageant_green"):
		return Vector3(float(l["x"]) + float(h % 29) - 14.0, 0.0, float(l["y"]) + float((h >> 5) % 21) - 10.0)
	if lot in ["marina", "launch_quay"]:
		var door: Vector3 = d["door"]
		return Vector3(door.x + float(h % 9) - 4.0, 0.0, builder.SHORE_Z - 2.0 - float((h >> 4) % 18)) if lot == "launch_quay" else Vector3(door.x + float(h % 25) - 12.0, 0.0, door.z + float((h >> 3) % 4) * (-1.0))
	var f: Vector3 = d["front"]
	var door2: Vector3 = d["door"]
	return Vector3(f.x + float(h % 11) - 5.0, 0.0, lerpf(f.z, door2.z, 0.4 + float((h >> 4) % 4) * 0.12))


func _visible_activity(p: RefCounted) -> bool:
	if p.location == "":
		return false
	if p.activity in OUTDOOR_ACTS and p.location != p.home:
		return true
	return p.location in ["pageant_green", "marina", "launch_quay"]


## The sim has just moved everyone: send each resident to where they now are. `snap` skips the walking (after a time skip).
## People whose place has not changed since the last tick are left alone.
func resync(snap: bool = false) -> void:
	_ensure_agents()
	for id in sim.order:
		if id == skip_id:
			continue
		var p: RefCounted = sim.people[id]
		var a: Dictionary = agents[id]
		if not sim.alive(p) or p.location == "":
			a["state"] = "inside"
			a["path"] = []
			a["key"] = ""
			_release(a)
			continue
		var want_out := _visible_activity(p)
		var key := "%s|%s|%d" % [p.location, "o" if want_out else "i", sim.day]
		if not snap and a["key"] == key:
			continue
		a["key"] = key
		var target: Vector3 = _spot(p.location, id, false) if want_out else _door_of(p.location)
		a["lot"] = p.location
		a["inside_after"] = not want_out
		if a["state"] == "inside":
			a["pos"] = _door_of(a.get("last_lot", p.home))
		if snap or ((a["pos"] as Vector3).distance_to(focus) > HIDE_RADIUS and target.distance_to(focus) > HIDE_RADIUS):
			a["pos"] = target if want_out else _door_of(p.location)
			a["path"] = []
			a["state"] = "outside" if want_out else "inside"
			a["last_lot"] = p.location
			if a["state"] == "inside":
				_release(a)
			continue
		var path: Array = grid.route(a["pos"], target)
		a["path"] = path.slice(1)
		var dist := PathGrid.length(path)
		a["speed"] = clampf(dist / (tick_seconds * 0.7), 1.3, 7.0)
		a["state"] = "walking"
		a["last_lot"] = p.location
		a["last"] = _clock
	if snap:
		_spawn_near()


## Give bodies to everybody who is outdoors within sight (used after a snap, so the street is populated at once).
func _spawn_near() -> void:
	var r2 := SHOW_RADIUS * SHOW_RADIUS
	for id in _roster:
		if _bodies.size() >= MAX_VISIBLE:
			break
		var a: Dictionary = agents[id]
		if id == skip_id or a["human"] != null or a["state"] == "inside":
			continue
		if (a["pos"] as Vector3).distance_squared_to(focus) < r2:
			_spawn(a)


func _release(a: Dictionary) -> void:
	if a["human"] != null:
		(a["human"] as Node).queue_free()
		a["human"] = null
		_bodies.erase(a["id"])


## Walk an agent along its route for `dt` seconds.
func _advance(a: Dictionary, dt: float) -> void:
	if a["state"] != "walking":
		return
	var path: Array = a["path"]
	if path.is_empty():
		a["state"] = "inside" if a["inside_after"] else "outside"
		return
	var pos: Vector3 = a["pos"]
	var left: float = float(a["speed"]) * dt
	var guard := 0
	while left > 0.0 and not path.is_empty() and guard < 6:
		guard += 1
		var tgt: Vector3 = path[0]
		var to := tgt - pos
		to.y = 0.0
		var l := to.length()
		a["dir"] = to
		if l <= left:
			pos = tgt
			path.remove_at(0)
			left -= l
		else:
			pos += to / l * left
			left = 0.0
	a["pos"] = pos
	if path.is_empty():
		a["state"] = "inside" if a["inside_after"] else "outside"


func _process(delta: float) -> void:
	_clock += delta
	_frame += 1
	# 1) everybody with a body, every frame
	var i := _bodies.size() - 1
	while i >= 0:
		var a: Dictionary = agents[_bodies[i]]
		i -= 1
		_advance(a, delta)
		var d2 := (a["pos"] as Vector3).distance_squared_to(focus)
		if a["state"] == "inside" or d2 > HIDE_RADIUS * HIDE_RADIUS:
			_release(a)
			continue
		var h = a["human"]
		h.position = a["pos"]
		var moving: bool = a["state"] == "walking"
		var far := d2 > FAR_ANIM * FAR_ANIM
		var step := delta
		if far:
			a["acc"] = float(a.get("acc", 0.0)) + delta
			if (_frame + int(a["h"])) % 3 != 0:
				if moving and a.has("dir"):
					h.face_dir(a["dir"], delta)
				continue
			step = float(a["acc"])
			a["acc"] = 0.0
		h.set_speed(float(a["speed"]) if moving else 0.0)
		if moving:
			if a.has("dir"):
				h.face_dir(a["dir"], step)
			h.talking = false
		else:
			var pid: String = a["partner"]
			if pid != "" and agents.has(pid):
				h.face_point(agents[pid]["pos"], step)
		h.animate(step)
	# 2) everyone else, in slices: they walk with the time since they were last seen, and may get a body
	var n := _roster.size()
	if n == 0:
		return
	var per := ceili(float(n) / float(SLICES))
	var start := (_frame % SLICES) * per
	for k in per:
		var idx := start + k
		if idx >= n:
			break
		var id: String = _roster[idx]
		if id == skip_id:
			continue
		var a2: Dictionary = agents[id]
		if a2["human"] != null:
			continue
		var dt: float = _clock - float(a2["last"])
		a2["last"] = _clock
		_advance(a2, dt)
		if a2["state"] == "inside":
			continue
		var d3 := (a2["pos"] as Vector3).distance_squared_to(focus)
		if d3 < SHOW_RADIUS * SHOW_RADIUS and _bodies.size() < MAX_VISIBLE:
			_spawn(a2)
	_partner_timer -= delta
	if _partner_timer <= 0.0:
		_partner_timer = 1.1
		_update_partners()


func _spawn(a: Dictionary) -> void:
	var h := Human.new()
	h.managed = true
	add_child(h)
	h.setup(sim.people[a["id"]])
	h.position = a["pos"]
	h.rotation.y = float(a["yaw0"])
	a["human"] = h
	_bodies.append(a["id"])
	_partner_timer = 0.0


## People standing still near each other face their nearest neighbour and take turns to talk.
func _update_partners() -> void:
	var idle: Array = []
	for id in _bodies:
		var a: Dictionary = agents[id]
		if a["state"] == "outside":
			idle.append(a)
		else:
			a["partner"] = ""
			a["human"].talking = false
	for a in idle:
		var best := ""
		var best_d := 20.25          # 4.5 m
		var pa: Vector3 = a["pos"]
		for b in idle:
			if b == a:
				continue
			var d := pa.distance_squared_to(b["pos"])
			if d < best_d:
				best_d = d
				best = b["id"]
		a["partner"] = best
		var h = a["human"]
		if best == "":
			h.talking = false
		else:
			var turn := int(_clock * 0.28) % 2 == 0
			h.talking = turn == (String(a["id"]) < best)


func human_of(id: String) -> Node3D:
	var a: Dictionary = agents.get(id, {})
	return a.get("human") if not a.is_empty() else null


## People you could talk to right now: [{id, dist}] within `radius` of `p`, nearest first.
func nearby(p: Vector3, radius: float = 3.2) -> Array:
	var out: Array = []
	var r2 := radius * radius
	for id in _bodies:
		var a: Dictionary = agents[id]
		if id == skip_id:
			continue
		var d2 := (a["pos"] as Vector3).distance_squared_to(p)
		if d2 <= r2:
			out.append({"id": a["id"], "dist": sqrt(d2)})
	if out.size() > 1:
		out.sort_custom(func(x, y): return x["dist"] < y["dist"])
	return out


func visible_count() -> int:
	return _bodies.size()
