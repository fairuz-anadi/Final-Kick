extends Control
## Title screen. Entry point of the game — Start loads the current
## playable level. Space (the "kick" action) also starts, so the first input
## the game teaches is the same one the whole game runs on.

@export var start_scene: String = "res://scenes/levels/level_1.tscn"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("kick"):
		_on_start_pressed()

func _on_start_pressed() -> void:
	ScoreManager.reset_run()
	get_tree().change_scene_to_file(start_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_how_to_play_pressed() -> void:
	InstructionsPanel.open()

# The three difficulty buttons share a ButtonGroup (radio-button behavior),
# so exactly one of these fires with `pressed = true` per selection change —
# the others fire `false` as they get deselected, which is ignored here.
func _on_easy_toggled(pressed: bool) -> void:
	if pressed:
		Difficulty.current = Difficulty.Level.EASY

func _on_medium_toggled(pressed: bool) -> void:
	if pressed:
		Difficulty.current = Difficulty.Level.MEDIUM

func _on_hard_toggled(pressed: bool) -> void:
	if pressed:
		Difficulty.current = Difficulty.Level.HARD
