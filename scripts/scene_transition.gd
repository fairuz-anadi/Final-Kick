extends CanvasLayer
## Autoload ("SceneTransition"). Every level/screen change (except the
## opening cinematic's own bespoke flash-cut) should route through go() or
## reload() instead of calling change_scene_to_file()/reload_current_scene()
## directly, so switching screens reads as a quick fade rather than a hard
## cut. Sits above every other overlay and runs even while the tree is
## paused (pause menu's "MAIN MENU" fades out while paused).

const FADE_TIME := 0.22

@onready var _fade: ColorRect = %Fade

func _ready() -> void:
	_fade.color.a = 0.0

## Fades to black, swaps to `path`, then fades back in.
func go(path: String) -> void:
	_swap(func() -> void: get_tree().change_scene_to_file(path))

## Same fade wrapped around reload_current_scene() — used for level retry/restart.
func reload() -> void:
	_swap(func() -> void: get_tree().reload_current_scene())

func _swap(swap_callable: Callable) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(swap_callable)
	tween.tween_property(_fade, "color:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
