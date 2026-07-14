extends ProgressBar

@onready var ball: RigidBody3D = get_node("../../Ball")

func _process(_delta: float) -> void:
	visible = ball.charging
	value = ball.charge_ratio * 100.0
