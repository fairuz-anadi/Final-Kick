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

static func play_heart_loss() -> void:
	_play_2d(_synthesize_heart_loss())

static func play_shutdown() -> void:
	_play_2d(_synthesize_shutdown())

static func play_machine_start(at: Node3D) -> void:
	_play(_synthesize_machine_start(), at)

static func play_narrator_blip() -> void:
	_play_2d(_synthesize_narrator_blip())

static func play_spark(at: Node3D) -> void:
	_play(_synthesize_spark(), at)

static func play_rewind() -> void:
	_play_2d(_synthesize_rewind())

## Charge feedback: one short tick each time the charge bar crosses a
## stage (40% / 80% / max) — pitch rises with the stage.
static func play_charge_tick(stage: int) -> void:
	_play_2d(_synthesize_charge_tick(stage))

## Slightly deeper/warmer than the narrator chime — the Worker's own voice
## cue, used when HE speaks (cinematic) rather than the narrator.
static func play_worker_blip() -> void:
	_play_2d(_synthesize_worker_blip())

# --- Looping ambient streams: callers own the AudioStreamPlayer (start,
# volume, stop) — these just synthesize the loop. Used by the cinematic
# (wind, clock) and LifeManager (low-hearts heartbeat). ---

static func wind_loop() -> AudioStreamWAV:
	return _synthesize_wind_loop()

static func clock_tick_loop() -> AudioStreamWAV:
	return _synthesize_clock_loop()

static func heartbeat_loop() -> AudioStreamWAV:
	return _synthesize_heartbeat_loop()

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
	player.finished.connect(player.queue_free)
	# Deferred add + play-on-entry so this is safe to call from _ready
	# (e.g. a narrator line on a scene's very first frame), when the tree
	# is still busy setting up children.
	player.tree_entered.connect(player.play)
	tree.root.add_child.call_deferred(player)

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

static func _make_loop_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := _make_wav(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
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

## Heart loss: a soft descending two-note "aww" — sad but gentle, matching
## the hopeful tone (a setback, not a horror sting).
static func _synthesize_heart_loss() -> AudioStreamWAV:
	var notes := [392.0, 311.13]  # G4 -> Eb4, falling minor third-ish
	var note_duration := 0.22
	var n_per_note := int(SAMPLE_RATE * note_duration)
	var samples := PackedFloat32Array()
	samples.resize(n_per_note * notes.size())
	for note_index in notes.size():
		var freq: float = notes[note_index]
		var base: int = note_index * n_per_note
		for i in n_per_note:
			var t: float = i / SAMPLE_RATE
			var env: float = exp(-t * 8.0)
			samples[base + i] = (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)) * env * 0.5
	return _make_wav(samples)

## Factory shutdown: a long dying power-down sweep — the whole room losing
## its charge. Pitch falls and the sound decays into silence.
static func _synthesize_shutdown() -> AudioStreamWAV:
	var duration := 1.4
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var progress: float = t / duration
		var env: float = (1.0 - progress) * (1.0 - progress)
		var freq: float = lerp(220.0, 35.0, pow(progress, 0.6))
		samples[i] = (sin(TAU * freq * t) + 0.4 * sin(TAU * freq * 0.5 * t)) * env * 0.6
	return _make_wav(samples)

## Machine startup: a rising rumble that resolves into a steady hum — the
## sound of something waking up after decades. Pairs with FactoryManager's
## activation pulse.
static func _synthesize_machine_start() -> AudioStreamWAV:
	var duration := 0.9
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var t: float = i / SAMPLE_RATE
		var progress: float = t / duration
		var attack: float = clampf(progress * 4.0, 0.0, 1.0)
		var release: float = 1.0 - clampf((progress - 0.75) * 4.0, 0.0, 1.0)
		var freq: float = lerp(40.0, 110.0, pow(progress, 0.5))
		var rumble: float = sin(TAU * freq * t) + 0.5 * sin(TAU * freq * 1.5 * t)
		var grit: float = rng.randf_range(-1.0, 1.0) * 0.12 * (1.0 - progress)
		samples[i] = (rumble * 0.5 + grit) * attack * release * 0.8
	return _make_wav(samples)

## Narrator line cue: one warm, quiet low bell — draws the eye to the
## subtitle without competing with gameplay sounds.
static func _synthesize_narrator_blip() -> AudioStreamWAV:
	var duration := 0.4
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 5.0)
		samples[i] = (sin(TAU * 440.0 * t) + 0.25 * sin(TAU * 880.0 * t)) * env * 0.28
	return _make_wav(samples)

## Small spark: a tiny bright crackle for ambient dressing / activation bursts.
static func _synthesize_spark() -> AudioStreamWAV:
	var duration := 0.12
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 35.0)
		var crackle: float = rng.randf_range(-1.0, 1.0)
		samples[i] = (crackle * 0.5 + sin(TAU * 3000.0 * t) * 0.3) * env * 0.4
	return _make_wav(samples)

## Rewind engage: a falling, wobbling sweep — time being pulled backwards.
static func _synthesize_rewind() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var progress: float = t / duration
		var env: float = exp(-t * 4.0) * minf(t * 40.0, 1.0)
		var freq: float = lerp(1400.0, 250.0, progress)
		var wobble: float = 1.0 + 0.08 * sin(TAU * 11.0 * t)
		samples[i] = sin(TAU * freq * wobble * t) * env * 0.35
	return _make_wav(samples)

static func _synthesize_charge_tick(stage: int) -> AudioStreamWAV:
	var duration := 0.06
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var freq := 500.0 + stage * 280.0
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 55.0)
		samples[i] = (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 1.5 * t)) * env * 0.35
	return _make_wav(samples)

## The Worker's voice cue: like the narrator bell but lower and warmer.
static func _synthesize_worker_blip() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t: float = i / SAMPLE_RATE
		var env: float = exp(-t * 4.5)
		samples[i] = (sin(TAU * 293.66 * t) + 0.3 * sin(TAU * 587.33 * t)) * env * 0.3
	return _make_wav(samples)

## Wind: slow-breathing filtered noise, 4s seamless loop. "Filtered" here is
## a cheap two-pole smoothing of white noise — enough to read as air, not static.
static func _synthesize_wind_loop() -> AudioStreamWAV:
	var duration := 4.0
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2147
	var smooth_a := 0.0
	var smooth_b := 0.0
	for i in n:
		var t: float = i / SAMPLE_RATE
		smooth_a = lerpf(smooth_a, rng.randf_range(-1.0, 1.0), 0.045)
		smooth_b = lerpf(smooth_b, smooth_a, 0.045)
		# Two gusts per loop, each a whole sine cycle so the seam is silent.
		var gust: float = 0.55 + 0.45 * sin(TAU * 0.5 * t)
		samples[i] = smooth_b * gust * 0.9
	return _make_loop_wav(samples)

## Clock: one soft tick per second, 2s loop (tick slightly stronger than
## tock, like a real mechanism).
static func _synthesize_clock_loop() -> AudioStreamWAV:
	var duration := 2.0
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for tick in 2:
		var start := int(tick * 1.0 * SAMPLE_RATE)
		var strength := 0.4 if tick == 0 else 0.28
		for i in int(SAMPLE_RATE * 0.04):
			var t: float = i / SAMPLE_RATE
			var env: float = exp(-t * 160.0)
			samples[start + i] = (sin(TAU * 1900.0 * t) + 0.4 * sin(TAU * 950.0 * t)) * env * strength
	return _make_loop_wav(samples)

## Heartbeat: the classic lub-dub, one beat per second — plays under
## everything once the player is down to two hearts.
static func _synthesize_heartbeat_loop() -> AudioStreamWAV:
	var duration := 1.0
	var n := int(SAMPLE_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for thump_index in 2:
		var start := int((0.0 if thump_index == 0 else 0.28) * SAMPLE_RATE)
		var strength := 0.85 if thump_index == 0 else 0.6
		for i in int(SAMPLE_RATE * 0.18):
			var t: float = i / SAMPLE_RATE
			var env: float = exp(-t * 22.0) * minf(t * 220.0, 1.0)
			samples[start + i] += sin(TAU * 52.0 * t) * env * strength
	return _make_loop_wav(samples)

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
