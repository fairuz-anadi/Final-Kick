extends Node
## Autoload ("LifeManager" — historical name). No hearts, no lives: losing
## the ball (out of bounds, kill zone) drains Factory Energy instead, so the
## stakes live in the same bar the player is already trying to fill. Machines
## stay awake and the ball just respawns — waking the next machine earns the
## energy back.
##
## The only fail state: if careless losses drain away ALL the energy the
## player had earned (energy hits 0 while at least one machine is awake),
## the factory blacks out and the level restarts. With no progress yet
## there's nothing to drain, so early experimenting is always free.
##
## Wiring, all runtime — no per-scene setup:
## - HUD calls start_level() from its _ready (a HUD exists in every level).
## - ball.gd calls on_ball_lost(ball) when it falls out of bounds.
## - kill_zone.gd (Area3D) calls the same for explicit hazard volumes.
## - HUD listens to energy_drained / power_critical for popups + vignette.
## - The blackout overlay (text + fade to black) is owned here, on its own
##   high CanvasLayer, so no scene needs to include it.

signal energy_drained(amount: float)
signal power_critical(active: bool)
signal factory_shutdown

## Factory Energy lost per ball loss (out of 100).
const DRAIN_PER_LOSS := 20.0
## Below this (with progress made) the HUD shows the red warning state.
const CRITICAL_ENERGY := 25.0
## Blackout text hold time before the black fade finishes and the level reloads.
const SHUTDOWN_HOLD := 2.2

var _in_level: bool = false
var _shutting_down: bool = false
var _critical: bool = false

var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect
var _shutdown_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

## Called by the HUD when a level starts.
func start_level() -> void:
	_in_level = true
	_shutting_down = false
	_critical = false
	_fade_rect.modulate.a = 0.0
	_shutdown_label.visible = false

## Called from menus/cinematics so a stray on_ball_lost can't fire there.
func leave_level() -> void:
	_in_level = false

## The one entry point for "the ball is gone". The caller stays responsible
## for actually respawning the ball (ball.gd already resets itself);
## this only handles the energy drain, feedback, and the blackout sequence.
func on_ball_lost(ball: Node3D) -> void:
	if not _in_level or _shutting_down:
		return
	var had_progress: bool = FactoryManager.progress_pct > 0.0
	# Before any machine is awake there's no earned energy to lose — early
	# experimenting stays free. The HUD reads amount 0 as a plain "BALL LOST".
	if had_progress:
		FactoryManager.drain_energy(DRAIN_PER_LOSS)
		energy_drained.emit(DRAIN_PER_LOSS)
	else:
		energy_drained.emit(0.0)
	PlaceholderSFX.play_heart_loss()
	_shake_camera(ball)

	# Escalation: drained to zero after real progress = blackout restart;
	# critically low = warning state + narrator; otherwise just the sting.
	if had_progress and FactoryManager.energy <= 0.0:
		_begin_shutdown()
	elif had_progress and FactoryManager.energy <= CRITICAL_ENERGY:
		_set_critical(true)
		NarratorManager.on_power_critical()
	else:
		NarratorManager.on_death()

## Waking a machine can lift the factory back out of the critical state —
## FactoryManager calls this whenever energy changes upward.
func on_energy_recovered() -> void:
	if _critical and FactoryManager.energy > CRITICAL_ENERGY:
		_set_critical(false)

func _set_critical(active: bool) -> void:
	if _critical == active:
		return
	_critical = active
	power_critical.emit(active)

func _shake_camera(ball: Node3D) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var camera := ball.get_viewport().get_camera_3d()
	# CameraDirector exposes _on_big_impact(strength, pos) for exactly this
	# kind of jolt; strength 3.0 is a firm-but-not-max shake.
	if camera and camera.has_method("_on_big_impact"):
		camera._on_big_impact(3.0, ball.global_position)

func _begin_shutdown() -> void:
	_shutting_down = true
	_set_critical(false)
	factory_shutdown.emit()
	PlaceholderSFX.play_shutdown()
	NarratorManager.clear()

	_shutdown_label.visible = true
	_shutdown_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 1.2)
	tween.parallel().tween_property(_shutdown_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(SHUTDOWN_HOLD)
	tween.tween_callback(_restart_level)

func _restart_level() -> void:
	get_tree().reload_current_scene()
	# start_level() runs again via the fresh HUD's _ready; fade back from
	# black here so the reloaded room is revealed rather than popping in.
	_shutdown_label.visible = false
	_shutting_down = false
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.9)

func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 90
	add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_fade_rect)

	_shutdown_label = Label.new()
	_shutdown_label.text = "POWER  LOST"
	_shutdown_label.visible = false
	_shutdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shutdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shutdown_label.add_theme_font_size_override("font_size", 42)
	_shutdown_label.add_theme_color_override("font_color", Color(1.0, 0.239, 0.506))
	var font: FontFile = load("res://assets/fonts/Orbitron.ttf")
	if font:
		_shutdown_label.add_theme_font_override("font", font)
	_overlay_layer.add_child(_shutdown_label)
