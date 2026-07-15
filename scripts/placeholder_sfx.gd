extends RefCounted
class_name PlaceholderSFX
## Audio. Every one-shot below is now a real CC0 clip from Kenney's
## Impact/Sci-fi/Interface Sounds packs (kenney.nl/assets, public domain, no
## attribution required) — see docs/asset_list.md and CREDITS.md for the
## per-file source. `worker_blip` and `charge_tick` reuse a single real clip
## each with a different `pitch_scale` per call rather than needing a
## separate file per pitch.
##
## Only the three looping ambient beds (wind, clock, heartbeat) are still
## synthesized: none of Kenney's packs have a seamless ambience loop that
## fits, and getting a loop's seam wrong is a worse risk than a synthesized
## one that's guaranteed click-free. Swap them for real loops later by
## replacing `_synthesize_*_loop()`'s call site — nothing else needs to change.

const SAMPLE_RATE := 22050.0

const KickThud := preload("res://assets/audio/sfx/kick_thud.ogg")
const GearClink := preload("res://assets/audio/sfx/gear_clink.ogg")
const VialExplosion := preload("res://assets/audio/sfx/vial_explosion.ogg")
const GridZap := preload("res://assets/audio/sfx/grid_zap.ogg")
const UiHover := preload("res://assets/audio/sfx/ui_hover.ogg")
const UiClick := preload("res://assets/audio/sfx/ui_click.ogg")
const TargetDing := preload("res://assets/audio/sfx/target_ding.ogg")
const MaxPower := preload("res://assets/audio/sfx/max_power.ogg")
const LevelComplete := preload("res://assets/audio/sfx/level_complete.ogg")
const HeartLoss := preload("res://assets/audio/sfx/heart_loss.ogg")
const Shutdown := preload("res://assets/audio/sfx/shutdown.ogg")
const MachineStart := preload("res://assets/audio/sfx/machine_start.ogg")
const NarratorBlip := preload("res://assets/audio/sfx/narrator_blip.ogg")
const Spark := preload("res://assets/audio/sfx/spark.ogg")
const Rewind := preload("res://assets/audio/sfx/rewind.ogg")
const ChargeTick := preload("res://assets/audio/sfx/charge_tick.ogg")

static func play_thud(at: Node3D) -> void:
	_play(KickThud, at)

static func play_clink(at: Node3D) -> void:
	_play(GearClink, at)

static func play_explosion(at: Node3D) -> void:
	_play(VialExplosion, at)

static func play_zap(at: Node3D) -> void:
	_play(GridZap, at)

# --- UI / meta sounds: not tied to a world position, so these use a plain
# (non-positional) AudioStreamPlayer instead of a 3D one. ---

static func play_ui_hover() -> void:
	_play_2d(UiHover)

static func play_ui_click() -> void:
	_play_2d(UiClick)

static func play_target_ding() -> void:
	_play_2d(TargetDing)

static func play_max_power() -> void:
	_play_2d(MaxPower)

static func play_level_complete() -> void:
	_play_2d(LevelComplete)

static func play_heart_loss() -> void:
	_play_2d(HeartLoss)

static func play_shutdown() -> void:
	_play_2d(Shutdown)

static func play_machine_start(at: Node3D) -> void:
	_play(MachineStart, at)

static func play_narrator_blip() -> void:
	_play_2d(NarratorBlip)

static func play_spark(at: Node3D) -> void:
	_play(Spark, at)

static func play_rewind() -> void:
	_play_2d(Rewind)

## Charge feedback: one short tick each time the charge bar crosses a
## stage (40% / 80% / max) — pitch rises with the stage, via pitch_scale on
## one real clip rather than three separate files.
static func play_charge_tick(stage: int) -> void:
	_play_2d(ChargeTick, 1.0 + stage * 0.22)

## Slightly deeper/warmer than the narrator chime — the Worker's own voice
## cue, used when HE speaks (cinematic) rather than the narrator. Same clip
## as play_narrator_blip, pitched down instead of using a second file.
static func play_worker_blip() -> void:
	_play_2d(NarratorBlip, 0.72)

# --- Looping ambient streams: callers own the AudioStreamPlayer (start,
# volume, stop) — these just synthesize the loop. Used by the cinematic
# (wind, clock) and LifeManager (low-hearts heartbeat). ---

static func wind_loop() -> AudioStreamWAV:
	return _synthesize_wind_loop()

static func clock_tick_loop() -> AudioStreamWAV:
	return _synthesize_clock_loop()

static func heartbeat_loop() -> AudioStreamWAV:
	return _synthesize_heartbeat_loop()

static func _play(stream: AudioStream, at: Node3D, pitch_scale: float = 1.0) -> void:
	if at == null or not at.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.pitch_scale = pitch_scale
	at.get_tree().current_scene.add_child(player)
	player.global_position = at.global_position
	player.play()
	player.finished.connect(player.queue_free)

static func _play_2d(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch_scale
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
