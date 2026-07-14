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

# The camera's "intended" pose, ignoring shake. Shake is applied as a
# per-frame additive jitter on top of this rather than fighting over
# `transform` directly with whatever's tweening `_cinematic_transform`.
var _cinematic_transform: Transform3D
var _shake_trauma: float = 0.0  # 0..1, decays over time; drives jitter magnitude
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_cinematic_transform = transform
	_rng.randomize()

func _process(delta: float) -> void:
	transform = _cinematic_transform
	if _shake_trauma <= 0.0:
		return
	var amount: float = _shake_trauma * _shake_trauma  # ease-out: big hits punch harder, fade fast
	position += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * amount * 0.3
	_shake_trauma = move_toward(_shake_trauma, 0.0, delta / shake_duration)

func _on_big_impact(strength: float, _impact_position: Vector3) -> void:
	_shake_trauma = clamp(_shake_trauma + strength * shake_strength_per_impact, 0.0, 1.0)
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
