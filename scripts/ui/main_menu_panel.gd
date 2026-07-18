extends CanvasLayer
## Autoload ("MainMenuPanel"). The title screen's five secondary options
## (Difficulty, How To Play, Settings, Story, Leaderboard) collapsed behind
## one "MAIN MENU" button instead of a full row. Sits below the other
## overlays (layer 19) so opening one of them from here layers on top —
## closing that overlay drops the player back into this menu, not straight
## to the title screen.

@onready var _panel: Control = %Panel

func _ready() -> void:
	_panel.visible = false

func open() -> void:
	_panel.visible = true

func is_open() -> bool:
	return _panel.visible

func _on_back_pressed() -> void:
	_panel.visible = false

func _on_difficulty_pressed() -> void:
	DifficultyPanel.open()

func _on_how_to_play_pressed() -> void:
	InstructionsPanel.open()

func _on_settings_pressed() -> void:
	SettingsPanel.open()

func _on_story_pressed() -> void:
	# A written story page (StoryPanel overlay), NOT a replay of the opening
	# cinematic — changing scene here yanked the player out of the menu.
	StoryPanel.open()

func _on_leaderboard_pressed() -> void:
	LeaderboardPanel.open()
