extends RigidBody3D

const GhostMaterial := preload("res://assets/materials/ghost_material.tres")

# --- Kick tuning ---
@export var min_impulse: float = 4.0
@export var max_impulse: float = 13.5
@export var max_charge_time: float = 1.2
@export var kick_height_ratio: float = 0.15  # fixed ratio, but scales with impulse — kept low so max-charge kicks (~30 m/s) apex under ~1m, not over the 3m level walls

# --- Final Kick burst: hold past full charge to arm a one-per-level,
# much stronger kick (see _process_kick). Resets automatically per level
# since each level scene instances its own fresh Ball. ---
@export var burst_hold_window: float = 0.5  # extra hold time past max_charge_time to arm
@export var burst_impulse: float = 22.0

var burst_available: bool = true
var burst_armed: bool = false

# --- Rewind/scrub tuning ---
@export var max_history_frames: int = 600  # ~10s of history at 60 physics fps
@export var scrub_speed: float = 30.0      # history frames stepped per second while scrubbing

# --- Ghost trail (shows the abandoned "first attempt" after a rewind + new kick) ---
@export var ghost_trail_point_count: int = 10   # sampled markers spread across the abandoned path
@export var ghost_trail_marker_radius: float = 0.5  # matches the ball's default SphereMesh radius
@export var ghost_trail_fade_duration: float = 1.5

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

# CROSS-TEAM ADDITION (UI): additive only — fires once per committed kick so
# the HUD can count kicks and react to full-power ones. No behavior change.
signal kicked(power_ratio: float)

# Fires instead of (in addition to) `kicked` when a burst-armed charge is
# released, so the HUD can show a distinct "FINAL KICK!" callout.
signal burst_kicked

@export var big_impact_threshold: float = 4.0  # min contact impulse magnitude that counts as "big"
@export var big_impact_cooldown: float = 0.3   # don't re-fire faster than this even during a hard multi-frame hit

var _impact_cooldown_remaining: float = 0.0

# --- Out-of-bounds recovery ---
# Rooms are open-fronted (no wall where the ball starts) and finite-sized
# floors — a hard kick or a bad bounce can send the ball rolling off the
# edge, off a bumper, wherever, with no way back. Rather than relying on the
# player to notice and manually pause+restart, catch the fall and reset.
@export var out_of_bounds_y: float = -5.0

var _start_transform: Transform3D

func _ready() -> void:
	_start_transform = transform
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

	if global_position.y < out_of_bounds_y:
		_reset_to_start()
		return

	_process_kick(delta)
	_record_frame()

func _reset_to_start() -> void:
	transform = _start_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	charging = false
	charge_time = 0.0
	charge_ratio = 0.0
	# The old trajectory led off the edge of the world — nothing in it is
	# somewhere worth scrubbing back to, so start the timeline over too.
	history.clear()

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
	burst_armed = false

func _exit_scrub() -> void:
	# Resume live simulation from wherever the scrub was left — that point
	# becomes the new "present," so any frames recorded after it are now a
	# future that never happened and get dropped.
	var index := int(round(scrub_index))
	var abandoned: Array[Dictionary] = history.slice(index + 1)
	history = history.slice(0, index + 1)
	is_scrubbing = false
	freeze = false
	_spawn_ghost_trail(abandoned)

# --- Ghost trail: a faint marker at intervals along wherever the ball went
# during the attempt that just got overwritten by rewinding + kicking again. ---

func _spawn_ghost_trail(abandoned: Array[Dictionary]) -> void:
	if abandoned.is_empty():
		return
	var step: int = maxi(1, int(ceil(abandoned.size() / float(ghost_trail_point_count))))
	var i := 0
	while i < abandoned.size():
		_spawn_ghost_marker(abandoned[i]["position"])
		i += step

func _spawn_ghost_marker(marker_position: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = ghost_trail_marker_radius
	sphere.height = ghost_trail_marker_radius * 2.0
	marker.mesh = sphere

	# Duplicated so fading this marker's alpha doesn't fade every other
	# marker (or the scrubbing ball) sharing the same base resource.
	var mat := GhostMaterial.duplicate() as ShaderMaterial
	marker.material_override = mat

	get_tree().current_scene.add_child(marker)
	marker.global_position = marker_position

	var tween := marker.create_tween()
	tween.tween_property(mat, "shader_parameter/ghost_color:a", 0.0, ghost_trail_fade_duration)
	tween.parallel().tween_property(marker, "scale", Vector3.ZERO, ghost_trail_fade_duration)
	tween.tween_callback(marker.queue_free)

# --- Kick (paused entirely while scrub mode is active) ---

func _process_kick(delta: float) -> void:
	if Input.is_action_just_pressed("kick"):
		charging = true
		charge_time = 0.0
		charge_ratio = 0.0
		burst_armed = false
	elif charging and Input.is_action_pressed("kick"):
		# Charge keeps accumulating past max_charge_time (instead of clamping
		# there) only while a burst is still up for grabs, so holding longer
		# can arm it; charge_ratio itself stays clamped to [0,1] so the
		# existing HUD bar/colors are unaffected by the extra hold time.
		var charge_cap: float = max_charge_time + burst_hold_window if burst_available else max_charge_time
		charge_time = min(charge_time + delta, charge_cap)
		charge_ratio = clamp(charge_time / max_charge_time, 0.0, 1.0)
		burst_armed = burst_available and charge_time >= max_charge_time + burst_hold_window
	elif charging and Input.is_action_just_released("kick"):
		if burst_armed:
			apply_central_impulse(_get_aim_direction() * burst_impulse)
			burst_available = false
			burst_armed = false
			# Emitted before `kicked` so HUD listeners can flag this as a burst
			# before the generic kicked/MAX-POWER handler runs.
			burst_kicked.emit()
			kicked.emit(1.0)
		else:
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
