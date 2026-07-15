extends Node
## Autoload ("LevelFlow"). Godot's change_scene_to_file() can't pass
## parameters, so this is the handoff: ResultScreen calls go_to_level()
## instead of changing the scene directly, and if the destination has an
## intro screen, that's shown first with this path stashed for it to read.

var next_level_path: String = ""

## Levels that get a story/description interstitial before they start.
## Anything not listed here (e.g. the ending, or level_1 — reached straight
## from the title screen, not "after" a level) loads directly instead.
const HAS_INTRO := {
	"res://scenes/levels/level_2.tscn": true,
	"res://scenes/levels/level_3.tscn": true,
	"res://scenes/levels/level_4.tscn": true,
	"res://scenes/levels/level_5.tscn": true,
}

func go_to_level(path: String) -> void:
	if HAS_INTRO.has(path):
		next_level_path = path
		get_tree().change_scene_to_file("res://scenes/ui/level_intro.tscn")
	else:
		get_tree().change_scene_to_file(path)
