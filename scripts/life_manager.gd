extends Node
## Autoload ("LifeManager"). The game's punishment system: each level grants
## MAX_LIVES attempts. Losing the ball (out of bounds, kill zone) costs one
## heart but keeps level progress — the ball just respawns. At zero hearts
## the whole factory "shuts down": fade to black, restart the level.
##
## Wiring, all runtime — no per-scene setup:
## - HUD calls start_level() from its _ready (a HUD exists in every level).
## - ball.gd calls on_ball_lost(ball) when it falls out of bounds.
## - kill_zone.gd (Area3D) calls the same for explicit hazard volumes.
## - HUD listens to lives_changed to draw the hearts.
## - The shutdown overlay (text + fade to black) is owned here, on its own
##   high CanvasLayer, so no scene needs to include it.

signal lives_changed(lives: int, max_lives: int)
signal factory_shutdown

const MAX_LIVES := 5
## Shutdown text hold time before the black fade finishes and the level reloads.
const SHUTDOWN_HOLD := 2.2

var lives: int = MAX_LIVES
var _in_level: bool = false
var _shutting_down: bool = false

var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect
var _shutdown_label: Label
var _heartbeat: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	# Heartbeat bed for the 2-hearts-left state; starts silent, not playing.
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.stream = PlaceholderSFX.heartbeat_loop()
	_heartbeat.volume_db = -14.0
	add_child(_heartbeat)

## Called by the HUD when a level starts. Full refill — hearts are per-level.
func start_level() -> void:
	lives = MAX_LIVES
	_in_level = true
	_shutting_down = false
	_fade_rect.modulate.a = 0.0
	_shutdown_label.visible = false
	_heartbeat.stop()
	lives_changed.emit(lives, MAX_LIVES)

## Called from menus/cinematics so a stray on_ball_lost can't fire there.
func leave_level() -> void:
	_in_level = false

## The one entry point for "the ball is gone". The caller stays responsible
## for actually respawning the ball (ball.gd already resets itself);
## this only handles hearts, feedback, and the shutdown sequence.
func on_ball_lost(ball: Node3D) -> void:
	if not _in_level or _shutting_down or lives <= 0:
		return
	lives -= 1
	lives_changed.emit(lives, MAX_LIVES)
	PlaceholderSFX.play_heart_loss()
	_shake_camera(ball)

	# Escalating heart states: 3 = narrator steadies you, 2 = heartbeat
	# starts (and stays on through 1), 1 = the stakes line (HUD adds the
	# red vignette off lives_changed), 0 = shutdown.
	if lives <= 0:
		_begin_shutdown()
	elif lives == 1:
		NarratorManager.on_last_life()
	elif lives == 2:
		if not _heartbeat.playing:
			_heartbeat.play()
		NarratorManager.on_death()
	elif lives == 3:
		NarratorManager.on_three_hearts()
	else:
		NarratorManager.on_death()

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
	factory_shutdown.emit()
	_heartbeat.stop()
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
	_shutdown_label.text = "FACTORY  SHUTDOWN"
	_shutdown_label.visible = false
	_shutdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shutdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shutdown_label.add_theme_font_size_override("font_size", 42)
	_shutdown_label.add_theme_color_override("font_color", Color(0.85, 0.33, 0.31))
	var font: FontFile = load("res://assets/fonts/Orbitron.ttf")
	if font:
		_shutdown_label.add_theme_font_override("font", font)
	_overlay_layer.add_child(_shutdown_label)
