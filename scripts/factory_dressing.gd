extends Node3D
## Procedural factory dressing, spawned into every level at runtime by
## FactoryManager — pipes, hanging cables, emissive wall strips, warm/cool
## accent lights, a rotating wall fan, blinking warning lights, steam vents
## and drifting dust. Pure visuals: nothing here has collision, and
## everything sits at/outside the standard 20x20 room walls so gameplay
## physics is untouched.
##
## Everything reacts to set_energy(0..100): strips brighten, accent lights
## ramp up, the fan spins up, steam thickens, warning lights start blinking.
## At 0% the room reads "decades dead"; at 100% it reads alive.

const ROOM_HALF := 9.7   # just inside the ±10 walls
const WALL_HEIGHT := 3.0

const WARM_ORANGE := Color(1.0, 0.62, 0.22)
const MACHINE_BLUE := Color(0.3, 0.65, 1.0)
const STRIP_CYAN := Color(0.25, 0.85, 0.9)

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

func _ready() -> void:
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

func _process(delta: float) -> void:
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
			Vector3(side * ROOM_HALF, 2.55, 0), mat)
	var back_mat := _emissive_material(WARM_ORANGE)
	_strips.append(back_mat)
	_add_box(Vector3(ROOM_HALF * 2.0, 0.08, 0.06),
		Vector3(0, 2.55, -ROOM_HALF), back_mat)

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
		var length: float = rng.randf_range(0.5, 1.1)
		var cable := _add_cylinder(0.025, length,
			Vector3(side * (ROOM_HALF - 0.25), WALL_HEIGHT - length * 0.5, z), mat)
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
