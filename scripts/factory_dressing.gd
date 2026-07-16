extends Node3D
## Procedural laboratory dressing, spawned into every level at runtime by
## FactoryManager. Two jobs:
##
## 1. Architecture — a ceiling, concrete columns, steel girders, glowing
##    factory windows: turns the bare 20x20 box into a room with structure.
## 2. Laboratory set dressing — big green vats (with bubbling liquid), a
##    workbench with glassware, wall shelves of jars, a chalkboard, pipes,
##    cables, a wall fan, steam and dust: makes it read as the Last
##    Worker's lab, lived-in and specific.
##
## Pure visuals: nothing here has collision. Floor-standing props check
## _spot_free() against the level's actual machines so dressing never
## overlaps gameplay objects; everything else hugs the walls/ceiling.
## Anecdote props (scattered notes, the Worker's mug, chalkboard mid-
## thought, test tubes, posters) carry the story without a word of text.
##
## Everything reacts to set_energy(0..100): strips/vats brighten, lights
## ramp, fan spins, steam thickens. Industrial palette: cool steel and
## cyan asleep, warming amber + green lab glass as it wakes.

const ROOM_HALF := 9.7   # just inside the ±10 walls
const WALL_HEIGHT := 3.0     # the levels' real (colliding) wall height
## The visual room is taller than the gameplay walls: dressing extends the
## walls up to this ceiling height so the space feels like a hall, not a
## crawlspace. Nothing above WALL_HEIGHT has collision — the ball can't get
## there anyway (out-of-bounds catches anything that clears the real walls).
const CEILING_HEIGHT := 4.6

## Industrial palette: steel, concrete, cyan conduits, blue machinery
## light — with warm amber lamps and green lab glass as the living accents.
const WARM_ORANGE := Color(1.0, 0.62, 0.22)
const MACHINE_BLUE := Color(0.3, 0.65, 1.0)
const STRIP_CYAN := Color(0.25, 0.85, 0.9)
const CONCRETE_DARK := Color(0.14, 0.15, 0.18)
const STEEL_DARK := Color(0.13, 0.14, 0.17)
const WOOD_BENCH := Color(0.42, 0.28, 0.16)

var _energy: float = 0.0

var _strips: Array[StandardMaterial3D] = []
var _warm_lights: Array[OmniLight3D] = []
var _blue_lights: Array[OmniLight3D] = []
var _fan_blades: Node3D
var _warning_mats: Array[StandardMaterial3D] = []
var _warning_lights: Array[OmniLight3D] = []
var _steam_emitters: Array[GPUParticles3D] = []

var _fan_speed: float = 0.0
var _blink_time: float = 0.0

var _vat_liquids: Array[StandardMaterial3D] = []
var _vat_bubbles: Array[GPUParticles3D] = []
var _ceiling: MeshInstance3D
## Global XZ positions of the level's real physics objects (machines, crates,
## dominoes…) — floor-standing dressing keeps its distance from these.
var _occupied: Array[Vector3] = []

func _ready() -> void:
	_scan_occupied()
	_build_ceiling()
	_build_columns_and_beams()
	_build_windows()
	_build_lab_vats()
	_build_lab_bench()
	_build_shelves()
	_build_chalkboard()
	_build_anecdotes()
	_build_wall_strips()
	_build_accent_lights()
	_build_pipes()
	_build_hanging_cables()
	_build_fan()
	_build_warning_lights()
	_build_steam_vents()
	_build_dust()
	set_energy(0.0)

func set_energy(pct: float) -> void:
	_energy = clampf(pct / 100.0, 0.0, 1.0)
	var tween := create_tween().set_parallel(true)

	# Emissive strips: barely-visible standby glow → full neon lines.
	for mat in _strips:
		tween.tween_property(mat, "emission_energy_multiplier",
			lerpf(0.15, 2.6, _energy), 1.2)

	# Warm lights lead the wake-up; blue "machinery" lights trail behind it
	# (they need more of the factory online before they come back).
	for light in _warm_lights:
		tween.tween_property(light, "light_energy", lerpf(0.25, 2.2, _energy), 1.2)
	for light in _blue_lights:
		var blue_t: float = clampf((_energy - 0.3) / 0.7, 0.0, 1.0)
		tween.tween_property(light, "light_energy", lerpf(0.05, 1.6, blue_t), 1.2)

	# Steam mostly arrives in the 60%+ band (design: "60% — steam"),
	# with a faint idle wisp below so vents never look like set dressing.
	var steam_t: float = clampf((_energy - 0.5) / 0.5, 0.0, 1.0)
	for steam in _steam_emitters:
		tween.tween_property(steam, "amount_ratio", lerpf(0.1, 1.0, steam_t), 1.2)

	# Lab vats: the liquid glows brighter and bubbles harder as the factory
	# wakes — the chemistry is coming back to life along with the machines.
	for mat in _vat_liquids:
		tween.tween_property(mat, "emission_energy_multiplier",
			lerpf(0.5, 2.4, _energy), 1.2)
	var bubble_t: float = clampf((_energy - 0.15) / 0.85, 0.0, 1.0)
	for bubbles in _vat_bubbles:
		tween.tween_property(bubbles, "amount_ratio", lerpf(0.15, 1.0, bubble_t), 1.2)

func _process(delta: float) -> void:
	# The ceiling steps aside whenever the player orbits the camera above it,
	# so the top-down view looks INTO the room instead of at a lid.
	if _ceiling:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_ceiling.visible = cam.global_position.y < CEILING_HEIGHT - 0.2

	# Machinery motion is staged (design: "80% — moving machinery"): a lazy
	# idle turn once anything is powered, full spin in the 80%+ band.
	var machinery_t: float = clampf((_energy - 0.55) / 0.45, 0.0, 1.0)
	var idle_spin: float = 0.4 if _energy > 0.15 else 0.0
	_fan_speed = move_toward(_fan_speed, idle_spin + machinery_t * 4.0, delta * 0.8)
	if _fan_blades:
		_fan_blades.rotate_z(_fan_speed * delta)

	# Warning beacons blink once anything is powered; faster as energy rises.
	if _warning_mats.is_empty():
		return
	_blink_time += delta * (1.0 + _energy * 2.0)
	var on: bool = _energy > 0.01 and fmod(_blink_time, 1.2) < 0.6
	for mat in _warning_mats:
		mat.emission_energy_multiplier = 3.0 if on else 0.1
	for light in _warning_lights:
		light.light_energy = 1.2 if on else 0.0

# --- Builders ---------------------------------------------------------

## Record where the level's real physics objects stand so floor props can
## stay out of their way. Floors, walls, and the Ball itself don't count.
func _scan_occupied() -> void:
	var scene := get_parent()
	if scene == null:
		return
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node == self or not (node is PhysicsBody3D):
			continue
		var node_name := String(node.name)
		if node_name.begins_with("Floor") or node_name.contains("Wall") or node_name == "Ball":
			continue
		_occupied.append((node as Node3D).global_position)

func _spot_free(pos: Vector3, clearance: float) -> bool:
	for occupied_pos in _occupied:
		if Vector2(occupied_pos.x, occupied_pos.z).distance_to(Vector2(pos.x, pos.z)) < clearance:
			return false
	return true

## A ceiling closes the box so the camera never sees dead void above the
## walls — essential for the inside-the-room view. Shadow casting is OFF so
## the scene's DirectionalLight still lights the room exactly as before.
## Upper wall bands bridge the gap between the real 3m walls and the taller
## visual ceiling. _process hides the ceiling whenever the player orbits the
## camera above it, so the top-down view looks into the room, not at a lid.
func _build_ceiling() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.11, 0.14)
	mat.roughness = 0.9
	_ceiling = _add_box(
		Vector3(ROOM_HALF * 2.0 + 1.2, 0.12, ROOM_HALF * 2.0 + 1.2),
		Vector3(0, CEILING_HEIGHT + 0.06, 0), mat)
	_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Upper wall bands, matching the levels' concrete walls.
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.16, 0.175, 0.2)
	band.roughness = 0.95
	var band_height := CEILING_HEIGHT - WALL_HEIGHT
	var band_y := WALL_HEIGHT + band_height * 0.5
	for side in [-1.0, 1.0]:
		var upper := _add_box(Vector3(0.5, band_height, 20.6),
			Vector3(side * 10.0, band_y, 0), band)
		upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var back := _add_box(Vector3(20.6, band_height, 0.5),
		Vector3(0, band_y, -10.0), band)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Concrete pilasters along the walls + steel girders overhead — the single
## cheapest way to make a bare box read as a built room. Columns sit mostly
## inside the wall thickness so the ball never visibly clips them.
func _build_columns_and_beams() -> void:
	var column_mat := StandardMaterial3D.new()
	column_mat.albedo_color = CONCRETE_DARK
	column_mat.roughness = 0.95
	for z in [-5.0, 1.0, 7.0]:
		for side in [-1.0, 1.0]:
			_add_box(Vector3(0.45, CEILING_HEIGHT, 0.45),
				Vector3(side * 9.85, CEILING_HEIGHT * 0.5, z), column_mat)
	for x in [-6.5, 6.5]:
		_add_box(Vector3(0.45, CEILING_HEIGHT, 0.45),
			Vector3(x, CEILING_HEIGHT * 0.5, -9.85), column_mat)

	var girder := StandardMaterial3D.new()
	girder.albedo_color = STEEL_DARK
	girder.metallic = 0.6
	girder.roughness = 0.55
	for z in [-6.0, -2.0, 2.0, 6.0]:
		_add_box(Vector3(ROOM_HALF * 2.0, 0.22, 0.3),
			Vector3(0, CEILING_HEIGHT - 0.2, z), girder)

## Two pale glowing factory windows high on the back wall, each throwing a
## real volumetric light shaft into the room — the world outside exists.
## Does more against "claustrophobic box" than anything else here.
func _build_windows() -> void:
	var frame := StandardMaterial3D.new()
	frame.albedo_color = STEEL_DARK
	frame.metallic = 0.5
	frame.roughness = 0.6
	var glass := _emissive_material(Color(0.78, 0.88, 1.0), 1.5)
	for x in [-4.5, 4.5]:
		# Tall factory windows, running up into the raised ceiling space.
		_add_box(Vector3(1.5, 2.9, 0.05), Vector3(x, 2.55, -9.73), frame)
		_add_box(Vector3(1.3, 2.7, 0.06), Vector3(x, 2.55, -9.7), glass)
		# Mullions so it reads "window", not "glowing rectangle".
		_add_box(Vector3(0.08, 2.7, 0.08), Vector3(x, 2.55, -9.68), frame)
		_add_box(Vector3(1.3, 0.08, 0.08), Vector3(x, 1.9, -9.68), frame)
		_add_box(Vector3(1.3, 0.08, 0.08), Vector3(x, 3.2, -9.68), frame)

		var shaft := SpotLight3D.new()
		shaft.light_color = Color(0.82, 0.9, 1.0)
		shaft.light_energy = 1.1
		shaft.spot_range = 11.0
		shaft.spot_angle = 32.0
		add_child(shaft)
		shaft.position = Vector3(x, 3.2, -9.4)
		shaft.look_at(Vector3(x * 0.6, 0.0, -3.5))

## Big green laboratory vats in the back corners (the reference image's
## glowing tanks): copper base and cap, glass shell, emissive liquid that
## brightens with energy, bubbles rising inside.
func _build_lab_vats() -> void:
	var glass: Material = load("res://assets/materials/green_glass.tres")
	var copper := _metal_material()
	for x in [-8.2, 8.2]:
		var pos := Vector3(x, 0.0, -8.2)
		if not _spot_free(pos, 2.3):
			continue
		_add_cylinder(1.05, 0.25, pos + Vector3(0, 0.125, 0), copper)

		var liquid := StandardMaterial3D.new()
		liquid.albedo_color = Color(0.15, 0.4, 0.2)
		liquid.emission_enabled = true
		liquid.emission = Color(0.42, 0.75, 0.35)
		liquid.emission_energy_multiplier = 0.5
		_vat_liquids.append(liquid)
		_add_cylinder(0.8, 1.6, pos + Vector3(0, 1.05, 0), liquid)

		_add_cylinder(0.95, 1.9, pos + Vector3(0, 1.2, 0), glass)
		_add_cylinder(1.0, 0.3, pos + Vector3(0, 2.3, 0), copper)
		# Feed pipe from the cap into the back wall.
		var pipe := _add_cylinder(0.09, 1.5, Vector3(x, 2.35, -8.95), copper)
		pipe.rotation.x = PI / 2.0

		var bubbles := GPUParticles3D.new()
		bubbles.amount = 14
		bubbles.amount_ratio = 0.15
		bubbles.lifetime = 2.2
		bubbles.preprocess = 2.0
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(0.5, 0.1, 0.5)
		process.direction = Vector3(0, 1, 0)
		process.spread = 4.0
		process.initial_velocity_min = 0.3
		process.initial_velocity_max = 0.7
		process.gravity = Vector3.ZERO
		bubbles.process_material = process
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 0.045
		bubble_mesh.height = 0.09
		var bubble_mat := StandardMaterial3D.new()
		bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bubble_mat.albedo_color = Color(0.7, 1.0, 0.75, 0.5)
		bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bubble_mesh.material = bubble_mat
		bubbles.draw_pass_1 = bubble_mesh
		add_child(bubbles)
		bubbles.position = pos + Vector3(0, 0.5, 0)
		_vat_bubbles.append(bubbles)

## The Worker's bench against the back wall: wooden counter, brass legs,
## a row of glowing flasks. Skipped if a machine already lives there.
func _build_lab_bench() -> void:
	var pos := Vector3(0.0, 0.0, -8.9)
	if not _spot_free(pos, 2.6):
		return
	var counter := StandardMaterial3D.new()
	counter.albedo_color = Color(0.42, 0.28, 0.16)
	counter.roughness = 0.7
	var brass := _metal_material()
	_add_box(Vector3(4.2, 0.12, 0.9), pos + Vector3(0, 0.92, 0), counter)
	for corner in [Vector3(-1.95, 0.43, -0.35), Vector3(1.95, 0.43, -0.35), Vector3(-1.95, 0.43, 0.35), Vector3(1.95, 0.43, 0.35)]:
		_add_box(Vector3(0.09, 0.86, 0.09), pos + corner, brass)
	var flask: Material = load("res://assets/materials/green_liquid.tres")
	for i in 4:
		var x := lerpf(-1.5, 1.5, i / 3.0)
		var height := 0.22 + 0.1 * float(i % 2)
		_add_cylinder(0.1 + 0.03 * float(i % 2), height,
			pos + Vector3(x, 0.98 + height * 0.5, 0), flask)

	# The Worker's mug, still where he left it — the smallest, loudest story
	# in the room.
	var mug := StandardMaterial3D.new()
	mug.albedo_color = Color(0.7, 0.32, 0.26)
	mug.roughness = 0.7
	_add_cylinder(0.05, 0.1, pos + Vector3(0.85, 1.03, 0.25), mug)

	# Test tube rack: a small block with a row of green-lit tubes.
	var rack := StandardMaterial3D.new()
	rack.albedo_color = Color(0.3, 0.19, 0.11)
	rack.roughness = 0.8
	_add_box(Vector3(0.34, 0.05, 0.12), pos + Vector3(-0.75, 1.0, 0.22), rack)
	for i in 4:
		_add_cylinder(0.022, 0.16,
			pos + Vector3(-0.75 - 0.12 + i * 0.08, 1.1, 0.22), flask)

## Wall shelves of glowing jars on both side walls, up out of gameplay's way.
func _build_shelves() -> void:
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.3, 0.19, 0.11)
	plank.roughness = 0.8
	var jar: Material = load("res://assets/materials/green_liquid.tres")
	for shelf_config in [[-1.0, -2.0], [1.0, 4.0], [-1.0, 5.5], [1.0, -4.0]]:
		var side: float = shelf_config[0]
		var z: float = shelf_config[1]
		_add_box(Vector3(0.3, 0.06, 2.2), Vector3(side * 9.55, 1.85, z), plank)
		for i in 3:
			_add_cylinder(0.08, 0.2,
				Vector3(side * 9.55, 1.98, z + lerpf(-0.8, 0.8, i / 2.0)), jar)

## A chalkboard on the back wall covered in the Worker's scribbles.
func _build_chalkboard() -> void:
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.42, 0.28, 0.16)
	frame.roughness = 0.7
	var board := StandardMaterial3D.new()
	board.albedo_color = Color(0.08, 0.14, 0.11)
	board.roughness = 0.9
	var chalk := StandardMaterial3D.new()
	chalk.albedo_color = Color(0.9, 0.92, 0.88)
	chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_box(Vector3(2.7, 1.6, 0.05), Vector3(-2.2, 1.7, -9.73), frame)
	_add_box(Vector3(2.5, 1.4, 0.06), Vector3(-2.2, 1.7, -9.7), board)
	# Chalk scribbles: uneven line lengths so it reads as writing, plus one
	# circled "diagram" — the Worker was mid-thought.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7147
	for i in 5:
		var width := rng.randf_range(0.7, 1.9)
		_add_box(Vector3(width, 0.035, 0.02),
			Vector3(-2.9 + width * 0.5, 2.25 - i * 0.22, -9.66), chalk)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.2
	var circle := MeshInstance3D.new()
	circle.mesh = ring
	circle.material_override = chalk
	add_child(circle)
	circle.position = Vector3(-1.4, 1.35, -9.66)
	circle.rotation.x = PI / 2.0

## Environmental storytelling scatter: loose notes on the floor where the
## Worker dropped them, and pinned diagrams/warnings on the side walls.
## Floor notes respect machine clearance like every floor prop.
func _build_anecdotes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242  # deterministic — same story, every visit
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.85, 0.83, 0.75)
	paper.roughness = 0.9
	for i in 6:
		var pos := Vector3(rng.randf_range(-8.5, 8.5), 0.015, rng.randf_range(-8.5, 7.5))
		if not _spot_free(pos, 1.2):
			continue
		var note := _add_box(Vector3(0.28, 0.005, 0.38), pos, paper)
		note.rotation.y = rng.randf_range(0.0, TAU)

	# Pinned wall diagrams: steel frame, faded paper, a few sketched lines.
	var frame := StandardMaterial3D.new()
	frame.albedo_color = STEEL_DARK
	frame.metallic = 0.5
	frame.roughness = 0.6
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.25, 0.28, 0.35)
	for poster_config in [[-1.0, 3.0], [1.0, -1.5]]:
		var side: float = poster_config[0]
		var z: float = poster_config[1]
		_add_box(Vector3(0.04, 1.05, 0.8), Vector3(side * 9.72, 1.7, z), frame)
		_add_box(Vector3(0.04, 0.95, 0.7), Vector3(side * 9.7, 1.7, z), paper)
		for line in 3:
			_add_box(Vector3(0.04, 0.03, rng.randf_range(0.3, 0.55)),
				Vector3(side * 9.68, 1.95 - line * 0.22, z), ink)

	# One hazard sign near the vats — this lab bites if mishandled.
	var stripe: Material = load("res://assets/materials/hazard_orange.tres")
	_add_box(Vector3(0.04, 0.5, 0.65), Vector3(9.72, 1.5, -6.5), frame)
	for i in 3:
		var band := _add_box(Vector3(0.05, 0.09, 0.5),
			Vector3(9.7, 1.62 - i * 0.14, -6.5), stripe)
		band.rotation.x = -0.5

func _emissive_material(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 1.0).darkened(0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat

func _metal_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.21, 0.24)
	mat.metallic = 0.8
	mat.roughness = 0.55
	return mat

func _add_box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	inst.position = pos
	return inst

func _add_cylinder(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	inst.position = pos
	return inst

## Thin emissive light lines running along the left/right/back walls near
## the ceiling — the classic "power conduit" read.
func _build_wall_strips() -> void:
	for side in [-1.0, 1.0]:
		var mat := _emissive_material(STRIP_CYAN)
		_strips.append(mat)
		_add_box(Vector3(0.06, 0.08, ROOM_HALF * 2.0),
			Vector3(side * ROOM_HALF, CEILING_HEIGHT - 0.5, 0), mat)
	var back_mat := _emissive_material(WARM_ORANGE)
	_strips.append(back_mat)
	_add_box(Vector3(ROOM_HALF * 2.0, 0.08, 0.06),
		Vector3(0, CEILING_HEIGHT - 0.5, -ROOM_HALF), back_mat)

## Warm orange corner lights + blue mid-wall machinery lights. All start
## nearly off; set_energy ramps them.
func _build_accent_lights() -> void:
	for corner in [Vector3(-8, 2.4, -8), Vector3(8, 2.4, -8), Vector3(-8, 2.4, 6), Vector3(8, 2.4, 6)]:
		var light := OmniLight3D.new()
		light.light_color = WARM_ORANGE
		light.omni_range = 8.0
		light.light_energy = 0.25
		add_child(light)
		light.position = corner
		_warm_lights.append(light)
	for spot in [Vector3(-9, 1.4, 0), Vector3(9, 1.4, 0)]:
		var light := OmniLight3D.new()
		light.light_color = MACHINE_BLUE
		light.omni_range = 6.0
		light.light_energy = 0.05
		add_child(light)
		light.position = spot
		_blue_lights.append(light)

## Horizontal pipe runs along the back wall at two heights.
func _build_pipes() -> void:
	var mat := _metal_material()
	for pipe_config in [{"y": 2.2, "r": 0.12}, {"y": 1.9, "r": 0.08}, {"y": 2.45, "r": 0.06}]:
		var pipe := _add_cylinder(pipe_config.r, ROOM_HALF * 2.0,
			Vector3(0, pipe_config.y, -ROOM_HALF + 0.25), mat)
		pipe.rotation.z = PI / 2.0
	# A few vertical feeder pipes connecting the runs to the floor.
	for x in [-7.0, -2.5, 4.0, 8.0]:
		_add_cylinder(0.09, 2.2, Vector3(x, 1.1, -ROOM_HALF + 0.25), mat)

## Cables drooping from the ceiling line along the side walls — slight
## random lean so they read as hung, not placed.
func _build_hanging_cables() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.1)
	mat.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 20147  # deterministic per run — same factory every time
	for i in 8:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z: float = lerpf(-8.5, 5.0, i / 7.0)
		var length: float = rng.randf_range(0.8, 1.7)
		var cable := _add_cylinder(0.025, length,
			Vector3(side * (ROOM_HALF - 0.25), CEILING_HEIGHT - length * 0.5, z), mat)
		cable.rotation.x = rng.randf_range(-0.12, 0.12)
		cable.rotation.z = side * rng.randf_range(0.05, 0.2)

## Big slow wall fan on the back wall: housing ring + 3 blades that
## _process spins up with energy.
func _build_fan() -> void:
	var housing_mat := _metal_material()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.95
	ring.outer_radius = 1.15
	var housing := MeshInstance3D.new()
	housing.mesh = ring
	housing.material_override = housing_mat
	add_child(housing)
	housing.position = Vector3(-5.5, 2.0, -ROOM_HALF + 0.1)
	housing.rotation.x = PI / 2.0

	_fan_blades = Node3D.new()
	add_child(_fan_blades)
	_fan_blades.position = Vector3(-5.5, 2.0, -ROOM_HALF + 0.18)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.14, 0.15, 0.17)
	blade_mat.metallic = 0.6
	blade_mat.roughness = 0.6
	for i in 3:
		var blade := _add_box(Vector3(0.22, 0.85, 0.04), Vector3.ZERO, blade_mat, _fan_blades)
		blade.position = Vector3(0, 0.45, 0).rotated(Vector3.BACK, i * TAU / 3.0)
		blade.rotation.z = i * TAU / 3.0

## Small orange beacons high on the back wall corners; blink driven in _process.
func _build_warning_lights() -> void:
	for x in [-ROOM_HALF + 0.6, ROOM_HALF - 0.6]:
		var mat := _emissive_material(Color(1.0, 0.45, 0.1), 0.1)
		_warning_mats.append(mat)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		bulb.mesh = sphere
		bulb.material_override = mat
		add_child(bulb)
		bulb.position = Vector3(x, 2.75, -ROOM_HALF + 0.15)

		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.1)
		light.omni_range = 4.0
		light.light_energy = 0.0
		add_child(light)
		light.position = Vector3(x, 2.75, -ROOM_HALF + 0.5)
		_warning_lights.append(light)

## Steam columns rising from floor vents at the back corners.
func _build_steam_vents() -> void:
	for x in [-8.0, 7.0]:
		var steam := GPUParticles3D.new()
		steam.amount = 24
		steam.amount_ratio = 0.15
		steam.lifetime = 2.8
		steam.preprocess = 2.0

		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0, 1, 0)
		process.spread = 8.0
		process.initial_velocity_min = 0.5
		process.initial_velocity_max = 1.1
		process.gravity = Vector3(0, 0.25, 0)
		process.scale_min = 1.2
		process.scale_max = 2.6
		process.color = Color(0.85, 0.88, 0.92, 0.05)
		steam.process_material = process

		var mesh := SphereMesh.new()
		mesh.radius = 0.35
		mesh.height = 0.7
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.88, 0.92, 0.05)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = mat
		steam.draw_pass_1 = mesh

		add_child(steam)
		steam.position = Vector3(x, 0.1, -8.0)
		_steam_emitters.append(steam)

## Slow ambient dust across the whole room — always on; a dead factory is
## nothing if not dusty.
func _build_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 60
	dust.lifetime = 8.0
	dust.preprocess = 8.0

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(ROOM_HALF, 1.5, ROOM_HALF)
	process.gravity = Vector3(0, -0.02, 0)
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.08
	process.scale_min = 0.5
	process.scale_max = 1.0
	dust.process_material = process

	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.9, 0.95, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	dust.draw_pass_1 = mesh

	add_child(dust)
	dust.position = Vector3(0, 1.6, -1.0)
