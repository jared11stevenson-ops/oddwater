extends RefCounted
## Per-NPC suspicion. Never a hard fail: at the threshold the NPC "stages a test".

var tuning: Dictionary
var values: Dictionary = {}


func _init(t: Dictionary) -> void:
	tuning = t


func get_s(npc: String) -> int:
	return int(values.get(npc, 0))


func raise(npc: String, amount: int) -> void:
	values[npc] = clampi(get_s(npc) + amount, 0, 100)


func calm(npc: String, amount: int) -> void:
	values[npc] = clampi(get_s(npc) - amount, 0, 100)


func stages_test(npc: String) -> bool:
	return get_s(npc) >= int(tuning["suspicion_stage_test"])


## Overnight decay. Fog (low town mood) keeps people uneasy.
func decay_overnight(foggy: bool) -> void:
	var d: int = int(tuning["suspicion_decay_fog"] if foggy else tuning["suspicion_decay_clear"])
	for k in values.keys():
		values[k] = maxi(0, int(values[k]) - d)
