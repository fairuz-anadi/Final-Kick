extends Node3D
class_name LastWorker
## The Last Worker — the game's only human, built from Godot primitives in
## the same blocky diorama style as everything else in the project (no
## external assets). Used by the opening cinematic; the ending shows only
## what he left behind.
##
## Features driven by the cinematic script:
## - set_pose("stand" / "repair" / "sit") — repair adds a gentle working
##   motion on the mechanical arm; sit folds him into a chair.
## - set_age(old) — young: brown hair, no beard. old: white hair + beard.
## - Subtle idle breathing runs always so he never reads as a statue.

const SKIN := Color(0.87, 0.72, 0.58)
const JACKET_ORANGE := Color(0.85, 0.45, 0.12)
const PANTS_NAVY := Color(0.12, 0.16, 0.24)
const HAIR_YOUNG := Color(0.32, 0.22, 0.14)
const HAIR_OLD := Color(0.92, 0.92, 0.9)
const METAL_ARM := Color(0.55, 0.58, 0.62)

var _pose := "stand"
var _time := 0.0

var _torso: Node3D
var _head_pivot: Node3D
var _left_arm_pivot: Node3D
var _right_arm_pivot: Node3D   # the mechanical one
var _left_leg_pivot: Node3D
var _right_leg_pivot: Node3D
var _hair_mat: StandardMaterial3D
var _beard: MeshInstance3D

func _ready() -> void:
	_build()
	set_age(true)

func _process(delta: float) -> void:
	_time += delta
	# Idle breathing: barely-visible torso rise/fall.
	if _torso:
		_torso.position.y = 0.78 + sin(_time * 1.6) * 0.008
	# Repair pose: the mechanical arm works at something, head watching it.
	if _pose == "repair" and _right_arm_pivot:
		_right_arm_pivot.rotation.x = -1.9 + sin(_time * 3.2) * 0.22
		_head_pivot.rotation.x = -0.18 + sin(_time * 3.2) * 0.03

func set_pose(pose: String) -> void:
	_pose = pose
	match pose:
		"stand":
			_left_arm_pivot.rotation = Vector3.ZERO
			_right_arm_pivot.rotation = Vector3.ZERO
			_left_leg_pivot.rotation = Vector3.ZERO
			_right_leg_pivot.rotation = Vector3.ZERO
			_head_pivot.rotation = Vector3.ZERO
			position.y = 0.0
		"repair":
			_left_arm_pivot.rotation = Vector3(-0.4, 0, 0)
			_right_arm_pivot.rotation = Vector3(-1.9, 0, 0)
			_left_leg_pivot.rotation = Vector3.ZERO
			_right_leg_pivot.rotation = Vector3.ZERO
			position.y = 0.0
		"sit":
			# Legs fold mostly forward (not a full right angle, so the feet
			# still reach toward the floor); the body rises to seat height.
			_left_leg_pivot.rotation = Vector3(-1.2, 0, 0)
			_right_leg_pivot.rotation = Vector3(-1.2, 0, 0)
			_left_arm_pivot.rotation = Vector3(-0.5, 0, 0)
			_right_arm_pivot.rotation = Vector3(-0.5, 0, 0)
			_head_pivot.rotation = Vector3(0.12, 0, 0)  # chin dips, at rest
			position.y = 0.06

## old=false gives the flashback look (brown hair, no beard) for the
## "time passing" beat; old=true is his real, final self.
func set_age(old: bool) -> void:
	_hair_mat.albedo_color = HAIR_OLD if old else HAIR_YOUNG
	_beard.visible = old

# --- Construction ------------------------------------------------------

func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	inst.position = pos
	return inst

func _build() -> void:
	var skin := _flat(SKIN)
	var jacket := _flat(JACKET_ORANGE)
	var pants := _flat(PANTS_NAVY)
	var metal := _flat(METAL_ARM)
	metal.metallic = 0.8
	metal.roughness = 0.4
	_hair_mat = _flat(HAIR_OLD)

	# Legs hang from hip pivots so "sit" can fold them forward.
	_left_leg_pivot = _pivot(Vector3(-0.12, 0.5, 0))
	_box(_left_leg_pivot, Vector3(0.16, 0.5, 0.16), Vector3(0, -0.25, 0), pants)
	_right_leg_pivot = _pivot(Vector3(0.12, 0.5, 0))
	_box(_right_leg_pivot, Vector3(0.16, 0.5, 0.16), Vector3(0, -0.25, 0), pants)

	_torso = _pivot(Vector3(0, 0.78, 0))
	_box(_torso, Vector3(0.46, 0.56, 0.26), Vector3.ZERO, jacket)
	# Utility belt with a brass buckle.
	_box(_torso, Vector3(0.48, 0.07, 0.28), Vector3(0, -0.26, 0), _flat(Color(0.16, 0.13, 0.1)))
	_box(_torso, Vector3(0.08, 0.05, 0.03), Vector3(0, -0.26, 0.15), _flat(Color(0.72, 0.55, 0.25)))

	# Left arm: human. Right arm: mechanical (his story in one glance).
	_left_arm_pivot = _pivot(Vector3(-0.31, 1.0, 0))
	_box(_left_arm_pivot, Vector3(0.13, 0.46, 0.13), Vector3(0, -0.23, 0), jacket)
	_box(_left_arm_pivot, Vector3(0.11, 0.1, 0.11), Vector3(0, -0.5, 0), skin)
	_right_arm_pivot = _pivot(Vector3(0.31, 1.0, 0))
	_box(_right_arm_pivot, Vector3(0.13, 0.44, 0.13), Vector3(0, -0.22, 0), metal)
	var joint := MeshInstance3D.new()
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = 0.085
	joint_mesh.height = 0.17
	joint.mesh = joint_mesh
	joint.material_override = metal
	_right_arm_pivot.add_child(joint)
	joint.position = Vector3(0, -0.46, 0)

	# Head on its own pivot so poses can tilt it.
	_head_pivot = _pivot(Vector3(0, 1.14, 0))
	_box(_head_pivot, Vector3(0.3, 0.3, 0.28), Vector3(0, 0.16, 0), skin)
	# Hair cap + back, beard, goggles resting on the forehead.
	_box(_head_pivot, Vector3(0.32, 0.09, 0.3), Vector3(0, 0.33, -0.01), _hair_mat)
	_box(_head_pivot, Vector3(0.32, 0.2, 0.06), Vector3(0, 0.2, -0.14), _hair_mat)
	_beard = _box(_head_pivot, Vector3(0.26, 0.12, 0.05), Vector3(0, 0.03, 0.14), _hair_mat)
	var goggle_band := _flat(Color(0.2, 0.2, 0.22))
	_box(_head_pivot, Vector3(0.32, 0.05, 0.3), Vector3(0, 0.27, 0), goggle_band)
	for x in [-0.07, 0.07]:
		var lens := MeshInstance3D.new()
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.05
		lens_mesh.bottom_radius = 0.05
		lens_mesh.height = 0.03
		lens.mesh = lens_mesh
		var lens_mat := _flat(Color(0.5, 0.8, 0.85))
		lens_mat.metallic = 0.6
		lens_mat.roughness = 0.2
		lens.material_override = lens_mat
		_head_pivot.add_child(lens)
		lens.position = Vector3(x, 0.27, 0.15)
		lens.rotation.x = PI / 2.0

func _pivot(at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = at
	return pivot
