extends Control
## Aim crosshair (Samprity). Follows the mouse; the HUD feeds it state every
## frame via set_state(). Grows while charging, spins cyan while rewinding.
## Drawn as thin lines so it never obstructs the play field.

var _charge: float = 0.0
var _rewinding: bool = false
var _spin: float = 0.0

func set_state(charge: float, rewinding: bool) -> void:
	_charge = charge
	_rewinding = rewinding

func _process(delta: float) -> void:
	if _rewinding:
		_spin += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var center := get_local_mouse_position()
	var radius := 9.0 + _charge * 7.0
	var color := Color(0.416, 0.549, 0.686, 0.95) if _rewinding else Color(0.918, 0.918, 0.918, 0.8)
	draw_arc(center, radius, 0, TAU, 32, color, 1.5, true)
	for i in 4:
		var angle := _spin + TAU * i / 4.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * (radius + 3.0), center + dir * (radius + 8.0), color, 1.5, true)
	draw_circle(center, 1.5, color)
