extends CanvasLayer
## Pause menu. ESC (ui_cancel) toggles. The root CanvasLayer runs
## with process_mode ALWAYS (set in the scene) so it keeps receiving input
## while the tree is paused. Holds the full controls reference.

@onready var _panel: Control = %Panel

func _ready() -> void:
	_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	_panel.visible = tree.paused

func _on_resume_pressed() -> void:
	toggle()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_how_to_play_pressed() -> void:
	InstructionsPanel.open()

func _on_settings_pressed() -> void:
	SettingsPanel.open()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
