extends RefCounted
class_name PlaceholderSFX
## PLACEHOLDER audio. Every sound here is synthesized procedurally at
## runtime — no recorded/licensed audio files involved — so there's a real,
## audible stand-in for each trigger event without any copyright risk.
##
## Rabib: swap any of these for real recorded/sourced SFX by replacing the
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

static func _play(stream: AudioStreamWAV, at: Node3D) -> void:
	if at == null or not at.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	at.get_tree().current_scene.add_child(player)
	player.global_position = at.global_position
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
