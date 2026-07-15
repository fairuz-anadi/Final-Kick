extends Node
## Autoload ("NarratorManager"). The voice of the factory — short, sparse
## lines shown as cinematic subtitles on their own CanvasLayer, so every
## scene (levels, cinematic, ending) can trigger narration with one call.
##
## There are no recorded voice lines (jam constraint), so each line is
## "spoken" as a subtitle plus a soft narrator chime (PlaceholderSFX). Swap
## in real VO later by playing a stream inside _show_next_line().
##
## Wiring: HUD._ready calls play_level_intro(scene_path); LifeManager calls
## on_death()/on_last_life(); the ending scene calls play_final_completion().

const LEVEL_LINES := {
	"res://scenes/levels/level_1.tscn": ["One gear remains.", "Wake it."],
	"res://scenes/levels/level_2.tscn": ["Power needs a path.", "Help it find one."],
	"res://scenes/levels/level_3.tscn": ["He always said machines are like people.", "They work better together."],
	"res://scenes/levels/level_4.tscn": ["This is the room he spoke about.", "Wake them all."],
	"res://scenes/levels/level_5.tscn": ["The line breaks here.", "Reach the far side — whatever it takes."],
}

## Spoken once the level's last machine wakes — small rewards that keep
## the Worker present between rooms.
const LEVEL_COMPLETE_LINES := {
	"res://scenes/levels/level_2.tscn": ["Power always finds a way."],
	"res://scenes/levels/level_3.tscn": ["He spent years maintaining this place."],
	"res://scenes/levels/level_4.tscn": ["He knew you would make it."],
	"res://scenes/levels/level_5.tscn": ["Even the gap couldn't stop you."],
}

const DEATH_LINE := "Not every kick finds its target."
const THREE_HEARTS_LINE := "Steady. You were built for this."
const LAST_LIFE_LINE := "Careful. The factory is counting on you."
const FINAL_LINES := ["Listen.", "Do you hear it?", "That's life."]

## Seconds between repeatable one-off lines (deaths) so rapid falls
## don't turn the narrator into a nag.
const DEATH_LINE_COOLDOWN := 8.0

var _queue: Array[String] = []
var _speaking: bool = false
var _death_line_cooldown_left: float = 0.0

var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_subtitle_ui()

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
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.3)

func play_level_intro(scene_path: String) -> void:
	clear()
	if LEVEL_LINES.has(scene_path):
		# Small delay so the line lands after the level fades in, not during.
		await get_tree().create_timer(0.8).timeout
		say(LEVEL_LINES[scene_path])

func play_level_complete(scene_path: String) -> void:
	if LEVEL_COMPLETE_LINES.has(scene_path):
		clear()
		say(LEVEL_COMPLETE_LINES[scene_path])

func on_death() -> void:
	if _death_line_cooldown_left > 0.0 or _speaking:
		return
	_death_line_cooldown_left = DEATH_LINE_COOLDOWN
	say([DEATH_LINE])

## The 3-hearts-left state: one steadying comment, cuts ahead of any
## pending death line so the escalation reads clearly.
func on_three_hearts() -> void:
	_queue.clear()
	_speaking = false
	say([THREE_HEARTS_LINE])

func on_last_life() -> void:
	# The stakes line always cuts through, even mid-sentence.
	_queue.clear()
	_speaking = false
	say([LAST_LIFE_LINE])

func play_final_completion() -> void:
	clear()
	say(FINAL_LINES)

func _show_next_line() -> void:
	if _queue.is_empty():
		_speaking = false
		return
	_speaking = true
	var line: String = _queue.pop_front()
	_label.text = line
	PlaceholderSFX.play_narrator_blip()

	# Hold time scales with line length so short punches stay punchy.
	var hold := 1.6 + line.length() * 0.055
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(hold)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.5)
	tween.tween_interval(0.25)
	tween.tween_callback(_show_next_line)

func _build_subtitle_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 80
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.modulate.a = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bottom-center cinematic subtitle position, floated above the charge bar.
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -190.0
	_panel.offset_bottom = -140.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.1, 0.75)  # dark navy glass
	style.border_color = Color(0.22, 0.78, 0.84, 0.35)  # faint cyan edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
