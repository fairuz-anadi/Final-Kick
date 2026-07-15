extends Button
class_name CutCornerButton
## Self-drawn "control panel" button: angled top-left/bottom-right corners
## and a bracket-style border instead of a plain rounded rect, so it reads
## as part of the factory's machinery rather than a generic UI default.
## `flat = true` strips the engine's own stylebox; this draws everything
## itself, underneath the Button's normal text rendering.

@export var accent_color := Color(0.25, 0.85, 0.9)
@export var cut := 10.0

var _hovering := false
var _pressing := false

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func() -> void: _hovering = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovering = false; queue_redraw())
	button_down.connect(func() -> void: _pressing = true; queue_redraw())
	button_up.connect(func() -> void: _pressing = false; queue_redraw())

func _draw() -> void:
	var size := get_size()
	var pts := PackedVector2Array([
		Vector2(cut, 0), Vector2(size.x, 0),
		Vector2(size.x, size.y - cut), Vector2(size.x - cut, size.y),
		Vector2(0, size.y), Vector2(0, cut),
	])

	var fill: Color
	var border: Color
	if _pressing:
		fill = Color(0.961, 0.651, 0.137, 0.92)
		border = Color(1.0, 1.0, 1.0, 0.9)
	elif _hovering:
		fill = Color(accent_color.r, accent_color.g, accent_color.b, 0.24)
		border = Color(accent_color, 1.0)
	else:
		fill = Color(0.078, 0.086, 0.106, 0.88)
		border = Color(accent_color.r, accent_color.g, accent_color.b, 0.5)

	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, border, 1.6, true)

	# Bracket accents at the two square corners — the "control panel" read.
	var tick := minf(cut, 8.0)
	draw_polyline(PackedVector2Array([Vector2(0, size.y - tick * 1.6), Vector2(0, size.y), Vector2(tick * 1.6, size.y)]), border, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(size.x - tick * 1.6, 0), Vector2(size.x, 0), Vector2(size.x, tick * 1.6)]), border, 2.0, true)
