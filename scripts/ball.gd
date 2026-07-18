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

# --- Overcharge: unlike the one-shot burst above, this is a repeatable
# risk/reward every regular kick gets access to. Holding past max_charge_time
# (the same extra window the burst uses to arm) scales impulse up further and
# wobbles the aim direction proportionally, so more range/power costs
# precision instead of being free. Introduced for Level 6. ---
@export var overcharge_impulse_multiplier: float = 1.6  # extra impulse multiplier at full overcharge, on top of max_impulse
@export var overcharge_wobble_degrees: float = 14.0      # max random aim deviation at full overcharge

var overcharge_ratio: float = 0.0  # 0 = normal charge, 1 = fully overcharged (about to arm burst if available)

# --- Rewind/scrub tuning ---
@export var max_history_frames: int = 600  # ~10s of history at 60 physics fps
@export var scrub_speed: float = 30.0      # history frames stepped per second while scrubbing

# --- Ghost trail (shows the abandoned "first attempt" after a rewind + new kick) ---
@export var ghost_trail_point_count: int = 10   # sampled markers spread across the abandoned path
@export var ghost_trail_marker_radius: float = 0.5  # matches the ball's default SphereMesh radius
@export var ghost_trail_fade_duration: float = 1.5

## Set by the HUD the moment the level completes: the ball keeps simulating
## (the win moment shouldn't freeze it mid-air) but accepts no more kicks or
## rewinds, and a post-win roll off the edge just quietly respawns it.
var input_locked: bool = false

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

# --- Impact audio: every meaningful hit makes a sound (not just "big" ones),
# volume-scaled by contact strength. Much lower threshold + shorter cooldown
# than big_impact, so bounces feel physical without machine-gunning while
# the ball rolls. ---
@export var impact_sound_threshold: float = 0.8
@export var impact_sound_cooldown: float = 0.12

var _impact_cooldown_remaining: float = 0.0
var _impact_sound_cooldown_remaining: float = 0.0
var _pending_impact_sound: float = 0.0  # set in _integrate_forces (physics callback), played in _physics_process

# --- Out-of-bounds recovery ---
# Rooms are open-fronted (no wall where the ball starts) and finite-sized
# floors — a hard kick or a bad bounce can send the ball rolling off the
# edge, off a bumper, wherever, with no way back. Rather than relying on the
# player to notice and manually pause+restart, catch the fall and reset.
@export var out_of_bounds_y: float = -5.0

var _start_transform: Transform3D

# --- Personality (visual only, physics untouched): the mesh squashes on
# impacts, stretches along fast flight, coils down while charging, and a
# glow core brightens with the charge. ---
var _visual_mesh: MeshInstance3D
var _glow_light: OmniLight3D
var _squash: float = 0.0  # 1 = fully squashed, decays each frame

func _ready() -> void:
	_start_transform = transform
	# Difficulty scales the rewind window (Easy: longer, Hard: shorter);
	# overrides the exported default rather than replacing it, so the
	# inspector value still applies as the Medium/fallback baseline.
	max_history_frames = Difficulty.rewind_frames()
	contact_monitor = true
	max_contacts_reported = 4
	# High kick speeds (up to ~30 m/s) can tunnel a small fast body through thin
	# colliders (e.g. the 0.05m-thick wire-node panels) within one physics step.
	continuous_cd = true

	for child in get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh:
			_visual_mesh = child
			break
	_glow_light = OmniLight3D.new()
	_glow_light.omni_range = 3.0
	_glow_light.light_energy = 0.0
	add_child(_glow_light)

func _process(delta: float) -> void:
	_update_personality(delta)

## Squash & stretch + charge glow. Scales/orients only the child mesh, so
## the collision sphere and all physics are untouched.
func _update_personality(delta: float) -> void:
	if _glow_light:
		if charging:
			# Cyan while safe, hot pink approaching max — same language as
			# the HUD charge bar.
			_glow_light.light_color = Color(0.0, 0.898, 1.0).lerp(
				Color(1.0, 0.24, 0.51), clampf((charge_ratio - 0.4) / 0.6, 0.0, 1.0))
			_glow_light.light_energy = move_toward(
				_glow_light.light_energy, 0.3 + charge_ratio * 1.4, delta * 6.0)
		else:
			_glow_light.light_energy = move_toward(_glow_light.light_energy, 0.0, delta * 5.0)

	if _visual_mesh == null:
		return
	if is_scrubbing:
		_visual_mesh.basis = Basis.IDENTITY
		return
	_squash = move_toward(_squash, 0.0, delta * 4.0)
	var speed := linear_velocity.length()
	var stretch := clampf(speed / 28.0, 0.0, 1.0) * 0.22
	# Anticipation: the ball coils down while a kick charges, like it's
	# crouching before a jump.
	var coil := 0.10 * charge_ratio if charging else 0.0
	var net := stretch - _squash * 0.6 - coil
	if speed > 1.5:
		# Align the mesh's Y axis with the velocity so stretch happens along
		# the direction of motion (and squash flattens against it).
		var dir := linear_velocity / speed
		var x_axis := dir.cross(Vector3.UP)
		if x_axis.length() < 0.01:
			x_axis = Vector3.RIGHT
		x_axis = x_axis.normalized()
		_visual_mesh.global_transform.basis = Basis(x_axis, dir, x_axis.cross(dir))
	else:
		_visual_mesh.basis = Basis.IDENTITY
	_visual_mesh.scale = Vector3(1.0 - net * 0.45, 1.0 + net, 1.0 - net * 0.45)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var max_strength := 0.0
	for i in state.get_contact_count():
		var impulse: Vector3 = state.get_contact_impulse(i)
		var strength: float = impulse.length()
		max_strength = maxf(max_strength, strength)
		if strength >= big_impact_threshold and _impact_cooldown_remaining <= 0.0:
			_impact_cooldown_remaining = big_impact_cooldown
			big_impact.emit(strength, state.get_contact_local_position(i))
	# Don't spawn audio nodes from inside the physics callback — just flag
	# the hit; _physics_process plays it on the next safe tick.
	if max_strength >= impact_sound_threshold and _impact_sound_cooldown_remaining <= 0.0:
		_impact_sound_cooldown_remaining = impact_sound_cooldown
		_pending_impact_sound = max_strength

func _physics_process(delta: float) -> void:
	if _impact_cooldown_remaining > 0.0:
		_impact_cooldown_remaining -= delta
	if _impact_sound_cooldown_remaining > 0.0:
		_impact_sound_cooldown_remaining -= delta
	if _pending_impact_sound > 0.0:
		PlaceholderSFX.play_impact(self, _pending_impact_sound)
		_squash = maxf(_squash, clampf(_pending_impact_sound / 8.0, 0.35, 1.0))
		_pending_impact_sound = 0.0

	if input_locked:
		if is_scrubbing:
			_exit_scrub()
		if global_position.y < out_of_bounds_y:
			_reset_to_start()  # silent — the round is over, no drain/popup
		return

	if Input.is_key_pressed(KEY_R):
		_scrub(delta)
		return

	if is_scrubbing:
		_exit_scrub()

	if global_position.y < out_of_bounds_y:
		lose_ball()
		return

	_process_kick(delta)
	_record_frame()

## Ball is lost (fell out of bounds, touched a kill zone): drains Factory
## Energy via LifeManager, then respawns at the start with level progress intact.
## Public so KillZone areas can trigger the same flow as a fall.
func lose_ball() -> void:
	LifeManager.on_ball_lost(self)
	_reset_to_start()

func _reset_to_start() -> void:
	transform = _start_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	charging = false
	charge_time = 0.0
	charge_ratio = 0.0
	overcharge_ratio = 0.0
	_squash = 0.0
	if _visual_mesh:
		_visual_mesh.basis = Basis.IDENTITY
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
	overcharge_ratio = 0.0

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
		overcharge_ratio = 0.0
	elif charging and Input.is_action_pressed("kick"):
		# Charge keeps accumulating past max_charge_time (instead of clamping
		# there) only while a burst is still up for grabs, so holding longer
		# can arm it; charge_ratio itself stays clamped to [0,1] so the
		# existing HUD bar/colors are unaffected by the extra hold time.
		var charge_cap: float = max_charge_time + burst_hold_window if burst_available else max_charge_time
		charge_time = min(charge_time + delta, charge_cap)
		charge_ratio = clamp(charge_time / max_charge_time, 0.0, 1.0)
		burst_armed = burst_available and charge_time >= max_charge_time + burst_hold_window
		# Same extra hold window doubles as the overcharge ramp, whether or
		# not a burst is available this level — this way Overcharge still
		# works after the one-per-level burst has been spent.
		overcharge_ratio = clamp((charge_time - max_charge_time) / burst_hold_window, 0.0, 1.0)
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
			if overcharge_ratio > 0.0:
				impulse_strength = lerp(impulse_strength, max_impulse * overcharge_impulse_multiplier, overcharge_ratio)
			apply_central_impulse(_get_aim_direction(overcharge_ratio) * impulse_strength)
			kicked.emit(charge_ratio)
		# Kick audio scales with how hard the kick actually was (a burst
		# release always has charge_ratio at 1.0).
		PlaceholderSFX.play_kick(self, charge_ratio)
		# Release flash + recoil squash — the coiled-up charge visibly fires.
		if _glow_light:
			_glow_light.light_energy = 2.2
		_squash = 0.5
		charging = false
		charge_time = 0.0
		charge_ratio = 0.0
		overcharge_ratio = 0.0

## `wobble_ratio` (0-1) rotates the horizontal aim by a random angle up to
## overcharge_wobble_degrees — 0 (the default) is a plain, precise aim.
func _get_aim_direction(wobble_ratio: float = 0.0) -> Vector3:
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
	horizontal = horizontal.normalized()

	if wobble_ratio > 0.0:
		var max_wobble_rad: float = deg_to_rad(overcharge_wobble_degrees) * wobble_ratio
		var wobble_angle: float = randf_range(-max_wobble_rad, max_wobble_rad)
		horizontal = horizontal.rotated(Vector3.UP, wobble_angle)

	return (horizontal + Vector3.UP * kick_height_ratio).normalized()
