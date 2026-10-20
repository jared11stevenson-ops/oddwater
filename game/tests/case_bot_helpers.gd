extends RefCounted
const Cctv = preload("res://scripts/detective/cctv.gd")

static func call_calibrate(sim: RefCounted, c: Dictionary, det: RefCounted, cam_id: String) -> void:
	Cctv.calibrate(sim, c, det, cam_id)
