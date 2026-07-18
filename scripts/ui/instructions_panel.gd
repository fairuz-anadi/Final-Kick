extends CanvasLayer
## Autoload ("InstructionsPanel"). The "HOW TO PLAY" manual — shared by the
## title screen and the pause menu so both open the exact same overlay
## instead of duplicating content. Lives above everything (layer 20) and
## runs while the tree is paused, so it works whether a level is currently
## running or not. Never shown during live gameplay itself — only from
## those two entry points.

@onready var _panel: Control = %Panel

func _ready() -> void:
	_panel.visible = false

func open() -> void:
	_panel.visible = true

func is_open() -> bool:
	return _panel.visible

func _on_back_pressed() -> void:
	_panel.visible = false
