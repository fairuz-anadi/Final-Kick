extends Camera3D
class_name CameraDirector
## Attach to a level's Camera3D. Independent features, all driven by
## connecting other objects' signals to this script rather than this script
## reaching out to them:
##
## - `_on_big_impact(strength, position)`: wire any hard-collision signal
##   here (e.g. Ball's `big_impact`) for screen shake + a brief slow-motion
##   dip, scaled by how hard the hit was.
## - `_on_level_complete()`: wire a WinConditionDetector's `level_complete`
##   here for the "Spectacle Cam" — a dramatic push-in + tilt replacing the
##   normal view for the win payoff, then a return to normal.
## - `_on_target_activated()`: wire each intermediate Gear/Vial/GridNode's own
##   `activated` signal here (NOT WinConditionDetector's — that one only
##   reports "all done", not "which one, in what order") to advance a
##   FIXED -> FOLLOWING -> TRANSITIONING -> FIXED sequence: once the
##   currently-shown target activates, the camera chases the ball
##   (position only, same viewing angle) until the ball nears
##   `arrival_targets[stage]`, then tweens (move, then rotate if needed)
##   into `waypoint_markers[stage]`'s pose and locks there. Both arrays are
##   indexed in the order targets are meant to activate; the last target
##   needs no entry in either — its activation instead reaches
##   WinConditionDetector -> `_on_level_complete()` above.

# Interior view (art direction): bring the camera down INTO the room —
# eye-ish height, gentle pitch — instead of hovering above the walls. The
# same reframe is applied to every cinematic waypoint marker so mid-level
# camera moves stay consistent with the rest pose.
@export var interior_view: bool = true
@export var interior_camera_height: float = 2.25
@export var interior_pitch_degrees: float = 11.0

# Free orbit (player view control): hold the RIGHT mouse button and drag to
# swing the camera all the way around the room — any yaw, near-full pitch
# (top-down to near-bottom-up), so every gear can be lined up and inspected.
# Scroll-zoom still dollies along the current view. HOME resets to the
# level's framed shot. Orbit is an offset on top of _cinematic_transform, so
# shake / spectacle / waypoint moves all still work.
@export var orbit_sensitivity: float = 0.3    # degrees per pixel of drag
# Pitch still stops just short of ±90° — exactly vertical is a gimbal
# singularity for the look-at basis below (the "up" vector degenerates).
@export var orbit_pitch_min: float = -85.0
@export var orbit_pitch_max: float = 85.0

var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0

# Named preset views (keys 1-4, or the HUD's view buttons): instant snaps to
# a cardinal angle around the room so every gear can be lined up without
# hand-dragging the orbit. Yaw/pitch are offsets on the same rest pose the
# free orbit above uses, so a preset can still be nudged further by hand
# afterward. Front is the level's own framed shot (0, 0); Back is the
# opposite side; Top/Bottom sit at the same near-vertical clamp the free
# orbit stops at, for the same gimbal-singularity reason.
const VIEW_PRESETS := {
	"front": {"yaw": 0.0, "pitch": 0.0},
	"back": {"yaw": 180.0, "pitch": 0.0},
	"top": {"yaw": 0.0, "pitch": 85.0},
	"bottom": {"yaw": 0.0, "pitch": -85.0},
}

@export var shake_strength_per_impact: float = 0.15
@export var shake_duration: float = 0.3
@export var slow_motion_scale: float = 0.25
@export var slow_motion_duration: float = 0.12  # real-world seconds, unaffected by the dip itself

@export var spectacle_zoom_in: float = 0.6   # 0..1, how far to close the gap toward the origin
@export var spectacle_tilt_degrees: float = 12.0
@export var spectacle_transition_time: float = 1.2
@export var spectacle_hold_time: float = 2.5

# CROSS-TEAM ADDITION (UI): additive player zoom — mouse wheel or +/- keys
# dolly the camera along its own forward axis. Applied as an offset on top of
# _cinematic_transform, so shake and the spectacle move are unaffected.
@export var zoom_step: float = 1.5           # meters per wheel notch (before acceleration)
@export var zoom_key_speed: float = 6.0      # meters per second while +/- held
# Wide enough to back all the way out of the 9.7m room or push in close on
# a single gear; not literally unbounded so the camera can't dolly through
# the walls and out into the void.
@export var zoom_min: float = -10.0          # max dolly OUT (negative = away)
@export var zoom_max: float = 12.0           # max dolly IN (toward the room)
@export var zoom_smoothing: float = 8.0      # lerp speed toward the target zoom
# Shooter-style aim zoom: wheel-in dollies toward the point UNDER THE MOUSE
# (not the screen center), so zooming reads as "closing in on my target",
# and the FOV tightens slightly on the way in for a scoped feel.
@export var zoom_fov_tighten: float = 14.0   # degrees of FOV narrowing at full zoom-in
@export var zoom_dir_smoothing: float = 6.0  # lerp speed when the aim point moves mid-zoom
# Wheel acceleration: single ticks stay precise, but flicking the wheel ramps
# the per-notch step up so crossing the whole zoom range takes a quick spin,
# not seventeen deliberate clicks.
@export var zoom_accel_window: float = 0.25  # seconds — notches faster than this accelerate
@export var zoom_accel_max: float = 3.0      # cap on the step multiplier
# Pull-back overview: zooming OUT also climbs toward the ceiling (an RTS-style
# rising arc) and widens the FOV — so even once the room-shell clamp stops the
# dolly at the wall, the view keeps opening up into a full-room overview
# instead of just going dead.
@export var zoom_out_rise: float = 0.4       # meters climbed per meter of pull-back
@export var zoom_out_fov_widen: float = 18.0 # extra FOV degrees at full zoom-out
@export var zoom_out_tilt: float = 22.0      # extra downward pitch at full zoom-out

# Final position safety clamp (see _process) — keeps the wide zoom/orbit
# ranges above from pushing the camera through the walls or ceiling, which
# have no collision. Matches factory_dressing.gd's ROOM_HALF/CEILING_HEIGHT
# with a small inward margin.
const ROOM_BOUND := 9.0
const CEILING_CLEARANCE := 4.3

var _zoom_target: float = 0.0
var _zoom_current: float = 0.0
# Dolly direction in VIEW-LOCAL space — (0,0,-1) is the classic straight-ahead
# dolly; wheel-in retargets it at the mouse ray so the zoom tracks the aim.
# Local (not world) so the offset swings along if the player orbits afterward.
var _zoom_dir: Vector3 = Vector3(0, 0, -1)
var _zoom_dir_target: Vector3 = Vector3(0, 0, -1)
var _zoom_accel: float = 1.0
var _last_wheel_ms: int = 0

# CROSS-TEAM ADDITION (UI): additive presentation polish, both offset-based
# on top of _cinematic_transform — the rest pose and spectacle tween are
# untouched. Set follow_target (e.g. the Ball) for a subtle horizontal drift
# toward the action; big impacts also punch the FOV out briefly.
@export var follow_target: NodePath
@export var follow_amount: float = 0.12       # fraction of target offset applied
@export var follow_max_offset: float = 1.2    # meters, per horizontal axis
@export var follow_smoothing: float = 3.0
@export var fov_punch_per_impact: float = 1.2 # degrees per unit of impact strength
@export var fov_punch_max: float = 8.0
@export var fov_recover_speed: float = 10.0   # degrees per second back to rest

var _follow_node: Node3D
var _follow_offset := Vector3.ZERO
var _base_fov: float = 75.0
var _fov_extra: float = 0.0

# --- Multi-gear sequence: FIXED (locked, showing current target) ->
# FOLLOWING (chases the ball, position only, angle frozen) -> TRANSITIONING
# (tweens into the next fixed shot) -> FIXED again. Driven by
# `_on_target_activated()`, reusing `_follow_node` above as the chase target
# rather than a second NodePath — every level already points `follow_target`
# at the Ball for the subtle-drift feature.
enum CamState { FIXED, FOLLOWING, TRANSITIONING }

@export var waypoint_markers: Array[NodePath] = []  # fixed pose per stage, indexed by activation order
@export var arrival_targets: Array[NodePath] = []    # same indexing: node whose vicinity ends FOLLOWING
@export var arrival_radius: float = 2.5              # meters, horizontal distance to arrival_target
@export var chase_smoothing: float = 5.0             # lerp speed while FOLLOWING; separate from follow_smoothing (that's the always-on subtle drift, not this)
@export var waypoint_move_time: float = 1.2
@export var waypoint_rotate_time: float = 0.6
# How many `_on_target_activated()` calls the *current* stage needs before the
# camera actually leaves — e.g. a chamber with two interlocked gears both
# visible in the same fixed shot needs both hit, not just the first, or the
# camera would peel away mid-chamber. Indexed by stage; a missing or <=0
# entry defaults to 1 (the common case, one target per stage, like Level 6).
@export var stage_required_activations: Array[int] = []

var _cam_state: CamState = CamState.FIXED
var _stage_index: int = 0
var _stage_activation_count: int = 0
var _stage_ready_to_follow: bool = false  # this stage's count hit its target; waiting for FIXED to act on it
var _chase_offset := Vector3.ZERO

# The camera's "intended" pose, ignoring shake. Shake is applied as a
# per-frame additive jitter on top of this rather than fighting over
# `transform` directly with whatever's tweening `_cinematic_transform`.
var _cinematic_transform: Transform3D
var _shake_trauma: float = 0.0  # 0..1, decays over time; drives jitter magnitude
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if interior_view:
		transform = _interior_pose(transform)
		for path in waypoint_markers:
			var marker := get_node_or_null(path)
			if marker is Node3D:
				marker.global_transform = _interior_pose(marker.global_transform)
	_cinematic_transform = transform
	_rng.randomize()
	_base_fov = fov
	_follow_node = get_node_or_null(follow_target)

## Rebuild a camera pose for the inside-the-room view: clamp height to
## just under the ceiling, keep the original yaw, and flatten the pitch to
## a gentle look-down so the frame is filled by the room, not the void
## above it.
func _interior_pose(t: Transform3D) -> Transform3D:
	var origin := t.origin
	origin.y = minf(origin.y, interior_camera_height)
	var forward := -t.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var dir := (forward + Vector3.DOWN * tan(deg_to_rad(interior_pitch_degrees))).normalized()
	return Transform3D(Basis.looking_at(dir, Vector3.UP), origin)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel_zoom(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel_zoom(-1.0)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Yaw wraps freely (full 360° orbit); only pitch stays clamped, to
		# avoid the vertical gimbal singularity.
		_orbit_yaw = wrapf(_orbit_yaw - event.relative.x * orbit_sensitivity, -180.0, 180.0)
		_orbit_pitch = clampf(_orbit_pitch - event.relative.y * orbit_sensitivity,
			orbit_pitch_min, orbit_pitch_max)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		_orbit_yaw = 0.0
		_orbit_pitch = 0.0
		_zoom_target = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_preset_view("front")
			KEY_2: set_preset_view("back")
			KEY_3: set_preset_view("top")
			KEY_4: set_preset_view("bottom")

## One wheel notch of zoom. Rapid consecutive notches ramp the step up (see
## zoom_accel_*), a pause resets it back to a precise single step. Zooming IN
## aims the dolly at whatever the mouse is over; zooming back out retreats
## along the same line (no retarget), so a full in-and-out round trip returns
## to the exact rest framing.
func _wheel_zoom(direction: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_wheel_ms < int(zoom_accel_window * 1000.0):
		_zoom_accel = minf(_zoom_accel + 0.4, zoom_accel_max)
	else:
		_zoom_accel = 1.0
	_last_wheel_ms = now
	_zoom_target = clampf(_zoom_target + direction * zoom_step * _zoom_accel, zoom_min, zoom_max)
	if direction > 0.0:
		_aim_zoom_at_mouse()

## Point the zoom dolly at the mouse: take the ray through the cursor and
## store it in view-local space as the new dolly direction. Straight-ahead
## mouse == the old (0,0,-1) center dolly, so nothing changes unless the
## player is actually aiming off-center.
func _aim_zoom_at_mouse() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray := project_ray_normal(mouse_pos)
	var local_dir := (global_transform.basis.inverse() * ray).normalized()
	if local_dir.z < -0.1:  # sanity: must still point into the scene
		_zoom_dir_target = local_dir

## Snap the orbit straight to a named cardinal view — see VIEW_PRESETS.
## Zoom is left untouched; only the angle changes.
func set_preset_view(view_name: String) -> void:
	if not VIEW_PRESETS.has(view_name):
		push_warning("CameraDirector: unknown preset view '%s'" % view_name)
		return
	var preset: Dictionary = VIEW_PRESETS[view_name]
	_orbit_yaw = preset["yaw"]
	_orbit_pitch = clampf(preset["pitch"], orbit_pitch_min, orbit_pitch_max)

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		_zoom_target = clampf(_zoom_target + zoom_key_speed * delta, zoom_min, zoom_max)
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_zoom_target = clampf(_zoom_target - zoom_key_speed * delta, zoom_min, zoom_max)
	_zoom_current = lerpf(_zoom_current, _zoom_target, clampf(zoom_smoothing * delta, 0.0, 1.0))

	# Subtle follow: drift a fraction of the way toward the target's horizontal
	# position, clamped and smoothed so it can never induce motion sickness.
	if _follow_node:
		var target_offset := Vector3(
			clampf(_follow_node.global_position.x * follow_amount, -follow_max_offset, follow_max_offset),
			0.0,
			clampf(_follow_node.global_position.z * follow_amount * 0.5, -follow_max_offset, follow_max_offset))
		_follow_offset = _follow_offset.lerp(target_offset, clampf(follow_smoothing * delta, 0.0, 1.0))

	if _cam_state == CamState.FOLLOWING:
		_process_chase(delta)

	# When the zoom fully retreats, forget the last aim point so the next
	# zoom-in starts from a clean straight-ahead dolly.
	if absf(_zoom_current) < 0.05 and absf(_zoom_target) < 0.01:
		_zoom_dir_target = Vector3(0, 0, -1)
	_zoom_dir = _zoom_dir.lerp(_zoom_dir_target, clampf(zoom_dir_smoothing * delta, 0.0, 1.0)).normalized()

	_fov_extra = move_toward(_fov_extra, 0.0, fov_recover_speed * delta)
	# Scope feel in, wide-angle out: the FOV tightens as the player dollies in
	# and widens as they pull back — the widen is what keeps zoom-out alive
	# after the wall clamp below stops the physical dolly. Impact FOV punch
	# stacks on top unchanged.
	var zoom_in_ratio := clampf(_zoom_current / zoom_max, 0.0, 1.0)
	var zoom_out_ratio := clampf(-_zoom_current / absf(zoom_min), 0.0, 1.0)
	fov = _base_fov + _fov_extra - zoom_fov_tighten * zoom_in_ratio \
		+ zoom_out_fov_widen * zoom_out_ratio

	var view := _orbited_pose(_cinematic_transform)
	transform = view
	# As the pull-back arc rises (below), pitch the view down with it so the
	# overview looks AT the room, not over it at the far wall.
	if _zoom_current < 0.0:
		transform.basis = view.basis.rotated(
			view.basis.x, -deg_to_rad(zoom_out_tilt) * zoom_out_ratio)
	# Dolly along the (view-local) aim direction — straight ahead by default,
	# toward the cursor after a wheel-in — so zoom respects any tilt the
	# spectacle move or the player's orbit applies; offset-based, so it never
	# mutates the rest pose.
	position += view.basis * (_zoom_dir * _zoom_current) + _follow_offset
	# Pull-back rises toward the ceiling (world-space, capped by the ceiling
	# clamp below) so zooming out arcs up into an overview instead of just
	# backing flat into a wall.
	if _zoom_current < 0.0:
		position += Vector3.UP * (-_zoom_current) * zoom_out_rise
	# The wide zoom/orbit ranges above can otherwise push the camera straight
	# through the room's walls/ceiling (which have no collision) — clamp the
	# final position to stay inside the ~9.7m room shell (factory_dressing.gd's
	# ROOM_HALF) regardless of how far the player zoomed or orbited.
	position.x = clampf(position.x, -ROOM_BOUND, ROOM_BOUND)
	position.z = clampf(position.z, -ROOM_BOUND, ROOM_BOUND)
	position.y = clampf(position.y, 0.5, CEILING_CLEARANCE)
	if _shake_trauma <= 0.0:
		return
	var amount: float = _shake_trauma * _shake_trauma  # ease-out: big hits punch harder, fade fast
	position += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * amount * 0.3
	_shake_trauma = move_toward(_shake_trauma, 0.0, delta / shake_duration)

func _on_big_impact(strength: float, _impact_position: Vector3) -> void:
	_shake_trauma = clamp(_shake_trauma + strength * shake_strength_per_impact, 0.0, 1.0)
	_fov_extra = clampf(_fov_extra + strength * fov_punch_per_impact, 0.0, fov_punch_max)
	Engine.time_scale = slow_motion_scale
	# ignore_time_scale=true so this dip's own real-world duration isn't
	# stretched by the time_scale change it just made.
	var timer := get_tree().create_timer(slow_motion_duration, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)

func _on_level_complete() -> void:
	var rest := _cinematic_transform
	# Push toward the room center but hold a filming height — from the low
	# interior rest pose, aiming at the true origin would dive into the floor.
	var target_origin: Vector3 = rest.origin.lerp(Vector3(0.0, 1.6, 0.0), spectacle_zoom_in)
	var target_basis: Basis = rest.basis.rotated(Vector3.RIGHT, deg_to_rad(spectacle_tilt_degrees))
	var target := Transform3D(target_basis, target_origin)

	var tween := create_tween()
	tween.tween_method(_set_cinematic_transform, rest, target, spectacle_transition_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(spectacle_hold_time)
	tween.tween_method(_set_cinematic_transform, target, rest, spectacle_transition_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _set_cinematic_transform(t: Transform3D) -> void:
	_cinematic_transform = t

## Apply the player's orbit angles to a rest pose: swing the camera around
## the point the shot is looking at, then re-aim at that point. At zero
## angles this returns the pose untouched (the pivot lies on the original
## forward ray), so there's no jump when the player first grabs the view.
func _orbited_pose(rest: Transform3D) -> Transform3D:
	if absf(_orbit_yaw) < 0.01 and absf(_orbit_pitch) < 0.01:
		return rest
	var forward := -rest.basis.z
	# Pivot: where the view ray crosses ~0.8m height (the action plane).
	var dist := 10.0
	if absf(forward.y) > 0.01:
		dist = clampf((0.8 - rest.origin.y) / forward.y, 6.0, 20.0)
	var pivot := rest.origin + forward * dist
	var offset := rest.origin - pivot
	offset = offset.rotated(Vector3.UP, deg_to_rad(_orbit_yaw))
	var right := offset.cross(Vector3.UP)
	if right.length() > 0.01:
		offset = offset.rotated(right.normalized(), deg_to_rad(_orbit_pitch))
	var origin := pivot + offset
	origin.y = maxf(origin.y, 0.5)
	var dir := (pivot - origin).normalized()
	# Near top-down, UP is almost parallel to the view — use a stable fallback.
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(dir, up), origin)

## Wire directly to a Gear/Vial/GridNode's `activated` signal (one connection
## per intermediate target, in the order they're meant to activate — NOT to
## WinConditionDetector, which only reports "all done"). Counting happens
## regardless of camera state — a stage's arrival_target is usually itself
## one of the NEXT stage's required objects, so its `activated` signal can
## easily land while the camera is still FOLLOWING/TRANSITIONING out of the
## previous stage (arriving at a gear and hitting it tend to happen in the
## same beat). Whichever stage is "not yet locked in" is the one such a
## signal belongs to — see `_counting_stage()` — not necessarily `_stage_index`
## itself, which only advances once the camera is actually FIXED again.
func _on_target_activated() -> void:
	var stage: int = _counting_stage()
	if stage >= waypoint_markers.size():
		return
	_stage_activation_count += 1
	if _stage_activation_count < _required_for_stage(stage):
		return
	_stage_activation_count = 0
	_stage_ready_to_follow = true
	_try_begin_follow()

# While FIXED, the stage on screen (_stage_index) is still accumulating
# activations. Once the camera has left FIXED (FOLLOWING/TRANSITIONING out of
# it), _stage_index hasn't incremented yet, but any further activation can
# only belong to the stage being traveled toward — _stage_index + 1.
func _counting_stage() -> int:
	return _stage_index if _cam_state == CamState.FIXED else _stage_index + 1

func _required_for_stage(stage: int) -> int:
	if stage < stage_required_activations.size() and stage_required_activations[stage] > 0:
		return stage_required_activations[stage]
	return 1

func _try_begin_follow() -> void:
	if not _stage_ready_to_follow or _cam_state != CamState.FIXED:
		return
	_stage_ready_to_follow = false
	if _follow_node == null:
		push_warning("CameraDirector: follow_target isn't set, can't enter FOLLOWING")
		return
	# Preserve whatever offset the fixed shot currently has from the ball
	# (distance + framing), so the chase reads as "the same shot sliding
	# along," not a jump-cut to sitting on top of the ball.
	_chase_offset = _cinematic_transform.origin - _follow_node.global_position
	_cam_state = CamState.FOLLOWING

func _process_chase(delta: float) -> void:
	var target_origin: Vector3 = _follow_node.global_position + _chase_offset
	var new_origin: Vector3 = _cinematic_transform.origin.lerp(
		target_origin, clampf(chase_smoothing * delta, 0.0, 1.0))
	# Basis (viewing angle) is untouched here — that's the "position only" requirement.
	_cinematic_transform = Transform3D(_cinematic_transform.basis, new_origin)

	var arrival_node: Node3D = get_node_or_null(arrival_targets[_stage_index])
	if arrival_node == null:
		push_warning("CameraDirector: arrival_targets[%d] not found" % _stage_index)
		return
	var ball_flat: Vector3 = _follow_node.global_position
	var target_flat: Vector3 = arrival_node.global_position
	ball_flat.y = 0.0
	target_flat.y = 0.0
	if ball_flat.distance_to(target_flat) <= arrival_radius:
		_begin_transition()

func _begin_transition() -> void:
	var marker: Node3D = get_node_or_null(waypoint_markers[_stage_index])
	if marker == null:
		push_warning("CameraDirector: waypoint_markers[%d] not found" % _stage_index)
		_cam_state = CamState.FIXED  # fail safe — don't strand the camera mid-chase forever
		return

	_cam_state = CamState.TRANSITIONING
	var start: Transform3D = _cinematic_transform
	var moved: Transform3D = Transform3D(start.basis, marker.global_position)  # translate first...
	var final: Transform3D = marker.global_transform                          # ...only then rotate

	var tween := create_tween()
	tween.tween_method(_set_cinematic_transform, start, moved, waypoint_move_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not moved.basis.is_equal_approx(final.basis):
		tween.tween_method(_set_cinematic_transform, moved, final, waypoint_rotate_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		_cinematic_transform = final
	tween.tween_callback(_end_transition)

func _end_transition() -> void:
	_cam_state = CamState.FIXED
	_stage_index += 1
	# Rare but possible: the new stage's own requirement was already fully met
	# mid-transition (e.g. a required=1 stage whose one target got hit the
	# instant the ball arrived). Act on it immediately instead of waiting for
	# another `activated` signal that may never come.
	_try_begin_follow()
