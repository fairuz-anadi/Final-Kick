extends Node3D
class_name RotatingGate
## Timed obstacle for Level 6 (Overcharge Precision): a panel that swings
## between blocking a corridor and lying flush against the wall, on a fixed
## cycle. Collision is a hard on/off toggle in sync with the visual swing —
## the rotation is what the player reads, the CollisionShape3D disable is
## what actually gates the ball.

@export var cycle_duration: float = 2.6      # full open->closed->open period, in seconds
@export var open_ratio: float = 0.35          # fraction of the cycle the gate spends open
@export var closed_angle_deg: float = 90.0    # panel angle (around local Y) when blocking the corridor
@export var swing_time: float = 0.4           # seconds spent mid-swing between states, for readability

@onready var _panel: Node3D = $Panel
@onready var _collision: CollisionShape3D = $Panel/CollisionShape3D

var _t: float = 0.0

func _ready() -> void:
	# Start mid-cycle rather than always at the same phase, so a room with
	## multiple gates doesn't have them all open/close in obvious lockstep.
	_t = randf() * cycle_duration

func _process(delta: float) -> void:
	_t = fmod(_t + delta, cycle_duration)
	var open_time: float = cycle_duration * open_ratio

	# One continuous pass: closed -> swing open -> hold open -> swing closed
	# -> hold closed, so there's no snap between segments.
	var angle_deg: float = closed_angle_deg
	if _t < swing_time:
		angle_deg = lerp(closed_angle_deg, 0.0, _t / swing_time)
	elif _t < open_time:
		angle_deg = 0.0
	elif _t < open_time + swing_time:
		angle_deg = lerp(0.0, closed_angle_deg, (_t - open_time) / swing_time)
	else:
		angle_deg = closed_angle_deg

	_panel.rotation.y = deg_to_rad(angle_deg)
	# Collision follows the swing itself (open once past halfway through the
	# opening motion) rather than a separate timer, so what the player sees
	# always matches what actually blocks the ball.
	_collision.disabled = angle_deg < closed_angle_deg * 0.5
