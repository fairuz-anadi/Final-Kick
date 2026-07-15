extends Node3D
class_name WorkshopRoom
## The Last Worker's workshop, built from primitives — one room, two jobs:
## the opening cinematic (worker alive, machine running, ball on the desk)
## and the ending (empty chair, his goggles and lantern, a note that says
## "Thank you."). Both scripts drive it through the small API below:
##
## - set_light_level(0..1): 0 = dead dark, 1 = warm and lived-in.
## - clock_speed: minute-hand radians/sec (cranked up for time passing).
## - set_ball_glow(0..1), set_ring_visible(bool): the ball prop waking up.
## - set_machine_alive(bool): the big machine's screen + status lights.
## - add_memorial(): ending-only props (note, resting goggles).

const CONCRETE := preload("res://assets/materials/concrete.tres")
const DARK_METAL := preload("res://assets/materials/dark_metal.tres")

var clock_speed: float = 0.0

var _clock_minute: Node3D
var _clock_hour: Node3D
var _lamp_light: OmniLight3D
var _lantern_light: OmniLight3D
var _machine_screen_mat: StandardMaterial3D
var _machine_light_mats: Array[StandardMaterial3D] = []
var _ball_mesh: MeshInstance3D
var _ball_mat: StandardMaterial3D
var _ball_ring: MeshInstance3D
var _ball_glow_light: OmniLight3D

func _ready() -> void:
	_build_shell()
	_build_machine()
	_build_desk_corner()
	_build_bed()
	_build_clutter()
	_build_dust()
	set_light_level(1.0)
	set_ball_glow(0.0)
	set_ring_visible(false)

func _process(delta: float) -> void:
	if _clock_minute:
		_clock_minute.rotation.z -= clock_speed * delta
		_clock_hour.rotation.z -= clock_speed * delta / 12.0

## 0 = the decades-dead dark; 1 = the warm workshop while he lived.
func set_light_level(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	_lamp_light.light_energy = lerpf(0.02, 1.6, t)
	_lantern_light.light_energy = lerpf(0.0, 0.9, t)

func set_machine_alive(alive: bool) -> void:
	_machine_screen_mat.emission_energy_multiplier = 1.8 if alive else 0.05
	for mat in _machine_light_mats:
		mat.emission_energy_multiplier = 2.2 if alive else 0.05

func set_ball_glow(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	_ball_mat.emission_energy_multiplier = lerpf(0.05, 3.2, t)
	_ball_glow_light.light_energy = lerpf(0.0, 2.4, t)

func set_ring_visible(ring_visible: bool) -> void:
	_ball_ring.visible = ring_visible

## Ending: the ball isn't here anymore — it's out in the factory, being
## the player.
func set_ball_visible(ball_visible: bool) -> void:
	_ball_mesh.visible = ball_visible
	_ball_ring.visible = ball_visible and _ball_ring.visible
	if not ball_visible:
		_ball_glow_light.light_energy = 0.0

## Where the cinematic should stand the worker / park the camera.
func machine_spot() -> Vector3: return Vector3(-1.6, 0, -2.4)
func desk_spot() -> Vector3: return Vector3(2.2, 0, -1.9)
func chair_spot() -> Vector3: return Vector3(3.1, 0, -0.9)
func ball_position() -> Vector3: return Vector3(2.2, 1.06, -2.6)

## Ending-only: the room he left behind.
func add_memorial() -> void:
	# His goggles, set down on the desk for the last time.
	for x in [2.62, 2.74]:
		var lens := MeshInstance3D.new()
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.055
		lens_mesh.bottom_radius = 0.055
		lens_mesh.height = 0.04
		lens.mesh = lens_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.8, 0.85)
		mat.metallic = 0.6
		mat.roughness = 0.25
		lens.material_override = mat
		add_child(lens)
		lens.position = Vector3(x, 1.03, -2.15)

	var note := Label3D.new()
	note.text = "Thank you."
	note.font_size = 42
	note.pixel_size = 0.004
	note.modulate = Color(0.95, 0.9, 0.8)
	note.rotation.x = -PI / 2.0
	add_child(note)
	# Lying flat on the desk, angled slightly like it was set down by hand.
	note.position = Vector3(1.75, 1.021, -2.2)
	note.rotate_y(0.18)

	# A paper backing so the text reads as a note, not floating letters.
	var paper := MeshInstance3D.new()
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(0.5, 0.008, 0.32)
	paper.mesh = paper_mesh
	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.9, 0.87, 0.78)
	paper_mat.roughness = 1.0
	paper.material_override = paper_mat
	add_child(paper)
	paper.position = Vector3(1.75, 1.012, -2.2)
	paper.rotation.y = 0.18

# --- Builders ----------------------------------------------------------

func _flat(color: Color, rough := 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat

func _emissive(color: Color, energy := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 1.0).darkened(0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	inst.position = pos
	return inst

func _cylinder(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	add_child(inst)
	inst.position = pos
	return inst

func _build_shell() -> void:
	_box(Vector3(12, 0.3, 10), Vector3(0, -0.15, 0), CONCRETE)      # floor
	_box(Vector3(12, 4, 0.3), Vector3(0, 2, -4.85), CONCRETE)       # back wall
	_box(Vector3(0.3, 4, 10), Vector3(-5.85, 2, 0), CONCRETE)       # left wall

	# Warm ceiling lamp: shade + light. The room's main light source.
	_cylinder(0.4, 0.18, Vector3(0.5, 3.1, -1.2), _flat(Color(0.15, 0.15, 0.17)))
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = Color(1.0, 0.85, 0.6)
	_lamp_light.omni_range = 9.0
	_lamp_light.shadow_enabled = true
	add_child(_lamp_light)
	_lamp_light.position = Vector3(0.5, 2.95, -1.2)

	# Wall clock: face + hands (spun by clock_speed) + 12 o'clock tick.
	var face := _cylinder(0.42, 0.05, Vector3(-2.8, 2.5, -4.65), _flat(Color(0.85, 0.83, 0.78)))
	face.rotation.x = PI / 2.0
	_box(Vector3(0.05, 0.1, 0.03), Vector3(-2.8, 2.82, -4.6), _flat(Color(0.2, 0.2, 0.22)))
	_clock_minute = Node3D.new()
	add_child(_clock_minute)
	_clock_minute.position = Vector3(-2.8, 2.5, -4.6)
	_box(Vector3(0.035, 0.34, 0.02), Vector3(0, 0.17, 0), _flat(Color(0.15, 0.15, 0.17)), _clock_minute)
	_clock_hour = Node3D.new()
	add_child(_clock_hour)
	_clock_hour.position = Vector3(-2.8, 2.5, -4.59)
	_box(Vector3(0.045, 0.22, 0.02), Vector3(0, 0.11, 0), _flat(Color(0.15, 0.15, 0.17)), _clock_hour)

	# Pipes along the back wall + hanging cables, same language as the levels.
	for pipe_y in [3.3, 3.55]:
		var pipe := _cylinder(0.09, 11.0, Vector3(0, pipe_y, -4.6), DARK_METAL)
		pipe.rotation.z = PI / 2.0
	var cable_mat := _flat(Color(0.08, 0.08, 0.1), 0.95)
	for i in 5:
		var x := lerpf(-4.5, 4.5, i / 4.0)
		var cable := _cylinder(0.02, randf_range(0.5, 1.0), Vector3(x, 3.4, -4.4), cable_mat)
		cable.rotation.x = randf_range(-0.1, 0.1)

func _build_machine() -> void:
	# The giant machine he spent his life maintaining: stacked mass against
	# the back wall with a screen and a strip of status lights.
	var body := _flat(Color(0.18, 0.2, 0.24), 0.6)
	_box(Vector3(3.2, 2.6, 1.2), Vector3(-2.2, 1.3, -4.1), body)
	_box(Vector3(1.4, 3.4, 1.0), Vector3(-4.4, 1.7, -4.2), body)
	_box(Vector3(0.8, 0.5, 0.9), Vector3(-2.2, 2.9, -4.15), body)
	for duct_x in [-3.2, -1.2]:
		_cylinder(0.14, 1.2, Vector3(duct_x, 3.2, -4.2), DARK_METAL)

	_machine_screen_mat = _emissive(Color(0.3, 0.85, 0.9), 0.05)
	_box(Vector3(1.1, 0.7, 0.06), Vector3(-2.2, 1.7, -3.46), _machine_screen_mat)

	for i in 4:
		var mat := _emissive(Color(1.0, 0.62, 0.22), 0.05)
		_machine_light_mats.append(mat)
		_box(Vector3(0.12, 0.12, 0.05), Vector3(-3.4 + i * 0.35, 0.9, -3.48), mat)

func _build_desk_corner() -> void:
	var wood := _flat(Color(0.35, 0.26, 0.18))
	_box(Vector3(2.4, 0.08, 1.1), Vector3(2.2, 1.0, -2.3), wood)          # desktop
	for leg_offset in [Vector2(-1.05, -0.45), Vector2(1.05, -0.45), Vector2(-1.05, 0.45), Vector2(1.05, 0.45)]:
		_box(Vector3(0.09, 1.0, 0.09), Vector3(2.2 + leg_offset.x, 0.5, -2.3 + leg_offset.y), wood)

	# Blueprints: pale cyan sheets, slightly skewed like they're in use.
	for sheet in [Vector3(1.6, 1.05, -2.3), Vector3(2.05, 1.05, -2.05)]:
		var paper := _box(Vector3(0.55, 0.01, 0.4), sheet, _flat(Color(0.62, 0.78, 0.85)))
		paper.rotation.y = randf_range(-0.3, 0.3)

	# His lantern on the desk corner — a tiny warm light of its own.
	_cylinder(0.09, 0.22, Vector3(3.05, 1.15, -2.55), _flat(Color(0.25, 0.2, 0.12)))
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.75, 0.4)
	_lantern_light.omni_range = 3.0
	add_child(_lantern_light)
	_lantern_light.position = Vector3(3.05, 1.25, -2.55)

	# The chair he'll rest in.
	var chair_mat := _flat(Color(0.22, 0.18, 0.14))
	_box(Vector3(0.55, 0.08, 0.55), Vector3(3.1, 0.5, -0.9), chair_mat)
	_box(Vector3(0.55, 0.7, 0.08), Vector3(3.1, 0.85, -1.2), chair_mat)
	for chair_leg in [Vector2(-0.22, -0.22), Vector2(0.22, -0.22), Vector2(-0.22, 0.22), Vector2(0.22, 0.22)]:
		_box(Vector3(0.06, 0.5, 0.06), Vector3(3.1 + chair_leg.x, 0.25, -0.9 + chair_leg.y), chair_mat)

	# The ball, resting on the desk: same sphere + strap ring as the player.
	_ball_mat = _emissive(Color(1.0, 0.72, 0.35), 0.05)
	_ball_mesh = MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.16
	ball_mesh.height = 0.32
	_ball_mesh.mesh = ball_mesh
	_ball_mesh.material_override = _ball_mat
	add_child(_ball_mesh)
	_ball_mesh.position = ball_position()

	_ball_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.17
	ring_mesh.outer_radius = 0.2
	_ball_ring.mesh = ring_mesh
	_ball_ring.material_override = _emissive(Color(0.3, 0.85, 0.9), 1.4)
	add_child(_ball_ring)
	_ball_ring.position = ball_position()

	_ball_glow_light = OmniLight3D.new()
	_ball_glow_light.light_color = Color(1.0, 0.72, 0.35)
	_ball_glow_light.omni_range = 4.0
	_ball_glow_light.light_energy = 0.0
	add_child(_ball_glow_light)
	_ball_glow_light.position = ball_position() + Vector3.UP * 0.2

func _build_bed() -> void:
	# The medical bed in the corner — the quiet detail that says he lived
	# (and was ill) here. Left neat.
	var frame := _flat(Color(0.5, 0.52, 0.56), 0.5)
	_box(Vector3(0.9, 0.35, 2.0), Vector3(-4.9, 0.35, 2.6), frame)
	_box(Vector3(0.86, 0.12, 1.96), Vector3(-4.9, 0.58, 2.6), _flat(Color(0.88, 0.9, 0.92)))
	_box(Vector3(0.7, 0.1, 0.4), Vector3(-4.9, 0.68, 1.85), _flat(Color(0.95, 0.95, 0.97)))

func _build_clutter() -> void:
	# Crates, a barrel, a toolbox — a workshop, not a showroom.
	var crate := _flat(Color(0.4, 0.32, 0.22))
	_box(Vector3(0.7, 0.7, 0.7), Vector3(-0.6, 0.35, 3.4), crate)
	_box(Vector3(0.55, 0.55, 0.55), Vector3(0.25, 0.28, 3.6), crate)
	_box(Vector3(0.55, 0.4, 0.55), Vector3(-0.55, 1.05, 3.45), crate)
	_cylinder(0.32, 0.8, Vector3(4.6, 0.4, -3.9), _flat(Color(0.55, 0.25, 0.15), 0.6))
	var toolbox := _flat(Color(0.7, 0.2, 0.15), 0.5)
	_box(Vector3(0.5, 0.25, 0.28), Vector3(1.1, 1.09, -2.55), toolbox)
	_box(Vector3(0.04, 0.12, 0.04), Vector3(1.1, 1.28, -2.55), _flat(Color(0.2, 0.2, 0.22)))

func _build_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(5.5, 1.6, 4.5)
	process.gravity = Vector3(0, -0.02, 0)
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.06
	dust.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.008
	mesh.height = 0.016
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.92, 0.85, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	dust.draw_pass_1 = mesh
	add_child(dust)
	dust.position = Vector3(0, 1.8, 0)
