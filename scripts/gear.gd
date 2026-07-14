extends RigidBody3D
class_name Gear
## Reusable "interlocking gear" component. Attach to any gear-shaped mesh
## (with its own CollisionShape3D) to make it spin from physical impacts and
## pass that spin along to gears wired up in `connected_gears`.
##
## The gear stays fixed in place — frozen + kinematic — so it never falls or
## gets pushed around; the only thing that ever changes is its own rotation.
##
## Emits `spun` whenever momentum is added (direct hit or via a connected
## gear), so something downstream (e.g. a GridNode) can react without this
## script needing to know what that is — connect the signal in the scene.

signal spun(source: Node3D)

@export var spin_axis: Vector3 = Vector3.UP  # local axis this gear spins around
@export var moment_of_inertia: float = 0.5   # resistance to spin-up; higher = harder to start spinning
@export var spin_damping: float = 0.6        # spin bleeds off at this rate (per second) so it settles
@export var min_impact_impulse: float = 0.5  # impacts weaker than this are ignored (filters resting-contact noise)
@export var external_trigger_spin: float = 3.0  # angular impulse used by trigger(), for non-physical activation

# Other Gear nodes physically meshed with this one. On any impact (direct or
# received), each connected gear gets driven the opposite way — like real teeth.
@export var connected_gears: Array[NodePath] = []

var _spin: float = 0.0  # current signed angular speed (rad/sec) around spin_axis

func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 8

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for i in state.get_contact_count():
		var impulse: Vector3 = state.get_contact_impulse(i)
		if impulse.length() < min_impact_impulse:
			continue
		var contact_offset: Vector3 = state.get_contact_local_position(i) - global_position
		_apply_impact(contact_offset, impulse)

func _physics_process(delta: float) -> void:
	if absf(_spin) > 0.001:
		rotate(spin_axis.normalized(), _spin * delta)
	_spin = lerp(_spin, 0.0, clamp(spin_damping * delta, 0.0, 1.0))

func _apply_impact(contact_offset: Vector3, impulse: Vector3) -> void:
	# Torque = r x J; only the component along our own spin axis matters, so
	# where you hit the gear (not just how hard) determines spin direction.
	var torque: Vector3 = contact_offset.cross(impulse)
	var angular_impulse: float = torque.dot(spin_axis.normalized())
	if absf(angular_impulse) < 0.001:
		return
	_receive_spin(angular_impulse, [self])

func receive_meshed_spin(angular_impulse: float, visited: Array) -> void:
	_receive_spin(angular_impulse, visited)

func apply_external_spin(angular_impulse: float) -> void:
	_receive_spin(angular_impulse, [self])

# Generic hook so other trigger types (e.g. a GridNode's `surged` signal) can
# spin this gear without a physical impact — matches the same trigger(source)
# shape as GridNode/Vial so any of the three can be wired interchangeably.
func trigger(_source: Node3D = null) -> void:
	apply_external_spin(external_trigger_spin)

func _receive_spin(angular_impulse: float, visited: Array) -> void:
	_spin += angular_impulse / moment_of_inertia
	spun.emit(self)
	for path in connected_gears:
		var neighbor: Node = get_node_or_null(path)
		if neighbor == null or not (neighbor is Gear) or neighbor in visited:
			continue
		visited.append(neighbor)
		# visited (not just "who sent this") guards against infinite loops if
		# gears are ever wired into a closed ring rather than a simple chain.
		(neighbor as Gear).receive_meshed_spin(-angular_impulse, visited)
