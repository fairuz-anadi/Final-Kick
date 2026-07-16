extends Area3D
class_name KillZone
## Drop-in hazard volume: any Area3D with this script (plus a
## CollisionShape3D) drains Factory Energy on contact, exactly like falling
## out of bounds. Place over pits, crushers, live rails — anywhere the ball
## shouldn't go.
##
## Only reacts to the Ball (identified by its lose_ball() method), so other
## physics objects (crates, dominoes) can pass through hazards freely.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("lose_ball"):
		body.lose_ball()
