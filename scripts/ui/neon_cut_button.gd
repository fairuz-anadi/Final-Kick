extends Button
class_name NeonCutButton
## Neon magenta cut-corner button (title screen). Same silhouette as
## CutCornerButton, but drawn as a solid glowing shape: opaque magenta
## body, hot pink border, and a soft outer glow that flares up on hover
## and burns brightest while pressed.
##
## The body is drawn on a child canvas item with show_behind_parent, so
## the opaque fill sits UNDER the button's own label — a script _draw()
## on the button itself would paint over the text.

@export var accent_color := Color(1.0, 0.38, 0.87)
@export var fill_color := Color(0.62, 0.13, 0.48)
@export var glow_strength := 1.0
@export var cut := 12.0
@export var hover_ease_speed := 12.0  ## how fast the glow eases toward idle/hover/pressed

var _hovering := false
var _pressing := false
var _bg: Control

# Eased 0..1 heat driving the glow/fill — chases _target_hot() each frame
# instead of snapping, so hover/press reads as an animation, not a toggle.
var _hot := 0.0

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL

	_bg = Control.new()
	_bg.show_behind_parent = true
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_body)
	add_child(_bg)

	mouse_entered.connect(func() -> void: _hovering = true)
	mouse_exited.connect(func() -> void: _hovering = false)
	button_down.connect(func() -> void: _pressing = true)
	button_up.connect(func() -> void: _pressing = false)

func _process(delta: float) -> void:
	var target := _target_hot()
	if is_equal_approx(_hot, target):
		return
	_hot = lerpf(_hot, target, clampf(hover_ease_speed * delta, 0.0, 1.0))
	if absf(_hot - target) < 0.002:
		_hot = target
	_bg.queue_redraw()

# 0..1 heat: idle → hover → pressed. A latched toggle (difficulty radio
# buttons) stays at full heat while selected.
func _target_hot() -> float:
	return 1.0 if (_pressing or button_pressed) else (0.6 if _hovering else 0.0)

func _draw_body() -> void:
	var sz := _bg.get_size()
	var pts := PackedVector2Array([
		Vector2(cut, 0), Vector2(sz.x, 0),
		Vector2(sz.x, sz.y - cut), Vector2(sz.x - cut, sz.y),
		Vector2(0, sz.y), Vector2(0, cut),
	])
	var closed := pts.duplicate()
	closed.append(pts[0])

	var hot := _hot

	# Soft outer glow: three rings, the widest the faintest. Drawn before
	# the opaque fill so only the outward half of each ring survives.
	for i in range(3):
		var alpha := (0.12 + 0.14 * hot) * glow_strength * float(3 - i) / 3.0
		_bg.draw_polyline(closed,
			Color(accent_color.r, accent_color.g, accent_color.b, alpha),
			5.0 + i * 6.0, true)

	# Solid body — never see-through, brightens toward the accent when hot.
	var fill := fill_color.lerp(accent_color, 0.35 * hot)
	fill.a = 1.0
	_bg.draw_colored_polygon(pts, fill)

	var border := accent_color.lerp(Color.WHITE, 0.2 + 0.5 * hot)
	border.a = 1.0
	_bg.draw_polyline(closed, border, 2.5, true)
