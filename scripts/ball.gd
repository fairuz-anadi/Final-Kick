extends RigidBody3D

# --- Kick tuning ---
@export var min_impulse: float = 4.0
@export var max_impulse: float = 13.5
@export var max_charge_time: float = 1.2
@export var kick_height_ratio: float = 0.4

# --- Rewind/scrub tuning ---
@export var max_history_frames: int = 600  # ~10s of history at 60 physics fps
@export var scrub_speed: float = 30.0      # history frames stepped per second while scrubbing

var charging: bool = false
var charge_time: float = 0.0
var charge_ratio: float = 0.0

# Recorded (position, rotation) pairs, oldest first, capped at max_history_frames.
# This recording/scrub pattern is ball-specific for now but is written to be
# straightforward to lift into a shared component if other objects need it too.
var history: Array[Dictionary] = []

var is_scrubbing: bool = false
var scrub_index: float = 0.0  # float so scrub_speed can advance by fractional frames per tick

@onready var camera: Camera3D = get_viewport().get_camera_3d()

# Debug: confirms these key events are actually reaching Godot at all, since
# nothing in the scrub system responds if they aren't. Fires once per key-down
# (not every physics frame) so the console stays readable.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			print("DEBUG input: R pressed")
		elif event.physical_keycode == KEY_LEFT:
			print("DEBUG input: Left arrow pressed")
		elif event.physical_keycode == KEY_RIGHT:
			print("DEBUG input: Right arrow pressed")

func _physics_process(delta: float) -> void:
	# Raw keycodes instead of Input Map actions: the "rewind"/"scrub_*" actions
	# are registered in InputMap but weren't responding to key presses in-game,
	# so we read the keys directly — no Input Map entry required either way.
	if Input.is_key_pressed(KEY_R):
		_scrub(delta)
		return

	if is_scrubbing:
		_exit_scrub()

	_process_kick(delta)
	_record_frame()

# --- Recording (always running, even outside scrub mode) ---

func _record_frame() -> void:
	history.append({"position": global_position, "rotation": global_transform.basis})
	if history.size() > max_history_frames:
		history.pop_front()  # drop the oldest frame once the buffer is full

# --- Scrub mode: held R pauses kicking; Left/Right arrows move through history ---

func _scrub(delta: float) -> void:
	if history.is_empty():
		return

	if not is_scrubbing:
		_enter_scrub()

	if Input.is_key_pressed(KEY_LEFT):
		scrub_index -= scrub_speed * delta
	if Input.is_key_pressed(KEY_RIGHT):
		scrub_index += scrub_speed * delta
	scrub_index = clamp(scrub_index, 0, history.size() - 1)

	# Teleport directly to the recorded frame rather than nudging with forces,
	# so scrubbing looks like true rewind/fast-forward rather than a shove.
	var frame: Dictionary = history[int(round(scrub_index))]
	global_transform = Transform3D(frame["rotation"], frame["position"])

func _enter_scrub() -> void:
	# Freeze physics so gravity/velocity can't fight the teleported transform.
	is_scrubbing = true
	scrub_index = history.size() - 1
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func _exit_scrub() -> void:
	# Resume live simulation from wherever the scrub was left — that point
	# becomes the new "present," so any frames recorded after it are now a
	# future that never happened and get dropped.
	var index := int(round(scrub_index))
	history = history.slice(0, index + 1)
	is_scrubbing = false
	freeze = false

# --- Kick (paused entirely while scrub mode is active) ---

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
