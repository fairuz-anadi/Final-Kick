extends Node2D
## Opening cinematic — the project's main scene. Six illustrated shots
## (Samprity's art in assets/cinematic/) played as a living storyboard:
## every shot has a slow camera move, and light behaves like light —
## the ball's glow breathes, the desk lamp flickers, fog drifts, dust
## floats. The final shot is built from separate layers (bench / ball /
## kid) so the camera gets real parallax.
##
##  1  The dead factory skyline. "There was a time..."
##  2  The empty workshop — bench, chair, the waiting ball.
##  3  A kid in the doorway.
##  4  Close-up: the note. "Wake them."
##  5  The ball in his hands.
##  6  Parallax: the kid at the bench, finishing what was started.
##  7  The ball's glow flashes out — straight into the title screen.
##
## The SKIP button (only) jumps straight to the title screen.

const TITLE_SCREEN := "res://scenes/ui/title_screen.tscn"
const NeonCutButtonScript := preload("res://scripts/ui/neon_cut_button.gd")

const ART := "res://assets/cinematic/"

const GLOW_CYAN := Color(0.35, 0.85, 1.0, 0.5)
const GLOW_WARM := Color(1.0, 0.72, 0.4, 0.5)
const GLOW_MOON := Color(0.75, 0.85, 1.0, 0.4)

# Layout of the parallax bench shot, tuned against the art.
const BENCH_BALL_NORM := Vector2(0.44, 0.55)   # on the tabletop, left of centre
const BENCH_KID_NORM := Vector2(0.71, 0.67)    # sitting at the right end
const BENCH_KID_HEIGHT := 0.62                 # kid height, fraction of screen
const BENCH_BALL_HEIGHT := 0.16                # ball height, fraction of screen

var _vs: Vector2

var _shot: Node2D
var _tweens: Array[Tween] = []
var _cam_tween: Tween        # the active shot's camera move — killed per shot

# Last camera state, so a window resize can re-frame immediately.
var _active_spr: Sprite2D
var _active_zoom := 1.0
var _active_focus := Vector2(0.5, 0.5)
var _bench_group: Node2D

var _overlay: ColorRect
var _flash: ColorRect
var _subtitle: Label
var _skip_button: Button

var _music_player: AudioStreamPlayer

var _pulse_glows: Array[Sprite2D] = []    # breathing machine-glow
var _flicker_glows: Array[Sprite2D] = []  # unsteady lamp light
var _fogs: Array[Sprite2D] = []           # drifting haze
var _kid: Sprite2D                        # breathes, in the bench shot

var _finished := false

func _ready() -> void:
	_vs = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_viewport_resized)
	_build_overlay_ui()
	_build_skip_ui()
	_start_ambience()
	_shot_1()

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for g in _pulse_glows:
		g.modulate.a = g.get_meta("base_a") \
			+ g.get_meta("amp") * sin(t * g.get_meta("speed") + g.get_meta("phase"))
	for g in _flicker_glows:
		var a: float = g.modulate.a + randf_range(-0.05, 0.05)
		g.modulate.a = clampf(lerpf(a, g.get_meta("base_a"), 0.1), 0.3, 1.0)
	for f in _fogs:
		f.position.x += f.get_meta("drift") * delta
		if absf(f.position.x - f.get_meta("home_x")) > f.get_meta("range"):
			f.set_meta("drift", -f.get_meta("drift"))
	if is_instance_valid(_kid):
		_kid.scale.y = _kid.get_meta("base_scale") * (1.0 + 0.006 * sin(t * 1.5))

## Skipping is via the dedicated SKIP button only (see _build_skip_ui) —
## deliberately NOT any key/click, so a stray input during the story (or
## someone just trying to move the mouse) doesn't cut it short by accident.

# --- The six shots -----------------------------------------------------

func _shot_1() -> void:
	var spr := _add_art("01_skyline.png")
	_animate_cam(spr, 9.5, 1.05, 1.17, Vector2(0.5, 0.5), Vector2(0.58, 0.44))
	_add_glow(spr, Vector2(0.305, 0.195), GLOW_MOON, 190.0, 0.45, 0.15, 0.5)
	_add_fog(spr, 0.86, 2)

	_overlay.modulate.a = 1.0
	var st := _tween()
	st.tween_property(_overlay, "modulate:a", 0.0, 2.4)
	_add_line(st, "There was a time... when the lights never went out.", 3.0)
	_add_line(st, "That was a long time ago...", 2.4)
	st.tween_interval(0.6)
	st.tween_callback(_shot_2)

func _shot_2() -> void:
	var spr := _add_art("02_workshop_empty.png")
	_animate_cam(spr, 10.0, 1.08, 1.2, Vector2(0.34, 0.56), Vector2(0.53, 0.5))
	_add_glow(spr, Vector2(0.525, 0.495), GLOW_CYAN, 150.0, 0.55, 0.2, 1.6)
	_add_glow(spr, Vector2(0.655, 0.23), GLOW_WARM, 170.0, 0.6, 0.0, 0.0, true)
	_add_dust(spr, Vector2(0.62, 0.4), Vector2(150, 130))

	var st := _tween()
	_add_line(st, "For decades, one worker kept the old machines company...", 3.2)
	_add_line(st, "Now — his chair sits empty.", 2.6)
	st.tween_interval(0.6)
	st.tween_callback(_shot_3)

func _shot_3() -> void:
	var spr := _add_art("03_doorway.png")
	_animate_cam(spr, 8.0, 1.12, 1.08, Vector2(0.58, 0.52), Vector2(0.32, 0.5))
	_add_glow(spr, Vector2(0.655, 0.52), GLOW_CYAN, 140.0, 0.55, 0.2, 1.6)
	_add_glow(spr, Vector2(0.795, 0.29), GLOW_WARM, 150.0, 0.55, 0.0, 0.0, true)
	_add_glow(spr, Vector2(0.215, 0.135), GLOW_MOON, 130.0, 0.4, 0.12, 0.5)

	var st := _tween()
	st.tween_interval(1.2)
	_add_line(st, "But... someone found the workshop.", 3.0)
	st.tween_interval(1.0)
	st.tween_callback(_shot_4)

func _shot_4() -> void:
	var spr := _add_art("04_note.png")
	_animate_cam(spr, 8.5, 1.03, 1.14, Vector2(0.54, 0.55), Vector2(0.56, 0.5))
	_add_glow(spr, Vector2(0.13, 0.4), GLOW_CYAN, 210.0, 0.5, 0.18, 1.6)

	var st := _tween()
	st.tween_interval(0.8)
	_add_line(st, "\"Wake them.\"", 2.8, true)
	_add_line(st, "That was all the note said...", 2.4)
	st.tween_interval(0.5)
	st.tween_callback(_shot_5)

func _shot_5() -> void:
	var spr := _add_art("05_hands_ball.png")
	_animate_cam(spr, 8.0, 1.04, 1.16, Vector2(0.55, 0.52), Vector2(0.565, 0.48))
	_add_glow(spr, Vector2(0.565, 0.5), GLOW_CYAN, 230.0, 0.6, 0.25, 2.0)

	var st := _tween()
	st.tween_interval(0.8)
	_add_line(st, "The old man's final invention — still glowing... still waiting...", 3.4)
	st.tween_interval(0.6)
	st.tween_callback(_shot_6)

func _shot_6() -> void:
	# Parallax: bench, ball and kid on separate layers, camera dollying
	# across. Nearer layers pan farther, so the flat art gains depth.
	_begin_shot()

	var group := Node2D.new()
	group.position = _vs * 0.5
	_shot.add_child(group)

	var bench := Sprite2D.new()
	bench.texture = load(ART + "06_bench_bg.png")
	var bts: Vector2 = bench.texture.get_size()
	var bscale := maxf(_vs.x / bts.x, _vs.y / bts.y) * 1.1
	bench.scale = Vector2(bscale, bscale)
	group.add_child(bench)
	_add_glow(bench, Vector2(0.545, 0.26), GLOW_WARM, 190.0, 0.6, 0.0, 0.0, true)
	_add_dust(bench, Vector2(0.53, 0.42), Vector2(160, 120))

	var ball := Sprite2D.new()
	ball.texture = load(ART + "ball_cutout.png")
	var ball_ts: Vector2 = ball.texture.get_size()
	var ball_scale := BENCH_BALL_HEIGHT * _vs.y / (0.68 * ball_ts.y)
	ball.scale = Vector2(ball_scale, ball_scale)
	group.add_child(ball)
	_add_glow(ball, Vector2(0.5, 0.49), GLOW_CYAN, 420.0, 0.5, 0.2, 1.6)

	_kid = Sprite2D.new()
	_kid.texture = load(ART + "kid_sitting.png")
	var kid_ts: Vector2 = _kid.texture.get_size()
	var kid_scale := BENCH_KID_HEIGHT * _vs.y / (0.88 * kid_ts.y)
	_kid.scale = Vector2(kid_scale, kid_scale)
	_kid.offset = -(Vector2(0.55, 0.52) - Vector2(0.5, 0.5)) * kid_ts
	_kid.set_meta("base_scale", kid_scale)
	group.add_child(_kid)

	var ball_base := (BENCH_BALL_NORM - Vector2(0.5, 0.5)) * bts * bscale
	var kid_base := (BENCH_KID_NORM - Vector2(0.5, 0.5)) * bts * bscale

	var cam := _tween()
	cam.tween_method(_bench_cam.bind(group, bench, ball, ball_base, kid_base),
		0.0, 1.0, 11.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween = cam
	_bench_group = group

	var st := _tween()
	st.tween_interval(1.0)
	_add_line(st, "So the kid took the old man's seat...", 3.0)
	_add_line(st, "...and finished what was started!", 3.0)
	st.tween_interval(0.8)
	st.tween_callback(_ignite)

## Camera drive for the parallax shot: one zoom + a dolly where nearer
## layers pan farther than the bench behind them.
func _bench_cam(t: float, group: Node2D, bench: Sprite2D, ball: Sprite2D,
		ball_base: Vector2, kid_base: Vector2) -> void:
	group.scale = Vector2.ONE * lerpf(1.03, 1.13, t)
	var pan := lerpf(30.0, -30.0, t)
	bench.position = Vector2(pan, 0)
	ball.position = ball_base + Vector2(pan * 1.2, 0)
	if is_instance_valid(_kid):
		_kid.position = kid_base + Vector2(pan * 1.5, 0)

## The ball's light swells into a flash, and the flash IS the cut:
## the title screen takes over at full white.
func _ignite() -> void:
	if _finished:
		return
	PlaceholderSFX.play_max_power()
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 1.0, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_go_to_title_screen)

func _go_to_title_screen() -> void:
	if _finished:
		return
	_finished = true
	get_tree().change_scene_to_file(TITLE_SCREEN)

# --- Shot machinery ----------------------------------------------------

func _tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw

## Crossfades from the previous shot to a fresh empty one. The outgoing
## shot's camera tween dies here — it must never outlive its sprite.
func _begin_shot() -> void:
	var old := _shot
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_active_spr = null
	_bench_group = null
	_pulse_glows.clear()
	_flicker_glows.clear()
	_fogs.clear()
	_kid = null
	_shot = Node2D.new()
	add_child(_shot)
	_shot.modulate.a = 0.0
	var fade := _tween()
	fade.tween_property(_shot, "modulate:a", 1.0, 0.9)
	if old:
		fade.parallel().tween_property(old, "modulate:a", 0.0, 0.9)
		fade.tween_callback(old.queue_free)

## Starts a new shot holding one full-frame illustration.
func _add_art(tex_name: String) -> Sprite2D:
	_begin_shot()
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = load(ART + tex_name)
	_shot.add_child(spr)
	return spr

## Frames `focus` (normalized image coords) at screen centre at `zoom`
## (1.0 = image just covers the viewport), clamped so edges never show.
func _apply_cam(spr: Sprite2D, zoom: float, focus: Vector2) -> void:
	var ts: Vector2 = spr.texture.get_size()
	var s := maxf(_vs.x / ts.x, _vs.y / ts.y) * zoom
	spr.scale = Vector2(s, s)
	var pos := _vs * 0.5 - focus * ts * s
	pos.x = clampf(pos.x, _vs.x - ts.x * s, 0.0)
	pos.y = clampf(pos.y, _vs.y - ts.y * s, 0.0)
	spr.position = pos
	_active_spr = spr
	_active_zoom = zoom
	_active_focus = focus

func _animate_cam(spr: Sprite2D, dur: float, z0: float, z1: float,
		f0: Vector2, f1: Vector2) -> void:
	_apply_cam(spr, z0, f0)
	var tw := _tween()
	tw.tween_method(_cam_step.bind(spr, z0, z1, f0, f1),
		0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween = tw

func _cam_step(t: float, spr: Sprite2D, z0: float, z1: float,
		f0: Vector2, f1: Vector2) -> void:
	if is_instance_valid(spr):
		_apply_cam(spr, lerpf(z0, z1, t), f0.lerp(f1, t))

## The window changed size (resize, maximise, fullscreen): re-measure and
## re-frame whatever is on screen right now.
func _on_viewport_resized() -> void:
	_vs = get_viewport_rect().size
	if is_instance_valid(_active_spr):
		_apply_cam(_active_spr, _active_zoom, _active_focus)
	if is_instance_valid(_bench_group):
		_bench_group.position = _vs * 0.5

# --- Light, haze and dust ----------------------------------------------

func _make_glow_tex(inner: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, Color(inner.r, inner.g, inner.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex

## Additive light blob glued to a point on `spr`'s image, so it rides the
## camera move. Pulsing (amp/speed) for machine glow, flicker=true for
## unsteady lamp light. `radius_px` is in image pixels.
func _add_glow(spr: Sprite2D, norm: Vector2, color: Color, radius_px: float,
		base_a: float, amp: float, speed: float, flicker := false) -> void:
	var ts: Vector2 = spr.texture.get_size()
	var glow := Sprite2D.new()
	glow.texture = _make_glow_tex(color)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.scale = Vector2.ONE * (radius_px / 128.0)
	glow.position = norm * ts - (ts * 0.5 if spr.centered else Vector2.ZERO)
	glow.modulate.a = base_a
	glow.set_meta("base_a", base_a)
	glow.set_meta("amp", amp)
	glow.set_meta("speed", speed)
	glow.set_meta("phase", randf() * TAU)
	spr.add_child(glow)
	if flicker:
		_flicker_glows.append(glow)
	else:
		_pulse_glows.append(glow)

## Soft haze blobs drifting slowly along the bottom of the frame.
func _add_fog(spr: Sprite2D, norm_y: float, count: int) -> void:
	var ts: Vector2 = spr.texture.get_size()
	for i in count:
		var fog := Sprite2D.new()
		fog.texture = _make_glow_tex(Color(0.55, 0.65, 0.85, 0.14))
		fog.scale = Vector2(6.5, 2.2)
		var x := ts.x * (0.25 + 0.5 * float(i) / maxf(count - 1, 1.0))
		fog.position = Vector2(x, ts.y * norm_y)
		fog.set_meta("home_x", x)
		fog.set_meta("range", ts.x * 0.06)
		fog.set_meta("drift", (12.0 if i % 2 == 0 else -9.0))
		spr.add_child(fog)
		_fogs.append(fog)

## Dust motes hanging in the light around `norm` (image coords).
func _add_dust(spr: Sprite2D, norm: Vector2, extents: Vector2) -> void:
	var ts: Vector2 = spr.texture.get_size()
	var dust := CPUParticles2D.new()
	dust.amount = 24
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = extents
	dust.direction = Vector2(0, -1)
	dust.spread = 30.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 9.0
	dust.scale_amount_min = 0.015
	dust.scale_amount_max = 0.045
	dust.color = Color(1.0, 0.95, 0.8, 0.4)
	dust.texture = _make_glow_tex(Color.WHITE)
	dust.position = norm * ts - (ts * 0.5 if spr.centered else Vector2.ZERO)
	spr.add_child(dust)

# --- Overlay UI (unchanged from the 3D version) ------------------------

## Chains one subtitle line into `tween`: set text, fade in, hold, fade out.
## worker=true styles it as the Worker speaking — and that one line keeps its
## voice cue; ordinary narration lines appear silently so the music carries
## the scene instead of a blip stamping every sentence.
func _add_line(tween: Tween, text: String, hold: float, worker := false) -> void:
	tween.tween_callback(func() -> void:
		_subtitle.text = text
		_subtitle.add_theme_color_override("font_color",
			Color(1.0, 0.78, 0.5) if worker else Color(0.9, 0.92, 0.95))
		if worker:
			PlaceholderSFX.play_worker_blip())
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.6)
	tween.tween_interval(hold)
	tween.tween_property(_subtitle, "modulate:a", 0.0, 0.5)

func _build_overlay_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var vignette := TextureRect.new()
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0))
	vg.set_color(1, Color(0, 0, 0, 0.5))
	vg.add_point(0.55, Color(0, 0, 0, 0.02))
	var vtex := GradientTexture2D.new()
	vtex.gradient = vg
	vtex.fill = GradientTexture2D.FILL_RADIAL
	vtex.fill_from = Vector2(0.5, 0.5)
	vtex.fill_to = Vector2(0.5, -0.1)
	vtex.width = 512
	vtex.height = 512
	vignette.texture = vtex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vignette)

	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.06
		else:
			bar.anchor_top = 0.94
			bar.anchor_bottom = 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bar)

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	_flash = ColorRect.new()
	_flash.color = Color(0.75, 0.95, 1.0)
	_flash.modulate.a = 0.0
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	var font: FontFile = load("res://assets/fonts/BubblegumSans-Regular.ttf")

	_subtitle = Label.new()
	_subtitle.modulate.a = 0.0
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 0.8
	_subtitle.anchor_bottom = 0.88
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		_subtitle.add_theme_font_override("font", font)
	_subtitle.add_theme_font_size_override("font_size", 29)
	_subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_subtitle)

## The one always-available exit from the cinematic — deliberately the ONLY
## way to skip (no "press any key"), so it's an explicit choice, not an
## accident. Same glowing cut-corner look as every other button in the game
## (title screen, difficulty/settings/instructions pages). Fades in after a
## beat so the opening black frame isn't cluttered with UI before anything's
## happened.
func _build_skip_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 51  # above the story overlay layer
	add_child(layer)

	var font: FontFile = load("res://assets/fonts/BubblegumSans-Regular.ttf")

	_skip_button = NeonCutButtonScript.new()
	# ASCII only — "▸" has no glyph in the bundled fonts, and web exports have
	# no system fonts to fall back to (it rendered as tofu boxes in Chrome).
	_skip_button.text = "SKIP  >>"
	# Colors, cut, font size and outline all match the title screen's
	# MAIN MENU/QUIT buttons exactly — one button language everywhere.
	_skip_button.accent_color = Color(0.95, 0.42, 0.88)
	_skip_button.fill_color = Color(0.2, 0.08, 0.24)
	_skip_button.glow_strength = 0.7
	_skip_button.pressed.connect(_go_to_title_screen)
	layer.add_child(_skip_button)
	_style_skip_button(_skip_button, font, Vector2(-190, -62))

	_skip_button.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_skip_button, "modulate:a", 1.0, 0.8).set_delay(1.0)

func _style_skip_button(b: Button, font: FontFile, offset: Vector2) -> void:
	b.custom_minimum_size = Vector2(168, 50)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = offset.x
	b.offset_right = offset.x + 168.0
	b.offset_top = offset.y
	b.offset_bottom = offset.y + 50.0
	if font:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 3)

func _start_ambience() -> void:
	# Real story track (replaces the old synthesized wind + clock ambience).
	# The procedural groove is suspended for the cinematic's whole run and
	# resumes automatically when the scene changes to the title screen.
	AudioDirector.suspend_music()
	tree_exiting.connect(AudioDirector.resume_music)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load("res://assets/audio/music/story.wav")
	_music_player.volume_db = -6.0
	_music_player.bus = "Music"
	add_child(_music_player)
	_music_player.play()
	# Loop by restarting on finish — works regardless of the wav's import
	# loop settings, in case the cinematic outlasts the track.
	_music_player.finished.connect(_music_player.play)
