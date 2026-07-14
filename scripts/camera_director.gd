extends Camera3D
class_name CameraDirector
## Attach to a level's Camera3D. Two independent features, both driven by
## connecting other objects' signals to this script rather than this script
## reaching out to them:
##
## - `_on_big_impact(strength, position)`: wire any hard-collision signal
##   here (e.g. Ball's `big_impact`) for screen shake + a brief slow-motion
##   dip, scaled by how hard the hit was.
## - `_on_level_complete()`: wire a WinConditionDetector's `level_complete`
##   here for the "Spectacle Cam" — a dramatic push-in + tilt replacing the
##   normal view for the win payoff, then a return to normal.

@export var shake_strength_per_impact: float = 0.15
@export var shake_duration: float = 0.3
@export var slow_motion_scale: float = 0.25
@export var slow_motion_duration: float = 0.12  # real-world seconds, unaffected by the dip itself

@export var spectacle_zoom_in: float = 0.6   # 0..1, how far to close the gap toward the origin
@export var spectacle_tilt_degrees: float = 12.0
@export var spectacle_transition_time: float = 1.2
@export var spectacle_hold_time: float = 2.5

# ANADI REVIEW (Samprity/UI): additive player zoom — mouse wheel or +/- keys
# dolly the camera along its own forward axis. Applied as an offset on top of
# _cinematic_transform, so shake and the spectacle move are unaffected.
@export var zoom_step: float = 0.7           # meters per wheel notch
@export var zoom_key_speed: float = 6.0      # meters per second while +/- held
@export var zoom_min: float = -4.0           # max dolly OUT (negative = away)
@export var zoom_max: float = 6.0            # max dolly IN (toward the room)
@export var zoom_smoothing: float = 8.0      # lerp speed toward the target zoom

var _zoom_target: float = 0.0
var _zoom_current: float = 0.0

# ANADI REVIEW (Samprity/UI): additive presentation polish, both offset-based
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

# The camera's "intended" pose, ignoring shake. Shake is applied as a
# per-frame additive jitter on top of this rather than fighting over
# `transform` directly with whatever's tweening `_cinematic_transform`.
var _cinematic_transform: Transform3D
var _shake_trauma: float = 0.0  # 0..1, decays over time; drives jitter magnitude
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_cinematic_transform = transform
	_rng.randomize()
	_base_fov = fov
	_follow_node = get_node_or_null(follow_target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clampf(_zoom_target + zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clampf(_zoom_target - zoom_step, zoom_min, zoom_max)

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

	_fov_extra = move_toward(_fov_extra, 0.0, fov_recover_speed * delta)
	fov = _base_fov + _fov_extra

	transform = _cinematic_transform
	# Dolly along the camera's own forward (-Z) so zoom respects any tilt the
	# spectacle move applies; offset-based, so it never mutates the rest pose.
	position += -_cinematic_transform.basis.z * _zoom_current + _follow_offset
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
	var target_origin: Vector3 = rest.origin.lerp(Vector3.ZERO, spectacle_zoom_in)
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
