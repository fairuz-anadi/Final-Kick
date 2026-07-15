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

# --- Hard-impact reporting (screen shake / slow-mo hook, and CCD tunneling fix) ---
signal big_impact(strength: float, impact_position: Vector3)

# ANADI REVIEW (Samprity/UI): additive only — fires once per committed kick so
# the HUD can count kicks and react to full-power ones. No behavior change.
signal kicked(power_ratio: float)

@export var big_impact_threshold: float = 4.0  # min contact impulse magnitude that counts as "big"
@export var big_impact_cooldown: float = 0.3   # don't re-fire faster than this even during a hard multi-frame hit

var _impact_cooldown_remaining: float = 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	# High kick speeds (up to ~30 m/s) can tunnel a small fast body through thin
	# colliders (e.g. the 0.05m-thick wire-node panels) within one physics step.
	continuous_cd = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _impact_cooldown_remaining > 0.0:
		return
	for i in state.get_contact_count():
		var impulse: Vector3 = state.get_contact_impulse(i)
		var strength: float = impulse.length()
		if strength >= big_impact_threshold:
			_impact_cooldown_remaining = big_impact_cooldown
			big_impact.emit(strength, state.get_contact_local_position(i))
			break

func _physics_process(delta: float) -> void:
	if _impact_cooldown_remaining > 0.0:
		_impact_cooldown_remaining -= delta

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
	# Edge case: kick charging isn't paused via any input action, it's paused
	# by _process_kick never running while scrubbing — so a release event
	# that happens while R is held would never be seen, softlocking the charge
	# forever. Cancel any in-progress charge outright instead; committing to
	# rewind means abandoning the current charge, not banking it.
	charging = false
	charge_time = 0.0
	charge_ratio = 0.0

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
		kicked.emit(charge_ratio)
		PlaceholderSFX.play_thud(self)  # PLACEHOLDER SFX — see placeholder_sfx.gd
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
