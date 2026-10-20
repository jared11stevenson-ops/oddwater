extends RefCounted
## The Little Mercy Courier, the radio, and the letters page. Once a killer has taken three, the town stops whispering and starts printing.
## Everything is a pure function of the serial state, so a saved game reads the same paper.

const STAGES := ["quiet", "uneasy", "alarmed", "panic", "siege"]


static func stage(pressure: float) -> String:
	if pressure >= 90.0:
		return "siege"
	if pressure >= 70.0:
		return "panic"
	if pressure >= 40.0:
		return "alarmed"
	if pressure > 0.0:
		return "uneasy"
	return "quiet"


static func _nick(s: Dictionary) -> String:
	return String(s.get("nick", "")) if String(s.get("nick", "")) != "" else "the killer"


## One front page for a morning. `kind`: murder (a new victim), day (a quiet day with the killer at large), caught, failed.
static func front_page(s: Dictionary, day: int, kind: String, victim_name: String = "", place: String = "") -> Dictionary:
	var kills: int = (s.get("kills", []) as Array).size()
	var nick := _nick(s)
	var left := maxi(int(s.get("deadline", day)) - day, 0)
	var head := ""
	var body := ""
	match kind:
		"murder":
			if kills == 3:
				head = "THIRD DEATH IN LITTLE MERCY. POLICE REFUSE TO SAY 'SERIAL'"
				body = "%s was found dead at %s this morning, the third resident to die in as many weeks. Each scene, our sources say, bore the same unsettling mark: %s. Sheriff's office would say only that the detective is 'following every lead'. A local shopkeeper, asked if the doors of Little Mercy would be locked tonight, laughed. 'We never had keys,' she said. 'We are looking for them.'" % [victim_name, place, String(s["signature"]).to_lower()]
			elif kills == 4:
				head = "%s STRIKES AGAIN: FOURTH VICTIM" % nick.to_upper()
				body = "The name the town has given the killer is now on every lip. %s was found at %s. The Courier has learned that the detective was seen at the scene before dawn and left without comment. The town council has called an emergency meeting. The deadline set by the state police, we are told, is %d days away." % [victim_name, place, left]
			else:
				head = "%d DEAD. TOWN ASKS: WHERE IS THE DETECTIVE?" % kills
				body = "%s is dead at %s, and this paper has stopped counting the nights since anyone slept. A petition at the post office has gathered four hundred names. It asks for one thing: an arrest. %d days remain before the state takes over." % [victim_name, place, left]
		"day":
			match stage(float(s.get("pressure", 0.0))):
				"alarmed":
					head = "%s STILL AT LARGE" % nick.to_upper()
					body = "No arrest, no suspect named, and the town grows restless. Shops closed early on Main Street; the chapel held an extra vigil. %d days remain." % left
				"panic":
					head = "TOWN IN PANIC AS DEADLINE NEARS"
					body = "Neighbours are patrolling in pairs. Three households have left for the coast. At the Pink Heron, talk is of the detective, and none of it is kind. State police have been seen at the edge of town. %d days remain." % left
				"siege":
					head = "STATE POLICE ARRIVE; DETECTIVE'S POSITION 'UNTENABLE'"
					body = "Sources close to the Sheriff say that unless %s is in custody within %d days, the detective's office will be taken from them. Nobody in Little Mercy sleeps with the lamp off." % [nick, left]
				_:
					head = "LITTLE MERCY WAITS"
					body = "The detective's office would not comment. The lake, as ever, was calm."
		"caught":
			head = "%s CAUGHT. THE DETECTIVE DID IT" % nick.to_upper()
			body = "After %d deaths, the killer who held Little Mercy by the throat is behind bars. The Sheriff called it 'the quietest day of my career, and the best'. The chapel bell, silent since the first death, rang at noon." % kills
		"failed":
			head = "STATE POLICE TAKE OVER KILLER CASE"
			body = "The deadline has passed. The detective has been relieved of the %s investigation and the Sheriff has been called to the capital. %d dead. The killer, as far as anyone knows, is still among us." % [nick, kills]
	return {"day": day, "kind": kind, "head": head, "body": body}


## A line of radio for the HUD ticker.
static func radio(s: Dictionary) -> String:
	match stage(float(s.get("pressure", 0.0))):
		"siege": return "WLMC: ...locked doors, please. The Sheriff asks everyone indoors by dusk."
		"panic": return "WLMC: ...the state police have set a deadline, folks. Eight days, they said, and the clock is running."
		"alarmed": return "WLMC: ...and in local news, still no arrest. The caller line is open."
		"uneasy": return "WLMC: ...a reminder to neighbours: lock up, and check on each other."
	return ""


## A letter to the editor, rotating by day.
static func letter(s: Dictionary, day: int) -> String:
	var l := [
		"Sir, my mother has slept in her coat for a week. Is this the detective's idea of safety? Yours, A Resident of Larch Row.",
		"Sir, I have lived in Little Mercy for seventy years and never once locked my door. I have now bought three locks. I would like my seventy years back. Yours, Name Withheld.",
		"Sir, why are the same strange objects left at every scene? It is plain to me that somebody wishes to be understood. Yours, A Reader.",
		"Sir, in the matter of the old jury. Some of us remember. Some of us would rather not. Yours, Anonymous.",
	]
	return l[(day + int(s.get("pressure", 0.0))) % l.size()] if stage(float(s.get("pressure", 0.0))) != "quiet" else ""
