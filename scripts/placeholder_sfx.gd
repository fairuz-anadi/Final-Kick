extends RefCounted
class_name PlaceholderSFX
## PLACEHOLDER audio. Every sound here is synthesized procedurally at
## runtime — no recorded/licensed audio files involved — so there's a real,
## audible stand-in for each trigger event without any copyright risk.
##
## Swap any of these for real recorded/sourced SFX by replacing the
## call site (e.g. `PlaceholderSFX.play_thud(self)`) with your own
## AudioStreamPlayer3D + real AudioStream — nothing else needs to change.

const SAMPLE_RATE := 22050.0

static func play_thud(at: Node3D) -> void:
	_play(_synthesize_thud(), at)

static func play_clink(at: Node3D) -> void:
	_play(_synthesize_clink(), at)

static func play_explosion(at: Node3D) -> void:
	_play(_synthesize_explosion(), at)

static func play_zap(at: Node3D) -> void:
	_play(_synthesize_zap(), at)

# --- UI / meta sounds: not tied to a world position, so these use a plain
# (non-positional) AudioStreamPlayer instead of a 3D one. ---

static func play_ui_hover() -> void:
	_play_2d(_synthesize_ui_hover())

static func play_ui_click() -> void:
	_play_2d(_synthesize_ui_click())

static func play_target_ding() -> void:
	_play_2d(_synthesize_target_ding())

static func play_max_power() -> void:
	_play_2d(_synthesize_max_power())

static func play_level_complete() -> void:
	_play_2d(_synthesize_level_complete())

static func _play(stream: AudioStreamWAV, at: Node3D) -> void:
	if at == null or not at.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	at.get_tree().current_scene.add_child(player)
	player.global_position = at.global_position
	player.play()
	player.finished.connect(player.queue_free)

static func _play_2d(stream: AudioStreamWAV) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	tree.root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

static func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	stream.data = bytes
	return stream

## Kick: a short, low-frequency thump with a fast decay.
static func _synthesize_thud() -> AudioStreamWAV:
	var duration := 0.16
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 28.0)
		samples[i] = sin(TAU * 95.0 * t) * env * 0.9
	return _make_wav(samples)

## Gear/grid trigger: a bright, very short metallic ping.
static func _synthesize_clink() -> AudioStreamWAV:
	var duration := 0.09
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 45.0)
		samples[i] = (sin(TAU * 1100.0 * t) + 0.5 * sin(TAU * 1800.0 * t)) * env * 0.5
	return _make_wav(samples)

## Vial: filtered noise burst layered with a low sine "boom" for body.
static func _synthesize_explosion() -> AudioStreamWAV:
	var duration := 0.45
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 7.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var boom: float = sin(TAU * 60.0 * t) * exp(-t * 12.0)
		samples[i] = clampf(noise * 0.6 + boom * 0.7, -1.0, 1.0) * env
	return _make_wav(samples)

## Grid surge: a downward frequency sweep with a crackly noise layer.
static func _synthesize_zap() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 14.0)
		var freq: float = lerp(2200.0, 300.0, t / duration)
		var crackle: float = rng.randf_range(-0.3, 0.3)
		samples[i] = (sin(TAU * freq * t) * 0.7 + crackle) * env
	return _make_wav(samples)

## Button hover: very quiet, very short high tick — meant to be felt more
## than heard, since it fires constantly as the mouse moves across a menu.
static func _synthesize_ui_hover() -> AudioStreamWAV:
	var duration := 0.035
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 90.0)
		samples[i] = sin(TAU * 1500.0 * t) * env * 0.3
	return _make_wav(samples)

## Button press: a slightly firmer two-tone blip, confirming the click landed.
static func _synthesize_ui_click() -> AudioStreamWAV:
	var duration := 0.07
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 40.0)
		var freq: float = lerp(900.0, 1400.0, clampf(t / duration, 0.0, 1.0))
		samples[i] = sin(TAU * freq * t) * env * 0.5
	return _make_wav(samples)

## HUD "TARGET ACTIVATED" notification: a single bright, musical bell tone —
## distinct from the mechanical clink so it reads as a UI/meta cue, not a
## world sound.
static func _synthesize_target_ding() -> AudioStreamWAV:
	var duration := 0.3
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 6.0)
		samples[i] = (sin(TAU * 1046.5 * t) + 0.4 * sin(TAU * 2093.0 * t)) * env * 0.55
	return _make_wav(samples)

## MAX POWER kick: a short, bright rising sweep with a buzzy harmonic layer —
## pairs with the HUD's existing MAX POWER flash/pulse.
static func _synthesize_max_power() -> AudioStreamWAV:
	var duration := 0.28
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var progress: float = t / duration
		var env: float = exp(-t * 5.0) * clampf(progress * 8.0, 0.0, 1.0)
		var freq: float = lerp(400.0, 1600.0, progress)
		samples[i] = (sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t)) * env * 0.6
	return _make_wav(samples)

## Level complete: a short ascending three-note chime (major arpeggio) —
## the "you solved it" payoff, played once the Spectacle Cam kicks in.
static func _synthesize_level_complete() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99]  # C5, E5, G5
	var note_duration := 0.16
	var n_per_note := int(SAMPLE_RATE * note_duration)
	var samples := PackedFloat32Array()
	samples.resize(n_per_note * notes.size())
	for note_index in notes.size():
		var freq: float = notes[note_index]
		var base: int = note_index * n_per_note
		for i in n_per_note:
			var t: float = i / SAMPLE_RATE
			var env: float = exp(-t * 9.0)
			samples[base + i] = sin(TAU * freq * t) * env * 0.6
	return _make_wav(samples)
