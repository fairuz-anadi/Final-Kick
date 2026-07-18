extends Node
## Autoload ("NarratorManager"). The voice of the factory — short, sparse
## lines queued and paced one after another, so every scene (levels,
## cinematic, ending) can trigger narration with one call.
##
## Audio-only: no on-screen subtitle box (removed — it had no way to avoid
## covering the ball, since its screen position is fixed but the ball's
## isn't, across levels with very different camera framing). Each line is
## just a soft narrator chime (PlaceholderSFX), paced by _show_next_line()'s
## timer. Swap in real VO later by playing a stream there instead.
##
## Wiring: HUD._ready calls play_level_intro(scene_path); LifeManager calls
## on_death()/on_power_critical(); the ending scene calls play_final_completion().

const LEVEL_LINES := {
	"res://scenes/levels/level_1.tscn": ["One gear remains.", "Wake it."],
	"res://scenes/levels/level_2.tscn": ["Power needs a path.", "Help it find one."],
	"res://scenes/levels/level_3.tscn": ["He always said machines are like people.", "They work better together."],
	"res://scenes/levels/level_4.tscn": ["This is the room he spoke about.", "Wake them all."],
	"res://scenes/levels/level_5.tscn": ["The line breaks here.", "Reach the far side — whatever it takes."],
	"res://scenes/levels/level_6.tscn": ["He built this gate after the accident.", "Some power should cost something."],
	"res://scenes/levels/level_7.tscn": ["He walked this hall every morning.", "He greeted every machine by name."],
	"res://scenes/levels/level_8.tscn": ["His notes warn: the vials never wait.", "Chemistry keeps its own schedule."],
	"res://scenes/levels/level_9.tscn": ["He dreamed of being two places at once.", "So he built the echo."],
	"res://scenes/levels/level_10.tscn": ["His final page says only:", "'Everything, once more.'"],
}

## Spoken once the level's last machine wakes — small rewards that keep
## the Worker present between rooms.
const LEVEL_COMPLETE_LINES := {
	"res://scenes/levels/level_2.tscn": ["Power always finds a way."],
	"res://scenes/levels/level_3.tscn": ["He spent years maintaining this place."],
	"res://scenes/levels/level_4.tscn": ["He knew you would make it."],
	"res://scenes/levels/level_5.tscn": ["Even the gap couldn't stop you."],
	"res://scenes/levels/level_6.tscn": ["The gate remembers him kindly."],
	"res://scenes/levels/level_7.tscn": ["Every machine, greeted by name."],
	"res://scenes/levels/level_8.tscn": ["Right on schedule after all."],
	"res://scenes/levels/level_9.tscn": ["Two kicks. One heart."],
	"res://scenes/levels/level_10.tscn": ["Listen. The whole factory is singing."],
}

const DEATH_LINE := "Not every kick finds its target."
const POWER_CRITICAL_LINE := "The power is slipping away. Wake a machine."
## Spoken once per session, on the very first lost ball — the game's only
## teaching of the rewind mechanic, kept diegetic since the HUD carries no
## instruction text.
const REWIND_TEACH_LINES := ["I can turn back time for you.", "Hold R. The arrows steer the past."]
const FINAL_LINES := ["Listen.", "Do you hear it?", "That's life."]

## Seconds between repeatable one-off lines (deaths) so rapid falls
## don't turn the narrator into a nag.
const DEATH_LINE_COOLDOWN := 8.0

var _queue: Array[String] = []
var _speaking: bool = false
var _death_line_cooldown_left: float = 0.0
var _rewind_taught: bool = false
## Bumped by clear(). The pacing timers below are one-shots that can't be
## cancelled, so an interrupt (power-critical line, level change) would
## otherwise leave a stale timer alive that re-enters _show_next_line and
## runs a SECOND chain in parallel — lines firing at double speed. Stale
## timers compare their captured generation and bow out instead.
var _generation: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if _death_line_cooldown_left > 0.0:
		_death_line_cooldown_left -= delta

## Queue a list of lines; they play one after another.
func say(lines: Array) -> void:
	for line in lines:
		_queue.append(str(line))
	if not _speaking:
		_show_next_line()

## Wipe pending narration immediately (e.g. factory shutdown cuts the voice off).
func clear() -> void:
	_queue.clear()
	_speaking = false
	_generation += 1

func play_level_intro(scene_path: String) -> void:
	clear()
	var gen := _generation
	if LEVEL_LINES.has(scene_path):
		# Small delay so the line lands after the level fades in, not during.
		await get_tree().create_timer(0.8).timeout
		# Another clear()/intro happened during the delay (rapid scene change,
		# blackout) — this intro belongs to a level the player already left.
		if gen == _generation:
			say(LEVEL_LINES[scene_path])

func play_level_complete(scene_path: String) -> void:
	if LEVEL_COMPLETE_LINES.has(scene_path):
		clear()
		say(LEVEL_COMPLETE_LINES[scene_path])

func on_death() -> void:
	# The first lost ball of the session is the perfect moment to reveal the
	# rewind — the player just wished they could undo something.
	if not _rewind_taught:
		_rewind_taught = true
		clear()  # also bumps _generation, killing any in-flight pacing chain
		say(REWIND_TEACH_LINES)
		return
	if _death_line_cooldown_left > 0.0 or _speaking:
		return
	_death_line_cooldown_left = DEATH_LINE_COOLDOWN
	say([DEATH_LINE])

## Energy critically low after real progress: the stakes line always cuts
## through, even mid-sentence.
func on_power_critical() -> void:
	clear()  # also bumps _generation, killing any in-flight pacing chain
	say([POWER_CRITICAL_LINE])

func play_final_completion() -> void:
	clear()
	say(FINAL_LINES)

## No on-screen subtitle box — narration is audio-only (the chime below),
## just paced the same way the old subtitle timing was so multiple queued
## lines still play back to back instead of firing all at once.
func _show_next_line() -> void:
	if _queue.is_empty():
		_speaking = false
		return
	_speaking = true
	var line: String = _queue.pop_front()
	PlaceholderSFX.play_narrator_blip()

	var hold := 1.6 + line.length() * 0.055
	var gen := _generation
	get_tree().create_timer(hold + 0.25).timeout.connect(func() -> void:
		if gen == _generation:
			_show_next_line())
