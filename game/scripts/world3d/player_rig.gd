extends CharacterBody3D
## You, in the host's body. Left thumb moves (virtual stick, or WASD), right thumb orbits the camera (drag, or right mouse button).
## The camera sits behind and above, pulls in when a wall is in the way, and the body turns to face where you're going.

const Human = preload("res://scripts/world3d/human.gd")

const WALK := 3.4
const RUN := 6.6

var human: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.3
var dist := 7.4
var move_input := Vector2.ZERO          # from the on-screen stick: x = right, y = forward (up is positive)
var look_delta := Vector2.ZERO
var frozen := false
var running := false
var moved_recently := 0.0
var _cam_dist := 7.4
var shoulder := 0.55                   # the camera sits a little over your right shoulder so the street ahead is clear


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 66.0
	cam.near = 0.15
	cam.far = 4800.0
	add_child(cam)
	cam.current = true


func set_person(p: RefCounted) -> void:
	if human != null:
		human.queue_free()
	human = Human.new()
	add_child(human)
	human.setup(p)


func teleport(pos: Vector3, face_yaw: float = 0.0) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	velocity = Vector3.ZERO
	yaw = face_yaw
	_update_camera(0.0, true)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not frozen:
		dir = move_input
		if dir == Vector2.ZERO:
			dir.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
			dir.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
		running = Input.is_key_pressed(KEY_SHIFT) or dir.length() > 0.92 and move_input != Vector2.ZERO
	if dir.length() > 1.0:
		dir = dir.normalized()
	var basis_yaw := Basis(Vector3.UP, yaw)
	var wish := basis_yaw * Vector3(dir.x, 0.0, -dir.y)
	var speed := (RUN if running else WALK) * clampf(dir.length() * 1.15, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, wish.x * speed, clampf(delta * 12.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, wish.z * speed, clampf(delta * 12.0, 0.0, 1.0))
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if human != null:
		human.set_speed(hv.length())
		if hv.length() > 0.3:
			human.face_dir(hv, delta, 9.0)
	moved_recently = 2.0 if hv.length() > 0.3 else maxf(moved_recently - delta, 0.0)


func _process(delta: float) -> void:
	yaw -= look_delta.x * 0.006
	pitch = clampf(pitch - look_delta.y * 0.005, -1.05, 0.25)
	look_delta = Vector2.ZERO
	_update_camera(delta)


func _update_camera(delta: float, snap: bool = false) -> void:
	if cam == null:
		return
	var pivot := global_position + Vector3(0, 1.75, 0)
	var basis_y := Basis(Vector3.UP, yaw)
	var right := basis_y * Vector3(1, 0, 0)
	var back := basis_y * Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, 1)
	var want := dist
	# pull the camera in if geometry is in the way
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pivot, pivot + back * dist + right * shoulder, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = maxf(1.2, (hit["position"] as Vector3).distance_to(pivot) - 0.4)
	_cam_dist = want if snap else lerpf(_cam_dist, want, clampf(delta * 10.0, 0.0, 1.0))
	var k := _cam_dist / maxf(dist, 0.01)
	cam.global_position = pivot + back * _cam_dist + right * shoulder * k
	cam.look_at(pivot + right * shoulder * 0.6 * k + Vector3(0, 0.15, 0), Vector3.UP)


func apply_zoom(factor: float) -> void:
	dist = clampf(dist * factor, 2.6, 16.0)
