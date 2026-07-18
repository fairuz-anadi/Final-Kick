extends CanvasLayer
## Autoload ("StoryPanel"). The game's backstory as a written page — same
## reusable-overlay pattern as InstructionsPanel/LeaderboardPanel, opened
## from the title screen's main menu. Deliberately NOT a replay of the
## opening cinematic (the STORY button used to change scene to it, which
## yanked the player out of the menu) — this is the read-at-your-own-pace
## version of the same canon.

@onready var _panel: Control = %Panel

func _ready() -> void:
	_panel.visible = false

func open() -> void:
	_panel.visible = true

func is_open() -> bool:
	return _panel.visible

func _on_back_pressed() -> void:
	_panel.visible = false
