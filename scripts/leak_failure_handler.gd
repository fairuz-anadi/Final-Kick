extends Node
class_name LeakFailureHandler
## Level 8. A LeakingVial that destabilizes on its own (see leaking_vial.gd's
## `leaked` signal) can never satisfy the win condition anymore — the room is
## unwinnable from that point on, so reload after a beat (so the player sees
## what happened) rather than leaving them stuck with no obvious way out.

@export var vial_paths: Array[NodePath] = []
@export var hud_path: NodePath
@export var reload_delay: float = 1.6

func _ready() -> void:
	for path in vial_paths:
		var vial := get_node_or_null(path)
		if vial and vial.has_signal("leaked"):
			vial.leaked.connect(_on_leaked)

func _on_leaked() -> void:
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("notify"):
		hud.notify("VIAL LOST — RESETTING", Color(0.851, 0.325, 0.31))
	await get_tree().create_timer(reload_delay).timeout
	get_tree().reload_current_scene()
