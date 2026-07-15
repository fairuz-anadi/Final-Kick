extends CanvasLayer
## Gameplay HUD — "laboratory OS" pass. Reads live state off the
## Ball's public vars and two additive signals (ball.kicked,
## detector.progress_changed); no gameplay behavior is touched.
##
## Palette (art direction): panels #1A1D22 @85%, text #EAEAEA / #A8ADB5,
## highlight #F5A623, warning #D9534F, rewind #6A8CAF.

@export var level_name: String = "MACHINE HALL 01"
@export var objective: String = "Wake every machine"
@export var ball_path: NodePath
@export var ghost_material: Material

const FloatingTextScene := preload("res://scenes/ui/floating_text.tscn")

const COLOR_TEXT := Color(0.918, 0.918, 0.918)
const COLOR_MUTED := Color(0.659, 0.678, 0.71)
const COLOR_HIGHLIGHT := Color(0.961, 0.651, 0.137)
const COLOR_WARNING := Color(0.851, 0.325, 0.31)
const COLOR_SUCCESS := Color(0.42, 0.749, 0.349)
const COLOR_REWIND := Color(0.416, 0.549, 0.686)
const COLOR_BURST := Color(0.545, 0.361, 0.965)  # violet — distinct from the red MAX POWER state

@onready var _ball: RigidBody3D = get_node_or_null(ball_path)
@onready var _level_label: Label = %LevelName
@onready var _objective_label: Label = %Objective
@onready var _targets_label: Label = %Targets
@onready var _time_label: Label = %TimeLabel
@onready var _kicks_label: Label = %KicksLabel
@onready var _rewinds_label: Label = %RewindsLabel
@onready var _charge_box: Control = %ChargeBox
@onready var _charge_bar: ProgressBar = %ChargeBar
@onready var _power_label: Label = %PowerLabel
@onready var _rewind_gauge: ProgressBar = %RewindGauge
@onready var _rewind_gauge_label: Label = %RewindGaugeLabel
@onready var _crosshair: Control = %Crosshair
@onready var _rewind_overlay: ColorRect = %RewindOverlay
@onready var _film_grain: ColorRect = %FilmGrain
@onready var _tutorial_hint: Label = %TutorialHint

var _ball_mesh: MeshInstance3D
var _was_scrubbing := false
var _elapsed := 0.0
var _timer_running := true
var _vignette_boost := 0.0

var kicks_used := 0
var rewinds_used := 0
var targets_done := 0
var targets_total := 0
var _burst_notified_this_kick := false

func _ready() -> void:
	_level_label.text = level_name
	_objective_label.text = objective
	if _ball == null:
		push_warning("HUD: ball_path not set or Ball not found — HUD will stay idle")
		return
	for child in _ball.get_children():
		if child is MeshInstance3D:
			_ball_mesh = child
			break
	if _ball.has_signal("kicked"):
		_ball.kicked.connect(_on_kicked)
	if _ball.has_signal("burst_kicked"):
		_ball.burst_kicked.connect(_on_burst_kicked)
	_fade_tutorial_hint()

func _process(_delta: float) -> void:
	if _ball == null:
		return
	if _timer_running:
		_elapsed += _delta
	_time_label.text = "TIME   %02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]

	# Vignette punch from MAX POWER kicks decays back to the resting 5%.
	if _vignette_boost > 0.0:
		_vignette_boost = move_toward(_vignette_boost, 0.0, _delta * 2.0)
		if _film_grain.material is ShaderMaterial:
			_film_grain.material.set_shader_parameter("boost", _vignette_boost)

	var scrubbing: bool = _ball.is_scrubbing
	_update_charge()
	_update_rewind_gauge(scrubbing)
	_crosshair.set_state(_ball.charge_ratio if _ball.charging else 0.0, scrubbing)

	if scrubbing != _was_scrubbing:
		_was_scrubbing = scrubbing
		_rewind_overlay.visible = scrubbing
		if _ball_mesh and ghost_material:
			_ball_mesh.material_override = ghost_material if scrubbing else null
		if scrubbing:
			rewinds_used += 1
			_rewinds_label.text = "REWINDS   %d" % rewinds_used
			notify("TIME REWIND", COLOR_REWIND)

func _update_charge() -> void:
	_charge_box.visible = _ball.charging
	if not _ball.charging:
		return
	var ratio: float = _ball.charge_ratio
	_charge_bar.value = ratio * 100.0

	# Art direction: white -> orange at 40% -> deep red at 80%; glow at MAX only.
	var state_color := COLOR_TEXT
	if ratio >= 0.8:
		state_color = COLOR_WARNING
	elif ratio >= 0.4:
		state_color = COLOR_HIGHLIGHT
	var at_max := ratio >= 0.995
	var burst_armed: bool = _ball.burst_armed
	if burst_armed:
		state_color = COLOR_BURST
	var fill := _charge_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		fill.bg_color = state_color
		fill.shadow_color = Color(state_color, 0.5 if (at_max or burst_armed) else 0.0)
		fill.shadow_size = 6 if (at_max or burst_armed) else 0

	if burst_armed:
		_power_label.text = "FINAL KICK READY"
		_power_label.modulate = Color(COLOR_BURST, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.025))
	elif at_max:
		_power_label.text = "MAX POWER"
		_power_label.modulate = Color(COLOR_WARNING, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.02))
	else:
		_power_label.text = "KICK POWER   %d%%" % int(ratio * 100.0)
		_power_label.modulate = Color(COLOR_TEXT, 1.0)

func _update_rewind_gauge(scrubbing: bool) -> void:
	_rewind_gauge.max_value = maxf(_ball.max_history_frames, 1.0)
	var frames: int = _ball.history.size()
	_rewind_gauge.value = _ball.scrub_index if scrubbing else float(frames)
	var fill := _rewind_gauge.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		fill.bg_color = COLOR_REWIND
	if scrubbing:
		_rewind_gauge_label.text = "REWIND — ACTIVE"
		_rewind_gauge_label.modulate = Color(COLOR_REWIND, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012))
	elif frames < 10:
		# Barely any recorded history yet — rewinding now would do nothing.
		_rewind_gauge_label.text = "REWIND — NO DATA"
		_rewind_gauge_label.modulate = Color(COLOR_WARNING, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.015))
	else:
		_rewind_gauge_label.text = "REWIND — HOLD R"
		_rewind_gauge_label.modulate = Color(COLOR_MUTED, 1.0)

func _on_kicked(power_ratio: float) -> void:
	kicks_used += 1
	_kicks_label.text = "KICKS   %d" % kicks_used
	if _burst_notified_this_kick:
		# The burst callout already covered the notify/vignette for this kick —
		# skip the generic MAX POWER reaction so they don't double up.
		_burst_notified_this_kick = false
		return
	if power_ratio >= 0.995:
		notify("MAX POWER KICK", COLOR_WARNING)
		_vignette_boost = 1.0
		PlaceholderSFX.play_max_power()

func _on_burst_kicked() -> void:
	_burst_notified_this_kick = true
	notify("FINAL KICK!", COLOR_BURST)
	_vignette_boost = 1.0

## Connect WinConditionDetector.progress_changed here (done in the level scene).
func on_progress(done: int, total: int) -> void:
	if done > targets_done and done > 0:
		notify("TARGET ACTIVATED   %d / %d" % [done, total], COLOR_SUCCESS)
		PlaceholderSFX.play_target_ding()
	targets_done = done
	targets_total = total
	_targets_label.text = "TARGETS   %d / %d" % [done, total]
	if total > 0 and done == total:
		_timer_running = false

## Spawns floating feedback text near the upper third of the screen.
func notify(message: String, color: Color) -> void:
	var floating := FloatingTextScene.instantiate()
	floating.setup(message, color)
	add_child(floating)
	var viewport_size := get_viewport().get_visible_rect().size
	floating.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.3)

## Real run stats for the result screen.
func get_stats() -> Dictionary:
	return {
		"time": _elapsed,
		"kicks": kicks_used,
		"rewinds": rewinds_used,
		"targets_done": targets_done,
		"targets_total": targets_total,
	}

func _fade_tutorial_hint() -> void:
	await get_tree().create_timer(10.0).timeout
	var tween := create_tween()
	tween.tween_property(_tutorial_hint, "modulate:a", 0.0, 1.2)
