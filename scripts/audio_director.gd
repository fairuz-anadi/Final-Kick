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
##    an upbeat synth groove (kick/hats/bouncy bass) always → a plucky
##    lead hook as the factory stirs → sparkle arps + claps near 100%.
##    All three loops play in sync permanently; energy only fades their
##    volumes, so layers blend instead of restarting.

const HOVER_SCALE := 1.05
const HOVER_TWEEN_TIME := 0.08
const HUM_VOLUME_DB := -22.0

## One musical phrase: 16 beats at 120 BPM. All layers share it so they stay
## in step just by starting together.
const MUSIC_LOOP_SECONDS := 8.0
const GROOVE_DB := -13.0
const MELODY_DB := -14.0
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

## Factory Energy (0..100) → music intensity. The groove is always present;
## the melody breathes in from ~30%; the full layer completes it from ~65%.
func set_energy(pct: float) -> void:
	var t := clampf(pct / 100.0, 0.0, 1.0)
	_fade_layer("melody", lerpf(0.0, 1.0, clampf((t - 0.3) / 0.5, 0.0, 1.0)), MELODY_DB)
	_fade_layer("full", lerpf(0.0, 1.0, clampf((t - 0.65) / 0.35, 0.0, 1.0)), FULL_DB)

func _fade_layer(layer_name: String, mix: float, full_db: float) -> void:
	var player: AudioStreamPlayer = _music_layers.get(layer_name)
	if player == null:
		return
	var target_db := OFF_DB if mix <= 0.001 else lerpf(OFF_DB * 0.35, full_db, mix)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, 2.5)

func _start_music() -> void:
	_music_layers["groove"] = _make_music_player(_synthesize_groove_loop(), GROOVE_DB)
	_music_layers["melody"] = _make_music_player(_synthesize_melody_loop(), OFF_DB)
	_music_layers["full"] = _make_music_player(_synthesize_full_loop(), OFF_DB)

func _make_music_player(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = db
	player.bus = "Music"
	add_child(player)
	player.play()
	return player

## Silence the procedural groove + hum while a scene plays a real music track
## of its own (story cinematic, level-clear screen). Stopped, not muted, so
## the replacement track can live on the Music bus and still respect the
## player's music volume setting.
func suspend_music() -> void:
	if _hum_player:
		_hum_player.stop()
	for player in _music_layers.values():
		player.stop()

## Bring the groove back after a suspend. All layers restart together, which
## is also what keeps them beat-synced (they only ever align by starting at
## the same instant — see MUSIC_LOOP_SECONDS).
func resume_music() -> void:
	if _hum_player and not _hum_player.playing:
		_hum_player.play()
	for player in _music_layers.values():
		if not player.playing:
			player.play()

## Briefly pulls the Music bus down so a big SFX stinger (MAX POWER, level
## complete, shutdown) actually reads as loud instead of getting buried in
## the groove — a few uses only, not called per-hit, or it'd pump/flutter.
func duck_music(amount_db: float = 6.0, hold_time: float = 0.3, recover_time: float = 0.6) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		return
	var tween := create_tween()
	tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db), 0.0, -amount_db, 0.1)
	tween.tween_interval(hold_time)
	tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db), -amount_db, 0.0, recover_time)

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
	_hum_player.bus = "Music"
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
# share MUSIC_LOOP_SECONDS (16 beats @ 120 BPM) and the A-major pentatonic
# world (A B C# E F#) so they can stack in any combination and nothing
# ever clashes. ---

const MUSIC_SAMPLE_RATE := 22050.0
const BEAT := MUSIC_LOOP_SECONDS / 16.0  # 0.5s — 120 BPM

## Layer 1 — the groove (always on): four-on-the-floor kick, off-beat hats,
## and a bouncy octave bass line. Upbeat from the very first second, even
## before any machine wakes.
func _synthesize_groove_loop() -> AudioStreamWAV:
	var n := int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	# Kick drum on every beat: a pitch-dropping sine thump with a tiny click.
	for b in 16:
		var start := int(b * BEAT * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.22)):
			var t: float = i / MUSIC_SAMPLE_RATE
			var freq: float = 42.0 + 70.0 * exp(-t * 28.0)
			var env: float = exp(-t * 16.0)
			samples[start + i] += sin(TAU * freq * t) * env * 0.75

	# Hats on the off-beats: short bright noise ticks — the bounce.
	for b in 16:
		var start := int((b * BEAT + BEAT * 0.5) * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.05)):
			var t: float = i / MUSIC_SAMPLE_RATE
			samples[start + i] += rng.randf_range(-1.0, 1.0) * exp(-t * 110.0) * 0.22

	# Bass: octave-bounce eighth notes over A / F# / E / A — root on the
	# beat, octave-up on the "and". Saw-ish tone so it cuts through.
	var bar_roots := [110.0, 92.5, 82.41, 110.0]  # A2, F#2, E2, A2
	for b in 16:
		var root: float = bar_roots[floori(b / 4.0)]
		for half in 2:
			var freq: float = root if half == 0 else root * 2.0
			var start := int((b * BEAT + half * BEAT * 0.5) * MUSIC_SAMPLE_RATE)
			for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.20)):
				var t: float = i / MUSIC_SAMPLE_RATE
				var env: float = exp(-t * 9.0) * minf(t * 300.0, 1.0)
				var tone: float = sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 2.0 * t) + 0.2 * sin(TAU * freq * 3.0 * t)
				samples[start + i] += tone * env * 0.30

	for i in n:
		samples[i] = clampf(samples[i], -1.0, 1.0)
	return _make_looping_wav(samples, MUSIC_SAMPLE_RATE)

## Layer 2 — the hook: a plucky, cheerful lead melody, one note per beat.
## Fades in as the factory stirs — the moment the level starts going well,
## the music starts singing.
func _synthesize_melody_loop() -> AudioStreamWAV:
	var n := int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(n)
	# A-major pentatonic hook: rises, bounces, resolves home — hopeful and hummable.
	var notes := [
		329.63, 440.0, 493.88, 554.37,   # E4  A4  B4  C#5
		659.25, 554.37, 493.88, 440.0,   # E5  C#5 B4  A4
		369.99, 440.0, 493.88, 659.25,   # F#4 A4  B4  E5
		554.37, 493.88, 440.0, 493.88,   # C#5 B4  A4  B4
	]
	for note_index in notes.size():
		var freq: float = notes[note_index]
		var start := int(note_index * BEAT * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.55)):
			var t: float = i / MUSIC_SAMPLE_RATE
			var env: float = exp(-t * 5.0) * minf(t * 200.0, 1.0)
			var tone: float = sin(TAU * freq * t) + 0.4 * sin(TAU * freq * 2.0 * t) + 0.15 * sin(TAU * freq * 3.0 * t)
			samples[start + i] += tone * env * 0.22
	for i in n:
		samples[i] = clampf(samples[i], -1.0, 1.0)
	return _make_looping_wav(samples, MUSIC_SAMPLE_RATE)

## Layer 3 — full mix top: 16th-note sparkle arps plus claps on beats 2 & 4.
## Stacks on top of the groove + hook for the near-fully-awake climax.
func _synthesize_full_loop() -> AudioStreamWAV:
	var n := int(MUSIC_SAMPLE_RATE * MUSIC_LOOP_SECONDS)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41

	# Sparkle: A5/C#6/E6/A6 climbing 16ths, quiet glitter over everything.
	var arp := [880.0, 1108.73, 1318.51, 1760.0]
	var step := BEAT / 2.0
	for s in 32:
		var freq: float = arp[s % 4]
		var start := int(s * step * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.14)):
			var t: float = i / MUSIC_SAMPLE_RATE
			var env: float = exp(-t * 16.0) * minf(t * 250.0, 1.0)
			samples[start + i] += sin(TAU * freq * t) * env * 0.11

	# Claps on beats 2 and 4 of every bar: layered noise bursts.
	for b in 16:
		if b % 4 != 1 and b % 4 != 3:
			continue
		var start := int(b * BEAT * MUSIC_SAMPLE_RATE)
		for i in mini(n - start, int(MUSIC_SAMPLE_RATE * 0.09)):
			var t: float = i / MUSIC_SAMPLE_RATE
			samples[start + i] += rng.randf_range(-1.0, 1.0) * exp(-t * 45.0) * 0.32

	for i in n:
		samples[i] = clampf(samples[i], -1.0, 1.0)
	return _make_looping_wav(samples, MUSIC_SAMPLE_RATE)
