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

func _on_settings_pressed() -> void:
	SettingsPanel.open()

func _on_difficulty_pressed() -> void:
	DifficultyPanel.open()
