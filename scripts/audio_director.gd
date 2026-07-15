extends Node
## Autoload ("AudioDirector"). Two jobs, both global by design so nothing
## needs per-scene wiring:
##
## 1. Gives every Button in the game (present and future, any scene) a
##    consistent hover/press feel — a subtle scale animation plus
##    PlaceholderSFX hover/click sounds — by watching the tree for new
##    Button nodes rather than requiring each scene to wire its own buttons.
## 2. Plays a quiet, looping ambient factory hum for atmosphere (the plan's
##    "factory heartbeat" idea) — synthesized procedurally, same as the SFX.

const HOVER_SCALE := 1.05
const HOVER_TWEEN_TIME := 0.08
const HUM_VOLUME_DB := -22.0

var _hum_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons(get_tree().root)
	_start_ambient_hum()

func _wire_existing_buttons(node: Node) -> void:
	if node is Button:
		_wire_button(node)
	for child in node.get_children():
		_wire_existing_buttons(child)

func _on_node_added(node: Node) -> void:
	if node is Button:
		_wire_button(node)

func _wire_button(button: Button) -> void:
	if button.has_meta("_audio_director_wired"):
		return
	button.set_meta("_audio_director_wired", true)

	button.mouse_entered.connect(func() -> void:
		PlaceholderSFX.play_ui_hover()
		button.pivot_offset = button.size / 2.0
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE * HOVER_SCALE, HOVER_TWEEN_TIME)
	)
	button.mouse_exited.connect(func() -> void:
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, HOVER_TWEEN_TIME)
	)
	button.pressed.connect(func() -> void:
		PlaceholderSFX.play_ui_click()
	)

func _exit_tree() -> void:
	if _hum_player:
		_hum_player.stop()
		_hum_player.stream = null

func _start_ambient_hum() -> void:
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = _synthesize_ambient_hum()
	_hum_player.volume_db = HUM_VOLUME_DB
	add_child(_hum_player)
	_hum_player.play()

## PLACEHOLDER ambient bed: a few slightly-detuned low sine layers (for a
## slow beating/pulsing texture) plus faint filtered noise, looped
## seamlessly. Not meant to be musical — just a low industrial presence
## under everything, quiet enough to never compete with SFX or dialogue.
func _synthesize_ambient_hum() -> AudioStreamWAV:
	var sample_rate := 22050.0
	var duration := 6.0
	var n := int(sample_rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t: float = i / sample_rate
		var low_a: float = sin(TAU * 55.0 * t)
		var low_b: float = sin(TAU * 56.5 * t)  # detuned against low_a for slow beating
		var sub: float = sin(TAU * 27.5 * t) * 0.5
		var noise: float = rng.randf_range(-1.0, 1.0) * 0.03
		samples[i] = clampf((low_a + low_b) * 0.18 + sub * 0.15 + noise, -1.0, 1.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	return stream
