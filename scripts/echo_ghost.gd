extends RigidBody3D
class_name EchoGhost
## Level 9 (Echo Kick). Plays back a previously recorded Ball history array
## in real time, as a frozen/kinematic duplicate body — so a past attempt
## can "run again" in parallel with a new live one. Physically present (not
## just a visual), so it can still trigger GridNodes/Vials along its path.
## See echo_kick_station.gd for how a run gets banked into one of these.

@export var ghost_material: Material

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _frames: Array[Dictionary] = []
var _frame_index: int = 0

func _ready() -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 4
	if ghost_material and _mesh:
		_mesh.material_override = ghost_material

## Begins replaying `frames` (a copy of Ball.history) from the top, one frame
## per physics tick — matches the rate they were originally recorded at.
func start(frames: Array[Dictionary]) -> void:
	_frames = frames
	_frame_index = 0
	if not _frames.is_empty():
		var first: Dictionary = _frames[0]
		global_transform = Transform3D(first["rotation"], first["position"])

func _physics_process(_delta: float) -> void:
	if _frame_index >= _frames.size():
		queue_free()
		return
	var frame: Dictionary = _frames[_frame_index]
	global_transform = Transform3D(frame["rotation"], frame["position"])
	_frame_index += 1
