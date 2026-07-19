extends Node
## Autoload ("BallSkins"). Cosmetic-only: picks a ball look per level so the
## ball visibly "levels up" as the player progresses — mesh material, rings/
## spikes, the wrist-strap, and the kick trail all read from the same
## per-level palette. Physics, mass, and collision are never touched here.

## Indexed by level number (1-based), parsed from the scene file name
## (res://scenes/levels/level_N.tscn). Anything past the last entry repeats
## the final skin rather than erroring, so adding level_11+ later doesn't crash.
## `emission` is the primary glow (core/body); `accent` is a contrasting hot
## highlight used for rings/spikes/rim light/trail head, so each skin reads
## as a designed two-tone set rather than a single flat tint.
const SKINS := [
	{"albedo": Color(0.8, 0.81, 0.84), "emission": Color(0.961, 0.651, 0.137), "accent": Color(1.0, 0.85, 0.55), "energy": 0.3},  # 1 — stock chrome/amber
	{"albedo": Color(0.75, 0.78, 0.85), "emission": Color(0.0, 0.898, 1.0), "accent": Color(0.6, 1.0, 1.0), "energy": 0.45},       # 2 — cyan
	{"albedo": Color(0.72, 0.8, 0.76), "emission": Color(0.15, 1.0, 0.4), "accent": Color(0.75, 1.0, 0.5), "energy": 0.55},        # 3 — toxic green
	{"albedo": Color(0.8, 0.75, 0.7), "emission": Color(1.0, 0.4, 0.08), "accent": Color(1.0, 0.8, 0.2), "energy": 0.65},          # 4 — molten orange
	{"albedo": Color(0.78, 0.72, 0.82), "emission": Color(0.65, 0.15, 1.0), "accent": Color(0.85, 0.55, 1.0), "energy": 0.75},     # 5 — violet
	{"albedo": Color(0.85, 0.7, 0.72), "emission": Color(1.0, 0.1, 0.35), "accent": Color(1.0, 0.55, 0.7), "energy": 0.85},        # 6 — hot pink/red
	{"albedo": Color(0.7, 0.78, 0.82), "emission": Color(0.05, 0.55, 1.0), "accent": Color(0.5, 0.85, 1.0), "energy": 0.95},       # 7 — electric blue
	{"albedo": Color(0.82, 0.8, 0.65), "emission": Color(1.0, 0.82, 0.05), "accent": Color(1.0, 0.95, 0.6), "energy": 1.1},        # 8 — gold
	{"albedo": Color(0.78, 0.78, 0.82), "emission": Color(0.85, 0.9, 1.0), "accent": Color(1.0, 1.0, 1.0), "energy": 1.35},        # 9 — white-hot
	{"albedo": Color(0.1, 0.1, 0.12), "emission": Color(1.0, 0.08, 0.1), "accent": Color(1.0, 0.6, 0.15), "energy": 1.8},          # 10 — final, dark chrome + red core + molten rim
]

func _skin_for_level(level_number: int) -> Dictionary:
	return SKINS[clampi(level_number - 1, 0, SKINS.size() - 1)]

## Returns a fresh StandardMaterial3D for the given level number. Beyond the
## base albedo/emission swap, later levels ramp from a slightly dull stock
## finish toward a near-mirror polish (higher metallic, lower roughness,
## stronger clearcoat + rim) so the ball itself visibly gets more premium,
## not just brighter.
func material_for_level(level_number: int) -> StandardMaterial3D:
	var skin: Dictionary = _skin_for_level(level_number)
	var tier: int = _tier_for_level(level_number)
	var polish: float = tier / 4.0  # 0 at levels 1-2, 1 at levels 9-10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = skin["albedo"]
	mat.metallic = lerpf(0.7, 0.97, polish)
	mat.roughness = lerpf(0.4, 0.06, polish)
	mat.emission_enabled = true
	mat.emission = skin["emission"]
	mat.emission_energy_multiplier = skin["energy"]
	mat.clearcoat_enabled = true
	mat.clearcoat = lerpf(0.3, 1.0, polish)
	mat.clearcoat_roughness = lerpf(0.1, 0.02, polish)
	mat.rim_enabled = true
	mat.rim = lerpf(0.25, 0.75, polish)
	mat.rim_tint = 0.6
	return mat

## Parses "level_N" out of a scene path like res://scenes/levels/level_7.tscn.
## Returns 1 (the default skin) if the path doesn't match, e.g. the greybox
## test room or any non-level scene.
func level_number_from_path(scene_path: String) -> int:
	var file_name := scene_path.get_file().get_basename()  # "level_7"
	var parts := file_name.split("_")
	if parts.size() >= 2 and parts[0] == "level":
		var n := parts[1].to_int()
		if n > 0:
			return n
	return 1

# --- Decorations: geometry added on top of the sphere so the ball reads as
# visibly "more powerful" as levels climb, not just a different color.
# Attached as children of the ball's visual mesh (not the physics body), so
# they inherit its squash/stretch/velocity-facing without touching collision. ---

const BASE_RADIUS := 0.5  # matches the ball's SphereMesh / ghost trail marker

## 0 = bare sphere, up to 4 = fully decked out (levels 9-10).
func _tier_for_level(level_number: int) -> int:
	return clampi((level_number - 1) / 2, 0, 4)

## Rebuilds the decoration set on `visual_mesh` for `level_number`. Safe to
## call more than once — previous decorations (tagged via metadata) are
## cleared first.
func decorate(visual_mesh: MeshInstance3D, level_number: int) -> void:
	for child in visual_mesh.get_children():
		if child.has_meta("ball_skin_decoration"):
			child.queue_free()

	var skin: Dictionary = _skin_for_level(level_number)
	var primary: Color = skin["emission"]
	var accent: Color = skin["accent"]
	var tier: int = _tier_for_level(level_number)
	var is_final: bool = level_number >= 10

	# Rings widen and thicken with tier so later levels read as grander, not
	# just "another ring stacked on."
	if tier >= 1:
		visual_mesh.add_child(_build_ring(accent, BASE_RADIUS * (1.2 + tier * 0.02), 0.026 + tier * 0.006))
	if tier >= 2:
		var ring2 := _build_ring(primary, BASE_RADIUS * (1.28 + tier * 0.02), 0.02 + tier * 0.005)
		ring2.rotation_degrees = Vector3(90, 0, 0)
		visual_mesh.add_child(ring2)
	if tier >= 3:
		_add_spikes(visual_mesh, accent, 6, BASE_RADIUS * 0.32, 0.0, true)
	if tier >= 4:
		_add_spikes(visual_mesh, primary, 6, BASE_RADIUS * 0.32, 30.0, true)  # second, offset ring of spikes
		_add_core_glow(visual_mesh, accent if is_final else primary, is_final)
		_add_aura(visual_mesh, accent, is_final)

func _tag(node: Node) -> Node:
	node.set_meta("ball_skin_decoration", true)
	return node

func _decoration_material(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	mat.clearcoat_roughness = 0.05
	return mat

func _build_ring(color: Color, radius: float, thickness: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	mesh_instance.mesh = torus
	mesh_instance.material_override = _decoration_material(color, 1.8)
	return _tag(mesh_instance) as MeshInstance3D

## Scatters `count` small spikes evenly over the sphere (fibonacci-sphere
## distribution) so they read as a uniform "spiked weapon" silhouette rather
## than a random cluster. `angle_offset_degrees` rotates the whole set so a
## second batch doesn't just stack on the first. `gem_tips` caps each spike
## with a tiny brighter sphere, like a jewel setting, for the top tier.
func _add_spikes(visual_mesh: MeshInstance3D, color: Color, count: int, length: float, angle_offset_degrees: float = 0.0, gem_tips: bool = false) -> void:
	var mat := _decoration_material(color, 2.4)
	var gem_mat := _decoration_material(color, 4.5) if gem_tips else null
	for i in range(count):
		var t: float = (i + 0.5) / count
		var phi: float = acos(1.0 - 2.0 * t)
		var golden_angle: float = PI * (3.0 - sqrt(5.0))
		var theta: float = golden_angle * i + deg_to_rad(angle_offset_degrees)

		var dir := Vector3(
			sin(phi) * cos(theta),
			cos(phi),
			sin(phi) * sin(theta)
		).normalized()

		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = BASE_RADIUS * 0.14
		cone.height = length
		spike.mesh = cone
		spike.material_override = mat

		# Cylinders point along local +Y by default; orient +Y to `dir` and
		# sit the spike's base on the sphere surface, tip pointing outward.
		var y_axis := dir
		var x_axis := y_axis.cross(Vector3.UP)
		if x_axis.length() < 0.01:
			x_axis = Vector3.RIGHT
		x_axis = x_axis.normalized()
		var z_axis := x_axis.cross(y_axis).normalized()
		spike.transform = Transform3D(Basis(x_axis, y_axis, z_axis), dir * (BASE_RADIUS + length * 0.5))

		visual_mesh.add_child(_tag(spike))

		if gem_mat:
			var gem := MeshInstance3D.new()
			var gem_sphere := SphereMesh.new()
			gem_sphere.radius = BASE_RADIUS * 0.06
			gem_sphere.height = gem_sphere.radius * 2.0
			gem.mesh = gem_sphere
			gem.material_override = gem_mat
			gem.position = dir * (BASE_RADIUS + length)
			visual_mesh.add_child(_tag(gem))

## The strongest visual tier: a small bright inner sphere glowing through the
## shell, like a reactor core — final level gets it hottest.
func _add_core_glow(visual_mesh: MeshInstance3D, color: Color, is_final: bool) -> void:
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BASE_RADIUS * (0.45 if is_final else 0.35)
	sphere.height = sphere.radius * 2.0
	core.mesh = sphere
	core.material_override = _decoration_material(color, 5.5 if is_final else 3.2)
	visual_mesh.add_child(_tag(core))

## Top tiers (9-10) actually light the world around them, not just
## themselves — a soft colored OmniLight that makes the ball read as a real
## light source rolling through the room.
func _add_aura(visual_mesh: MeshInstance3D, color: Color, is_final: bool) -> void:
	var aura := OmniLight3D.new()
	aura.light_color = color
	aura.omni_range = 2.5 if is_final else 2.0
	aura.light_energy = 1.4 if is_final else 1.0
	visual_mesh.add_child(_tag(aura))

# --- Strap: the wristband-style torus already modeled on the ball. Retinted
# per skin (instead of its fixed cyan wire_glow material) so it doesn't clash
# with whatever palette the level is on. ---

func apply_strap(strap: MeshInstance3D, level_number: int) -> void:
	if strap == null:
		return
	var skin: Dictionary = _skin_for_level(level_number)
	var tier: int = _tier_for_level(level_number)
	var polish: float = tier / 4.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = skin["accent"]
	mat.metallic = lerpf(0.5, 0.9, polish)
	mat.roughness = lerpf(0.3, 0.05, polish)
	mat.emission_enabled = true
	mat.emission = skin["accent"]
	mat.emission_energy_multiplier = 0.8 + tier * 0.35
	mat.clearcoat_enabled = true
	mat.clearcoat = lerpf(0.5, 1.0, polish)
	mat.clearcoat_roughness = 0.06
	mat.rim_enabled = true
	mat.rim = lerpf(0.2, 0.6, polish)
	mat.rim_tint = 0.5
	strap.material_override = mat

# --- Kick trail (the "tail"): a GPUParticles3D streak behind the ball.
# Retinted to the level's two-tone palette (hot accent at the head fading
# through the primary glow) and scaled up in volume/reach on later tiers so
# higher levels leave a visibly bigger, brighter tail. ---

func apply_trail(trail: GPUParticles3D, level_number: int) -> void:
	if trail == null:
		return
	var skin: Dictionary = _skin_for_level(level_number)
	var tier: int = _tier_for_level(level_number)
	var accent: Color = skin["accent"]
	var primary: Color = skin["emission"]

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(accent.r, accent.g, accent.b, 0.85),
		Color(primary.r, primary.g, primary.b, 0.45),
		Color(primary.r, primary.g, primary.b, 0.0),
	])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = gradient

	var base_process_material: ParticleProcessMaterial = trail.process_material
	var process_material: ParticleProcessMaterial = base_process_material.duplicate() if base_process_material else ParticleProcessMaterial.new()
	process_material.color_ramp = ramp_texture
	process_material.scale_min = 0.5 + tier * 0.05
	process_material.scale_max = 0.9 + tier * 0.12
	trail.process_material = process_material

	# More levels behind you, more trail ahead of you: later skins leave a
	# denser, longer-lived streak.
	trail.amount = 64 + tier * 16
	trail.lifetime = 0.6 + tier * 0.12
