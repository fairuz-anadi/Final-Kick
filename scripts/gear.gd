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
##
## Also emits `activated` once, the moment cumulative rotation crosses
## `rotations_to_activate` — spin itself decays over time, so "has this gear
## fully spun" needs its own persistent one-shot state (e.g. for a
## win-condition detector), separate from the momentary `spun` event.

signal spun(source: Node3D)
signal activated

@export var spin_axis: Vector3 = Vector3.UP  # local axis this gear spins around
@export var moment_of_inertia: float = 0.5   # resistance to spin-up; higher = harder to start spinning
@export var spin_damping: float = 0.6        # spin bleeds off at this rate (per second) so it settles
@export var min_impact_impulse: float = 0.5  # impacts weaker than this are ignored (filters resting-contact noise)
@export var external_trigger_spin: float = 3.0  # angular impulse used by trigger(), for non-physical activation
@export var rotations_to_activate: float = 1.0  # cumulative full turns needed before `activated` fires

# Other Gear nodes physically meshed with this one. On any impact (direct or
# received), each connected gear gets driven the opposite way — like real teeth.
@export var connected_gears: Array[NodePath] = []

var _spin: float = 0.0  # current signed angular speed (rad/sec) around spin_axis
var _total_rotation: float = 0.0  # cumulative |rotation| in radians, for the activation threshold
var _is_activated: bool = false

# Hit audio is flagged here and played in _physics_process, never from inside
# _integrate_forces (spawning audio nodes mid-physics-callback isn't safe —
# same pattern as ball.gd). Direct ball hits get the full impulse-scaled
# clang; spin arriving via meshed neighbors or trigger() gets a soft rattle.
var _pending_hit_strength: float = 0.0
var _pending_mesh_sound: bool = false

# Progress feedback: activation needs a full turn of ACCUMULATED rotation,
# which is otherwise invisible — a gear at 70% looks identical to a cold one,
# so the player can't tell their hits are working. The gear's own material
# heats up with a warm emissive glow as _total_rotation approaches the
# threshold (duplicated per-gear, same pattern as GridNode's flash, so one
# gear glowing doesn't light up every mesh sharing the material).
var _glow_mesh: MeshInstance3D
var _glow_material: StandardMaterial3D

func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 8
	for child in get_children():
		if child is MeshInstance3D:
			_glow_mesh = child
			break
	if _glow_mesh:
		var mat: Material = _glow_mesh.get_active_material(0)
		# Only StandardMaterial3D gets the glow treatment; a gear with a
		# custom shader keeps it (and just skips this feedback).
		if mat is StandardMaterial3D or mat == null:
			_glow_material = (mat.duplicate() if mat else StandardMaterial3D.new()) as StandardMaterial3D
			_glow_material.emission = Color(1.0, 0.55, 0.2)  # warm "waking up" amber
			_glow_mesh.material_override = _glow_material

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	for i in state.get_contact_count():
		var impulse: Vector3 = state.get_contact_impulse(i)
		if impulse.length() < min_impact_impulse:
			continue
		var contact_offset: Vector3 = state.get_contact_local_position(i) - global_position
		_apply_impact(contact_offset, impulse)

func _physics_process(delta: float) -> void:
	if _pending_hit_strength > 0.0:
		PlaceholderSFX.play_gear_hit(self, _pending_hit_strength, activation_progress())
		_pending_hit_strength = 0.0
		_pending_mesh_sound = false  # the clang already covers this frame
	elif _pending_mesh_sound:
		PlaceholderSFX.play_gear_mesh(self)
		_pending_mesh_sound = false
	if absf(_spin) > 0.001:
		var step: float = _spin * delta
		rotate(spin_axis.normalized(), step)
		_total_rotation += absf(step)
		if not _is_activated and _total_rotation >= rotations_to_activate * TAU:
			_is_activated = true
			activated.emit()
	_spin = lerp(_spin, 0.0, clamp(spin_damping * delta, 0.0, 1.0))
	_update_progress_glow()

## 0 = cold, 1 = the cumulative-rotation threshold reached (or passed).
func activation_progress() -> float:
	if _is_activated:
		return 1.0
	return clampf(_total_rotation / (rotations_to_activate * TAU), 0.0, 1.0)

func _update_progress_glow() -> void:
	if _glow_material == null:
		return
	var p := activation_progress()
	# Base heat from accumulated progress, plus a live flicker while the gear
	# is actually turning — so each hit visibly "feeds" the glow, and an
	# awakened gear holds a steady warm burn.
	var energy: float = p * 0.85 + clampf(absf(_spin) * 0.06, 0.0, 0.35)
	_glow_material.emission_enabled = energy > 0.02
	_glow_material.emission_energy_multiplier = energy

func _apply_impact(contact_offset: Vector3, impulse: Vector3) -> void:
	# Torque = r x J; only the component along our own spin axis matters, so
	# where you hit the gear (not just how hard) determines spin direction.
	var torque: Vector3 = contact_offset.cross(impulse)
	var angular_impulse: float = torque.dot(spin_axis.normalized())
	if absf(angular_impulse) < 0.001:
		return
	_pending_hit_strength = maxf(_pending_hit_strength, impulse.length())
	_receive_spin(angular_impulse, [self])

func receive_meshed_spin(angular_impulse: float, visited: Array) -> void:
	_pending_mesh_sound = true
	_receive_spin(angular_impulse, visited)

func apply_external_spin(angular_impulse: float) -> void:
	_pending_mesh_sound = true
	_receive_spin(angular_impulse, [self])

# Generic hook so other trigger types (e.g. a GridNode's `surged` signal) can
# spin this gear without a physical impact — matches the same trigger(source)
# shape as GridNode/Vial so any of the three can be wired interchangeably.
func trigger(_source: Node3D = null) -> void:
	apply_external_spin(external_trigger_spin)

func _receive_spin(angular_impulse: float, visited: Array) -> void:
	_spin += angular_impulse / moment_of_inertia
	spun.emit(self)
	# Audio is NOT played here — see the _pending_* flags. This can run inside
	# _integrate_forces, and it also runs once per gear in a meshed chain, so
	# playing here meant N identical full-volume clinks per chain reaction.
	for path in connected_gears:
		var neighbor: Node = get_node_or_null(path)
		if neighbor == null or not (neighbor is Gear) or neighbor in visited:
			continue
		visited.append(neighbor)
		# visited (not just "who sent this") guards against infinite loops if
		# gears are ever wired into a closed ring rather than a simple chain.
		(neighbor as Gear).receive_meshed_spin(-angular_impulse, visited)
