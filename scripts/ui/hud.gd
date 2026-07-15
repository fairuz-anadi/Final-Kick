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
const COLOR_OVERCHARGE := Color(0.996, 0.541, 0.176)  # hot amber — between HIGHLIGHT and BURST, reads as "risky power" not "ready"

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
@onready var _hearts_box: HBoxContainer = %Hearts
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _energy_label: Label = %EnergyLabel

const COLOR_ENERGY := Color(0.25, 0.85, 0.9)  # cyan — factory energy accent
const COLOR_HEART := Color(1.0, 0.42, 0.45)
const COLOR_HEART_LOST := Color(0.28, 0.32, 0.42, 0.55)

## Milestone flavor under the energy bar — sells "the factory is waking up".
const ENERGY_MOODS := [
	[0.0, "SILENT"], [1.0, "STIRRING"], [40.0, "WARMING UP"],
	[70.0, "COMING ALIVE"], [99.9, "FULLY AWAKE"],
]

var _heart_icons: Array[HeartIcon] = []
var _shown_lives: int = 0
var _shown_energy: float = 0.0
var _danger_vignette: TextureRect  # red edges at 1 heart, built lazily
var _charge_stage: int = 0  # 0 none / 1 ≥40% / 2 ≥80% / 3 max-or-burst

## Vector-drawn heart (two lobes + point). Drawn in code because the "♥"
## glyph isn't guaranteed to exist in the project/default fonts — a tofu
## box at the top of the screen would be worse than no heart at all.
class HeartIcon extends Control:
	var color := Color.WHITE:
		set(value):
			color = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(22, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := custom_minimum_size.x
		var r := w * 0.25
		var left_center := Vector2(r, r)
		var right_center := Vector2(w - r, r)
		draw_circle(left_center, r, color)
		draw_circle(right_center, r, color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left_center.x - r, left_center.y + r * 0.35),
			Vector2(right_center.x + r, right_center.y + r * 0.35),
			Vector2(w * 0.5, w * 0.82),
		]), color)

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

	# The HUD is the one node guaranteed to exist in every level, so it's
	# where the per-level singletons get their "a level just started" call.
	_build_hearts()
	LifeManager.lives_changed.connect(_on_lives_changed)
	LifeManager.start_level()
	FactoryManager.energy_changed.connect(_on_energy_changed)
	# Deferred: get_tree().current_scene isn't assigned yet while the new
	# scene's _ready callbacks are still running during a scene change.
	FactoryManager.start_level.call_deferred()
	if owner and owner.scene_file_path:
		NarratorManager.play_level_intro(owner.scene_file_path)
	_animate_panels_in()

## Panels drift down into place on level start — small, but it makes the UI
## feel alive instead of stamped on.
func _animate_panels_in() -> void:
	var delay := 0.0
	for panel_name in ["TopLeftPanel", "TopCenterPanel", "TopRightPanel"]:
		var panel: Control = get_node_or_null(NodePath(panel_name))
		if panel == null:
			continue
		var rest_y := panel.position.y
		panel.modulate.a = 0.0
		panel.position.y = rest_y - 16.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, 0.45).set_delay(delay)
		tween.tween_property(panel, "position:y", rest_y, 0.45) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
		delay += 0.12

func _exit_tree() -> void:
	if LifeManager.lives_changed.is_connected(_on_lives_changed):
		LifeManager.lives_changed.disconnect(_on_lives_changed)
	if FactoryManager.energy_changed.is_connected(_on_energy_changed):
		FactoryManager.energy_changed.disconnect(_on_energy_changed)

# --- Hearts (life system) ---

func _build_hearts() -> void:
	_shown_lives = LifeManager.MAX_LIVES
	for i in LifeManager.MAX_LIVES:
		var heart := HeartIcon.new()
		heart.color = COLOR_HEART
		_hearts_box.add_child(heart)
		_heart_icons.append(heart)

func _on_lives_changed(lives: int, _max_lives: int) -> void:
	for i in _heart_icons.size():
		if i < lives:
			_heart_icons[i].color = COLOR_HEART
			_heart_icons[i].scale = Vector2.ONE
	# Animate only on loss (not the initial refill): the dying heart pops,
	# flashes hot, then settles into its hollow "spent" state.
	if lives < _shown_lives:
		for i in range(lives, mini(_shown_lives, _heart_icons.size())):
			_break_heart(_heart_icons[i])
		if lives == 1:
			notify("LAST LIFE", COLOR_WARNING)
	_shown_lives = lives
	_set_danger_vignette(lives == 1)

## One heart left: red creeps in from the screen edges and breathes with
## the heartbeat until the level restarts or resets.
func _set_danger_vignette(active: bool) -> void:
	if not active:
		if _danger_vignette:
			_danger_vignette.visible = false
		return
	if _danger_vignette == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.8, 0.1, 0.1, 0.0))  # clear center
		gradient.set_color(1, Color(0.8, 0.1, 0.1, 0.45))  # red edges
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		_danger_vignette = TextureRect.new()
		_danger_vignette.texture = texture
		_danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_danger_vignette.stretch_mode = TextureRect.STRETCH_SCALE
		_danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_danger_vignette)
		move_child(_danger_vignette, 2)  # above overlays, below the panels
	_danger_vignette.visible = true

func _break_heart(heart: HeartIcon) -> void:
	heart.pivot_offset = heart.custom_minimum_size / 2.0
	var tween := create_tween()
	tween.tween_property(heart, "scale", Vector2(1.6, 1.6), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(heart, "color", Color(1.0, 0.15, 0.15), 0.12)
	tween.tween_property(heart, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(heart, "color", COLOR_HEART_LOST, 0.3)

# --- Factory energy ---

func _on_energy_changed(pct: float) -> void:
	var tween := create_tween()
	tween.tween_property(_energy_bar, "value", pct, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_energy_label.text = "%d%%  —  %s" % [int(pct), _energy_mood(pct)]
	_energy_label.add_theme_color_override("font_color",
		COLOR_ENERGY if pct > 0.0 else COLOR_MUTED)
	if pct > _shown_energy:
		# Slight delay so this floats in after the TARGET ACTIVATED line
		# instead of stacking on top of it.
		var gained := pct - _shown_energy
		get_tree().create_timer(0.7).timeout.connect(
			func() -> void: notify("+ FACTORY ENERGY  +%d%%" % roundi(gained), COLOR_ENERGY))
	_shown_energy = pct

func _energy_mood(pct: float) -> String:
	var mood: String = ENERGY_MOODS[0][1]
	for entry in ENERGY_MOODS:
		if pct >= entry[0]:
			mood = entry[1]
	return mood

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

	# Danger vignette breathes in time with the heartbeat loop (~1 Hz).
	if _danger_vignette and _danger_vignette.visible:
		_danger_vignette.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.0063)

	if scrubbing != _was_scrubbing:
		_was_scrubbing = scrubbing
		_rewind_overlay.visible = scrubbing
		if _ball_mesh and ghost_material:
			_ball_mesh.material_override = ghost_material if scrubbing else null
		if scrubbing:
			rewinds_used += 1
			_rewinds_label.text = "REWINDS   %d" % rewinds_used
			notify("TIME REWIND", COLOR_REWIND)
			PlaceholderSFX.play_rewind()

func _update_charge() -> void:
	_charge_box.visible = _ball.charging
	if not _ball.charging:
		_charge_stage = 0
		return
	var ratio: float = _ball.charge_ratio
	_charge_bar.value = ratio * 100.0

	# Audible stage ticks as the charge crosses the same thresholds the
	# bar's colors use — power you can hear without looking down.
	var stage := 0
	if ratio >= 0.995 or _ball.burst_armed:
		stage = 3
	elif ratio >= 0.8:
		stage = 2
	elif ratio >= 0.4:
		stage = 1
	if stage > _charge_stage:
		PlaceholderSFX.play_charge_tick(stage)
	_charge_stage = stage

	# Art direction: white -> orange at 40% -> deep red at 80%; glow at MAX only.
	var state_color := COLOR_TEXT
	if ratio >= 0.8:
		state_color = COLOR_WARNING
	elif ratio >= 0.4:
		state_color = COLOR_HIGHLIGHT
	var at_max := ratio >= 0.995
	var burst_armed: bool = _ball.burst_armed
	var overcharge_ratio: float = _ball.overcharge_ratio if "overcharge_ratio" in _ball else 0.0
	var overcharging := overcharge_ratio > 0.0 and not burst_armed
	if burst_armed:
		state_color = COLOR_BURST
	elif overcharging:
		state_color = COLOR_OVERCHARGE
	var glowing := at_max or burst_armed or overcharging
	var fill := _charge_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		fill.bg_color = state_color
		fill.shadow_color = Color(state_color, 0.5 if glowing else 0.0)
		fill.shadow_size = 6 if glowing else 0

	if burst_armed:
		_power_label.text = "FINAL KICK READY"
		_power_label.modulate = Color(COLOR_BURST, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.025))
	elif overcharging:
		# Wobble is the cost of this power, so the label leans into that
		# instead of reading as a clean "more power" upgrade like MAX POWER.
		_power_label.text = "OVERCHARGE — AIM UNSTABLE"
		_power_label.modulate = Color(COLOR_OVERCHARGE, 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.03))
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
		notify("+ MACHINE AWAKENED   %d / %d" % [done, total], COLOR_SUCCESS)
		PlaceholderSFX.play_target_ding()
	targets_done = done
	targets_total = total
	_targets_label.text = "MACHINES   %d / %d" % [done, total]
	FactoryManager.register_progress(done, total)
	if total > 0 and done == total:
		_timer_running = false
		if owner and owner.scene_file_path:
			NarratorManager.play_level_complete(owner.scene_file_path)

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
	# Dim, don't fully hide: this is the only on-screen mention that ESC
	# pauses/restarts/quits. Fading it to nothing meant that reminder
	# vanished completely a few seconds into every level.
	tween.tween_property(_tutorial_hint, "modulate:a", 0.3, 1.2)
