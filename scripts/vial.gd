extends Area3D
class_name Vial
## Reusable "explosive vial" component. Attach to any vial-shaped mesh with
## its own CollisionShape3D. Stays an Area3D (a trigger volume, not a solid
## body) so nothing gets stuck bouncing off it before it goes off.

signal activated  # fires once, right when this vial explodes — for win-condition tracking etc.

@export var force_threshold: float = 5.0    # min impact strength (mass * speed) needed to trigger
@export var explosion_radius: float = 3.0   # rigid bodies within this radius feel the blast
@export var explosion_impulse: float = 8.0  # impulse strength at the center; falls off linearly with distance

var _exploded: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _exploded or not (body is RigidBody3D):
		return
	var impact_strength: float = body.linear_velocity.length() * body.mass
	if impact_strength >= force_threshold:
		_explode()

# Public hook so other trigger types (e.g. a GridNode's `surged` signal) can
# set this off without needing a physical impact at all.
func detonate() -> void:
	if not _exploded:
		_explode()

# Generic alias matching the same trigger(source) shape as GridNode/Gear, so
# any of the three can be wired interchangeably without special-casing types.
func trigger(_source: Node3D = null) -> void:
	detonate()

func _explode() -> void:
	_exploded = true
	_apply_explosion_impulse()
	_spawn_placeholder_flash()
	activated.emit()
	# One-shot: hide/disable immediately so a lingering body can't retrigger
	# it, then free once the flash (parented to the scene, not the vial) is done.
	monitoring = false
	visible = false
	queue_free()

func _apply_explosion_impulse() -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	for result in space_state.intersect_shape(query, 32):
		var collider = result["collider"]
		if not (collider is RigidBody3D):
			continue
		var offset: Vector3 = collider.global_position - global_position
		var distance: float = offset.length()
		if distance < 0.001:
			continue
		var falloff: float = clamp(1.0 - (distance / explosion_radius), 0.0, 1.0)
		collider.apply_central_impulse(offset.normalized() * explosion_impulse * falloff)

func _spawn_placeholder_flash() -> void:
	# PLACEHOLDER visual effect: a plain white sphere that scales up and
	# fades out. Swap for real particles/VFX later — this only exists so the
	# explosion is visible at all.
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	flash.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = mat

	get_tree().current_scene.add_child(flash)
	flash.global_position = global_position

	var duration := 0.25
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * (explosion_radius / 0.3), duration)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)
