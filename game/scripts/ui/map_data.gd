extends RefCounted
## What the map may show. Everything here reads only the public case file, the notebook (persons of interest, statements, cameras you
## know about), the town directory and the places you have stood at. It never touches the simulation's private truth.

const Interior = preload("res://scripts/world3d/interior.gd")

const STYLE_COLORS := {
	"home": Color("dba07c"), "bar": Color("a6577f"), "shop": Color("e0b04a"), "library": Color("4f9aa6"), "school": Color("e8d26a"),
	"clinic": Color("8fcfb0"), "chapel": Color("9d8bc8"), "office": Color("6f86b0"), "hall": Color("b49a7a"), "park": Color("8dbb6d")}
const STYLE_NAMES := {
	"home": "Homes", "bar": "Bars", "shop": "Shops", "library": "Library", "school": "School", "clinic": "Clinic and dentist",
	"chapel": "Chapel", "office": "Offices and law", "hall": "Halls and other", "park": "Parks"}
const WALK_M_PER_MIN := 15.0              # the same rate as every other trip: 450 m per half hour


static func style_of(l: Dictionary) -> String:
	if String(l.get("kind", "")) in ["park", "green"]:
		return "park"
	return Interior.style_for(String(l["id"]), String(l["kind"]))


static func color_of(l: Dictionary) -> Color:
	return STYLE_COLORS.get(style_of(l), STYLE_COLORS["hall"])


static func type_name(l: Dictionary) -> String:
	var st := style_of(l)
	return {"home": "Home", "bar": "Bar", "shop": "Shop", "library": "Library", "school": "School", "clinic": "Clinic", "chapel": "Chapel",
		"office": "Office", "hall": "Public hall", "park": "Park"}.get(st, "Place")


static func is_house(l: Dictionary) -> bool:
	return String(l.get("kind", "")) in ["house", "home"]


## Everyone the detective has a reason to know by name: persons of interest, the finder, newcomers, and yourself.
static func known_people(game: RefCounted) -> Dictionary:
	var out := {String(game.host): true}
	for id in game.persons_of_interest():
		out[String(id)] = true
	var fb := String(game.case.get("found_by", ""))
	if fb != "":
		out[fb] = true
	for n in game.newcomers:
		out[String(n["id"])] = true
	return out


## Residents of a lot, but only those the notebook (or the town directory for newcomers and the victim) lets you name.
static func residents_known(game: RefCounted, lot: String) -> Array:
	var known := known_people(game)
	var out: Array = []
	var victim := String(game.case.get("victim", ""))
	for id in game.sim.order:
		var p: RefCounted = game.sim.people[id]
		if String(p.home) == lot and (known.has(id) or id == victim) and game.sim.people.has(id):
			out.append(id)
	return out


static func workers_known(game: RefCounted, lot: String) -> Array:
	var known := known_people(game)
	var out: Array = []
	for id in game.sim.order:
		var p: RefCounted = game.sim.people[id]
		if String(p.work) == lot and known.has(id) and id != String(game.host):
			out.append(id)
	return out


static func visited(game: RefCounted, lot: String) -> bool:
	return bool(game.det.visited.get(lot, false)) or String(game.me().home) == lot


## Does the detective know where this building is, as a place to go (as opposed to just a house on a street)?
static func travel_known(game: RefCounted, l: Dictionary) -> bool:
	if not is_house(l):
		return true
	var lot := String(l["id"])
	if visited(game, lot) or lot == String(game.case.get("scene", "")):
		return true
	for n in game.newcomers:
		if String(n["home"]) == lot:
			return true
	return not residents_known(game, lot).is_empty()


## The markers the map draws, in the order they should be painted: [{lot, kind, label}]. Kinds: scene, objective, home, poi, camera, new.
static func markers(game: RefCounted, objective_lot: String = "") -> Array:
	var out: Array = []
	var seen := {}
	var add := func(lot: String, kind: String, label: String) -> void:
		if lot != "" and game.layout.by_id.has(lot):
			out.append({"lot": lot, "kind": kind, "label": label})
	for cam in game.cameras():
		add.call(String(cam["lot"]), "camera", String(cam["label"]))
	for n in game.newcomers:
		add.call(String(n["home"]), "new", String(n["name"]))
	for id in game.persons_of_interest():
		var p: RefCounted = game.sim.people[id]
		if not seen.has(p.home):
			seen[p.home] = true
			add.call(String(p.home), "poi", String(p.display))
	add.call(String(game.me().home), "home", "Home")
	if objective_lot != "" and objective_lot != String(game.case.get("scene", "")):
		add.call(objective_lot, "objective", "Next")
	if not game.solved():
		add.call(String(game.case.get("scene", "")), "scene", "Crime scene")
	return out


## A name for a lot on the map: landmarks and parks by name; houses only once you know whose they are.
static func label_for(game: RefCounted, l: Dictionary) -> String:
	var lot := String(l["id"])
	if not is_house(l):
		return String(l["name"])
	if lot == String(game.me().home):
		return "Home"
	if not residents_known(game, lot).is_empty() or lot == String(game.case.get("scene", "")):
		return String(game.place_name(lot))
	for n in game.newcomers:
		if String(n["home"]) == lot:
			return String(n["name"]).split(" ")[-1] + " (new)"
	return ""


static func minutes_for(meters: float) -> int:
	return 0 if meters < 12.0 else clampi(int(ceil(meters / WALK_M_PER_MIN)), 2, 240)
