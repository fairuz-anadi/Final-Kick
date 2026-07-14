extends Area3D
class_name GridNode
## Reusable "electric grid/wire" trigger node. Attach to any wire/grid-shaped
## mesh with its own CollisionShape3D. Contact (or an external trigger() call)
## makes it flash briefly and sends a surge along `connected_nodes` — other
## GridNodes chained the same way gears mesh together (see gear.gd).
##
## To make something *different* react (a Vial exploding, a Gear spinning),
## don't hardcode that here — connect this node's `surged` signal to whatever
## public method that object exposes (e.g. Vial.detonate, Gear.apply_external_spin).
## That keeps this script from needing to know about any other object type.

signal surged(source: Node3D)

@export var connected_nodes: Array[NodePath] = []
@export var flash_color: Color = Color(1.0, 0.95, 0.4)  # bright "electric" flash
@export var flash_duration: float = 0.2
@export var retrigger_cooldown: float = 0.5  # ignore new contacts for this long after firing

var _base_material: StandardMaterial3D
var _cooldown_remaining: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Duplicate whatever material this node's mesh is using so flashing it
	# doesn't also flash every other greybox object sharing that resource.
	var mesh_instance := _find_mesh_instance()
	if mesh_instance:
		var mat := mesh_instance.get_active_material(0)
		_base_material = (mat.duplicate() if mat else StandardMaterial3D.new()) as StandardMaterial3D
		mesh_instance.material_override = _base_material

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta

func _find_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null

func _on_body_entered(body: Node3D) -> void:
	trigger(body)

# Public entry point: contact fires this automatically, but anything else
# (a script, another trigger type) can call it directly too.
func trigger(source: Node3D = null) -> void:
	if _cooldown_remaining > 0.0:
		return
	_fire(source if source else self, [self])

# Called by an upstream GridNode passing the surge along the chain.
func receive_surge(source: Node3D, visited: Array) -> void:
	if _cooldown_remaining > 0.0:
		return
	_fire(source, visited)

func _fire(source: Node3D, visited: Array) -> void:
	_cooldown_remaining = retrigger_cooldown
	_flash()
	surged.emit(source)
	for path in connected_nodes:
		var neighbor: Node = get_node_or_null(path)
		if neighbor == null or neighbor in visited or not neighbor.has_method("receive_surge"):
			continue
		visited.append(neighbor)
		neighbor.receive_surge(source, visited)

func _flash() -> void:
	if _base_material == null:
		return
	var original := _base_material.albedo_color
	_base_material.albedo_color = flash_color
	var tween := create_tween()
	tween.tween_property(_base_material, "albedo_color", original, flash_duration)
