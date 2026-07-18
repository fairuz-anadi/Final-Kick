extends Control
## Title screen. Entry point of the game — Start prompts for a leaderboard
## name first, then loads the current playable level. Space (the "kick"
## action) also starts, so the first input the game teaches is the same one
## the whole game runs on — but only while the name prompt isn't up.

@export var start_scene: String = "res://scenes/levels/level_1.tscn"

@onready var _name_prompt: Control = %NamePrompt
@onready var _name_edit: LineEdit = %NameEdit

func _ready() -> void:
	_name_prompt.visible = false
	_name_edit.text = Leaderboard.pending_name

func _unhandled_input(event: InputEvent) -> void:
	if _name_prompt.visible:
		return
	if event.is_action_pressed("kick"):
		_on_start_pressed()

func _on_start_pressed() -> void:
	_name_prompt.visible = true
	_name_edit.grab_focus()

## Bound to both the name field's "text_submitted" (Enter key) and the Go
## button's "pressed" — the latter carries no argument, hence the default.
func _on_name_confirmed(_text: String = "") -> void:
	Leaderboard.pending_name = _name_edit.text.strip_edges()
	ScoreManager.reset_run()
	SceneTransition.go(start_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_main_menu_pressed() -> void:
	MainMenuPanel.open()
