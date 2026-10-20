extends Node3D
## Gives the sim's people bodies. Every resident has a logical position all the time; only the ones near the camera get a 3D body
## (a pool of Humans), so 200+ people cost the price of the few you can actually see. After each sim tick each resident is sent where
## the sim says they are: they walk the streets to get there, then either stand around outdoors (chatting, relaxing, at the market)
## or go in through the door and disappear (working, sleeping, eating at home).

const Human = preload("res://scripts/world3d/human.gd")
const PathGrid = preload("res://scripts/world3d/path_grid.gd")

const SHOW_RADIUS := 150.0
const HIDE_RADIUS := 185.0
const MAX_VISIBLE := 70
const OUTDOOR_ACTS := ["socialize", "relax", "worship", "errand"]

var sim: RefCounted
var builder: Node3D            # for door positions
var grid: RefCounted
var agents: Dictionary = {}    # person id -> Agent dict
var focus := Vector3.ZERO      # where the player is
var tick_seconds := 20.0
var skip_id := ""              # the host: the player's own body is not an NPC
var _rng := RandomNumberGenerator.new()


func setup(world: RefCounted, town_builder: Node3D, layout_spec: Dictionary) -> void:
	sim = world
	builder = town_builder
	grid = PathGrid.new(layout_spec)
	_rng.seed = 4242
	for id in sim.order:
		var p: RefCounted = sim.people[id]
		agents[id] = {"id": id, "pos": _spot(p.home, id, true), "path": [], "speed": 1.4, "state": "inside", "lot": p.home, "human": null,
			"inside_after": false, "idle": 0.0}
		agents[id]["pos"] = _door_of(p.home)


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
func resync(snap: bool = false) -> void:
	for id in sim.order:
		if id == skip_id:
			continue
		var p: RefCounted = sim.people[id]
		var a: Dictionary = agents[id]
		if not sim.alive(p) or p.location == "":
			a["state"] = "inside"
			a["path"] = []
			_release(a)
			continue
		var want_out := _visible_activity(p)
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


func _release(a: Dictionary) -> void:
	if a["human"] != null:
		(a["human"] as Node).queue_free()
		a["human"] = null


func _process(delta: float) -> void:
	var visible_count := 0
	for id in agents:
		var a: Dictionary = agents[id]
		if id == skip_id:
			continue
		# move along the route
		if a["state"] == "walking":
			var path: Array = a["path"]
			if path.is_empty():
				a["state"] = "inside" if a["inside_after"] else "outside"
			else:
				var tgt: Vector3 = path[0]
				var to := tgt - (a["pos"] as Vector3)
				to.y = 0.0
				var step: float = float(a["speed"]) * delta
				if to.length() <= step:
					a["pos"] = tgt
					path.remove_at(0)
				else:
					a["pos"] = (a["pos"] as Vector3) + to.normalized() * step
				a["dir"] = to
		# only the people near the player get bodies
		var d: float = (a["pos"] as Vector3).distance_to(focus)
		var show_me: bool = a["state"] != "inside" and d < (HIDE_RADIUS if a["human"] != null else SHOW_RADIUS)
		if show_me and a["human"] == null and visible_count < MAX_VISIBLE:
			_spawn(a)
		elif (not show_me) and a["human"] != null:
			_release(a)
		if a["human"] != null:
			visible_count += 1
			var h: Node3D = a["human"]
			h.position = a["pos"]
			var moving: bool = a["state"] == "walking"
			(h as Object).call("set_speed", float(a["speed"]) if moving else 0.0)
			if moving and a.has("dir"):
				(h as Object).call("face_dir", a["dir"], delta)
			elif a["state"] == "outside":
				# turn toward whoever is nearest, so groups seem to talk
				pass


func _spawn(a: Dictionary) -> void:
	var h := Human.new()
	add_child(h)
	h.setup(sim.people[a["id"]])
	h.position = a["pos"]
	a["human"] = h


func human_of(id: String) -> Node3D:
	var a: Dictionary = agents.get(id, {})
	return a.get("human") if not a.is_empty() else null


## People you could talk to right now: [{id, dist}] within `radius` of `p`, nearest first.
func nearby(p: Vector3, radius: float = 3.2) -> Array:
	var out: Array = []
	for id in agents:
		var a: Dictionary = agents[id]
		if id == skip_id or a["human"] == null:
			continue
		var d: float = (a["pos"] as Vector3).distance_to(p)
		if d <= radius:
			out.append({"id": id, "dist": d})
	out.sort_custom(func(x, y): return x["dist"] < y["dist"])
	return out


func visible_count() -> int:
	var n := 0
	for id in agents:
		if agents[id]["human"] != null:
			n += 1
	return n
