extends Node
## Autoload ("AudioDirector"). Two jobs, both global by design so nothing
## needs per-scene wiring:
##
## 1. Gives every Button in the game (present and future, any scene) a
##    consistent hover/press feel — a subtle scale animation plus
##    SFX hover/click sounds — by watching the tree for new
##    Button nodes rather than requiring each scene to wire its own buttons.
## 2. Plays a quiet, looping ambient factory hum for atmosphere (the plan's
##    "factory heartbeat" idea) — synthesized procedurally, since it's a
##    seamless drone rather than a one-shot effect. The kick/impact/zap/UI
##    one-shots in placeholder_sfx.gd are real recorded/sourced audio now;
##    everything still synthesized here is a loop or ambience bed, not a
##    discrete effect.
## 3. Layered procedural music driven by Factory Energy (set_energy):
##    calm piano always → ambient pad as the factory stirs → full arp/bass
##    mix near 100%. All three loops play in sync permanently; energy only
##    fades their volumes, so layers blend instead of restarting.

const HOVER_SCALE := 1.05
const HOVER_TWEEN_TIME := 0.08
const HUM_VOLUME_DB := -22.0

## One musical phrase: 8 beats at 75 BPM. All layers share it so they stay
## in step just by starting together.
const MUSIC_LOOP_SECONDS := 6.4
const PIANO_DB := -14.0
const PAD_DB := -17.0
const FULL_DB := -15.0
const OFF_DB := -60.0

var _hum_player: AudioStreamPlayer
var _music_layers: Dictionary = {}  # name -> AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons(get_tree().root)
	_start_ambient_hum()
	_start_music()

## Factory Energy (0..100) → music intensity. Piano is always present;
## the pad breathes in from ~30%; the full layer completes it from ~65%.
func set_energy(pct: float) -> void:
	var t := clampf(pct / 100.0, 0.0, 1.0)
	_fade_layer("pad", lerpf(0.0, 1.0, clampf((t - 0.3) / 0.5, 0.0, 1.0)), PAD_DB)
	_fade_layer("full", lerpf(0.0, 1.0, clampf((t - 0.65) / 0.35, 0.0, 1.0)), FULL_DB)

func _fade_layer(layer_name: String, mix: float, full_db: float) -> void:
	var player: AudioStreamPlayer = _music_layers.get(layer_name)
	if player == null:
		return
	var target_db := OFF_DB if mix <= 0.001 else lerpf(OFF_DB * 0.35, full_db, mix)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, 2.5)

func _start_music() -> void:
	_music_layers["piano"] = _make_music_player(_synthesize_piano_loop(), PIANO_DB)
	_music_layers["pad"] = _make_music_player(_synthesize_pad_loop(), OFF_DB)
	_music_layers["full"] = _make_music_player(_synthesize_full_loop(), OFF_DB)

func _make_music_player(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = db
	add_child(player)
	player.play()
	return player

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

## Synthesized ambient bed: a few slightly-detuned low sine layers (for a
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

	return _make_looping_wav(samples, sample_rate)

func _make_looping_wav(samples: PackedFloat32Array, sample_rate: float) -> AudioStreamWAV:
	var n := samples.size()
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

# --- PLACEHOLDER music loops (procedural, same spirit as PlaceholderSFX;
# swap for real tracks by loading streams into _make_music_player). All
# share MUSIC_LOOP_SECONDS and the A-minor pentatonic world so they can
# stack in any combination. ---

const MUSIC_SAMPLE_RATE := 22050.0

## Rounds a frequency so it completes whole cycles inside the loop —
## otherwise sustained tones click at the loop seam.
func _loopable(freq: float) -> float:
	return round(freq * MUSIC_LOOP_SECONDS) / MUSIC_LOOP_SECONDS

## Layer 1 — calm piano: a soft, hopeful 8-note phrase, one note per beat,
## long decays overlapping like held pedal.
func _synthesize_piano_loop() -> AudioStreamWAV:
	var n := int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var beat := MUSIC_LOOP_SECONDS / 8.0
	# A4, C5, E5, D5 / C5, E5, G5, E5 — rises and settles, hopeful not sad.
	var notes := [440.0, 523.25, 659.25, 587.33, 523.25, 659.25, 783.99, 659.25]
	for note_index in notes.size():
		var freq: float = notes[note_index]
		var start := int(note_index * beat * MUSIC_SAMPLE_RATE)
		var remaining := n - start
		for i in mini(remaining, int(MUSIC_SAMPLE_RATE * 2.0)):
			var t: float = i / MUSIC_SAMPLE_RATE
			var env: float = exp(-t * 2.2) * minf(t * 60.0, 1.0)
			var tone: float = sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t) + 0.1 * sin(TAU * freq * 3.0 * t)
			samples[start + i] += tone * env * 0.24
	for i in n:
		samples[i] = clampf(samples[i], -1.0, 1.0)
	return _make_looping_wav(samples, MUSIC_SAMPLE_RATE)

## Layer 2 — ambient pad: a sustained Am(add9) chord with slow breathing
## tremolo. Frequencies are loop-aligned so the sustain never clicks.
func _synthesize_pad_loop() -> AudioStreamWAV:
	var n := int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var chord := [_loopable(110.0), _loopable(164.81), _loopable(220.0), _loopable(246.94), _loopable(329.63)]
	var lfo := _loopable(0.3125)  # 2 full breaths per loop
	for i in n:
		var t: float = i / MUSIC_SAMPLE_RATE
		var breath: float = 0.6 + 0.4 * sin(TAU * lfo * t)
		var v := 0.0
		for freq in chord:
			v += sin(TAU * freq * t)
		samples[i] = clampf(v / chord.size() * breath * 0.5, -1.0, 1.0)
	return _make_looping_wav(samples, MUSIC_SAMPLE_RATE)

## Layer 3 — full mix top: soft bass pulses on each beat plus a quiet
## 16th-note arpeggio shimmer. Stacks on top of piano+pad for the climax.
func _synthesize_full_loop() -> AudioStreamWAV:
	var n := int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var beat := MUSIC_LOOP_SECONDS / 8.0
	# Bass: A1 pulses, every beat.
	for b in 8:
		var start := int(b * beat * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.45)):
			var t: float = i / MUSIC_SAMPLE_RATE
			var env: float = exp(-t * 6.0) * minf(t * 90.0, 1.0)
			samples[start + i] += sin(TAU * 55.0 * t) * env * 0.4
	# Arp: A5/C6/E6/A6 climbing, four per beat, very quiet sparkle.
	var arp := [880.0, 1046.5, 1318.5, 1760.0]
	var step := beat / 4.0
	for s in 32:
		var freq: float = arp[s % 4]
		var start := int(s * step * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.18)):
			var t: float = i / MUSIC_SAMPLE_RATE
			var env: float = exp(-t * 14.0) * minf(t * 200.0, 1.0)
			samples[start + i] += sin(TAU * freq * t) * env * 0.12
	for i in n:
		samples[i] = clampf(samples[i], -1.0, 1.0)
	return _make_looping_wav(samples, MUSIC_SAMPLE_RATE)
