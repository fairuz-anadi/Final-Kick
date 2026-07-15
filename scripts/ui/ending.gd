extends Control
## Ending screen. Shown after the last level's win screen.

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
