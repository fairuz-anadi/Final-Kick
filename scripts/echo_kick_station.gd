extends Node
class_name EchoKickStation
## Level 9 (Echo Kick). Press E to "bank" everything the Ball has done since
## its last reset as a ghost replay (see echo_ghost.gd), then reset the Ball
## back to its start so a second, live attempt can run alongside the ghost —
## the two together are what a SyncGateLock is listening for.

@export var ball_path: NodePath
@export var ghost_scene: PackedScene
@export var min_frames_to_bank: int = 20  # ignore E presses before there's a real run worth banking
@export var hud_path: NodePath

@onready var _ball: RigidBody3D = get_node_or_null(ball_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_bank()

func _bank() -> void:
	if _ball == null or not ("history" in _ball):
		return
	var frames: Array[Dictionary] = _ball.history
	if frames.size() < min_frames_to_bank:
		return
	var ghost: Node3D = ghost_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.start(frames.duplicate())
	if _ball.has_method("_reset_to_start"):
		_ball._reset_to_start()
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("notify"):
		hud.notify("ECHO BANKED — LIVE KICK NOW", Color(0.416, 0.549, 0.686))
