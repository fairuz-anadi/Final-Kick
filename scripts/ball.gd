extends RigidBody3D

@export var min_impulse: float = 4.0
@export var max_impulse: float = 13.5
@export var max_charge_time: float = 1.2
@export var kick_height_ratio: float = 0.4

@export var max_history_frames: int = 600
@export var mouse_scrub_speed: float = 0.5
@export var key_scrub_speed: float = 30.0

var charging: bool = false
var charge_time: float = 0.0
var charge_ratio: float = 0.0

var history: Array[Dictionary] = []
var is_scrubbing: bool = false
var scrub_index: float = 0.0
var _mouse_scrub_delta: float = 0.0

@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _input(event: InputEvent) -> void:
	if is_scrubbing and event is InputEventMouseMotion and Input.is_action_pressed("rewind"):
		_mouse_scrub_delta += event.relative.x

func _physics_process(delta: float) -> void:
	if is_scrubbing or _wants_to_scrub():
		_update_scrub(delta)
		return

	_process_kick(delta)
	_record_frame()

func _wants_to_scrub() -> bool:
	return not history.is_empty() and (
		Input.is_action_pressed("rewind")
		or Input.is_action_pressed("scrub_back")
		or Input.is_action_pressed("scrub_forward")
	)

func _update_scrub(delta: float) -> void:
	if not is_scrubbing:
		# Freeze the body so gravity/velocity can't fight the scrubbed transform.
		is_scrubbing = true
		scrub_index = history.size() - 1
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

	if Input.is_action_pressed("scrub_back"):
		scrub_index -= key_scrub_speed * delta
	if Input.is_action_pressed("scrub_forward"):
		scrub_index += key_scrub_speed * delta
	if Input.is_action_pressed("rewind"):
		scrub_index += _mouse_scrub_delta * mouse_scrub_speed
	_mouse_scrub_delta = 0.0

	scrub_index = clamp(scrub_index, 0, history.size() - 1)
	_apply_scrub_frame(int(round(scrub_index)))

	if not _wants_to_scrub():
		_exit_scrub()

func _apply_scrub_frame(index: int) -> void:
	var frame: Dictionary = history[index]
	global_transform = Transform3D(frame["rotation"], frame["position"])

func _exit_scrub() -> void:
	# Resume live sim from the scrubbed frame; drop recorded frames after it
	# so a later scrub can't replay a future that no longer happened.
	var index := int(round(scrub_index))
	history = history.slice(0, index + 1)
	is_scrubbing = false
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func _record_frame() -> void:
	history.append({"position": global_position, "rotation": global_transform.basis})
	if history.size() > max_history_frames:
		history.pop_front()

func _process_kick(delta: float) -> void:
	if Input.is_action_just_pressed("kick"):
		charging = true
		charge_time = 0.0
		charge_ratio = 0.0
	elif charging and Input.is_action_pressed("kick"):
		charge_time = min(charge_time + delta, max_charge_time)
		charge_ratio = charge_time / max_charge_time
	elif charging and Input.is_action_just_released("kick"):
		var impulse_strength: float = lerp(min_impulse, max_impulse, charge_ratio)
		apply_central_impulse(_get_aim_direction() * impulse_strength)
		charging = false
		charge_time = 0.0
		charge_ratio = 0.0

func _get_aim_direction() -> Vector3:
	var fallback := Vector3(0, kick_height_ratio, -1).normalized()
	if camera == null:
		return fallback

	# Aim is read from where the mouse points on the ground, not the camera's facing.
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return fallback

	var hit_point: Vector3 = hit
	var horizontal := hit_point - global_position
	horizontal.y = 0.0
	if horizontal.length() < 0.001:
		return fallback

	return (horizontal.normalized() + Vector3.UP * kick_height_ratio).normalized()
