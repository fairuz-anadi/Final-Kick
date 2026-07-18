extends CanvasLayer
## Gameplay HUD — neon arcade pass. Reads live state off the
## Ball's public vars and two additive signals (ball.kicked,
## detector.progress_changed); no gameplay behavior is touched.
##
## Palette (art direction, production plan): bg #0A0D16, cyan #00E5FF,
## pink #FF3D81, amber #FFB627 — bright, glowing, fun.

@export var level_name: String = "MACHINE HALL 01"
@export var objective: String = "Wake every machine"
@export var ball_path: NodePath
@export var ghost_material: Material

const FloatingTextScene := preload("res://scenes/ui/floating_text.tscn")

const COLOR_TEXT := Color(0.95, 0.97, 1.0)
const COLOR_MUTED := Color(0.62, 0.68, 0.82)
const COLOR_HIGHLIGHT := Color(1.0, 0.714, 0.153)   # amber #FFB627
const COLOR_WARNING := Color(1.0, 0.239, 0.506)     # hot pink #FF3D81
const COLOR_SUCCESS := Color(0.24, 1.0, 0.65)       # neon mint
const COLOR_REWIND := Color(0.30, 0.65, 1.0)        # electric blue
const COLOR_BURST := Color(0.71, 0.36, 1.0)         # violet — distinct from the pink MAX POWER state
const COLOR_OVERCHARGE := Color(1.0, 0.54, 0.17)    # hot amber — reads as "risky power" not "ready"
const COLOR_ENERGY := Color(0.0, 0.898, 1.0)        # electric cyan #00E5FF

## Chain popups escalate through the palette as the combo grows.
const CHAIN_COLORS := [COLOR_ENERGY, COLOR_HIGHLIGHT, COLOR_WARNING, COLOR_BURST]

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
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _energy_label: Label = %EnergyLabel
@onready var _view_front_button: Button = %FrontButton
@onready var _view_back_button: Button = %BackButton
@onready var _view_corner_left_button: Button = %CornerLeftButton
@onready var _view_corner_right_button: Button = %CornerRightButton

## Milestone flavor under the energy bar — sells "the factory is waking up".
const ENERGY_MOODS := [
	[0.0, "SILENT"], [1.0, "STIRRING"], [40.0, "WARMING UP"],
	[70.0, "COMING ALIVE"], [99.9, "FULLY AWAKE"],
]

var _shown_energy: float = 0.0
var _danger_vignette: TextureRect  # pink edges while power is critical, built lazily
var _danger_active := false
var _charge_stage: int = 0  # 0 none / 1 ≥40% / 2 ≥80% / 3 max-or-burst

var _ball_mesh: MeshInstance3D
var _camera_director: CameraDirector
var _was_scrubbing := false
var _elapsed := 0.0
var _timer_running := true
var _vignette_boost := 0.0

var kicks_used := 0
var rewinds_used := 0
var targets_done := 0
var targets_total := 0
var _burst_notified_this_kick := false

## Chain scoring: how many machines the current kick has woken so far.
## A new kick starts a new chain; ×2 and up get escalating popups.
var _chain_count := 0
var best_chain := 0

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

	var cam := get_viewport().get_camera_3d()
	if cam is CameraDirector:
		_camera_director = cam
	_view_front_button.pressed.connect(func() -> void: _set_view("front"))
	_view_back_button.pressed.connect(func() -> void: _set_view("back"))
	_view_corner_left_button.pressed.connect(func() -> void: _set_view("corner_left"))
	_view_corner_right_button.pressed.connect(func() -> void: _set_view("corner_right"))

	# The HUD is the one node guaranteed to exist in every level, so it's
	# where the per-level singletons get their "a level just started" call.
	LifeManager.energy_drained.connect(_on_energy_drained)
	LifeManager.power_critical.connect(_set_danger_vignette)
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
	# The three top panels live inside the TopRow HBoxContainer (so they can
	# never overlap, whatever the font/window does) — the row animates as one
	# unit, since a container would fight per-child position tweens.
	for panel_name in ["TopRow", "ViewBox", "RewindBox"]:
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
	if LifeManager.energy_drained.is_connected(_on_energy_drained):
		LifeManager.energy_drained.disconnect(_on_energy_drained)
	if LifeManager.power_critical.is_connected(_set_danger_vignette):
		LifeManager.power_critical.disconnect(_set_danger_vignette)
	if FactoryManager.energy_changed.is_connected(_on_energy_changed):
		FactoryManager.energy_changed.disconnect(_on_energy_changed)

# --- Energy drain (ball lost) ---

func _on_energy_drained(amount: float) -> void:
	if amount <= 0.0:
		# Ball lost before any progress — nothing to drain, just a nudge.
		notify("BALL LOST", COLOR_MUTED)
		return
	notify("POWER DRAINED  −%d%%" % roundi(amount), COLOR_WARNING, 30)
	_vignette_boost = 1.0
	_flash_energy_bar()

## The energy bar itself flinches pink for a beat, so the loss reads in the
## same place the player watches their progress.
func _flash_energy_bar() -> void:
	var fill := _energy_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		fill.bg_color = COLOR_WARNING
		fill.shadow_color = Color(COLOR_WARNING, 0.5)
		var tween := create_tween()
		tween.tween_interval(0.55)
		tween.tween_callback(func() -> void:
			fill.bg_color = COLOR_ENERGY
			fill.shadow_color = Color(COLOR_ENERGY, 0.35))

## Power critical: pink creeps in from the screen edges and breathes until
## energy recovers, the level restarts, or the factory blacks out.
func _set_danger_vignette(active: bool) -> void:
	_danger_active = active
	if not active:
		if _danger_vignette:
			_danger_vignette.visible = false
		return
	if _danger_vignette == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 0.24, 0.51, 0.0))  # clear center
		gradient.set_color(1, Color(1.0, 0.24, 0.51, 0.4))  # pink edges
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

	# Danger vignette breathes while power is critical (~1 Hz).
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

	# Art direction: cyan -> amber at 40% -> hot pink at 80%; glow at MAX only.
	var state_color := COLOR_ENERGY
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
		fill.shadow_color = Color(state_color, 0.6 if glowing else 0.25)
		fill.shadow_size = 8 if glowing else 3

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
		_rewind_gauge_label.text = "REWINDING"
		_rewind_gauge_label.modulate = Color(COLOR_REWIND, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012))
	elif frames < 10:
		# Barely any recorded history yet — rewinding now would do nothing.
		_rewind_gauge_label.text = "REWIND — CHARGING"
		_rewind_gauge_label.modulate = Color(COLOR_MUTED, 0.8)
	else:
		_rewind_gauge_label.text = "REWIND — READY"
		_rewind_gauge_label.modulate = Color(COLOR_MUTED, 1.0)

func _on_kicked(power_ratio: float) -> void:
	kicks_used += 1
	_chain_count = 0  # every kick starts a fresh chain
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
	notify("FINAL KICK!", COLOR_BURST, 34)
	_vignette_boost = 1.0

## Connect WinConditionDetector.progress_changed here (done in the level scene).
func on_progress(done: int, total: int) -> void:
	if done > targets_done and done > 0:
		_chain_count += done - targets_done
		best_chain = maxi(best_chain, _chain_count)
		notify("+ MACHINE AWAKENED   %d / %d" % [done, total], COLOR_SUCCESS)
		PlaceholderSFX.play_target_ding()
		if _chain_count >= 2:
			_notify_chain(_chain_count)
	targets_done = done
	targets_total = total
	_targets_label.text = "MACHINES   %d / %d" % [done, total]
	FactoryManager.register_progress(done, total)
	if total > 0 and done == total:
		_timer_running = false
		if owner and owner.scene_file_path:
			NarratorManager.play_level_complete(owner.scene_file_path)

## The star of the show: one kick waking several machines earns escalating
## CHAIN callouts — bigger, brighter, and pitched higher every step.
func _notify_chain(chain: int) -> void:
	var color: Color = CHAIN_COLORS[clampi(chain - 2, 0, CHAIN_COLORS.size() - 1)]
	var size: int = clampi(26 + chain * 4, 30, 52)
	# Slight delay so it lands after the MACHINE AWAKENED line, reading as
	# a reward on top rather than two lines fighting for the same spot.
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		notify("CHAIN  ×%d !" % chain, color, size)
		PlaceholderSFX.play_chain(chain))
	if chain >= 3:
		_vignette_boost = maxf(_vignette_boost, 0.7)

## Spawns floating feedback text near the upper third of the screen.
func notify(message: String, color: Color, font_size: int = 24) -> void:
	var floating := FloatingTextScene.instantiate()
	floating.setup(message, color, font_size)
	add_child(floating)
	var viewport_size := get_viewport().get_visible_rect().size
	floating.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.3)

func _set_view(view_name: String) -> void:
	if _camera_director:
		_camera_director.set_preset_view(view_name)

## Real run stats for the result screen.
func get_stats() -> Dictionary:
	return {
		"time": _elapsed,
		"kicks": kicks_used,
		"rewinds": rewinds_used,
		"targets_done": targets_done,
		"targets_total": targets_total,
		"best_chain": best_chain,
	}
