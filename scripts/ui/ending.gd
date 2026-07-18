extends Node3D
## Ending sequence. The factory is awake — and the camera goes back to the
## one room the player never saw during play: the Last Worker's workshop,
## warm now, machine humming, chair empty. His goggles and a note on the
## desk: "Thank you."
##
## Narration plays over a slow pan toward the desk, then the credits panel
## fades in. Any input skips ahead to the credits.

const BEATS := [
	{"text": "Listen.", "hold": 2.0},
	{"text": "Do you hear it?", "hold": 2.2},
	{"text": "That's life.", "hold": 3.0},
	{"text": "People thought this place was dead.", "hold": 2.6},
	{"text": "They were wrong.", "hold": 2.4},
	{"text": "It was only waiting.", "hold": 2.4},
	{"text": "Waiting for one final kick.", "hold": 3.4},
]

const RoomScene := preload("res://scripts/cinematic/workshop_room.gd")

var _room: WorkshopRoom
var _camera: Camera3D
var _cam_focus := Vector3(2.2, 1.0, -2.0)

var _subtitle: Label
var _credits_panel: PanelContainer

var _beat_index := -1
var _revealed := false
var _beat_tween: Tween

func _ready() -> void:
	# The whole point of the ending: every layer of the score, all at once.
	AudioDirector.set_energy(100.0)
	LifeManager.leave_level()
	_build_world()
	_build_ui()
	_start_camera_pan()
	_next_beat()

func _process(_delta: float) -> void:
	_camera.look_at(_cam_focus)

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed and not _revealed:
		_reveal_credits()

func _next_beat() -> void:
	_beat_index += 1
	if _beat_index >= BEATS.size():
		_reveal_credits()
		return
	var beat: Dictionary = BEATS[_beat_index]
	_subtitle.text = beat.text
	PlaceholderSFX.play_narrator_blip()
	_beat_tween = create_tween()
	_beat_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.6)
	_beat_tween.tween_interval(beat.hold)
	_beat_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.5)
	_beat_tween.tween_callback(_next_beat)

func _start_camera_pan() -> void:
	# One long, unhurried glide from the room's wide view down to the desk —
	# ends close enough to read the note.
	_camera.position = Vector3(7.5, 5.0, 7.0)
	var tween := create_tween()
	tween.tween_property(_camera, "position", Vector3(3.4, 2.0, 0.8), 14.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_method(_set_focus,
		_cam_focus, Vector3(1.95, 1.05, -2.2), 14.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", Vector3(2.6, 1.6, -0.6), 8.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_focus(focus: Vector3) -> void:
	_cam_focus = focus

func _reveal_credits() -> void:
	if _revealed:
		return
	_revealed = true
	if _beat_tween and _beat_tween.is_running():
		_beat_tween.kill()
	_subtitle.modulate.a = 0.0
	_credits_panel.visible = true
	_credits_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_credits_panel, "modulate:a", 1.0, 1.0)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

# --- Construction ------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.55, 0.45)  # the ALIVE warmth
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.15
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	_room = RoomScene.new()
	add_child(_room)  # add_child runs the room's _ready synchronously
	# The room as he left it — but alive: machine on, clock still keeping
	# time, ball long gone, his note and goggles where his hands were.
	_room.set_light_level(0.85)
	_room.set_machine_alive(true)
	_room.set_ball_visible(false)
	_room.clock_speed = 0.02
	_room.add_memorial()

	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Subtle screen-vision overlay (vignette + scanlines, no visible gradient
	# tint) so the ending reads through the same "HUD vision" language as the
	# other menus, without hiding the 3D workshop room behind it.
	var vision := ColorRect.new()
	var vision_material := ShaderMaterial.new()
	vision_material.shader = load("res://assets/shaders/gradient_vision.gdshader")
	vision_material.set_shader_parameter("opacity", 0.35)
	vision_material.set_shader_parameter("vignette_amount", 0.5)
	vision_material.set_shader_parameter("scanline_amount", 0.05)
	vision.material = vision_material
	vision.set_anchors_preset(Control.PRESET_FULL_RECT)
	vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vision)

	var font: FontFile = load("res://assets/fonts/BubblegumSans-Regular.ttf")

	_subtitle = Label.new()
	_subtitle.modulate.a = 0.0
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 0.8
	_subtitle.anchor_bottom = 0.88
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_subtitle)

	# Credits: navy glass panel, revealed after the narration.
	_credits_panel = PanelContainer.new()
	_credits_panel.visible = false
	_credits_panel.anchor_left = 0.5
	_credits_panel.anchor_right = 0.5
	_credits_panel.anchor_top = 0.5
	_credits_panel.anchor_bottom = 0.5
	_credits_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_credits_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.075, 0.145, 0.88)
	style.border_color = Color(0.22, 0.78, 0.84, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 44.0
	style.content_margin_right = 44.0
	style.content_margin_top = 30.0
	style.content_margin_bottom = 30.0
	_credits_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_credits_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_credits_panel.add_child(vbox)

	var title := Label.new()
	title.text = "THE FACTORY BREATHES AGAIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.961, 0.651, 0.137))
	vbox.add_child(title)

	var body := Label.new()
	# The last line ties the ending directly back to the jam's own framing
	# of "Kickoff" ("the spark that sets an entire chain of events into
	# motion") — in the Worker's voice, not a slogan lifted verbatim.
	body.text = "He never saw it wake.\nBut every light in this factory is his.\nOne kick. And the whole factory followed."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", Color(0.82, 0.84, 0.87))
	vbox.add_child(body)

	var is_new_best: bool = ScoreManager.finish_run()

	var score_label := Label.new()
	score_label.text = "FINAL SCORE   %d" % ScoreManager.total_score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		score_label.add_theme_font_override("font", font)
	score_label.add_theme_font_size_override("font_size", 29)
	score_label.add_theme_color_override("font_color", Color(0.961, 0.651, 0.137))
	vbox.add_child(score_label)

	var best_label := Label.new()
	if font:
		best_label.add_theme_font_override("font", font)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.add_theme_font_size_override("font_size", 20)
	if is_new_best:
		best_label.text = "NEW BEST!"  # ASCII only — "★" is tofu in web exports
		best_label.add_theme_color_override("font_color", Color(0.24, 1.0, 0.65))
	else:
		best_label.text = "BEST   %d" % ScoreManager.best_score
		best_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.82))
	vbox.add_child(best_label)

	_build_leaderboard_status(vbox, font)

	var credits := Label.new()
	credits.text = "ANADI — SYSTEMS & PHYSICS\nRABIB — LEVEL DESIGN & SOUND\nSAMPRITY — ART, UI & SHADERS\n\nMADE WITH GODOT 4.7 FOR THE KICKOFF GAMEJAM"
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 18)
	credits.add_theme_color_override("font_color", Color(0.659, 0.678, 0.71))
	vbox.add_child(credits)

	var back := Button.new()
	back.text = "BACK TO TITLE"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

## Submits the run's final total_score to the local leaderboard under the
## name entered on the title screen's pre-Start prompt (Leaderboard.
## pending_name). Leaderboard.gd handles dedupe (one entry per username,
## best score kept) and the top-10 cap — no player interaction needed here.
func _build_leaderboard_status(vbox: VBoxContainer, font: FontFile) -> void:
	var status := Label.new()
	if font:
		status.add_theme_font_override("font", font)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 16)
	vbox.add_child(status)

	var player_name := Leaderboard.pending_name
	if player_name.is_empty():
		status.text = "NO NAME ENTERED — SCORE NOT SAVED TO LEADERBOARD"
		status.add_theme_color_override("font_color", Color(0.62, 0.68, 0.82))
		return

	var saved := Leaderboard.submit_score(player_name, ScoreManager.total_score)
	if saved:
		status.text = "SAVED TO LEADERBOARD AS \"%s\"" % player_name
		status.add_theme_color_override("font_color", Color(0.24, 1.0, 0.65))
	else:
		# Covers both false cases: didn't beat this name's saved entry, or the
		# board is full and this score didn't crack the top 10.
		status.text = "\"%s\" — DIDN'T MAKE THE LEADERBOARD THIS TIME" % player_name
		status.add_theme_color_override("font_color", Color(0.62, 0.68, 0.82))
