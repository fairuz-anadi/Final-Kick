extends Node3D
## Opening cinematic — the project's main scene. Seven beats in the Last
## Worker's workshop (all primitives, built at runtime by WorkshopRoom /
## LastWorker):
##
##  1  Black. Wind and a ticking clock. "There was a time..."
##  2  The workshop, warm and alive — the Worker (younger) repairing the machine.
##  3  Time passes: the clock spins, the lights die, everyone leaves.
##  4  Decades later: the Worker, old now, stands at his desk. A dim sphere waits.
##  5  Close-up: he attaches the ring. Sparks. The ball wakes.
##  6  He sits down. The room goes dark. Only the ball still glows.
##  7  YEAR 2147 — FINAL KICK — then the title screen.
##
## Any input skips to the title card; a second input continues.

const TITLE_SCREEN := "res://scenes/ui/title_screen.tscn"
const WorkerScene := preload("res://scripts/cinematic/last_worker.gd")
const RoomScene := preload("res://scripts/cinematic/workshop_room.gd")
const CutCornerButtonScript := preload("res://scripts/ui/cut_corner_button.gd")

var _room: WorkshopRoom
var _worker: LastWorker
var _camera: Camera3D
var _cam_focus := Vector3(0, 1, 0)

var _overlay: ColorRect
var _subtitle: Label
var _title_year: Label
var _title_main: Label
var _prompt: Label
var _skip_button: Button
var _menu_button: Button

var _wind_player: AudioStreamPlayer
var _clock_player: AudioStreamPlayer

var _scene_tween: Tween
var _on_title_card := false
var _finished := false

func _ready() -> void:
	_build_world()
	_build_overlay_ui()
	_build_skip_ui()
	_start_ambience()
	_scene_1()

func _process(_delta: float) -> void:
	_camera.look_at(_cam_focus)
	if _on_title_card and _prompt.modulate.a > 0.0:
		_prompt.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	if _on_title_card:
		_go_to_title_screen()
	else:
		_show_title_card()

# --- The seven scenes --------------------------------------------------

func _scene_1() -> void:
	_overlay.modulate.a = 1.0
	_scene_tween = create_tween()
	_add_line(_scene_tween, "There was a time when the lights never went out.", 3.2)
	_scene_tween.tween_callback(_scene_2)

func _scene_2() -> void:
	# The living factory: warm light, running machine, the Worker at work.
	_room.set_light_level(1.0)
	_room.set_machine_alive(true)
	_room.clock_speed = 0.02
	_worker.set_age(false)
	_worker.position = _room.machine_spot()
	_worker.rotation.y = PI
	_worker.set_pose("repair")

	_camera.position = Vector3(7.0, 5.2, 6.5)
	_cam_focus = Vector3(-1.0, 1.2, -2.0)

	_scene_tween = create_tween()
	_scene_tween.tween_property(_overlay, "modulate:a", 0.0, 2.2)
	_scene_tween.parallel().tween_property(_camera, "position",
		Vector3(5.6, 4.2, 5.4), 6.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_add_line(_scene_tween, "This factory powered entire cities.", 2.8)
	_scene_tween.tween_callback(_scene_3)

func _scene_3() -> void:
	# Time passes: the clock races, the light drains, the machine dies.
	_scene_tween = create_tween()
	_scene_tween.tween_callback(func() -> void:
		_room.clock_speed = 30.0
		_clock_player.pitch_scale = 2.5)
	_scene_tween.tween_method(_room.set_light_level, 1.0, 0.12, 5.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scene_tween.parallel().tween_property(_camera, "position",
		Vector3(4.6, 3.4, 4.6), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_add_line(_scene_tween, "But eventually...", 1.8)
	_scene_tween.tween_callback(func() -> void: _room.set_machine_alive(false))
	_add_line(_scene_tween, "Everyone left.", 2.4)
	_scene_tween.tween_callback(_scene_4)

func _scene_4() -> void:
	# Decades later. He is old now, and he has one thing left to build.
	_room.clock_speed = 0.02
	_clock_player.pitch_scale = 1.0
	_worker.set_age(true)
	_worker.position = _room.desk_spot()
	_worker.rotation.y = PI
	_worker.set_pose("stand")

	_camera.position = Vector3(4.4, 2.6, 1.2)
	_cam_focus = _room.desk_spot() + Vector3(0, 1.1, -0.4)

	_scene_tween = create_tween()
	_scene_tween.tween_property(_camera, "position", Vector3(3.8, 2.2, 0.6), 3.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_add_line(_scene_tween, "For decades, one worker stayed.", 2.6)
	_add_line(_scene_tween, "And when his hands grew old, he built one last thing.", 3.0)
	_scene_tween.tween_callback(_scene_5)

func _scene_5() -> void:
	# Close on the desk: the ring attaches, sparks fly, the ball wakes.
	_cam_focus = _room.ball_position()
	_scene_tween = create_tween()
	_scene_tween.tween_property(_camera, "position",
		_room.ball_position() + Vector3(1.1, 0.7, 1.4), 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scene_tween.tween_callback(func() -> void:
		_room.set_ring_visible(true)
		_spawn_sparks(_room.ball_position())
		PlaceholderSFX.play_spark(_room))
	_scene_tween.tween_method(_room.set_ball_glow, 0.0, 0.55, 1.2)
	_add_line(_scene_tween, "\"You don't need to understand.\"", 2.4, true)
	_add_line(_scene_tween, "\"Just promise me one thing.\"", 2.4, true)
	_add_line(_scene_tween, "\"Wake them.\"", 3.0, true)
	_scene_tween.tween_callback(_scene_6)

func _scene_6() -> void:
	# He sits. The room lets go. The ball keeps its light.
	_worker.position = _room.chair_spot()
	_worker.rotation.y = 0.0
	_worker.set_pose("sit")

	_cam_focus = _room.chair_spot() + Vector3(-0.4, 0.9, -0.6)
	_camera.position = Vector3(1.4, 2.0, 2.8)

	_scene_tween = create_tween()
	_scene_tween.tween_method(_room.set_light_level, 0.12, 0.0, 4.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scene_tween.parallel().tween_method(_room.set_ball_glow, 0.55, 1.0, 4.5)
	_scene_tween.parallel().tween_property(_camera, "position",
		Vector3(2.2, 1.6, 2.0), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scene_tween.parallel().tween_property(_wind_player, "volume_db", -34.0, 5.0)
	_add_line(_scene_tween, "The Last Worker was gone.", 2.6)
	_add_line(_scene_tween, "But his final creation remained.", 3.0)
	_scene_tween.tween_callback(_show_title_card)

func _show_title_card() -> void:
	if _on_title_card:
		return
	_on_title_card = true
	if _scene_tween and _scene_tween.is_running():
		_scene_tween.kill()
	_subtitle.modulate.a = 0.0
	_clock_player.stop()

	# Skipping further isn't meaningful once the title card is already up —
	# only the way out (Main Menu) still makes sense here.
	var fade := create_tween()
	fade.tween_property(_skip_button, "modulate:a", 0.0, 0.3)
	fade.tween_callback(func() -> void: _skip_button.visible = false)

	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 1.4)
	tween.tween_callback(PlaceholderSFX.play_max_power)
	tween.tween_property(_title_year, "modulate:a", 1.0, 0.9)
	tween.tween_property(_title_main, "modulate:a", 1.0, 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_title_main, "scale", Vector2.ONE, 1.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.6)
	tween.tween_interval(4.5)
	tween.tween_callback(_go_to_title_screen)

func _go_to_title_screen() -> void:
	if _finished:
		return
	_finished = true
	get_tree().change_scene_to_file(TITLE_SCREEN)

# --- Helpers -----------------------------------------------------------

## Chains one subtitle line into `tween`: set text (+ voice cue), fade in,
## hold, fade out. worker=true styles it as the Worker speaking.
func _add_line(tween: Tween, text: String, hold: float, worker := false) -> void:
	tween.tween_callback(func() -> void:
		_subtitle.text = text
		_subtitle.add_theme_color_override("font_color",
			Color(1.0, 0.78, 0.5) if worker else Color(0.9, 0.92, 0.95))
		if worker:
			PlaceholderSFX.play_worker_blip()
		else:
			PlaceholderSFX.play_narrator_blip())
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.6)
	tween.tween_interval(hold)
	tween.tween_property(_subtitle, "modulate:a", 0.0, 0.5)

func _spawn_sparks(at: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 28
	sparks.lifetime = 0.7
	sparks.explosiveness = 0.95
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.6
	sparks.gravity = Vector3(0, -6, 0)
	sparks.scale_amount_min = 0.015
	sparks.scale_amount_max = 0.04
	sparks.color = Color(1.0, 0.8, 0.4)
	sparks.mesh = SphereMesh.new()
	add_child(sparks)
	sparks.position = at
	sparks.emitting = true
	get_tree().create_timer(2.0).timeout.connect(sparks.queue_free)

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.015, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.55)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_room = RoomScene.new()
	add_child(_room)
	_worker = WorkerScene.new()
	add_child(_worker)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.position = Vector3(7.0, 5.2, 6.5)
	_camera.current = true

func _build_overlay_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	var font: FontFile = load("res://assets/fonts/Orbitron.ttf")

	_subtitle = Label.new()
	_subtitle.modulate.a = 0.0
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 0.8
	_subtitle.anchor_bottom = 0.88
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_subtitle)

	_title_year = Label.new()
	_title_year.text = "YEAR 2147"
	_title_year.modulate.a = 0.0
	_title_year.anchor_left = 0.0
	_title_year.anchor_right = 1.0
	_title_year.anchor_top = 0.34
	_title_year.anchor_bottom = 0.4
	_title_year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_title_year.add_theme_font_override("font", font)
	_title_year.add_theme_font_size_override("font_size", 22)
	_title_year.add_theme_color_override("font_color", Color(0.25, 0.85, 0.9))
	layer.add_child(_title_year)

	_title_main = Label.new()
	_title_main.text = "FINAL KICK"
	_title_main.modulate.a = 0.0
	_title_main.scale = Vector2(0.92, 0.92)
	_title_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_main.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font:
		_title_main.add_theme_font_override("font", font)
	_title_main.add_theme_font_size_override("font_size", 84)
	_title_main.add_theme_color_override("font_color", Color(0.961, 0.651, 0.137))
	layer.add_child(_title_main)
	_title_main.pivot_offset = get_viewport().get_visible_rect().size / 2.0

	_prompt = Label.new()
	_prompt.text = "PRESS ANY KEY"
	_prompt.modulate.a = 0.0
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.78
	_prompt.anchor_bottom = 0.82
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_prompt.add_theme_font_override("font", font)
	_prompt.add_theme_font_size_override("font_size", 15)
	_prompt.add_theme_color_override("font_color", Color(0.25, 0.85, 0.9))
	layer.add_child(_prompt)

## Two always-available exits from the cinematic, since "press any key"
## alone isn't discoverable: SKIP jumps straight to the title card (same as
## the first key press already did), MAIN MENU bails out to the title
## screen entirely. Both fade in after a beat so the opening black frame
## isn't cluttered with UI before anything's happened.
func _build_skip_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 51  # above the story overlay/title layer
	add_child(layer)

	var font: FontFile = load("res://assets/fonts/Orbitron.ttf")

	_skip_button = CutCornerButtonScript.new()
	_skip_button.text = "SKIP  ▸▸"
	_skip_button.accent_color = Color(0.25, 0.85, 0.9)
	_skip_button.pressed.connect(_show_title_card)
	layer.add_child(_skip_button)
	_style_skip_button(_skip_button, font, Vector2(-172, -56))

	_menu_button = CutCornerButtonScript.new()
	_menu_button.text = "MAIN MENU"
	_menu_button.accent_color = Color(0.961, 0.651, 0.137)
	_menu_button.pressed.connect(_go_to_title_screen)
	layer.add_child(_menu_button)
	_style_skip_button(_menu_button, font, Vector2(-172, -100))

	for b in [_skip_button, _menu_button]:
		b.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(b, "modulate:a", 1.0, 0.8).set_delay(1.0)

func _style_skip_button(b: Button, font: FontFile, offset: Vector2) -> void:
	b.custom_minimum_size = Vector2(150, 40)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = offset.x
	b.offset_right = offset.x + 150.0
	b.offset_top = offset.y
	b.offset_bottom = offset.y + 40.0
	if font:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(0.04, 0.05, 0.09))

func _start_ambience() -> void:
	_wind_player = AudioStreamPlayer.new()
	_wind_player.stream = PlaceholderSFX.wind_loop()
	_wind_player.volume_db = -18.0
	add_child(_wind_player)
	_wind_player.play()

	_clock_player = AudioStreamPlayer.new()
	_clock_player.stream = PlaceholderSFX.clock_tick_loop()
	_clock_player.volume_db = -16.0
	add_child(_clock_player)
	_clock_player.play()
