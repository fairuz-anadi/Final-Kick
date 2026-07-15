extends Vial
class_name LeakingVial
## Level 8 variant: destabilizes the longer it goes un-triggered, and
## detonates on its own once fully destabilized. Runs on real elapsed time,
## not the Ball's recorded history — rewinding the Ball doesn't undo this
## timer, so stalling to "solve safely" isn't free the way it is with every
## other trigger type in the game. The liquid shifts from its base color
## toward `warning_color` as a readable countdown.

# Fires if this vial destabilizes and detonates on its own, without ever
# being triggered — deliberately NOT the same as `activated` (which a
# WinConditionDetector listens for), so a leaked vial never counts as a win.
# See leak_failure_handler.gd for what happens next (the room reloads).
signal leaked

@export var destabilize_time: float = 8.0
@export var warning_color: Color = Color(1.0, 0.15, 0.1)

var _age: float = 0.0
var _liquid_material: StandardMaterial3D
var _base_liquid_color: Color

func _ready() -> void:
	super._ready()
	var liquid := get_node_or_null("Liquid") as MeshInstance3D
	if liquid:
		var mat: Material = liquid.get_active_material(0)
		# Duplicated so this vial destabilizing doesn't tint every other vial
		# sharing the same base green_liquid material resource.
		_liquid_material = (mat.duplicate() if mat else StandardMaterial3D.new()) as StandardMaterial3D
		liquid.material_override = _liquid_material
		_base_liquid_color = _liquid_material.albedo_color

func _process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if _liquid_material:
		var ratio: float = clamp(_age / destabilize_time, 0.0, 1.0)
		_liquid_material.albedo_color = _base_liquid_color.lerp(warning_color, ratio)
	if _age >= destabilize_time:
		_leak_out()

## Detonates without ever emitting `activated` — a deliberately worse outcome
## than landing a real hit, so leaving this too long is a real cost instead
## of a free pass (unlike a normal Vial, which doesn't care how it's set off).
func _leak_out() -> void:
	if _exploded:
		return
	_exploded = true
	_apply_explosion_impulse()
	_spawn_placeholder_flash()
	PlaceholderSFX.play_explosion(self)
	leaked.emit()
	monitoring = false
	visible = false
	queue_free()
