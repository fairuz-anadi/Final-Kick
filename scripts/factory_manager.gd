extends Node
## Autoload ("FactoryManager"). Global "Factory Energy" system — the game's
## emotional throughline: the factory starts dead (0%) and every completed
## objective pumps energy back into it, visibly and audibly waking the room.
##
## Energy is per-level (done/total objectives), applied live to the current
## scene's WorldEnvironment + DirectionalLight3D, the procedural dressing
## (FactoryDressing, spawned here at level start), and the music layers
## (AudioDirector.set_energy).
##
## Wiring, all runtime: HUD._ready calls start_level(); HUD.on_progress
## calls register_progress(done, total); WinConditionDetector calls
## on_machine_activated(node) for the per-machine wake-up flourish.

signal energy_changed(pct: float)

const FactoryDressingScript := preload("res://scripts/factory_dressing.gd")

## Environment interpolation: DEAD (energy 0) → ALIVE (energy 100).
## Industrial palette (per Samprity): cool steel-blue when asleep, warming
## toward amber as the machines wake — the arc from cold to alive IS the
## lighting story.
const DEAD := {
	"ambient_energy": 0.3, "ambient_color": Color(0.3, 0.38, 0.52),
	"glow_intensity": 0.4, "glow_bloom": 0.05,
	"fog_color": Color(0.05, 0.06, 0.09), "sun_energy": 0.45,
	"sun_color": Color(0.85, 0.9, 1.0),
	"bg_color": Color(0.045, 0.052, 0.068),
}
const ALIVE := {
	"ambient_energy": 1.05, "ambient_color": Color(0.62, 0.55, 0.45),
	"glow_intensity": 0.9, "glow_bloom": 0.22,
	"fog_color": Color(0.16, 0.12, 0.07), "sun_energy": 1.0,
	"sun_color": Color(1.0, 0.93, 0.82),
	"bg_color": Color(0.09, 0.085, 0.08),
}

## Later levels start slightly brighter — the factory remembers every room
## already woken, so the world visibly heals across the whole game.
const LEVEL_BASE_BRIGHTNESS := {
	"res://scenes/levels/level_1.tscn": 0.0,
	"res://scenes/levels/level_2.tscn": 0.06,
	"res://scenes/levels/level_3.tscn": 0.12,
	"res://scenes/levels/level_4.tscn": 0.18,
	"res://scenes/levels/level_5.tscn": 0.24,
}

## What the player has earned: 100 * machines awakened / total machines.
var progress_pct: float = 0.0
## Accumulated penalty from lost balls (LifeManager.drain_energy). Persists
## for the level, so recovery comes from waking more machines, not waiting.
var drain: float = 0.0
## The one number everything reads: progress minus drain, floored at 0.
var energy: float = 0.0

var _environment: Environment
var _sun: DirectionalLight3D
var _dressing: Node3D
var _env_tween: Tween
var _base_brightness: float = 0.0

## Called by the HUD when a level starts: grab the scene's environment
## handles, drop the room to the DEAD state, and spawn the dressing.
func start_level() -> void:
	energy = 0.0
	progress_pct = 0.0
	drain = 0.0
	var scene := get_tree().current_scene
	if scene == null:
		return
	_base_brightness = LEVEL_BASE_BRIGHTNESS.get(scene.scene_file_path, 0.0)

	_environment = null
	_sun = null
	var world_env: WorldEnvironment = _find_first(scene, "WorldEnvironment")
	if world_env:
		_environment = world_env.environment
	_sun = _find_first(scene, "DirectionalLight3D")

	if _environment:
		# Soft volumetric fog so the accent lights get visible shafts —
		# subtle, tuned to read as dusty air rather than smoke.
		_environment.volumetric_fog_enabled = true
		_environment.volumetric_fog_density = 0.022
		_environment.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)

	_dressing = FactoryDressingScript.new()
	scene.add_child.call_deferred(_dressing)

	_apply_energy_to_environment(0.0)
	AudioDirector.set_energy(0.0)
	energy_changed.emit(0.0)

## Objective progress in the current level → global factory energy.
func register_progress(done: int, total: int) -> void:
	if total <= 0:
		return
	progress_pct = 100.0 * done / float(total)
	_recompute_energy()

## Lost ball penalty (see LifeManager): eats into earned energy. The world
## visibly dims back down with it — losses have to *feel* like losses.
func drain_energy(amount: float) -> void:
	drain += amount
	_recompute_energy()

func _recompute_energy() -> void:
	var new_energy := clampf(progress_pct - drain, 0.0, 100.0)
	if is_equal_approx(new_energy, energy):
		return
	var rising := new_energy > energy
	energy = new_energy
	_tween_environment(energy)
	if _dressing and is_instance_valid(_dressing):
		_dressing.set_energy(energy)
	AudioDirector.set_energy(energy)
	energy_changed.emit(energy)
	if rising:
		LifeManager.on_energy_recovered()

## Per-machine wake-up flourish: warm light bloom + rising spark burst +
## startup rumble at the machine that just came back to life.
func on_machine_activated(machine: Node3D) -> void:
	if machine == null or not machine.is_inside_tree():
		return
	PlaceholderSFX.play_machine_start(machine)
	_spawn_activation_light(machine)
	_spawn_activation_particles(machine)

func _spawn_activation_light(machine: Node3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.35)  # warm "power returning" orange
	light.omni_range = 7.0
	light.light_energy = 0.0
	machine.get_tree().current_scene.add_child(light)
	light.global_position = machine.global_position + Vector3.UP * 1.2

	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 5.0, 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Settles to a soft permanent glow instead of vanishing — an activated
	# machine stays visibly alive for the rest of the level.
	tween.tween_property(light, "light_energy", 0.9, 1.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _spawn_activation_particles(machine: Node3D) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 40
	particles.lifetime = 1.1
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0, -3.5, 0)
	particles.scale_amount_min = 0.03
	particles.scale_amount_max = 0.09
	particles.color = Color(1.0, 0.75, 0.3)
	particles.mesh = SphereMesh.new()
	(particles.mesh as SphereMesh).radius = 0.5
	(particles.mesh as SphereMesh).height = 1.0

	machine.get_tree().current_scene.add_child(particles)
	particles.global_position = machine.global_position + Vector3.UP * 0.5
	particles.emitting = true
	machine.get_tree().create_timer(2.5).timeout.connect(particles.queue_free)

func _tween_environment(pct: float) -> void:
	if _env_tween and _env_tween.is_running():
		_env_tween.kill()
	_env_tween = create_tween()
	_env_tween.tween_method(_apply_energy_to_environment,
		_last_applied, pct, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

var _last_applied: float = 0.0

func _apply_energy_to_environment(pct: float) -> void:
	_last_applied = pct
	# Later levels never drop all the way to fully-dead; the factory
	# remembers the rooms already woken.
	var t := clampf(pct / 100.0 + _base_brightness, 0.0, 1.0)
	if _environment:
		_environment.ambient_light_energy = lerpf(DEAD.ambient_energy, ALIVE.ambient_energy, t)
		_environment.ambient_light_color = DEAD.ambient_color.lerp(ALIVE.ambient_color, t)
		_environment.glow_intensity = lerpf(DEAD.glow_intensity, ALIVE.glow_intensity, t)
		_environment.glow_bloom = lerpf(DEAD.glow_bloom, ALIVE.glow_bloom, t)
		_environment.fog_light_color = DEAD.fog_color.lerp(ALIVE.fog_color, t)
		_environment.background_color = DEAD.bg_color.lerp(ALIVE.bg_color, t)
	if _sun and is_instance_valid(_sun):
		_sun.light_energy = lerpf(DEAD.sun_energy, ALIVE.sun_energy, t)
		_sun.light_color = DEAD.sun_color.lerp(ALIVE.sun_color, t)

func _find_first(root: Node, type_name: String) -> Variant:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found: Variant = _find_first(child, type_name)
		if found:
			return found
	return null
